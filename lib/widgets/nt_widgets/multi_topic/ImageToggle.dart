import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/services/nt4_client.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

/// GenericImageToggle
/// ------------------
/// A configurable multi-topic, multi-image widget.
/// Each image listens to a boolean NetworkTables topic:
///   - When the topic meets the highlight condition, that image is fully opaque (1.0)
///   - Otherwise it's dimmed to [baseOpacity]
///
/// Configure via the widget’s property panel:
///   - images (asset paths)
///   - topics (NT boolean topics)
///   - layout (row / column / grid with N columns)
///   - base opacity
///   - invert highlight logic
///   - image fit / padding / spacing
///
/// NOTES:
///  * Ensure `images.length == topics.length` for 1:1 mapping.
///  * Add assets in pubspec.yaml under `flutter.assets`.
class GenericImageToggleModel extends MultiTopicNTWidgetModel {
  @override
  String type = GenericImageToggle.widgetType;

  /// Image asset paths and matching topics
  List<String> images;
  List<String> topics;

  /// Visuals
  double baseOpacity;
  bool invertHighlight; // If true, false -> highlight, true -> dim
  String layout; // 'row' | 'column' | 'grid'
  int gridColumns;
  BoxFit boxFit;
  double padding;
  double spacing;

  /// Subscriptions in same order as [topics]
  final List<NT4Subscription> _subs = [];

  GenericImageToggleModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic, // You can use this as a root prefix, or ignore
    List<String>? images,
    List<String>? topics,
    this.baseOpacity = 0.30,
    this.invertHighlight = false,
    this.layout = 'row',
    this.gridColumns = 3,
    this.boxFit = BoxFit.contain,
    this.padding = 6.0,
    this.spacing = 6.0,
    super.period,
  }) : images = images ?? const [],
       topics = topics ?? const [],
       super();

  GenericImageToggleModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  }) : images = (tryCast<List<dynamic>>(jsonData['images']) ?? [])
           .whereType<String>()
           .toList(),
       topics = (tryCast<List<dynamic>>(jsonData['topics']) ?? [])
           .whereType<String>()
           .toList(),
       baseOpacity = tryCast(jsonData['base_opacity']) ?? 0.30,
       invertHighlight = tryCast(jsonData['invert_highlight']) ?? false,
       layout = tryCast(jsonData['layout']) ?? 'row',
       gridColumns = tryCast(jsonData['grid_columns']) ?? 3,
       boxFit = _parseBoxFit(tryCast(jsonData['box_fit']) ?? 'contain'),
       padding = (tryCast<num>(jsonData['padding']) ?? 6.0).toDouble(),
       spacing = (tryCast<num>(jsonData['spacing']) ?? 6.0).toDouble(),
       super.fromJson(jsonData: jsonData);

  @override
  List<NT4Subscription> get subscriptions => _subs;

  @override
  void initializeSubscriptions() {
    _disposeSubs();
    for (final t in topics) {
      _subs.add(ntConnection.subscribe(t, super.period));
    }
  }

  @override
  void resetSubscription() {
    // Resubscribe when topics change
    _disposeSubs();
    initializeSubscriptions();
    refresh();
  }

  @override
  void unSubscribe() {
    _disposeSubs();
  }

  void _disposeSubs() {
    for (final s in _subs) {
      ntConnection.unSubscribe(s);
    }
    _subs.clear();
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'images': images,
    'topics': topics,
    'base_opacity': baseOpacity,
    'invert_highlight': invertHighlight,
    'layout': layout,
    'grid_columns': gridColumns,
    'box_fit': _fitToString(boxFit),
    'padding': padding,
    'spacing': spacing,
  };

  @override
  List<Widget> getEditProperties(BuildContext context) {
    final theme = Theme.of(context);
    final ctrlImages = TextEditingController(text: images.join('\n'));
    final ctrlTopics = TextEditingController(text: topics.join('\n'));

    return [
      const SizedBox(height: 8),
      Text(
        'Images & Topics (one per line, same length)',
        style: theme.textTheme.titleMedium,
      ),
      const SizedBox(height: 6),

      // Adapt to width: side-by-side when wide, stacked when narrow
      _TwoColAdaptive(
        left: _LabeledArea(
          label: 'Images (assets)',
          child: TextField(
            controller: ctrlImages,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'assets/path1.png\nassets/path2.png\n...',
            ),
            onChanged: (_) {},
          ),
        ),
        right: _LabeledArea(
          label: 'Topics (booleans)',
          child: TextField(
            controller: ctrlTopics,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText:
                  '/MALog/SuperStructure/is Coral\n/MALog/SuperStructure/is algea\n...',
            ),
            onChanged: (_) {},
          ),
        ),
        gap: 12,
        breakpoint: 640, // px
      ),

      const SizedBox(height: 8),

      // Layout + Grid Columns (responsive)
      LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          final double minW = 180.0;
          final double sliderMax = ((maxW - 220).clamp(0.0, maxW)).toDouble();
          final double safeMaxW = sliderMax < minW ? minW : sliderMax;

          return Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 200, maxWidth: 360),
                child: _LabeledArea(
                  label: 'Layout',
                  child: DropdownButton<String>(
                    value: layout,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'row', child: Text('Row')),
                      DropdownMenuItem(value: 'column', child: Text('Column')),
                      DropdownMenuItem(value: 'grid', child: Text('Grid')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      layout = v;
                      refresh();
                    },
                  ),
                ),
              ),
              if (layout == 'grid')
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: minW,
                    maxWidth: safeMaxW.clamp(minW, maxW),
                  ),
                  child: _LabeledArea(
                    label: 'Grid Columns',
                    child: Slider(
                      value: gridColumns.clamp(1, 8).toDouble(),
                      min: 1,
                      max: 8,
                      divisions: 7,
                      label: '$gridColumns',
                      onChanged: (v) {
                        gridColumns = v.round();
                        refresh();
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),

      const SizedBox(height: 8),

      // Base Opacity + Highlight Logic (responsive)
      LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          final double minW = 180.0;
          final double sliderRoom = ((maxW - 220).clamp(0.0, maxW)).toDouble();
          final double safeMaxW = sliderRoom < minW ? minW : sliderRoom;

          return Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: minW,
                  maxWidth: safeMaxW.clamp(minW, maxW),
                ),
                child: _LabeledArea(
                  label: 'Base Opacity',
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
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 180, maxWidth: 360),
                child: _LabeledArea(
                  label: 'Highlight Logic',
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('True = Highlight'),
                      Switch(
                        value: invertHighlight,
                        onChanged: (val) {
                          invertHighlight = val;
                          refresh();
                        },
                      ),
                      const Text('Invert'),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),

      const SizedBox(height: 8),

      // Image Fit + Padding/Spacing (responsive)
      LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;

          return Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 200, maxWidth: 360),
                child: _LabeledArea(
                  label: 'Image Fit',
                  child: DropdownButton<String>(
                    value: _fitToString(boxFit),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'contain',
                        child: Text('Contain'),
                      ),
                      DropdownMenuItem(value: 'cover', child: Text('Cover')),
                      DropdownMenuItem(value: 'fill', child: Text('Fill')),
                      DropdownMenuItem(
                        value: 'fitWidth',
                        child: Text('Fit Width'),
                      ),
                      DropdownMenuItem(
                        value: 'fitHeight',
                        child: Text('Fit Height'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      boxFit = _parseBoxFit(v);
                      refresh();
                    },
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: 220,
                  maxWidth: maxW > 500 ? 520 : maxW,
                ),
                child: _LabeledArea(
                  label: 'Padding / Spacing',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Pad'),
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 120,
                          maxWidth: 220,
                        ),
                        child: Slider(
                          value: padding.clamp(0.0, 32.0),
                          min: 0,
                          max: 32,
                          divisions: 32,
                          label: padding.toStringAsFixed(0),
                          onChanged: (v) {
                            padding = v;
                            refresh();
                          },
                        ),
                      ),
                      const Text('Space'),
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 120,
                          maxWidth: 220,
                        ),
                        child: Slider(
                          value: spacing.clamp(0.0, 32.0),
                          min: 0,
                          max: 32,
                          divisions: 32,
                          label: spacing.toStringAsFixed(0),
                          onChanged: (v) {
                            spacing = v;
                            refresh();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),

      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton(
          onPressed: () {
            // Persist lists and rebuild subs
            images = ctrlImages.text
                .split('\n')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
            topics = ctrlTopics.text
                .split('\n')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
            resetSubscription();
          },
          child: const Text('Apply Images/Topics'),
        ),
      ),
      const SizedBox(height: 8),
    ];
  }

  /// Helper for getting opacity given the boolean value
  double opacityFor(bool value) {
    final active = invertHighlight ? !value : value;
    return active ? 1.0 : baseOpacity;
  }

  static String _fitToString(BoxFit fit) {
    switch (fit) {
      case BoxFit.contain:
        return 'contain';
      case BoxFit.cover:
        return 'cover';
      case BoxFit.fill:
        return 'fill';
      case BoxFit.fitWidth:
        return 'fitWidth';
      case BoxFit.fitHeight:
        return 'fitHeight';
      default:
        return 'contain';
    }
  }

  static BoxFit _parseBoxFit(String s) {
    switch (s) {
      case 'cover':
        return BoxFit.cover;
      case 'fill':
        return BoxFit.fill;
      case 'fitWidth':
        return BoxFit.fitWidth;
      case 'fitHeight':
        return BoxFit.fitHeight;
      case 'contain':
      default:
        return BoxFit.contain;
    }
  }
}

