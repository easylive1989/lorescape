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

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 4,
      left: 14,
      child: Semantics(
        button: true,
        label: MaterialLocalizations.of(context).backButtonTooltip,
        child: InkResponse(
          key: const Key('floating-back'),
          onTap: onPressed ?? () => context.pop(),
          child: Container(
            width: 40,
            height: 40,
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
