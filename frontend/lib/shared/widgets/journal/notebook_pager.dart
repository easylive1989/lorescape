import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:context_app/shared/widgets/page_dots.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 手記的紙張：橫線稿、左側紅褐天地線與裝訂孔帶。
///
/// 對應設計稿 `.nb-paper` 疊起來的三層背景——`repeating-linear-gradient`
/// 的橫線、`::before` 的 margin rule、`::after` 用 `radial-gradient` 打的
/// 裝訂孔。用 painter 畫是因為這三層都跟頁高有關，靠 `DecorationImage`
/// 拼不出隨高度重複的孔距。
class JournalPaperPainter extends CustomPainter {
  const JournalPaperPainter({
    required this.ruleColor,
    required this.marginRuleColor,
    required this.holeColor,
  });

  final Color ruleColor;
  final Color marginRuleColor;
  final Color holeColor;

  /// 第一條橫線的位置與行距（CSS 的 `transparent 0 33px, 色 33px 34px`）。
  static const double firstRule = 33;
  static const double ruleSpacing = 34;

  /// 天地線距左緣（`::before` 的 `left:34px`）。
  static const double marginRuleX = 34;

  /// 孔帶：`left:12px` 起、圓心在每格 tile 的 4px 處、半徑 2.5px、
  /// 每 40px 一顆，上下各留 20px。
  static const double holeCenterX = 16;
  static const double holeRadius = 2.5;
  static const double holeSpacing = 40;
  static const double holeInset = 20;

  /// 橫線的 y 座標。取 `+0.5` 讓 1px 的線壓在像素中心而不是跨兩格。
  static List<double> ruleOffsets(double height) {
    final offsets = <double>[];
    for (var y = firstRule; y <= height; y += ruleSpacing) {
      offsets.add(y + 0.5);
    }
    return offsets;
  }

  /// 裝訂孔的圓心 y 座標。
  static List<double> holeOffsets(double height) {
    final offsets = <double>[];
    final limit = height - holeInset;
    for (var y = holeInset + 4; y <= limit; y += holeSpacing) {
      offsets.add(y);
    }
    return offsets;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rule = Paint()
      ..color = ruleColor
      ..strokeWidth = 1;
    for (final y in ruleOffsets(size.height)) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
    }

    canvas.drawLine(
      const Offset(marginRuleX + 0.5, 0),
      Offset(marginRuleX + 0.5, size.height),
      Paint()
        ..color = marginRuleColor
        ..strokeWidth = 1,
    );

    final hole = Paint()..color = holeColor;
    for (final y in holeOffsets(size.height)) {
      canvas.drawCircle(Offset(holeCenterX, y), holeRadius, hole);
    }
  }

  @override
  bool shouldRepaint(JournalPaperPainter oldDelegate) =>
      oldDelegate.ruleColor != ruleColor ||
      oldDelegate.marginRuleColor != marginRuleColor ||
      oldDelegate.holeColor != holeColor;
}

/// 手記翻頁器的單頁資料。
@immutable
class NotebookPage {
  const NotebookPage({
    required this.title,
    required this.dateLabel,
    required this.text,
    this.address,
    this.imageUrl,
    this.onReplay,
    this.onAddToTrip,
    this.onShare,
    this.onDelete,
  });

  final String title;
  final String dateLabel;
  final String text;
  final String? address;
  final String? imageUrl;

  /// 重聽這一則手記；null 時標題右側不顯示重聽鍵。
  final VoidCallback? onReplay;

  /// 把這則手記收進另一本旅程；null 時不顯示該動作。
  final VoidCallback? onAddToTrip;
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
  const NotebookPager({super.key, required this.pages, this.onPageChanged});

  final List<NotebookPage> pages;

  /// 翻到第幾頁；外層需要知道現在停在哪一則時使用。
  final ValueChanged<int>? onPageChanged;

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
            onPageChanged: (i) {
              setState(() => _index = i);
              widget.onPageChanged?.call(i);
            },
            itemBuilder: (context, i) => _NotebookPageView(
              page: widget.pages[i],
              index: i,
              total: widget.pages.length,
            ),
          ),
        ),
        PageDots(
          count: widget.pages.length,
          index: _index,
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 18),
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

