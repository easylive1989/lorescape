import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:flutter/material.dart';

/// 頁面主標，對應設計稿的 `.masthead`：一段短橫線＋全大寫眼眉字，
/// 底下壓襯線大標，最後一條細分隔線（左端有一小段 clay 色）。
///
/// 三個分頁（故事／歷程／探索）都用這個元件，標題的位置與字級才會一致——
/// 探索頁曾經自己複製一份 `.map-hd`，兩份實作就各自漂移出 6px 的左緣差。
class Masthead extends StatelessWidget {
  const Masthead({
    super.key,
    required this.eyebrow,
    required this.title,
    this.actions,
    this.showRule = true,
  });

  final String eyebrow;
  final String title;
  final Widget? actions;

  /// 是否畫標題下的細分隔線。浮在地圖上時關掉：那裡靠紙色漸層與底圖分隔，
  /// 再壓一條線反而突兀。關掉時連同分隔線上方的間距一起省去。
  final bool showRule;

  /// 標題的左右內距。頁面若要讓其他內容（如探索頁的搜尋列）跟標題對齊，
  /// 引用這個值而不要各自寫死數字。
  static const double horizontalInset = 22;

  /// 標題與頁面上緣（安全區之後）的間距。
  static const double topInset = 10;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LorescapeTokens>();
    final colorScheme = Theme.of(context).colorScheme;
    final clay = tokens?.clay ?? colorScheme.primary;
    final line = tokens?.line ?? colorScheme.outlineVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        horizontalInset,
        topInset,
        horizontalInset,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 16,
                          height: 1.5,
                          decoration: BoxDecoration(
                            color: clay,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            eyebrow,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.3,
                              color: clay,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 37,
                        height: 0.98,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (actions != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: actions,
                ),
            ],
          ),
          if (showRule) ...[
            const SizedBox(height: 16),
            // 細分隔線，左端 46px 換成 clay 色（設計稿的
            // `.masthead__rule::before`）。
            SizedBox(
              height: 1,
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: line)),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 46,
                    child: ColoredBox(color: clay),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
