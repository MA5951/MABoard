import 'package:flutter/material.dart';

import 'package:dot_cast/dot_cast.dart';
import 'package:provider/provider.dart';

import 'package:elastic_dashboard/widgets/dialog_widgets/dialog_text_input.dart';
import 'package:elastic_dashboard/widgets/nt_widgets/nt_widget.dart';

class ChargedUpLevelTextModel extends SingleTopicNTWidgetModel {
  @override
  String type = ChargedUpLevelTextWidget.widgetType;

  // Styling
  double fontSize; // bigger by default
  double selectedOpacity;
  double unselectedOpacity;

  // Layout tuning
  double gap; // spacing between L1/L2/L3
  double outerPadding; // padding around the whole row

  ChargedUpLevelTextModel({
    required super.ntConnection,
    required super.preferences,
    required super.topic,
    this.fontSize = 40,
    this.selectedOpacity = 1.0,
    this.unselectedOpacity = 0.35,
    this.gap = 10,
    this.outerPadding = 0,
    super.ntStructMeta,
    super.dataType,
    super.period,
  }) : super();

  ChargedUpLevelTextModel.fromJson({
    required super.ntConnection,
    required super.preferences,
    required Map<String, dynamic> jsonData,
  })  : fontSize = tryCast<num>(jsonData['font_size'])?.toDouble() ?? 40,
        selectedOpacity =
            tryCast<num>(jsonData['selected_opacity'])?.toDouble() ?? 1.0,
        unselectedOpacity =
            tryCast<num>(jsonData['unselected_opacity'])?.toDouble() ?? 0.35,
        gap = tryCast<num>(jsonData['gap'])?.toDouble() ?? 10,
        outerPadding = tryCast<num>(jsonData['outer_padding'])?.toDouble() ?? 0,
        super.fromJson(jsonData: jsonData);

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'font_size': fontSize,
        'selected_opacity': selectedOpacity,
        'unselected_opacity': unselectedOpacity,
        'gap': gap,
        'outer_padding': outerPadding,
      };

  @override
  List<Widget> getEditProperties(BuildContext context) => [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('ChargedUp Level Text'),
            const SizedBox(height: 8),

            DialogTextInput(
              label: 'Font Size',
              initialText: fontSize.toStringAsFixed(1),
              onSubmit: (v) {
                final d = double.tryParse(v.trim());
                if (d == null) return;
                fontSize = d.clamp(8, 200);
                refresh();
              },
            ),
            const SizedBox(height: 6),

            DialogTextInput(
              label: 'Selected Opacity (0..1)',
              initialText: selectedOpacity.toStringAsFixed(2),
              onSubmit: (v) {
                final d = double.tryParse(v.trim());
                if (d == null) return;
                selectedOpacity = d.clamp(0.0, 1.0);
                refresh();
              },
            ),
            const SizedBox(height: 6),

            DialogTextInput(
              label: 'Unselected Opacity (0..1)',
              initialText: unselectedOpacity.toStringAsFixed(2),
              onSubmit: (v) {
                final d = double.tryParse(v.trim());
                if (d == null) return;
                unselectedOpacity = d.clamp(0.0, 1.0);
                refresh();
              },
            ),
            const SizedBox(height: 6),

            DialogTextInput(
              label: 'Gap Between Levels',
              initialText: gap.toStringAsFixed(1),
              onSubmit: (v) {
                final d = double.tryParse(v.trim());
                if (d == null) return;
                gap = d.clamp(0, 80);
                refresh();
              },
            ),
            const SizedBox(height: 6),

            DialogTextInput(
              label: 'Outer Padding',
              initialText: outerPadding.toStringAsFixed(1),
              onSubmit: (v) {
                final d = double.tryParse(v.trim());
                if (d == null) return;
                outerPadding = d.clamp(0, 80);
                refresh();
              },
            ),
          ],
        ),
      ];
}

class ChargedUpLevelTextWidget extends NTWidget {
  static const String widgetType = 'ChargedUp Level Text';
  const ChargedUpLevelTextWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final model = cast<ChargedUpLevelTextModel>(context.watch<NTWidgetModel>());

    return ListenableBuilder(
      listenable: Listenable.merge([model, model.subscription!]),
      builder: (context, _) {
        final raw = tryCast<num>(model.subscription!.value)?.toInt() ?? 0;
        final selected = raw.clamp(0, 3);

        return LayoutBuilder(
          builder: (context, constraints) {
            final hasBoundedWidth = constraints.hasBoundedWidth;

            final children = <Widget>[
              _levelText(context, model, 1, selected == 1),
              SizedBox(width: model.gap),
              _levelText(context, model, 2, selected == 2),
              SizedBox(width: model.gap),
              _levelText(context, model, 3, selected == 3),
            ];

            Widget row;
            if (hasBoundedWidth) {
              row = Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(child: Center(child: children[0])),
                  children[1],
                  Expanded(child: Center(child: children[2])),
                  children[3],
                  Expanded(child: Center(child: children[4])),
                ],
              );
            } else {
              row = Row(
                mainAxisSize: MainAxisSize.min,
                children: children,
              );
            }

            return Padding(
              padding: EdgeInsets.all(model.outerPadding),
              child: row,
            );
          },
        );
      },
    );
  }

  Color _levelBaseColor(int level) {
    switch (level) {
      case 1:
        return const Color.fromARGB(255, 0, 17, 255);
      case 2:
        return const Color.fromARGB(255, 255, 0, 179);
      case 3:
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  Widget _levelText(
    BuildContext context,
    ChargedUpLevelTextModel model,
    int level,
    bool isSelected,
  ) {
    final cs = Theme.of(context).colorScheme;

    final color = isSelected
        ? _levelBaseColor(level).withOpacity(model.selectedOpacity.clamp(0.0, 1.0))
        : cs.onSurface.withOpacity(model.unselectedOpacity.clamp(0.0, 1.0));

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        'L$level',
        style: TextStyle(
          fontSize: model.fontSize,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