/// 照片與筆記之間的固定間距，算筆記可用高度時要一起扣掉。
const double _photoNoteGap = 16;

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

    final radius = BorderRadius.circular(context.tokens.rLg);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: paper,
          borderRadius: radius,
          border: Border.all(color: tokens?.line ?? colorScheme.outlineVariant),
          boxShadow: tokens?.e2,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: CustomPaint(
            painter: const JournalPaperPainter(
              // 設計稿的三層紙紋固定值，不隨主題色走：換色就不是這張紙了。
              ruleColor: Color.fromRGBO(90, 66, 42, 0.055),
              marginRuleColor: Color.fromRGBO(151, 68, 42, 0.28),
              holeColor: Color.fromRGBO(60, 44, 32, 0.16),
            ),
            // 左邊留給裝訂孔與天地線，對應 `padding:20px 22px 22px 54px`。
            child: Padding(
              padding: const EdgeInsets.fromLTRB(54, 20, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          'journey.notebook.entry_no'.tr(
                            args: ['${index + 1}'.padLeft(2, '0')],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSerifTc(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.92,
                            color: ink3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _DateStamp(label: page.dateLabel),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 照片與筆記黏在頁首下方、動作列留在頁底：把這兩塊包成一個
                  // Expanded 的內層 Column。多出來的高度優先給筆記正文多顯示
                  // 幾行，正文用不完才留成筆記與動作列之間的空白。
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // 筆記是 Column 的非彈性子項，主軸約束是無限高，沒辦法
                        // 自己知道還剩多少空間——正文因此曾經只能寫死 3 行，把
                        // 剩下的高度全留成空白。照片的自然高度是寬度的函數，
                        // 先扣掉它就得到筆記真正可用的高度。
                        final noteExtent = math.max(
                          _Note.minHeight,
                          constraints.maxHeight -
                              _Polaroid.naturalHeight(constraints.maxWidth) -
                              _photoNoteGap,
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // loose：頁面夠高時照片只佔自然高度，太矮時才讓
                            // FittedBox 整體縮小（筆記守住 minHeight 下限，
                            // 讓出空間的是照片）。
                            Flexible(
                              child: _Polaroid(page: page, index: index),
                            ),
                            const SizedBox(height: _photoNoteGap),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: noteExtent,
                              ),
                              child: _Note(page: page),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  _PageFooter(page: page, index: index, total: total),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 日期戳章（`.nb-stamp`）：clay 色細框、微微歪斜蓋上去的手帳戳記。
class _DateStamp extends StatelessWidget {
  const _DateStamp({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final clay = context.tokens.clay;

    return Transform.rotate(
      angle: 2.5 * math.pi / 180,
      child: Opacity(
        opacity: 0.72,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(color: clay, width: 1.5),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            label,
            maxLines: 1,
            style: GoogleFonts.notoSerifTc(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.72,
              color: clay,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
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

  /// 相紙的內距：底邊留厚一點，保住拍立得的相紙感。
  static const EdgeInsets _paperInsets = EdgeInsets.fromLTRB(12, 12, 12, 28);

  /// 設計稿的 `width:74%; max-width:250px`——照片是正方形，寬度定了高度也
  /// 就定了。頁面太矮時交給 [FittedBox] 整體等比縮小。
  static double _side(double maxWidth) => math.min(maxWidth * 0.74, 250.0);

  /// 不被壓縮時整張相紙佔的高度。頁面排版要先扣掉這塊才知道筆記剩多少空間，
  /// 所以算式收在這裡讓 [build] 與外層共用同一個來源。
  ///
  /// 旋轉與位移都只影響繪製、不改變版面尺寸，故不計入。
  static double naturalHeight(double maxWidth) =>
      _side(maxWidth) + _paperInsets.vertical;

  @override
  Widget build(BuildContext context) {
    final isOdd = index.isOdd;

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = _side(constraints.maxWidth);

        // heightFactor 1：只包住照片本身的高度，讓外層的 Flexible 能把剩餘
        // 空間留給下方，而不是把照片撐到正中央。
        return Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            // `margin:10px 0 0 -16px`——照片略偏左，壓在天地線那一側。
            child: Transform.translate(
              offset: const Offset(-16, 10),
              child: Transform.rotate(
                angle: (isOdd ? 1.8 : -2.4) * math.pi / 180,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      // 圖說改由下方的筆記標題承擔，不再重複景點名。
                      padding: _paperInsets,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFDF8),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x381C140A),
                            blurRadius: 24,
                            offset: Offset(0, 10),
                          ),
                        ],
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: SizedBox(
                        width: side,
                        height: side,
                        child: _PolaroidPhoto(imageUrl: page.imageUrl),
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
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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

  /// 正文字級與行高（設計稿 `.nb-text`）；行數要靠這兩個值換算。
  static const double _bodyFontSize = 15;
  static const double _bodyHeightFactor = 1.72;

  /// 換算行數用的單行高度。刻意取 15 × 1.72 = 25.8 的**上界** 26——引擎會把
  /// 行高進位到整數像素，用 25.8 去除會偶爾多算一行，筆記就會超出配給的高度
  /// 反過來把照片擠小。寧可少算一行也不要擠到照片。
  static const double _bodyLineExtent = 26;

  /// 改版前寫死的行數，現在退化成下限：空間不足時至少仍看得到這麼多。
  static const int _minBodyLines = 3;

  /// 標題列＋地址列＋間距的高度概估（19pt 標題約 26、12pt 地址 18、間距 15），
  /// 只用來推導 [minHeight]，不參與實際排版——真正的高度由框架量。
  static const double _headerExtent = 60;

  /// 筆記至少要拿到的高度：放得下 [_minBodyLines] 行正文。頁面矮到給不出這麼
  /// 多時，讓出空間的是照片（外層 [FittedBox] 縮小），不是正文。
  static const double minHeight =
      _bodyLineExtent * _minBodyLines + _headerExtent;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LorescapeTokens>();
    final colorScheme = Theme.of(context).colorScheme;
    final address = page.address;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                page.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (page.onReplay != null) ...[
              const SizedBox(width: 10),
              _ReplayIconButton(onTap: page.onReplay!),
            ],
          ],
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
        // 行數隨剩餘高度成長：頁面高就多顯示幾行，只有真的放不下才截斷。
        // 外層以 ConstrainedBox 給定高度上限，這裡才量得到可用空間。
        Flexible(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fitted = constraints.maxHeight.isFinite
                  ? (constraints.maxHeight / _bodyLineExtent).floor()
                  : _minBodyLines;

              return Text(
                page.text,
                maxLines: math.max(_minBodyLines, fitted),
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: _bodyFontSize,
                  height: _bodyHeightFactor,
                  color: tokens?.ink2 ?? colorScheme.onSurfaceVariant,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 標題右側的重聽鍵：clay 色圓鈕、只放播放 icon——設計稿的文字藥丸版
/// 放進筆記標題列會擠掉長景點名，縮成 icon 才擺得下。
class _ReplayIconButton extends StatelessWidget {
  const _ReplayIconButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Semantics(
      button: true,
      label: 'journey.replay_note'.tr(),
      child: Material(
        color: tokens.clay,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          highlightColor: tokens.clayDeep,
          child: const SizedBox(
            width: 34,
            height: 34,
            child: Icon(
              Icons.play_arrow_rounded,
              size: 20,
              color: Color(0xFFFBF1E9),
            ),
          ),
        ),
      ),
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
          const SizedBox(width: 12),
          // 三顆動作在窄機型或長翻譯下會擠爆同一列，讓整組等比縮小而不是
          // 溢出——比讓標籤各自 ellipsis 成「加入旅…」好讀。
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(children: _actions()),
            ),
          ),
        ],
      ),
    );
  }

  /// 只排出有 callback 的動作，並在彼此之間插入間距——用 list 組而不是寫死
  /// 三段 `if`，才不會在中間那顆缺席時留下多餘的空白。
  List<Widget> _actions() {
    final actions = <Widget>[
      if (page.onAddToTrip != null)
        _FooterAction(
          icon: Icons.menu_book_outlined,
          label: 'trip.add_to_trip'.tr(),
          onTap: page.onAddToTrip!,
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
