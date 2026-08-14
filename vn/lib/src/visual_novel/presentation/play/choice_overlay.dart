import 'package:flutter/material.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/layout.dart';
import 'package:lorescape_vn/src/visual_novel/providers.dart';

class ChoiceOverlay extends StatelessWidget {
  const ChoiceOverlay({
    required this.options,
    required this.onChoose,
    required this.layout,
    super.key,
  });

  final List<VisibleOption> options;
  final void Function(int visibleIndex) onChoose;
  final VnLayout layout;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: layout.choiceInset,
      right: layout.choiceInset,
      top: layout.choiceTop,
      bottom: layout.choiceBottom,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          for (var i = 0; i < options.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  key: ValueKey<String>('choice-$i'),
                  onPressed: () => onChoose(i),
                  style: FilledButton.styleFrom(
                    backgroundColor: VnColors.ground.withValues(alpha: 0.90),
                    foregroundColor: VnColors.body,
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide(color: VnColors.ochre.withValues(alpha: 0.40)),
                    ),
                    textStyle: TextStyle(fontSize: layout.bodyFontSize * 0.95, height: 1.4),
                  ),
                  child: Text(options[i].option.text, textAlign: TextAlign.center),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
