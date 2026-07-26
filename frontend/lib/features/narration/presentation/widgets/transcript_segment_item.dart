import 'package:context_app/features/narration/domain/models/narration_segment.dart';
import 'package:context_app/features/narration/presentation/widgets/reading_palette.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

/// 單個轉錄文本段落項目
class TranscriptSegmentItem extends StatelessWidget {
  final NarrationSegment segment;
  final bool isActive;
  final AutoScrollController scrollController;
  final int index;

  /// 是否為導讀首段：為 true 時，首字以放大的紅土色 drop cap 呈現。
  final bool isLede;

  const TranscriptSegmentItem({
    super.key,
    required this.segment,
    required this.isActive,
    required this.scrollController,
    required this.index,
    this.isLede = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReadingPalette.of(context);
    final baseStyle = isActive
        ? GoogleFonts.notoSerifTc(
            fontSize: 20,
            height: 1.92,
            fontWeight: FontWeight.w600,
            color: palette.readInk,
          )
        : GoogleFonts.notoSerifTc(
            fontSize: 18.5,
            height: 1.92,
            color: palette.readDim,
          );

    final Widget text = isLede
        ? _buildLede(baseStyle, palette)
        : Text(segment.text, style: baseStyle);

    final Widget content = isActive
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -22,
                top: 6,
                bottom: 6,
                width: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.clay,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              text,
            ],
          )
        : text;

    return AutoScrollTag(
      key: ValueKey(index),
      controller: scrollController,
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: content,
      ),
    );
  }

  /// Lede 段落：首字放大為紅土色 drop cap，內嵌於段落起始（近似 CSS 的
  /// `.reader__lede .dropcap`；Flutter 無 float，故不做文字環繞）。
  Widget _buildLede(TextStyle baseStyle, ReadingPalette palette) {
    final chars = segment.text.characters;
    if (chars.isEmpty) {
      return Text(segment.text, style: baseStyle);
    }
    final first = chars.take(1).toString();
    final rest = chars.skip(1).toString();
    // 設計稿 `.reader__lede .dropcap`：固定 64px、line-height .84，字級不跟
    // 著段落走——drop cap 的份量是版面的支點，會隨 active 段落放大就散了。
    final dropStyle = GoogleFonts.notoSerifTc(
      fontSize: 64,
      height: 0.84,
      fontWeight: FontWeight.w700,
      color: palette.readCap,
    );
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Padding(
              // `padding:6px 12px 0 0`
              padding: const EdgeInsets.only(top: 6, right: 12),
              child: Text(
                first,
                key: const Key('reader-lede-dropcap'),
                style: dropStyle,
              ),
            ),
          ),
          TextSpan(text: rest, style: baseStyle),
        ],
      ),
    );
  }
}
