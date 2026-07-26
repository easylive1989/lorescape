import 'package:context_app/features/narration/providers.dart';
import 'package:context_app/features/narration/presentation/widgets/reading_palette.dart';
import 'package:context_app/features/narration/presentation/widgets/transcript_segment_item.dart';
import 'package:context_app/shared/widgets/adaptive/adaptive_widgets.dart';
import 'package:easy_localization/easy_localization.dart' as easy;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

/// 導覽轉錄文本顯示區域
class NarrationTranscriptArea extends ConsumerWidget {
  final AutoScrollController scrollController;

  /// Optional widget rendered as the first item of the scroll list (index 0).
  ///
  /// Typically an editorial hero that scrolls away as the user reads.
  /// Falls back to a `SizedBox(height: 60)` spacer when null.
  final Widget? header;

  /// Rendered after the last segment, above the tail spacer that clears the
  /// audio bar. Used for the article's closing source line.
  final Widget? footer;

  const NarrationTranscriptArea({
    super.key,
    required this.scrollController,
    this.header,
    this.footer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerControllerProvider);
    final palette = ReadingPalette.of(context);

    if (playerState.isLoading && playerState.content == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AdaptiveProgressIndicator(color: palette.clay),
            const SizedBox(height: 16),
            Text(
              'player_screen.loading'.tr(),
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: palette.readDim),
            ),
          ],
        ),
      );
    }

    if (playerState.hasError) {
      final errorMessage =
          playerState.errorMessage ?? 'player_screen.error'.tr();
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: palette.clay, size: 48),
              const SizedBox(height: 16),
              Text(
                errorMessage,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: palette.readInk),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final content = playerState.content;
    if (content == null) {
      return const SizedBox.shrink();
    }
    final currentSegmentIndex = playerState.currentSegmentIndex;

    return Stack(
      children: [
        ListView.builder(
          physics: const ClampingScrollPhysics(),
          controller: scrollController,
          padding: EdgeInsets.zero,
          itemCount: content.segments.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return header ?? const SizedBox(height: 60);
            }
            if (index == content.segments.length + 1) {
              return Column(
                children: [
                  if (footer != null) footer!,
                  const SizedBox(height: 200),
                ],
              );
            }
            final segmentIndex = index - 1;
            final segment = content.segments[segmentIndex];
            final isActive = currentSegmentIndex == segmentIndex;
            return Padding(
              // 設計稿 `.reader__body{ padding:30px 26px 40px }`
              padding: EdgeInsets.only(
                left: 26,
                right: 26,
                top: segmentIndex == 0 ? 30 : 0,
              ),
              child: TranscriptSegmentItem(
                segment: segment,
                isActive: isActive,
                scrollController: scrollController,
                index: index,
                isLede: segmentIndex == 0,
              ),
            );
          },
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 120,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [palette.readBg, palette.readBg.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
