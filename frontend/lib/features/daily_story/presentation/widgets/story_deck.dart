import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:context_app/features/daily_story/domain/models/daily_story.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 故事牌堆（設計稿 `.deck-stage` / `.dcard`）：一疊照片卡，最上面那張可以
/// 左右滑——右滑或點一下開始閱讀，左滑把它排到隊尾稍後再看。
///
/// 卡片不是被消耗掉而是輪轉：故事會一直在，左滑只是「現在先不讀」。
class StoryDeck extends StatefulWidget {
  const StoryDeck({super.key, required this.stories, required this.onOpen});

  final List<DailyStory> stories;
  final ValueChanged<DailyStory> onOpen;

  /// 滑到這個距離才算數（設計稿的 `THRESH = 96`）。
  static const double swipeThreshold = 96;

  /// 後面最多再露幾張，多了只是疊在同一處看不出來。
  static const int visibleBehind = 4;

  @override
  State<StoryDeck> createState() => _StoryDeckState();
}

class _StoryDeckState extends State<StoryDeck>
    with SingleTickerProviderStateMixin {
  /// 目前的排列順序（存 index）；第 0 個是最上面那張。
  late List<int> _order;

  double _dx = 0;
  bool _dragging = false;

  /// 飛出方向：1 右、-1 左、null 代表沒有卡片正在離場。
  int? _leaving;

  /// 在 initState 就建好而不是用 lazy `late final`：沒滑過任何一張卡就離開
  /// 時，dispose 會是第一次存取它，等於在樹拆解到一半才去建 ticker。
  late final AnimationController _leaveController;

  @override
  void initState() {
    super.initState();
    _leaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _order = List.generate(widget.stories.length, (i) => i);
  }

  @override
  void didUpdateWidget(StoryDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stories.length != widget.stories.length) {
      _order = List.generate(widget.stories.length, (i) => i);
    }
  }

  @override
  void dispose() {
    _leaveController.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails _) {
    if (_leaving != null) return;
    setState(() {
      _dragging = true;
      _dx = 0;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_leaving != null) return;
    setState(() => _dx += details.delta.dx);
  }

  void _onDragEnd(DragEndDetails _) {
    if (_leaving != null) return;
    final dx = _dx;
    if (dx > StoryDeck.swipeThreshold) {
      _commit(1);
      widget.onOpen(widget.stories[_order.first]);
    } else if (dx < -StoryDeck.swipeThreshold) {
      _commit(-1);
    } else {
      setState(() {
        _dragging = false;
        _dx = 0;
      });
    }
  }

  /// 讓最上面那張飛出去，動畫收尾後把它排到隊尾。
  Future<void> _commit(int direction) async {
    setState(() {
      _leaving = direction;
      _dragging = false;
      _dx = 0;
    });
    await _leaveController.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _order = [..._order.skip(1), _order.first];
      _leaving = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) return const SizedBox.shrink();

    final visible = _order.take(StoryDeck.visibleBehind + 1).toList();

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 12),
            child: GestureDetector(
              onHorizontalDragStart: _onDragStart,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              onTap: _leaving != null
                  ? null
                  : () => widget.onOpen(widget.stories[_order.first]),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 後面的先畫，最上面那張才會蓋在最上層。
                  for (var pos = visible.length - 1; pos >= 0; pos -= 1)
                    _positioned(story: widget.stories[visible[pos]], pos: pos),
                ],
              ),
            ),
          ),
        ),
        _DeckProgress(count: widget.stories.length, index: _order.first),
      ],
    );
  }

  Widget _positioned({required DailyStory story, required int pos}) {
    final isTop = pos == 0;
    if (!isTop) {
      // 往下扇開並左右交錯微傾，露出幾道卡緣＝一疊厚厚的卡。
      final tilt = (pos.isOdd ? -1 : 1) * (1.6 + pos * 0.9);
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..translateByDouble(0, pos * 13.0, 0, 1)
          ..scaleByDouble(1 - pos * 0.028, 1 - pos * 0.028, 1, 1)
          ..rotateZ(tilt * math.pi / 180),
        child: Opacity(
          opacity: 1 - pos * 0.05,
          child: _StoryDeckCard(story: story, isBehind: true),
        ),
      );
    }

    if (_leaving != null) {
      return AnimatedBuilder(
        animation: _leaveController,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_leaveController.value);
          return FractionalTranslation(
            translation: Offset(_leaving! * 1.35 * t, 0),
            child: Transform.rotate(
              angle: _leaving! * 16 * t * math.pi / 180,
              child: Opacity(opacity: 1 - t, child: child),
            ),
          );
        },
        child: _StoryDeckCard(story: story, isBehind: false),
      );
    }

    final hint = (_dx / StoryDeck.swipeThreshold).clamp(-1.0, 1.0);
    final card = Transform.translate(
      offset: Offset(_dx, 0),
      child: Transform.rotate(
        // 位移換算成手感上的傾斜，跟著手指走。
        angle: (_dx / 22) * math.pi / 180,
        child: _StoryDeckCard(story: story, isBehind: false, dragHint: hint),
      ),
    );

    return _dragging
        ? card
        : AnimatedSlide(
            offset: Offset.zero,
            duration: const Duration(milliseconds: 340),
            curve: const Cubic(0.22, 0.61, 0.36, 1),
            child: card,
          );
  }
}

