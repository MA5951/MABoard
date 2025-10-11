import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

/// ReefGamePieceStatus
/// --------------------
/// A simple multi-topic display for 2025 FRC Reefscape that shows two images:
/// - Left: Coral
/// - Right: Algae
/// Both are dimmed (30% opacity) by default. When the corresponding NT topic
/// is true, that image becomes fully opaque (highlighted).
///
/// Root topic should point to the SuperStructure table (e.g., '/MALog/SuperStructure').
/// It reads:
///   - '<root>/is Coral'  (boolean)
///   - '<root>/is algea'  (boolean)  // name matches your NT topic spelling
///
/// NOTE: Update the asset paths below to point to your actual image files.
class ReefGamePieceStatusModel extends MultiTopicNTWidgetModel {
  @override
  String type = ReefGamePieceStatus.widgetType;

  // Topics are derived from the provided root `topic`
  String get coralTopic => '$topic/Coral';
  String get algaeTopic => '$topic/Alge'; // keeping spelling as provided

  // Subscriptions
  late NT4Subscription coralSub;
  late NT4Subscription algaeSub;

  // Images (customize these to your asset locations)
  String coralAssetPath;
  String algaeAssetPath;

  // Base (dimmed) opacity when not selected
  double baseOpacity;

  ReefGamePieceStatusModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    this.coralAssetPath = 'assets/reefscape/coral.png',
    this.algaeAssetPath = 'assets/reefscape/algae.png',
    this.baseOpacity = 0.30,
    super.period,
  }) : super();

  ReefGamePieceStatusModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : coralAssetPath =
           tryCast(jsonData['coral_asset']) ?? 'assets/reefscape/coral.png',
       algaeAssetPath =
           tryCast(jsonData['algae_asset']) ?? 'assets/reefscape/algae.png',
       baseOpacity = tryCast(jsonData['base_opacity']) ?? 0.30,
       super.fromJson(jsonData: jsonData);

  @override
  void initializeSubscriptions() {
    coralSub = ntConnection.subscribe(coralTopic, super.period);
    algaeSub = ntConnection.subscribe(algaeTopic, super.period);
  }

  @override
  List<NT4Subscription> get subscriptions => [coralSub, algaeSub];

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'coral_asset': coralAssetPath,
    'algae_asset': algaeAssetPath,
    'base_opacity': baseOpacity,
  };

  @override
  List<Widget> getEditProperties(BuildContext context) => [
    // very simple for now: allow base opacity tweak
    Row(
      children: [
        const SizedBox(width: 8),
        const Text('Base Opacity'),
        const SizedBox(width: 8),
        Expanded(
          child: Slider(
            value: baseOpacity.clamp(0.0, 1.0),
            min: 0.0,
            max: 1.0,
            divisions: 20,
            label: baseOpacity.toStringAsFixed(2),
            onChanged: (v) {
              baseOpacity = v;
              refresh();
            },
          ),
        ),
      ],
    ),
  ];
}

class ReefGamePieceStatus extends NTWidget {
  static const String widgetType = 'Reef GamePiece Status';
  const ReefGamePieceStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final ReefGamePieceStatusModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge(model.subscriptions),
      builder: (context, _) {
        final bool hasCoral = tryCast(model.coralSub.value) ?? false;
        final bool hasAlgae = tryCast(model.algaeSub.value) ?? false;

        final double coralOpacity = hasCoral ? 1.0 : model.baseOpacity;
        final double algaeOpacity = hasAlgae ? 1.0 : model.baseOpacity;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left: Coral
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.transparent,
                  ),
                  child: Opacity(
                    opacity: coralOpacity,
                    child: Image.asset(
                      model.coralAssetPath,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),

            // Right: Algae
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.transparent,
                  ),
                  child: Opacity(
                    opacity: algaeOpacity,
                    child: Image.asset(
                      model.algaeAssetPath,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
