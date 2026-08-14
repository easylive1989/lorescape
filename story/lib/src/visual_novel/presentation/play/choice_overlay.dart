import 'package:flutter/material.dart';
import 'package:lorescape_story/src/visual_novel/presentation/play/layout.dart';
import 'package:lorescape_story/src/visual_novel/providers.dart';

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
      // 選項帶的高度是固定的（`choiceTop`／`choiceBottom` 算出來的），選項數
      // 或選項文字長度卻是劇本決定的——放不下時單純的 Column 會硬生生
      // overflow。放得下就置中顯示，放不下就能捲動，不會再被截斷或畫出警告
      // 條紋。
      //
      // ⚠️ 不能只用「Center 包 SingleChildScrollView」——Center 會把外層
      // Positioned 給的**寬度**限制從 tight 鬆成 loose，SingleChildScrollView
      // 在 loose 寬度下會縮到內容的自然寬度，Column 又沒有 stretch，最後整組
      // 按鈕會縮成比一個字還窄、逐字換行（已實測重現：按鈕寬度只剩選項帶的
      // 一小截）。用 LayoutBuilder 量出選項帶的實際高度，包一層
      // `ConstrainedBox(minHeight: ...)` 再放 `Center`：寬度全程維持 tight
      // （LayoutBuilder／SingleChildScrollView／ConstrainedBox 都不改變寬度
      // 限制），高度則靠 `minHeight` 讓 Center 在內容較短時仍能撐滿選項帶、
      // 真正置中；內容較高時 `minHeight` 不影響，維持可捲動。
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                            backgroundColor: VnColors.ground.withValues(
                              alpha: 0.90,
                            ),
                            foregroundColor: VnColors.body,
                            padding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                              side: BorderSide(
                                color: VnColors.ochre.withValues(alpha: 0.40),
                              ),
                            ),
                            textStyle: TextStyle(
                              fontSize: layout.bodyFontSize * 0.95,
                              height: 1.4,
                            ),
                          ),
                          child: Text(
                            options[i].option.text,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
