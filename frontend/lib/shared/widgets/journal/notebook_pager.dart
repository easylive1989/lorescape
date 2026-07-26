import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 手記翻頁器的單頁資料。
@immutable
class NotebookPage {
  const NotebookPage({
    required this.title,
    required this.dateLabel,
    required this.text,
    this.address,
    this.imageUrl,
    this.onPlay,
    this.onShare,
    this.onDelete,
  });

  final String title;
  final String dateLabel;
  final String text;
  final String? address;
  final String? imageUrl;

  /// 重新進入播放頁重聽這則記錄；null 時不顯示重聽鍵。
  final VoidCallback? onPlay;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;
}

/// 手記翻頁器，對應設計稿的 `.nb-*`：一頁一則記錄，左右拖曳翻頁。
///
/// 實作用 `PageView` 而不是照抄設計稿的手寫拖曳邏輯（位移門檻 60px、兩端
/// 0.32 阻尼）：自己排一列滿寬的頁面會讓 `Row` 永遠 overflow，`ClipRect`
/// 只遮得住畫面、遮不住框架的斷言，測試會直接掛掉。`PageView` 的物理效果
/// 是同一類手感（含兩端阻尼），而且順帶拿到無障礙與捲動語意。
class NotebookPager extends StatefulWidget {
  const NotebookPager({super.key, required this.pages});

  final List<NotebookPage> pages;

  @override
  State<NotebookPager> createState() => _NotebookPagerState();
}

class _NotebookPagerState extends State<NotebookPager> {
  final PageController _controller = PageController();
  int _index = 0;

  static const Duration _settleDuration = Duration(milliseconds: 400);
  static const Curve _settleCurve = Cubic(0.22, 0.61, 0.36, 1);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pages.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.pages.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => _NotebookPageView(
              page: widget.pages[i],
              index: i,
              total: widget.pages.length,
            ),
          ),
        ),
        _PageDots(
          count: widget.pages.length,
          index: _index,
          onSelect: (i) => _controller.animateToPage(
            i,
            duration: _settleDuration,
            curve: _settleCurve,
          ),
        ),
      ],
    );
  }
}

class _NotebookPageView extends StatelessWidget {
  const _NotebookPageView({
    required this.page,
    required this.index,
    required this.total,
  });

  final NotebookPage page;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LorescapeTokens>();
    final colorScheme = Theme.of(context).colorScheme;
    final paper = tokens?.paperRaised ?? colorScheme.surfaceContainerLow;
    final ink3 = tokens?.ink3 ?? colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
        decoration: BoxDecoration(
          color: paper,
          borderRadius: BorderRadius.circular(context.tokens.rLg),
          border: Border.all(color: tokens?.line ?? colorScheme.outlineVariant),
          boxShadow: tokens?.e2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'journey.notebook.entry_no'.tr(
                    args: ['${index + 1}'.padLeft(2, '0')],
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ink3,
                  ),
                ),
                Flexible(
                  child: Text(
                    page.dateLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: ink3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _Polaroid(page: page, index: index),
            ),
            const SizedBox(height: 16),
            _Note(page: page),
            _PageFooter(page: page, index: index, total: total),
          ],
        ),
      ),
    );
  }
}

/// 拍立得：正方形照片＋手寫圖說，奇偶頁左右微傾，角上貼一段膠帶。
class _Polaroid extends StatelessWidget {
  const _Polaroid({required this.page, required this.index});

  final NotebookPage page;
  final int index;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LorescapeTokens>();
    final isOdd = index.isOdd;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 照片是正方形，尺寸取「可用寬度」與「可用高度扣掉圖說」的較小者。
        // 直接用 AspectRatio 會以寬度為準，頁面矮的時候直接爆版。
        const chromeHeight = 78; // 內距 20 + 圖說約 58
        final side = math
            .min(
              constraints.maxWidth - 20,
              constraints.maxHeight - chromeHeight,
            )
            .clamp(72.0, 420.0);

