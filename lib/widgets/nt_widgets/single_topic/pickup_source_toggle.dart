import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class PickupSourceToggleModel extends SingleTopicNTWidgetModel {
  @override
  String type = PickupSourceToggleWidget.widgetType;

  String floorAssetPath;
  String feederAssetPath;

  // Optional: what to show when value isn't 1 or 2
  int defaultMode; // 1=floor, 2=feeder

  PickupSourceToggleModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    this.floorAssetPath = 'assets/charged_up/floor_pickup.png',
    this.feederAssetPath = 'assets/charged_up/feeder_station.png',
    this.defaultMode = 1,
    super.ntStructMeta,
    super.dataType,
    super.period,
  }) : super();

  PickupSourceToggleModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : floorAssetPath =
           tryCast(jsonData['floor_asset']) ?? 'assets/charged_up/floor_pickup.png',
       feederAssetPath =
           tryCast(jsonData['feeder_asset']) ?? 'assets/charged_up/feeder_station.png',
       defaultMode = tryCast<num>(jsonData['default_mode'])?.toInt() ?? 1,
       super.fromJson(jsonData: jsonData);

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'floor_asset': floorAssetPath,
    'feeder_asset': feederAssetPath,
    'default_mode': defaultMode,
  };

  @override
  List<Widget> getEditProperties(BuildContext context) => [
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Pickup Source Toggle'),
        const SizedBox(height: 8),
        DialogTextInput(
          label: 'Floor Asset Path (value=1)',
          initialText: floorAssetPath,
          onSubmit: (v) {
            floorAssetPath = v.trim();
            refresh();
          },
        ),
        const SizedBox(height: 6),
        DialogTextInput(
          label: 'Feeder Asset Path (value=2)',
          initialText: feederAssetPath,
          onSubmit: (v) {
            feederAssetPath = v.trim();
            refresh();
          },
        ),
        const SizedBox(height: 6),
        DialogTextInput(
          label: 'Default Mode (1 or 2)',
          initialText: defaultMode.toString(),
          onSubmit: (v) {
            final parsed = int.tryParse(v.trim());
            if (parsed == null) return;
            defaultMode = (parsed == 2) ? 2 : 1;
            refresh();
          },
        ),
      ],
    ),
  ];
}

class PickupSourceToggleWidget extends NTWidget {
  static const String widgetType = 'Pickup Source Toggle';
  const PickupSourceToggleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final model = cast<PickupSourceToggleModel>(context.watch<NTWidgetModel>());

    return ValueListenableBuilder(
      valueListenable: model.subscription!,
      builder: (context, data, _) {
        final int raw = tryCast<num>(data)?.toInt() ?? model.defaultMode;
        final int mode = (raw == 2) ? 2 : 1;

        final String asset =
            (mode == 1) ? model.floorAssetPath : model.feederAssetPath;

        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            asset,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stack) => const DecoratedBox(
              decoration: BoxDecoration(color: Colors.black12),
              child: Center(child: Icon(Icons.broken_image)),
            ),
          ),
        );
      },
    );
  }
}