/// 單張故事卡：滿版照片＋暗角，左上是序號，右上是 Anno 徽章，底下壓標題。
class _StoryDeckCard extends StatelessWidget {
  const _StoryDeckCard({
    required this.story,
    required this.isBehind,
    this.dragHint = 0,
  });

  final DailyStory story;
  final bool isBehind;

  /// -1 ~ 1：負值往「稍後」、正值往「閱讀」，決定兩枚印章的濃度。
  final double dragHint;

  static const _scrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x4D0F0B07),
      Color(0x000F0B07),
      Color(0x6B0F0B07),
      Color(0xED0F0B07),
    ],
    stops: [0.0, 0.26, 0.58, 1.0],
  );

  /// 後排的卡壓得更暗，才不會跟最上面那張搶注意力。
  static const _scrimBehind = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x570F0B07),
      Color(0x1A0F0B07),
      Color(0x800F0B07),
      Color(0xF20F0B07),
    ],
    stops: [0.0, 0.30, 0.62, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final imageUrl = story.imageUrl;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.paperSunk,
        borderRadius: BorderRadius.circular(tokens.rXl),
        boxShadow: isBehind
            ? const [
                BoxShadow(
                  color: Color(0x4D15100A),
                  blurRadius: 26,
                  offset: Offset(0, 10),
                ),
              ]
            : tokens.e3,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.rXl),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => ColoredBox(color: tokens.inkBg2),
              )
            else
              ColoredBox(color: tokens.inkBg2),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: isBehind ? _scrimBehind : _scrim,
              ),
            ),
            if (isBehind)
              const ColoredBox(color: Color(0x1A1B1611))
            else ...[
              _CardIndex(story: story),
              if (story.cardAnnoRoman != null)
                Positioned(
                  top: 18,
                  right: 18,
                  child: _ChapterBadge(label: story.cardAnnoRoman!),
                ),
              _DecisionStamp(
                label: 'story.deck_read'.tr(),
                opacity: dragHint.clamp(0.0, 1.0),
                alignRight: true,
              ),
              _DecisionStamp(
                label: 'story.deck_later'.tr(),
                opacity: (-dragHint).clamp(0.0, 1.0),
                alignRight: false,
              ),
            ],
            _CardCaption(story: story),
          ],
        ),
      ),
    );
  }
}

/// 左上角的期號（`.dcard__no`）：大字序號壓著小字 Anno。
class _CardIndex extends StatelessWidget {
  const _CardIndex({required this.story});

  final DailyStory story;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 18,
      left: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat('dd').format(story.publishDate),
            style: GoogleFonts.notoSerifTc(
              fontSize: 34,
              height: 0.8,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.9),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat('MMM').format(story.publishDate).toUpperCase(),
            style: GoogleFonts.notoSerifTc(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

/// 右上角的徽章（`.chapter-badge`）：白細框、寬字距的卷期標記。
class _ChapterBadge extends StatelessWidget {
  const _ChapterBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'ANNO · ${label.toUpperCase()}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.92,
        ),
      ),
    );
  }
}

/// 拖曳時浮出的決定印章（`.dcard__stamp`）：右「閱讀」、左「稍後」。
class _DecisionStamp extends StatelessWidget {
  const _DecisionStamp({
    required this.label,
    required this.opacity,
    required this.alignRight,
  });

  final String label;
  final double opacity;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 64,
      right: alignRight ? 22 : null,
      left: alignRight ? null : 22,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: (alignRight ? 11 : -11) * math.pi / 180,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: GoogleFonts.notoSerifTc(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 卡片下緣的文字（`.dcard__cap`）：短線眉標、大標、斜體副標、出處。
class _CardCaption extends StatelessWidget {
  const _CardCaption({required this.story});

  final DailyStory story;

  @override
  Widget build(BuildContext context) {
    final eyebrow = story.cardLocationEn ?? story.placeLocation;
    final sub = story.cardTitleSub;

    return Positioned(
      left: 24,
      right: 24,
      bottom: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 1,
                color: Colors.white.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  eyebrow.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.1,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            story.cardTitle ?? story.placeName,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.notoSerifTc(
              fontSize: 31,
              height: 1.12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              shadows: const [
                Shadow(
                  color: Color(0x800F0B07),
                  blurRadius: 22,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          if (sub != null && sub.isNotEmpty) ...[
            const SizedBox(height: 11),
            Text(
              sub,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.notoSerifTc(
                fontSize: 15,
                height: 1.55,
                fontStyle: FontStyle.italic,
                color: Colors.white.withValues(alpha: 0.84),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            '${story.placeName} · '
            '${DateFormat.yMMMd().format(story.publishDate)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.6,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

/// 牌堆進度（`.deck-progress`）：目前這張是一條 clay 短棒。
class _DeckProgress extends StatelessWidget {
  const _DeckProgress({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i += 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: i == index ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == index ? tokens.clay : tokens.lineStrong,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
