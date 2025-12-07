import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/services/nt4_type.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class SubsystemStatusModel extends MultiTopicNTWidgetModel {
  @override
  String type = SubsystemStatus.widgetType;

  // root is your SmartDashboard table, e.g. "/SmartDashboard/Shooter"
  String get stateTopic => '$topic/State';
  String get canMoveTopic => '$topic/CanMove';
  String get modeTopic => '$topic/Mode';

  late NT4Subscription stateSub;
  late NT4Subscription canMoveSub;
  late NT4Subscription modeSub;

  SubsystemStatusModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic, // e.g. "/SmartDashboard/Shooter"
    super.period,
  }) : super();

  SubsystemStatusModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : super.fromJson(jsonData: jsonData);

  @override
  void initializeSubscriptions() {
    stateSub = ntConnection.subscribe(stateTopic, super.period);
    canMoveSub = ntConnection.subscribe(canMoveTopic, super.period);
    modeSub  = ntConnection.subscribe(modeTopic, super.period);
  }

  @override
  List<NT4Subscription> get subscriptions => [stateSub, canMoveSub, modeSub];

  Future<void> publishMode(String value) async {
    // Try to locate already-announced topic
    NT4Topic? t = ntConnection.getTopicFromName(modeTopic);

    // If not found (unlikely, robot publishes it), create a client topic
    t ??= ntConnection.publishNewTopic(modeTopic, NT4Type.string());

    if (!ntConnection.isTopicPublished(t)) {
      ntConnection.publishTopic(t);
    }
    ntConnection.updateDataFromTopic(t, value);
  }
}

class SubsystemStatus extends NTWidget {
  static const String widgetType = 'Subsystem Status';
  const SubsystemStatus({super.key});

  static const List<String> kModes = ['Automatic', 'Manual'];

  @override
  Widget build(BuildContext context) {
    final SubsystemStatusModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge(model.subscriptions),
      builder: (context, _) {
        final String  state   = tryCast<String>(model.stateSub.value) ?? '—';
        final bool    canMove = tryCast<bool>(model.canMoveSub.value) ?? false;
        final String  modeStr = tryCast<String>(model.modeSub.value) ?? 'Automatic';

        final TextStyle label = Theme.of(context).textTheme.bodyMedium!;
        final TextStyle value = Theme.of(context).textTheme.titleMedium!;

        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              _row('State', Text(state, style: value), value),
              const SizedBox(height: 8),
              _row(
                'Can Move',
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      canMove ? Icons.check_circle : Icons.cancel,
                      color: canMove ? Colors.green : Colors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    
                  ],
                ),
                value,
              ),
              const SizedBox(height: 8),
              _row(
                'Mode',
                _ModeChooser(
                  current: kModes.contains(modeStr) ? modeStr : 'Automatic',
                  onChanged: (m) => model.publishMode(m),
                ),
                value,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(String name, Widget trailing, TextStyle label) => Row(
    children: [
      Expanded(child: Text(name, style: label)),
      const SizedBox(width: 8),
      trailing,
    ],
  );
}

class _ModeChooser extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _ModeChooser({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: current,
      items: const [
        DropdownMenuItem(value: 'Automatic', child: Text('Automatic')),
        DropdownMenuItem(value: 'Manual', child: Text('Manual')),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
