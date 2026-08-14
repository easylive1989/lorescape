import 'package:flutter/material.dart';
import 'package:lorescape_story/src/visual_novel/presentation/play/layout.dart';
import 'package:lorescape_story/src/visual_novel/presentation/play/typewriter_text.dart';

class DialogueBox extends StatelessWidget {
  const DialogueBox({
    required this.text,
    required this.layout,
    required this.completed,
    required this.onCompleted,
    required this.msPerCharacter,
    this.speakerName,
    this.graffiti = false,
    this.fontScale = 1.0,
    super.key,
  });

  static const ValueKey<String> nameTagKey = ValueKey<String>(
    'dialogue-name-tag',
  );

  final String text;
  final String? speakerName;
  final bool graffiti;
  final double fontScale;
  final VnLayout layout;

  /// 逐字顯示是否已補完——由 `_Stage` 依玩家點擊控制。
  final bool completed;
  final VoidCallback onCompleted;
  final double msPerCharacter;

  @override
  Widget build(BuildContext context) {
    final name = speakerName;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: layout.dialogueHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          // 規範 §2：上緣加細微漸層過渡。硬邊會讓對話框看起來像貼上去的一塊
          // 黑條，漸層才接得回背景。上緣 10% 做過渡，其餘維持 0.82 不透明。
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    VnColors.ground.withValues(alpha: 0),
                    VnColors.ground.withValues(alpha: 0.82),
                  ],
                  stops: const <double>[0, 0.1],
                ),
              ),
            ),
          ),
          if (name != null)
            Positioned(
              key: nameTagKey,
              left: layout.sideInset,
              top: -18,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                color: VnColors.ground.withValues(alpha: 0xF2 / 0xFF),
                child: Text(
                  name,
                  style: TextStyle(
                    color: VnColors.muted,
                    fontSize: layout.bodyFontSize * 0.85 * fontScale,
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: layout.sideInset,
              vertical: layout.dialogueHeight * 0.16,
            ),
            child: TypewriterText(
              text: text,
              completed: completed,
              onCompleted: onCompleted,
              msPerCharacter: msPerCharacter,
              style: TextStyle(
                color: graffiti ? VnColors.ochre : VnColors.body,
                fontSize: layout.bodyFontSize * fontScale,
                height: 1.7,
                fontStyle: graffiti ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
