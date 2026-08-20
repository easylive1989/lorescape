import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 浮在頁面左上角的返回鈕。
///
/// 歷程與設定原本是 bottom nav 的分頁，沒有返回的概念；改成從首頁 push
/// 之後就需要一個出口。做成浮動而不是 AppBar，是為了不動這兩頁既有的
/// Masthead 版面。
class FloatingBackButton extends StatelessWidget {
  const FloatingBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  /// 鈕的直徑與離左緣的距離。頁面若要讓出這顆鈕的位置（歷程頁的大標就在它
  /// 旁邊），引用這兩個值算出讓位寬度，不要各自寫死數字。
  static const double size = 40;
  static const double leftInset = 14;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 4,
      left: leftInset,
      child: Semantics(
        button: true,
        label: MaterialLocalizations.of(context).backButtonTooltip,
        child: InkResponse(
          key: const Key('floating-back'),
          onTap: onPressed ?? () => context.pop(),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: tokens.paperRaised,
              shape: BoxShape.circle,
              border: Border.all(color: tokens.line),
              boxShadow: tokens.e2,
            ),
            child: Icon(Icons.chevron_left, size: 24, color: tokens.ink2),
          ),
        ),
      ),
    );
  }
}
