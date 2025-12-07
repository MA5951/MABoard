import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

/// MALog Control
/// -------------
/// A multi-topic widget to monitor & control your MALog from the dashboard.
///
/// Root topic should point to the MALog SmartDashboard table:
///   e.g. '/SmartDashboard/MALog'
///
/// It reads/writes:
///   - '<root>/Recording'  (boolean)  // write true to start, false to stop
///   - '<root>/ElapsedSec' (number)   // read-only elapsed seconds
///   - '<root>/Mode'       (string)   // 'AUTO' | 'TELEOP' | 'TEST'
///   - '<root>/LogName'    (string)   // editable when not recording
class MALogControlModel extends MultiTopicNTWidgetModel {
  @override
  String type = MALogControl.widgetType;

  // Derived topics from provided root `topic`
  String get recordingTopic => '$topic/Recording';
  String get elapsedTopic => '$topic/ElapsedSec';
  String get modeTopic => '$topic/Mode';
  String get nameTopic => '$topic/LogName';

  // Subscriptions
  late NT4Subscription recordingSub;
  late NT4Subscription elapsedSub;
  late NT4Subscription modeSub;
  late NT4Subscription nameSub;

  // For editing the name (kept in sync with NT while not recording)
  TextEditingController? nameController;

  MALogControlModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic, // set this to '/SmartDashboard/MALog'
    super.period,
  }) : super();

  MALogControlModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData);

  @override
  void initializeSubscriptions() {
    recordingSub = ntConnection.subscribe(recordingTopic, super.period);
    elapsedSub = ntConnection.subscribe(elapsedTopic, super.period);
    modeSub = ntConnection.subscribe(modeTopic, super.period);
    nameSub = ntConnection.subscribe(nameTopic, super.period);
  }

  @override
  List<NT4Subscription> get subscriptions => [
    recordingSub,
    elapsedSub,
    modeSub,
    nameSub,
  ];

  // ---- Publishing helpers ----
  // We send values back to the robot by writing the same topic names.
  // NT stack will invoke the Sendable setters robot-side.
  void _send(String topicName, Object value) {
    // Get the announced topic object
    final ntTopic = ntConnection.getTopicFromName(topicName);
    if (ntTopic == null) {
      // Topic isn't announced yet; nothing to do
      return;
    }

    // If we haven't published this topic from the client yet, publish it
    final shouldPublish = !ntConnection.isTopicPublished(ntTopic);
    if (shouldPublish) {
      ntConnection.publishTopic(ntTopic);
    }

    // Now update the value
    ntConnection.updateDataFromTopic(ntTopic, value);
  }

  void publishRecording(bool recording) => _send(recordingTopic, recording);
  void publishMode(String mode) => _send(modeTopic, mode);
  void publishName(String name) => _send(nameTopic, name.trim());
}

class MALogControl extends NTWidget {
  static const String widgetType = 'MALog Control';
  const MALogControl({super.key});

  static const _modes = ['AUTO', 'TELEOP', 'TEST'];

  String _fmt(double s) {
    final int t = s.floor();
    final m = (t ~/ 60).toString().padLeft(2, '0');
    final ss = (t % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final MALogControlModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge(model.subscriptions),
      builder: (context, _) {
        final bool recording = tryCast<bool>(model.recordingSub.value) ?? false;
        final double elapsed =
            (tryCast<num>(model.elapsedSub.value)?.toDouble() ?? 0.0).clamp(
              0.0,
              double.infinity,
            );
        final String mode = (tryCast<String>(model.modeSub.value) ?? 'TELEOP')
            .toUpperCase();
        final String name = tryCast<String>(model.nameSub.value) ?? '';

        // Keep name controller in sync (but don't fight the user while recording)
        model.nameController ??= TextEditingController(text: name);
        if (!recording && model.nameController!.text != name) {
          model.nameController!.text = name;
        }

        final tt = Theme.of(context).textTheme;
        final label = tt.titleMedium!.copyWith(fontWeight: FontWeight.w600);
        final big = tt.headlineSmall!;
        final huge = tt.headlineMedium?.copyWith(fontWeight: FontWeight.w700);

        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status row
              Row(
                children: [
                  Icon(
                    recording ? Icons.fiber_manual_record : Icons.stop_circle,
                    color: recording ? Colors.red : Colors.grey,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(recording ? 'Recording' : 'Stopped', style: label),
                  const Spacer(),
                  Text(_fmt(elapsed), style: huge ?? big),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => model.publishRecording(!recording),
                    icon: Icon(recording ? Icons.stop : Icons.play_arrow),
                    label: Text(recording ? 'Stop' : 'Start'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Mode chooser
              Row(
                children: [
                  Text('Mode', style: label),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _modes.contains(mode) ? mode : 'TELEOP',
                    items: _modes
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(m, style: big),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) model.publishMode(v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Log name
              Text('Log Name', style: label),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: model.nameController,
                      enabled: !recording, // rename only when stopped
                      decoration: InputDecoration(
                        hintText: 'Enter log name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        isDense: true,
                      ),
                      onSubmitted: (v) {
                        if (!recording) model.publishName(v);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: recording
                        ? null
                        : () => model.publishName(model.nameController!.text),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
