import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_toggle_switch.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class ChargedUpScoringLevelModel extends SingleTopicNTWidgetModel {
  @override
  String type = ChargedUpScoringLevelWidget.widgetType;

  // --- Assets / layout ---
  String gridAssetPath;
  double imageAspectRatio; // width / height

  // --- Styling ---
  double activeFillOpacity;
  double inactiveFillOpacity;
  double borderWidth;
  double borderRadius;
  bool showLabels;
  bool labelOnlyWhenSelected;

  // --- Normalized rects (0..1) in image space ---
  // Level 1 = bottom, Level 2 = middle, Level 3 = top
  double l1x, l1y, l1w, l1h;
  double l2x, l2y, l2w, l2h;
  double l3x, l3y, l3w, l3h;

  ChargedUpScoringLevelModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    this.gridAssetPath = 'assets/charged_up/grid_side.png',
    this.imageAspectRatio = 612 / 408,
    this.activeFillOpacity = 0.35,
    this.inactiveFillOpacity = 0.05,
    this.borderWidth = 3.0,
    this.borderRadius = 8.0,
    this.showLabels = true,
    this.labelOnlyWhenSelected = true,

    // Defaults are "good enough" for your provided image, and editable in settings.
    // These are positioned on the right scoring area as three horizontal bands.
    this.l1x = 0.54,
    this.l1y = 0.74,
    this.l1w = 0.42,
    this.l1h = 0.14,

    this.l2x = 0.54,
    this.l2y = 0.46,
    this.l2w = 0.42,
    this.l2h = 0.14,

    this.l3x = 0.54,
    this.l3y = 0.18,
    this.l3w = 0.42,
    this.l3h = 0.14,

    super.ntStructMeta,
    super.dataType,
    super.period,
  }) : super();

  ChargedUpScoringLevelModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : gridAssetPath = tryCast(jsonData['grid_asset']) ?? 'assets/chargeup/grid.png',
       imageAspectRatio =
           tryCast<num>(jsonData['image_aspect_ratio'])?.toDouble() ??
           (612 / 408),
       activeFillOpacity =
           tryCast<num>(jsonData['active_fill_opacity'])?.toDouble() ?? 0.35,
       inactiveFillOpacity =
           tryCast<num>(jsonData['inactive_fill_opacity'])?.toDouble() ?? 0.05,
       borderWidth = tryCast<num>(jsonData['border_width'])?.toDouble() ?? 3.0,
       borderRadius =
           tryCast<num>(jsonData['border_radius'])?.toDouble() ?? 8.0,
       showLabels = tryCast(jsonData['show_labels']) ?? true,
       labelOnlyWhenSelected = tryCast(jsonData['label_only_selected']) ?? true,
       l1x = tryCast<num>(jsonData['l1x'])?.toDouble() ?? 0.54,
       l1y = tryCast<num>(jsonData['l1y'])?.toDouble() ?? 0.74,
       l1w = tryCast<num>(jsonData['l1w'])?.toDouble() ?? 0.42,
       l1h = tryCast<num>(jsonData['l1h'])?.toDouble() ?? 0.14,
       l2x = tryCast<num>(jsonData['l2x'])?.toDouble() ?? 0.54,
       l2y = tryCast<num>(jsonData['l2y'])?.toDouble() ?? 0.46,
       l2w = tryCast<num>(jsonData['l2w'])?.toDouble() ?? 0.42,
       l2h = tryCast<num>(jsonData['l2h'])?.toDouble() ?? 0.14,
       l3x = tryCast<num>(jsonData['l3x'])?.toDouble() ?? 0.54,
       l3y = tryCast<num>(jsonData['l3y'])?.toDouble() ?? 0.18,
       l3w = tryCast<num>(jsonData['l3w'])?.toDouble() ?? 0.42,
       l3h = tryCast<num>(jsonData['l3h'])?.toDouble() ?? 0.14,
       super.fromJson(jsonData: jsonData);

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'grid_asset': gridAssetPath,
    'image_aspect_ratio': imageAspectRatio,
    'active_fill_opacity': activeFillOpacity,
    'inactive_fill_opacity': inactiveFillOpacity,
    'border_width': borderWidth,
    'border_radius': borderRadius,
    'show_labels': showLabels,
    'label_only_selected': labelOnlyWhenSelected,
    'l1x': l1x,
    'l1y': l1y,
    'l1w': l1w,
    'l1h': l1h,
    'l2x': l2x,
    'l2y': l2y,
    'l2w': l2w,
    'l2h': l2h,
    'l3x': l3x,
    'l3y': l3y,
    'l3w': l3w,
    'l3h': l3h,
  };

  Widget _doubleField(
    String label,
    double value,
    void Function(double) setValue,
  ) {
    return DialogTextInput(
      label: label,
      initialText: value.toStringAsFixed(3),
      onSubmit: (text) {
        final v = double.tryParse(text);
        if (v == null) return;
        setValue(v);
        refresh();
      },
    );
  }

  @override
  List<Widget> getEditProperties(BuildContext context) => [
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Charged Up Scoring Level'),
        const SizedBox(height: 8),
        DialogTextInput(
          label: 'Grid Image Asset Path',
          initialText: gridAssetPath,
          onSubmit: (v) {
            gridAssetPath = v.trim();
            refresh();
          },
        ),
        const SizedBox(height: 6),
        _doubleField(
          'Image Aspect Ratio (W/H)',
          imageAspectRatio,
          (v) => imageAspectRatio = v,
        ),
        const SizedBox(height: 6),
        _doubleField(
          'Active Fill Opacity',
          activeFillOpacity,
          (v) => activeFillOpacity = v.clamp(0.0, 1.0),
        ),
        _doubleField(
          'Inactive Fill Opacity',
          inactiveFillOpacity,
          (v) => inactiveFillOpacity = v.clamp(0.0, 1.0),
        ),
        _doubleField(
          'Border Width',
          borderWidth,
          (v) => borderWidth = v.clamp(0.0, 20.0),
        ),
        _doubleField(
          'Border Radius',
          borderRadius,
          (v) => borderRadius = v.clamp(0.0, 50.0),
        ),
        const SizedBox(height: 6),
        DialogToggleSwitch(
          initialValue: showLabels,
          label: 'Show Labels',
          onToggle: (v) {
            showLabels = v;
            refresh();
          },
        ),
        DialogToggleSwitch(
          initialValue: labelOnlyWhenSelected,
          label: 'Label Only When Selected',
          onToggle: (v) {
            labelOnlyWhenSelected = v;
            refresh();
          },
        ),
        const SizedBox(height: 12),
        const Text('Rectangles (Normalized 0..1)'),
        const SizedBox(height: 6),

        const Text('Level 3 (Top)'),
        Row(
          children: [
            Expanded(child: _doubleField('x', l3x, (v) => l3x = v)),
            const SizedBox(width: 6),
            Expanded(child: _doubleField('y', l3y, (v) => l3y = v)),
          ],
        ),
        Row(
          children: [
            Expanded(child: _doubleField('w', l3w, (v) => l3w = v)),
            const SizedBox(width: 6),
            Expanded(child: _doubleField('h', l3h, (v) => l3h = v)),
          ],
        ),

        const SizedBox(height: 8),
        const Text('Level 2 (Middle)'),
        Row(
          children: [
            Expanded(child: _doubleField('x', l2x, (v) => l2x = v)),
            const SizedBox(width: 6),
            Expanded(child: _doubleField('y', l2y, (v) => l2y = v)),
          ],
        ),
        Row(
          children: [
            Expanded(child: _doubleField('w', l2w, (v) => l2w = v)),
            const SizedBox(width: 6),
            Expanded(child: _doubleField('h', l2h, (v) => l2h = v)),
          ],
        ),

        const SizedBox(height: 8),
        const Text('Level 1 (Bottom)'),
        Row(
          children: [
            Expanded(child: _doubleField('x', l1x, (v) => l1x = v)),
            const SizedBox(width: 6),
            Expanded(child: _doubleField('y', l1y, (v) => l1y = v)),
          ],
        ),
        Row(
          children: [
            Expanded(child: _doubleField('w', l1w, (v) => l1w = v)),
            const SizedBox(width: 6),
            Expanded(child: _doubleField('h', l1h, (v) => l1h = v)),
          ],
        ),
      ],
    ),
  ];
}

