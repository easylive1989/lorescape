import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:context_app/features/daily_story/domain/models/daily_story.dart';

/// 底部的每日故事橫向卡片列。
///
/// 捲動時回報目前置中的索引，首頁拿它去轉地球儀；點選中的那張才進故事，
/// 點旁邊的卡片只是把它捲到中間（跟設計稿一致，避免誤觸）。
class StoryRail extends StatefulWidget {
  const StoryRail({
    super.key,
    required this.stories,
    required this.activeIndex,
    required this.onActiveChanged,
    required this.onOpen,
  });

  final List<DailyStory> stories;
  final int activeIndex;
  final ValueChanged<int> onActiveChanged;
  final ValueChanged<DailyStory> onOpen;

  /// 卡片寬度＋間距，用來換算捲動位置。
  static const double stride = 324;

  @override
  State<StoryRail> createState() => _StoryRailState();
}

class _StoryRailState extends State<StoryRail> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    final index = (notification.metrics.pixels / StoryRail.stride)
        .round()
        .clamp(0, widget.stories.length - 1);
    if (index != widget.activeIndex) widget.onActiveChanged(index);
    return false;
  }

  void _onCardTap(int index) {
    if (index == widget.activeIndex) {
      widget.onOpen(widget.stories[index]);
      return;
    }
    _controller.animateTo(
      index * StoryRail.stride,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (widget.stories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text('home.empty'.tr(), textAlign: TextAlign.center),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              Text(
                'home.deck_label'.tr(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: tokens.clay,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Container(height: 1, color: tokens.line)),
            ],
          ),
        ),
        SizedBox(
          // 116：扣掉卡片內距後留給內容的高度要夠放「最新」徽章那一行
          // （比其他卡片的日期文字高），量測下來 108 會讓那張卡溢位。
          height: 116,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: widget.stories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) => _StoryCard(
                story: widget.stories[index],
                isActive: index == widget.activeIndex,
                isLatest: index == 0,
                onTap: () => _onCardTap(index),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.story,
    required this.isActive,
    required this.isLatest,
    required this.onTap,
  });

  final DailyStory story;
  final bool isActive;
  final bool isLatest;
  final VoidCallback onTap;

  String get _dateKey =>
      '${story.publishDate.year.toString().padLeft(4, '0')}-'
      '${story.publishDate.month.toString().padLeft(2, '0')}-'
      '${story.publishDate.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return GestureDetector(
      key: Key('story-card-$_dateKey'),
      onTap: onTap,
      child: Container(
        width: 312,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tokens.paperRaised,
          border: Border.all(color: isActive ? tokens.clay : tokens.line),
          borderRadius: BorderRadius.circular(tokens.rLg),
          boxShadow: isActive ? tokens.e2 : tokens.e1,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(tokens.rMd),
              child: SizedBox(
                width: 78,
                height: 78,
                child: story.imageUrl == null
                    ? ColoredBox(color: tokens.paperSunk)
                    : CachedNetworkImage(
                        imageUrl: story.imageUrl!,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLatest)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.clay,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'home.badge_latest'.tr(),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: tokens.paperRaised,
                        ),
                      ),
                    )
                  else
                    Text(
                      _dateKey,
                      style: TextStyle(fontSize: 11, color: tokens.ink3),
                    ),
                  const SizedBox(height: 7),
                  Text(
                    story.placeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    story.placeLocation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: tokens.ink3),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: tokens.ink3),
          ],
        ),
      ),
    );
  }
}