        return Center(
          child: Transform.rotate(
            angle: (isOdd ? 1.8 : -2.4) * math.pi / 180,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDFBF6),
                    boxShadow: tokens?.e2,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: side,
                        height: side,
                        child: _PolaroidPhoto(imageUrl: page.imageUrl),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
                        child: Text(
                          page.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          // Long Cang：設計稿指定的手寫體，撐起「手記」的味道。
                          style: GoogleFonts.longCang(
                            fontSize: 24,
                            height: 1.1,
                            color: context.tokens.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 膠帶：奇偶頁貼在不同側。
                Positioned(
                  top: -11,
                  left: isOdd ? null : -14,
                  right: isOdd ? -14 : null,
                  child: Transform.rotate(
                    angle: (isOdd ? 30 : -32) * math.pi / 180,
                    child: Container(
                      width: 78,
                      height: 26,
                      color: const Color(0x6BCBA86E),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PolaroidPhoto extends StatelessWidget {
  const _PolaroidPhoto({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isEmpty) return const _EmptyPhoto();
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => const _EmptyPhoto(),
    );
  }
}

/// 無照片時的斜紋底，對應設計稿的 `.polaroid__ph--empty`。
class _EmptyPhoto extends StatelessWidget {
  const _EmptyPhoto();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFEFE7D6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 30,
              color: context.tokens.lineStrong,
            ),
            const SizedBox(height: 8),
            Text(
              'journey.notebook.no_photo'.tr(),
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.2,
                color: context.tokens.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.page});

  final NotebookPage page;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LorescapeTokens>();
    final colorScheme = Theme.of(context).colorScheme;
    final address = page.address;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          page.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (address != null && address.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.place_outlined,
                size: 13,
                color: (tokens?.clay ?? colorScheme.primary).withValues(
                  alpha: 0.8,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: tokens?.ink3 ?? colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 9),
        Text(
          page.text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 15,
            height: 1.72,
            color: tokens?.ink2 ?? colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PageFooter extends StatelessWidget {
  const _PageFooter({
    required this.page,
    required this.index,
    required this.total,
  });

  final NotebookPage page;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LorescapeTokens>();
    final ink3 = tokens?.ink3 ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${'${index + 1}'.padLeft(2, '0')} / ${'$total'.padLeft(2, '0')}',
            style: TextStyle(fontSize: 13, letterSpacing: 0.5, color: ink3),
          ),
          Row(children: _actions()),
        ],
      ),
    );
  }

  /// 只排出有 callback 的動作，並在彼此之間插入間距——用 list 組而不是寫死
  /// 三段 `if`，才不會在中間那顆缺席時留下多餘的空白。
  List<Widget> _actions() {
    final actions = <Widget>[
      if (page.onPlay != null)
        _FooterAction(
          icon: Icons.play_circle_outline,
          label: 'common.replay'.tr(),
          onTap: page.onPlay!,
        ),
      if (page.onShare != null)
        _FooterAction(
          icon: Icons.ios_share,
          label: 'common.share'.tr(),
          onTap: page.onShare!,
        ),
      if (page.onDelete != null)
        _FooterAction(
          icon: Icons.delete_outline,
          label: 'common.delete'.tr(),
          onTap: page.onDelete!,
        ),
    ];

    return [
      for (var i = 0; i < actions.length; i += 1) ...[
        if (i > 0) const SizedBox(width: 18),
        actions[i],
      ],
    ];
  }
}

class _FooterAction extends StatelessWidget {
  const _FooterAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LorescapeTokens>();
    final ink3 = tokens?.ink3 ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: ink3),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ink3,
            ),
          ),
        ],
      ),
    );
  }
}

/// 頁碼指示器（`.nb-dots`）：目前頁是一條 clay 色短棒，其餘是灰點。
class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.index,
    required this.onSelect,
  });

  final int count;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LorescapeTokens>();
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: i == index ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == index
                        ? (tokens?.clay ?? colorScheme.primary)
                        : (tokens?.lineStrong ?? colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
