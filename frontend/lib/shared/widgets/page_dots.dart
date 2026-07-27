import 'dart:math' as math;

import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:flutter/material.dart';

/// 分頁指示器：目前這頁是一條 clay 色短棒，其餘是灰點。
///
/// 點數有上限：頁數多於 [maxDots] 時只畫一段以目前位置為中心的視窗，視窗
/// 邊緣若還有更多頁，該端的點縮小提示「這個方向還有」。沒有上限的話，一本
/// 三十則的旅程手記會在頁底鋪出三十個點。
///
/// 故事牌堆與手記翻頁器共用這個元件：牌堆只看不點（[onSelect] 為 null），
/// 手記的點可以直接跳頁，兩邊的外距也不同，因此 [padding] 由呼叫端指定。
class PageDots extends StatelessWidget {
  const PageDots({
    super.key,
    required this.count,
    required this.index,
    required this.padding,
    this.onSelect,
  });

  final int count;

  /// 目前這頁的序號（0 起算）。
  final int index;

  final EdgeInsetsGeometry padding;

  /// 點下某顆點時回報它代表的頁數；null 代表這排點純粹是進度顯示。
  final ValueChanged<int>? onSelect;

  static const int maxDots = 6;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final shown = math.min(count, maxDots);
    final start = (index - shown ~/ 2).clamp(0, count - shown);
    final end = start + shown;

    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = start; i < end; i += 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _dot(
                i,
                isHint: _isEdgeHint(i, start: start, end: end),
                tokens: tokens,
              ),
            ),
        ],
      ),
    );
  }

  Widget _dot(int i, {required bool isHint, required LorescapeTokens tokens}) {
    final dot = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: i == index
          ? 20
          : isHint
          ? 4
          : 6,
      height: isHint ? 4 : 6,
      decoration: BoxDecoration(
        color: i == index ? tokens.clay : tokens.lineStrong,
        borderRadius: BorderRadius.circular(3),
      ),
    );
    if (onSelect == null) return dot;
    return GestureDetector(onTap: () => onSelect!(i), child: dot);
  }

  /// 視窗邊緣、且該方向還有更多頁的點。
  bool _isEdgeHint(int i, {required int start, required int end}) {
    if (i == index) return false;
    return (i == start && start > 0) || (i == end - 1 && end < count);
  }
}