class ChargedUpScoringLevelWidget extends NTWidget {
  static const String widgetType = 'ChargedUp Scoring Level';
  const ChargedUpScoringLevelWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final model = cast<ChargedUpScoringLevelModel>(
      context.watch<NTWidgetModel>(),
    );

    // IMPORTANT: listen to BOTH model changes (edit UI) and NT value changes
    return ListenableBuilder(
      listenable: Listenable.merge([model, model.subscription!]),
      builder: (context, _) {
        final data = model.subscription!.value;
        final selected = (tryCast<num>(data)?.toInt() ?? 0).clamp(0, 3);

        return Center(
          child: AspectRatio(
            aspectRatio: model.imageAspectRatio <= 0
                ? (612 / 408)
                : model.imageAspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  model.gridAssetPath,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stack) => const DecoratedBox(
                    decoration: BoxDecoration(color: Colors.black12),
                    child: Center(child: Icon(Icons.broken_image)),
                  ),
                ),

                if (selected == 1)
                  _blinkingLevelRect(
                    model: model,
                    level: 1,
                    x: model.l1x,
                    y: model.l1y,
                    w: model.l1w,
                    h: model.l1h,
                  ),
                if (selected == 2)
                  _blinkingLevelRect(
                    model: model,
                    level: 2,
                    x: model.l2x,
                    y: model.l2y,
                    w: model.l2w,
                    h: model.l2h,
                  ),
                if (selected == 3)
                  _blinkingLevelRect(
                    model: model,
                    level: 3,
                    x: model.l3x,
                    y: model.l3y,
                    w: model.l3w,
                    h: model.l3h,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // FIXED: no LayoutBuilder here, so no "Positioned inside LayoutBuilder" error.
  // We use Align + FractionallySizedBox to place by normalized coordinates.
  Widget _blinkingLevelRect({
    required ChargedUpScoringLevelModel model,
    required int level,
    required double x,
    required double y,
    required double w,
    required double h,
  }) {
    final showText = model.showLabels; // selected only, so always fine

    final nx = x.clamp(0.0, 1.0);
    final ny = y.clamp(0.0, 1.0);
    final nw = w.clamp(0.0, 1.0);
    final nh = h.clamp(0.0, 1.0);

    final ax = nx * 2.0 - 1.0;
    final ay = ny * 2.0 - 1.0;

    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: Alignment(ax, ay),
          child: FractionallySizedBox(
            alignment: Alignment.topLeft,
            widthFactor: nw,
            heightFactor: nh,
            child: _BlinkingBox(
              key: ValueKey(
                'blink_$level',
              ), // reset when selected level changes
              borderRadius: model.borderRadius,
              borderWidth: model.borderWidth,
              fillOpacity: model.activeFillOpacity,
              label: showText ? 'L$level' : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _BlinkingBox extends StatefulWidget {
  final double borderRadius;
  final double borderWidth;
  final double fillOpacity;
  final String? label;

  const _BlinkingBox({
    super.key,
    required this.borderRadius,
    required this.borderWidth,
    required this.fillOpacity,
    required this.label,
  });

  @override
  State<_BlinkingBox> createState() => _BlinkingBoxState();
}

class _BlinkingBoxState extends State<_BlinkingBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _blink;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650), // blink speed
    )..repeat(reverse: true);

    _blink = Tween<double>(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _blink,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(widget.fillOpacity.clamp(0.0, 1.0)),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: Colors.green,
            width: widget.borderWidth,
          ),
        ),
        child: widget.label == null
            ? null
            : Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 6)],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
