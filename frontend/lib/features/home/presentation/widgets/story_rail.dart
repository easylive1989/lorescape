import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:context_app/features/daily_story/domain/models/daily_story.dart';
import 'package:context_app/shared/widgets/page_dots.dart';

/// 底部的每日故事橫向卡片列。
///
/// 捲動時回報目前置中的索引，首頁拿它去轉地球儀；點選中的那張才進故事，
/// 點旁邊的卡片只是把它捲到中間（跟設計稿一致，避免誤觸）。甩動放開後會
/// 用 [_SnapScrollPhysics] 停在卡片邊界，不會停在兩張卡中間；下方的
/// [PageDots] 標出目前位置。
class StoryRail extends StatefulWidget {
  const StoryRail({
    super.key,
    required this.stories,
    required this.isError,
    required this.onRetry,
    required this.activeIndex,
    required this.onActiveChanged,
    required this.onOpen,
  });

  final List<DailyStory> stories;

  /// 載入故事失敗（`homeStoriesProvider` 的 AsyncError）。跟 [stories] 為
  /// 空但沒出錯（真的沒有故事，或還在載入中）分開處理——前者要給重試入口。
  final bool isError;
  final VoidCallback onRetry;

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

  /// didUpdateWidget 觸發的程式化捲動進行中。這段期間 [_onScroll] 要閉嘴：
  /// activeIndex 已經是目的地了，中途經過的卡再回報 onActiveChanged 只會把
  /// 它改回中間值；而且 animateTo 是在 build 中被呼叫的，它同步發出的
  /// ScrollStart 若一路傳回 setState 會直接炸 setState-during-build。
  bool _autoScrolling = false;

  @override
  void didUpdateWidget(StoryRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    // activeIndex 從外部改變時（點地球儀上的釘點）把那張卡捲到中間。
    // 捲動自己觸發的變更（_onScroll 回報上來的）此時捲動位置已經在該卡
    // 附近，round 出來就是新 index，直接略過，才不會跟使用者的手指打架。
    if (widget.activeIndex == oldWidget.activeIndex) return;
    if (!_controller.hasClients) return;
    final scrollIndex = (_controller.position.pixels / StoryRail.stride)
        .round();
    if (scrollIndex == widget.activeIndex) return;
    _autoScrolling = true;
    _controller
        .animateTo(
          widget.activeIndex * StoryRail.stride,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        )
        // 使用者中途伸手打斷也會 complete，flag 一定會被清掉。
        .whenComplete(() => _autoScrolling = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (_autoScrolling) return false;
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

    if (widget.isError) {
      return _RailErrorState(onRetry: widget.onRetry);
    }

    if (widget.stories.isEmpty) {
      // 涵蓋兩種情況：真的還沒有故事，或還在第一次載入中——後者維持現狀
      // 直接當空的處理，不特別做骨架屏。
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
          height: 96,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              physics: const _SnapScrollPhysics(itemExtent: StoryRail.stride),
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
        PageDots(
          count: widget.stories.length,
          index: widget.activeIndex,
          padding: const EdgeInsets.only(top: 10),
        ),
      ],
    );
  }
}

/// 甩動放開後停在某張卡片的邊界，不會停在兩張卡中間——否則「目前選中的是
/// 哪一張」會曖昧，地球儀該轉到哪個定點也跟著曖昧。做法跟 Flutter 內建的
/// [PageScrollPhysics] 相同（往最近的 [itemExtent] 倍數收斂），只是這裡的
/// 卡片是固定寬度而非整頁，所以自己實作而不是用 PageView。
class _SnapScrollPhysics extends ScrollPhysics {
  const _SnapScrollPhysics({super.parent, required this.itemExtent});

  final double itemExtent;

  @override
  _SnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _SnapScrollPhysics(
      parent: buildParent(ancestor),
      itemExtent: itemExtent,
    );
  }

  /// 跟 [PageScrollPhysics] 一樣把甩動速度算進去：只要甩動快過
  /// [Tolerance.velocity]，就往甩動方向偏半張卡再取整——輕甩即可換到
  /// 下一張，不必實際拖超過半張卡的距離。
  double _targetPixels(
    ScrollMetrics position,
    Tolerance tolerance,
    double velocity,
  ) {
    var page = position.pixels / itemExtent;
    if (velocity < -tolerance.velocity) {
      page -= 0.5;
    } else if (velocity > tolerance.velocity) {
      page += 0.5;
    }
    return page.roundToDouble() * itemExtent;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // 已經滑出邊界，交給預設行為處理回彈，不要在這裡搶著收斂。
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final tolerance = toleranceFor(position);
    final target = _targetPixels(
      position,
      tolerance,
      velocity,
    ).clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - position.pixels).abs() < tolerance.distance) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}

/// 首頁故事卡片列載入失敗時的訊息＋重試鈕。
class _RailErrorState extends StatelessWidget {
  const _RailErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'home.load_error'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.ink3),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('home-stories-retry'),
            onPressed: onRetry,
            child: Text('home.retry'.tr()),
          ),
        ],
      ),
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
        padding: const EdgeInsets.all(10),
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
                width: 60,
                height: 60,
                child: story.imageUrl == null
                    ? ColoredBox(color: tokens.paperSunk)
                    : CachedNetworkImage(
                        imageUrl: story.imageUrl!,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLatest)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 1,
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
                  const SizedBox(height: 3),
                  Text(
                    story.placeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // 設計稿 `.hm-card__t` 是 serif 17.5 / line-height 1.25。
                    // titleLarge 已是 serif；壓緊行高後三行才塞得進 96 的卡。
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 16.5,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 3),
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