class GenericImageToggle extends NTWidget {
  static const String widgetType = 'Generic Image Toggle';
  const GenericImageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final GenericImageToggleModel model = cast(context.watch<NTWidgetModel>());

    // Merge all subscription notifiers so rebuilds happen together
    return ListenableBuilder(
      listenable: model.subscriptions.isEmpty
          ? ValueNotifier(0)
          : Listenable.merge(model.subscriptions),
      builder: (context, _) {
        final int n = model.images.length;
        final List<Widget> tiles = [];

        for (int i = 0; i < n; i++) {
          final String img = model.images[i];
          // If topics list is shorter, treat missing as false (dim)
          final bool val = (i < model.subscriptions.length)
              ? (tryCast(model.subscriptions[i].value) ?? false)
              : false;

          tiles.add(
            Padding(
              padding: EdgeInsets.all(model.padding),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.transparent,
                ),
                child: Opacity(
                  opacity: model.opacityFor(val),
                  child: Image.asset(
                    img,
                    fit: model.boxFit,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
          );
        }

        switch (model.layout) {
          case 'column':
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _withSpacing(tiles, model.spacing, axis: Axis.vertical),
            );
          case 'grid':
            final cols = model.gridColumns.clamp(1, 12);
            return LayoutBuilder(
              builder: (context, constraints) {
                return GridView.count(
                  crossAxisCount: cols,
                  crossAxisSpacing: model.spacing,
                  mainAxisSpacing: model.spacing,
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  children: tiles,
                );
              },
            );
          case 'row':
          default:
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _withSpacing(
                tiles,
                model.spacing,
                axis: Axis.horizontal,
              ).map((w) => Expanded(child: w)).toList(),
            );
        }
      },
    );
  }

  List<Widget> _withSpacing(
    List<Widget> children,
    double space, {
    required Axis axis,
  }) {
    if (children.isEmpty || space <= 0) return children;
    final spaced = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      spaced.add(children[i]);
      if (i != children.length - 1) {
        spaced.add(
          axis == Axis.horizontal
              ? SizedBox(width: space)
              : SizedBox(height: space),
        );
      }
    }
    return spaced;
  }
}

/// Small labeled section used in the property editor
class _LabeledArea extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledArea({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// Two-column layout that stacks on narrow widths to avoid overflows.
class _TwoColAdaptive extends StatelessWidget {
  final Widget left;
  final Widget right;
  final double gap;
  final double breakpoint; // if width < breakpoint -> stack

  const _TwoColAdaptive({
    required this.left,
    required this.right,
    this.gap = 12,
    this.breakpoint = 640,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= breakpoint;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              SizedBox(width: gap),
              Expanded(child: right),
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              left,
              SizedBox(height: gap),
              right,
            ],
          );
        }
      },
    );
  }
}
