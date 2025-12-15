import 'dart:math';
import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

/// LayerFlasher
/// ------------
/// Shows a base image, and flashes a colored overlay on one of 3 configurable
/// vertical "layers" based on an integer NT value:
///   1 => Layer 1 (top band)
///   2 => Layer 2 (middle band)
///   3 => Layer 3 (bottom band)
///
/// NetworkTables:
///   - topic/Layer (int): current layer id (1,2,3). Any other value => no highlight.
///
/// Settings let you change the image, band positions, color, opacity and flash speed.
///
///
class LayerFlasherModel extends MultiTopicNTWidgetModel {
  @override
  String type = LayerFlasher.widgetType;

  String get layerTopic => '$topic/Layer';

  late NT4Subscription _layerSub;
  @override
  List<NT4Subscription> get subscriptions => [_layerSub];

  // Visual config
  String assetPath;
  Color color;
  double pulseOpacity; // max opacity of flash (0..1)
  double periodMs; // flash period in ms

  /// Three vertical bands as fractions of height: [top, bottom] in [0..1]
  List<({double top, double bottom})> bands;

  LayerFlasherModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    this.assetPath = 'assets/layers/chassis.png',
    this.color = const Color(0xFF00FF00),
    this.pulseOpacity = 0.45,
    this.periodMs = 700,
    List<({double top, double bottom})>? bands,
    super.period,
  }) : bands = List.of(
         bands ??
             const [
               (top: 0.00, bottom: 0.33), // Layer 1
               (top: 0.33, bottom: 0.62), // Layer 2
               (top: 0.62, bottom: 1.00), // Layer 3
             ],
       ),

       super();

  LayerFlasherModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : assetPath =
           tryCast(jsonData['asset_path']) ?? 'assets/layers/chassis.png',
       color = _parseColor(tryCast(jsonData['color']) ?? '#00FF00'),
       pulseOpacity = (tryCast<num>(jsonData['pulse_opacity']) ?? 0.45)
           .toDouble()
           .clamp(0.0, 1.0),
       periodMs = (tryCast<num>(jsonData['period_ms']) ?? 700).toDouble().clamp(
         100,
         5000,
       ),
       bands = List.of(
         _parseBands(jsonData['bands']) ??
             const [
               (top: 0.00, bottom: 0.33),
               (top: 0.33, bottom: 0.62),
               (top: 0.62, bottom: 1.00),
             ],
       ),
       super.fromJson(jsonData: jsonData);

  @override
  void initializeSubscriptions() {
    _layerSub = ntConnection.subscribe(layerTopic, super.period);
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'asset_path': assetPath,
    'color': _colorToHex(color),
    'pulse_opacity': pulseOpacity,
    'period_ms': periodMs,
    'bands': bands
        .map((b) => {'top': b.top, 'bottom': b.bottom})
        .toList(growable: false),
  };

  @override
  List<Widget> getEditProperties(BuildContext context) {
    final assetCtrl = TextEditingController(text: assetPath);
    final colorCtrl = TextEditingController(text: _colorToHex(color));

    return [
      // Everything below is self-contained and rebuilds via setState
      StatefulBuilder(
        builder: (context, setState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Labeled(
              'Image Asset',
              TextField(
                controller: assetCtrl,
                decoration: const InputDecoration(
                  hintText: 'assets/layers/chassis.png',
                ),
              ),
            ),
            const SizedBox(height: 8),

            _Labeled(
              'Flash (period / max opacity / color)',
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    child: _LabelBelow(
                      label: '${periodMs.toStringAsFixed(0)} ms',
                      child: Slider(
                        value: periodMs.clamp(100, 5000),
                        min: 100,
                        max: 5000,
                        divisions: 98,
                        onChanged: (v) {
                          periodMs = v;
                          setState(() {}); // <— rebuild the editor
                          refresh(); // <— notify dashboard
                        },
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: _LabelBelow(
                      label: pulseOpacity.toStringAsFixed(2),
                      child: Slider(
                        value: pulseOpacity.clamp(0.0, 1.0),
                        min: 0,
                        max: 1,
                        divisions: 20,
                        onChanged: (v) {
                          pulseOpacity = v;
                          setState(() {});
                          refresh();
                        },
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: _LabeledInline(
                      prefix: const Text('#'),
                      child: TextField(
                        controller: colorCtrl,
                        maxLength: 9, // #RRGGBB or #AARRGGBB
                        decoration: const InputDecoration(
                          hintText: '00FF00',
                          counterText: '',
                        ),
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: () {
                      color = _parseColor(colorCtrl.text);
                      assetPath = assetCtrl.text.trim();
                      setState(() {}); // reflect new text immediately
                      refresh();
                    },
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Bands editor (passes setState so sliders animate)
            _BandsEditor(
              model: this,
              onAnyChange: () {
                setState(() {});
              },
            ),
          ],
        ),
      ),
    ];
  }

  static Color _parseColor(String s) {
    String t = s.trim();
    if (!t.startsWith('#')) t = '#$t';
    if (t.length == 7) t = '#FF${t.substring(1)}'; // add alpha
    final v = int.tryParse(t.substring(1), radix: 16) ?? 0xFF00FF00;
    return Color(v);
  }

  static String _colorToHex(Color c) =>
      '#${c.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';

  static List<({double top, double bottom})>? _parseBands(dynamic raw) {
    if (raw is! List) return null;
    final out = <({double top, double bottom})>[];
    for (final e in raw) {
      final t = (tryCast<num>(e['top']) ?? 0).toDouble();
      final b = (tryCast<num>(e['bottom']) ?? 1).toDouble();
      out.add((top: t.clamp(0.0, 1.0), bottom: max(t, b).clamp(0.0, 1.0)));
    }
    if (out.length == 3) return out;
    return null;
  }
}

class LayerFlasher extends NTWidget {
  static const String widgetType = 'Layer Flasher';
  const LayerFlasher({super.key});

  @override
  Widget build(BuildContext context) {
    final LayerFlasherModel model = cast(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge(model.subscriptions),
      builder: (context, _) {
        final int level = tryCast(model.subscriptions.first.value) ?? 0;

        return AspectRatio(
          aspectRatio: 612 / 408, // optional, matches your PNG shape
          child: _FlashingStack(
            assetPath: model.assetPath,
            level: level,
            color: model.color,
            pulseOpacity: model.pulseOpacity.clamp(0.0, 1.0),
            periodMs: model.periodMs.clamp(100, 5000),
            bands: model.bands,
          ),
        );
      },
    );
  }
}

/// Base image + 3 overlay bands. Bands are placed with pixel-accurate Positioned.
class _FlashingStack extends StatefulWidget {
  final String assetPath;
  final int level; // 1..3
  final Color color;
  final double pulseOpacity;
  final double periodMs;
  final List<({double top, double bottom})> bands;

  const _FlashingStack({
    required this.assetPath,
    required this.level,
    required this.color,
    required this.pulseOpacity,
    required this.periodMs,
    required this.bands,
  });

  @override
  State<_FlashingStack> createState() => _FlashingStackState();
}

class _FlashingStackState extends State<_FlashingStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  static final Set<String> _warnedAssets = {};

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.periodMs.round()),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _FlashingStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.periodMs != widget.periodMs) {
      _ctrl.duration = Duration(milliseconds: widget.periodMs.round());
      if (!_ctrl.isAnimating) _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bandIndex = (widget.level >= 1 && widget.level <= 3)
        ? widget.level - 1
        : -1;

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final h = constraints.maxHeight;

        final children = <Widget>[
          // Base image (safe)
          Image.asset(
            widget.assetPath,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (ctx, err, st) {
              if (!_warnedAssets.contains(widget.assetPath)) {
                _warnedAssets.add(widget.assetPath);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Could not load asset: ${widget.assetPath}',
                      ),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                });
              }
              return _MissingAssetTile(widget.assetPath);
            },
          ),
        ];

        // Add the 3 overlays
        for (int i = 0; i < 3 && i < widget.bands.length; i++) {
          final b = widget.bands[i];
          final topPx = (b.top.clamp(0.0, 1.0)) * h;
          final heightPx = ((b.bottom - b.top).clamp(0.0, 1.0)) * h;

          children.add(
            Positioned(
              left: 0,
              right: 0,
              top: topPx,
              height: max(0.0, heightPx),
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) {
                  final active = (i == bandIndex);
                  final alpha = active
                      ? (0.15 + _ctrl.value * (widget.pulseOpacity - 0.15))
                      : 0.0;
                  return Container(
                    color: widget.color.withOpacity(alpha),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'L${i + 1}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 4),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        }

        return Stack(fit: StackFit.expand, children: children);
      },
    );
  }
}

/// === Bands editor (missing piece) ===
class _BandsEditor extends StatelessWidget {
  final LayerFlasherModel model;
  final VoidCallback? onAnyChange; // <— new
  const _BandsEditor({required this.model, this.onAnyChange});

  @override
  Widget build(BuildContext context) {
    const double minBandHeight = 0.05;

    List<Widget> rows = [];
    for (int i = 0; i < 3; i++) {
      rows.add(
        _Labeled(
          'Layer ${i + 1} band (top / bottom)',
          Column(
            children: [
              _LabelBelow(
                label: 'top: ${model.bands[i].top.toStringAsFixed(2)}',
                child: Slider(
                  value: model.bands[i].top.clamp(0.0, 1.0),
                  min: 0,
                  max: 1,
                  divisions: 100,
                  onChanged: (v) {
                    final bottom = model.bands[i].bottom;
                    final newTop = v.clamp(0.0, max(0.0, bottom - minBandHeight));
                    // ensure mutable then assign
                    model.bands = List.of(model.bands);
                    model.bands[i] = (top: newTop.toDouble(), bottom: bottom.toDouble());
                    onAnyChange?.call();  // <— animate thumb
                    model.refresh();      // <— notify widget model
                  },
                ),
              ),
              _LabelBelow(
                label: 'bottom: ${model.bands[i].bottom.toStringAsFixed(2)}',
                child: Slider(
                  value: model.bands[i].bottom.clamp(0.0, 1.0),
                  min: 0,
                  max: 1,
                  divisions: 100,
                  onChanged: (v) {
                    final top = model.bands[i].top;
                    final newBottom = v.clamp(min(top + minBandHeight, 1.0), 1.0);
                    model.bands = List.of(model.bands);
                    model.bands[i] = (top: top.toDouble(), bottom: newBottom.toDouble());
                    onAnyChange?.call();
                    model.refresh();
                  },
                ),
              ),
            ],
          ),
        ),
      );
      rows.add(const SizedBox(height: 8));
    }

    return Column(children: rows);
  }
}


/// Small labeled section
class _Labeled extends StatelessWidget {
  final String label;
  final Widget child;
  const _Labeled(this.label, this.child);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _LabeledInline extends StatelessWidget {
  final Widget? prefix;
  final Widget child;
  const _LabeledInline({this.prefix, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (prefix != null) prefix!,
        Expanded(child: child),
      ],
    );
  }
}

class _LabelBelow extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabelBelow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        child,
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _MissingAssetTile extends StatelessWidget {
  final String path;
  const _MissingAssetTile(this.path);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange),
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image, color: Colors.orange, size: 28),
            const SizedBox(height: 6),
            Text(
              'Missing asset:\n$path',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
