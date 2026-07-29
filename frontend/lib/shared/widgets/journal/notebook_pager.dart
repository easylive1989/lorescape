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

/// 手記翻頁器，對應設計稿的 `.nb-*`：一頁一則記錄，左右拖曳像翻書一樣翻頁。
///
/// 頁面是繞左緣旋轉的 3D 翻頁（`.nb-page` 的 `rotateY` ＋ `perspective`），
/// 不是橫向捲動——曾經用 `PageView` 近似，但那只是把整頁平移，翻不出紙張
/// 拱起、反光掃過、翻到一半看見紙背這些手感。頁面用 `Stack` 疊而不是排成
/// 一列，所以沒有 `Row` overflow 的問題。
class NotebookPager extends StatefulWidget {
  const NotebookPager({super.key, required this.pages, this.onPageChanged});

  final List<NotebookPage> pages;

  /// 翻到第幾頁；外層需要知道現在停在哪一則時使用。
  final ValueChanged<int>? onPageChanged;

  @override
  State<NotebookPager> createState() => _NotebookPagerState();
}

class _NotebookPagerState extends State<NotebookPager>
    with SingleTickerProviderStateMixin {
  int _index = 0;

  /// 正在翻的是哪一頁（翻下一頁時是當前頁，往回翻時是前一頁）。
  int? _flipPage;

  /// 翻頁進度 0～1；1 代表整頁已翻過去（-180°）。
  double _flipT = 0;

  /// 這次拖曳是往後翻還是往回翻。
  bool _flipForward = true;

  double _stageWidth = 1;

  /// 鬆手後把進度補到 0 或 1 的動畫。
  ///
  /// 在 `initState` 建而不是 `late final` 的 lazy 初始化：從沒翻過頁的
  /// pager 會在 `dispose()` 才第一次讀到它，那時 element 已經 deactivate，
  /// `vsync` 去找 `TickerMode` 會直接拋 assertion。
  late final AnimationController _settle;
  double _settleFrom = 0;
  double _settleTo = 0;

  /// 正在跑收尾動畫的頁。鬆手的瞬間頁碼就已經換好、手勢狀態也已釋放，
  /// 動畫只是讓這張紙自己飄完剩下的路——所以收尾期間使用者隨時能開始
  /// 翻下一頁（改版前新手勢會被吞去續推還沒落地的頁，體感上滑不動）。
  int? _settlePage;
  bool _settleForward = true;
  double _settleT = 0;

  /// 收尾動畫的全程長度；實際長度按剩餘距離等比縮短（見 [_onDragEnd]），
  /// 甩到快滿的頁才不會在幾乎看不出在動的尾巴上磨滿 660ms。
  static const Duration _settleDuration = Duration(milliseconds: 660);
  static const Duration _settleMinDuration = Duration(milliseconds: 220);
  static const Curve _settleCurve = Cubic(0.36, 0.72, 0.22, 1);

  /// 鬆手時翻過這個比例才算翻頁，否則彈回。
  static const double _commitThreshold = 0.28;

  /// 鬆手速度超過這個值（邏輯像素／秒）就視為甩動，不足距離門檻也翻頁。
  /// 沒有這條的話，從螢幕左半起手的往左快滑永遠滑不滿 [_commitThreshold]
  /// 的距離（手指先碰到螢幕邊緣），翻頁就變成「只有某些位置滑得動」。
  static const double _flingVelocity = 700;

  /// 已經到頭時仍讓紙翻起一點點，手感上知道「沒有下一頁了」。
  static const double _edgeResistance = 0.07;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(vsync: this, duration: _settleDuration)
      ..addListener(_onSettleTick);
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _onSettleTick() {
    final t = _settleCurve.transform(_settle.value);
    setState(() {
      _settleT = _settleFrom + (_settleTo - _settleFrom) * t;
      if (_settle.isCompleted) {
        // 落地：頁碼在鬆手時就換好了，這裡只要清掉動畫狀態。
        _settlePage = null;
        _settleT = 0;
      }
    });
  }

  /// 換頁並通知外層。頁碼在「確定會翻過去」的當下就換，不等動畫跑完。
  void _commitTo(int next) {
    _index = next;
    widget.onPageChanged?.call(next);
  }

  void _onDragUpdate(DragUpdateDetails details, double width) {
    _stageWidth = width <= 0 ? 1 : width;
    final dx = details.primaryDelta ?? 0;
    final last = widget.pages.length - 1;

    setState(() {
      // 進度已歸零而手指正往反方向走時解除方向鎖：起手的微小抖動（先往右
      // 一兩個像素再往左滑）不該讓整個手勢卡死在錯的方向、放手也沒反應。
      if (_flipPage != null &&
          _flipT == 0 &&
          (_flipForward ? dx > 0 : dx < 0)) {
        _flipPage = null;
      }
      if (_flipPage == null) {
        // 第一個有效位移決定方向：往左翻下一頁、往右翻回上一頁。
        if (dx < 0) {
          _flipPage = _index;
          _flipForward = true;
        } else if (dx > 0) {
          _flipPage = _index - 1;
          _flipForward = false;
        }
        // 抓到的頁若還在收尾動畫中（例如反悔把剛翻走的頁拖回來），接住它
        // 從目前的角度續拖，不讓手勢與動畫兩套狀態同時控制同一張紙。
        if (_flipPage != null && _flipPage == _settlePage) {
          _settle.stop();
          _flipT = _flipForward == _settleForward ? _settleT : 1 - _settleT;
          _settlePage = null;
        }
      }
      final page = _flipPage;
      if (page == null) return;

      final limit = _flipForward
          ? (_index < last ? 1.0 : _edgeResistance)
          : (_index > 0 ? 1.0 : _edgeResistance);
      final delta = (_flipForward ? -dx : dx) / _stageWidth;
      _flipT = (_flipT + delta).clamp(0.0, limit);

      // 拖曳中就把頁翻滿：立刻換頁並釋放手勢狀態，同一個手勢繼續拖
      // 就接著翻下一頁，不會把後續位移吞在已經翻完的頁上。
      if (_flipT >= 1) {
        _commitTo(_flipForward ? page + 1 : page);
        _flipPage = null;
        _flipT = 0;
      }
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final page = _flipPage;
    if (page == null) return;
    final last = widget.pages.length - 1;
    final canFlip = _flipForward ? _index < last : _index > 0;

    // 甩動優先於距離：順著翻頁方向甩就翻、逆著甩就收回，距離門檻只在
    // 慢慢拖、鬆手沒有速度時才出場——與 PageView 的手感一致。
    final vx = details.primaryVelocity ?? 0;
    final flungAlong = _flipForward
        ? vx < -_flingVelocity
        : vx > _flingVelocity;
    final flungBack = _flipForward ? vx > _flingVelocity : vx < -_flingVelocity;
    final commit =
        canFlip && !flungBack && (flungAlong || _flipT > _commitThreshold);

    setState(() {
      // 手勢狀態立刻釋放、剩下的路交給收尾動畫：下一個手勢不必等這張紙
      // 落地就能翻下一頁。若這次收尾蓋掉了上一張還沒飄完的紙，那張會直接
      // 落定（它的頁碼早已換好），只是少了尾巴幾格動畫。
      _settlePage = page;
      _settleForward = _flipForward;
      _settleFrom = _flipT;
      _settleTo = commit ? 1 : 0;
      _settleT = _settleFrom;
      if (commit) _commitTo(_flipForward ? page + 1 : page);
      _flipPage = null;
      _flipT = 0;
    });

    // 收尾長度隨剩餘距離等比縮短：翻剩一點點就快快落地，別讓使用者
    // 盯著幾乎靜止的尾巴猜「到底翻完了沒」。
    final ms =
        (_settleDuration.inMilliseconds * (_settleTo - _settleFrom).abs())
            .round();
    _settle.duration = Duration(
      milliseconds: math.max(_settleMinDuration.inMilliseconds, ms),
    );
    _settle.forward(from: 0);
  }

  /// 跳頁（頁點）：直接切換，不做整段翻頁動畫。
  void _jumpTo(int i) {
    if (i == _index) return;
    setState(() {
      _settle.stop();
      _settlePage = null;
      _settleT = 0;
      _flipPage = null;
      _flipT = 0;
      _index = i;
    });
    widget.onPageChanged?.call(i);
  }

  /// 第 [page] 頁現在轉到幾度：0 是攤平、-180 是整頁翻過去。
  double _degreesFor(int page) {
    if (page == _flipPage) {
      return _flipForward ? -180 * _flipT : -180 + 180 * _flipT;
    }
    if (page == _settlePage) {
      return _settleForward ? -180 * _settleT : -180 + 180 * _settleT;
    }
    return page < _index ? -180 : 0;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pages.isEmpty) return const SizedBox.shrink();

    // 只 build 看得到的幾頁，整疊都掛上去沒有意義。分三群，由底往上疊：
    // 右疊攤平的頁（大到小）→ 左疊只露紙背孔帶的 peek → 空中的頁（小到
    // 大，越晚翻起的越上面）。空中可能同時有兩張：一張在收尾動畫、一張
    // 在手指下。peek 停在 -180°，幾何上剛好只在左側留白露出裝訂孔帶，
    // 讓非第一頁時看得出「左邊還壓著上一頁」。
    final flipPage = _flipPage;
    final settlePage = _settlePage;
    final flying = <int>{
      if (settlePage != null) settlePage,
      if (flipPage != null) flipPage,
    };
    final resting = <int>{
      _index,
      if (flipPage != null) flipPage + 1,
      if (settlePage != null) settlePage + 1,
    }.difference(flying);
    final peek = [_index, ...flying].reduce(math.min) - 1;
    final pages = <int>[
      ...resting.toList()..sort((a, b) => b.compareTo(a)),
      peek,
      ...flying.toList()..sort(),
    ].where((i) => i >= 0 && i < widget.pages.length).toList();

    // 疊影跟著最上面那張在空中的紙走。
    final activeDeg = flipPage != null
        ? _degreesFor(flipPage).abs()
        : settlePage != null
        ? _degreesFor(settlePage).abs()
        : 0.0;

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (d) =>
                    _onDragUpdate(d, constraints.maxWidth),
                onHorizontalDragEnd: _onDragEnd,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    for (final i in pages)
                      _FlipPage(
                        key: ValueKey(i),
                        degrees: _degreesFor(i),
                        child: _NotebookPageView(
                          page: widget.pages[i],
                          index: i,
                          total: widget.pages.length,
                        ),
                      ),
                    // 翻起的紙落在底頁上的影子。
                    IgnorePointer(
                      child: Opacity(
                        opacity:
                            math.sin(math.pi * math.min(1, activeDeg / 180)) *
                            0.9,
                        child: const _PageCastShadow(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        PageDots(
          count: widget.pages.length,
          index: _index,
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 18),
          onSelect: _jumpTo,
        ),
      ],
    );
  }
}

/// 一頁紙：繞左緣翻轉，翻的過程中紙面會拱起來（凹折）並掃過一道反光。
///
/// 曲率 `curve = sin(π × lift)` 在翻到一半時最大，同時驅動三件事——紙面
/// 微微歪斜（rotateZ）、往讀者方向拱起（translateZ）、以及 glare 的明暗
/// 分佈。三者共用同一個曲率，紙才像同一張紙在折，而不是各動各的。
class _FlipPage extends StatelessWidget {
  const _FlipPage({super.key, required this.degrees, required this.child});

  final double degrees;
  final Widget child;

  /// 對應 `perspective:1250px`。
  static const double _perspective = 1 / 1250;

  /// 對應 `transform-origin:20px 50%`：轉軸壓在左緣內側一點。
  static const double _hingeX = 20;

  @override
  Widget build(BuildContext context) {
    final lift = math.min(1.0, degrees.abs() / 180);
    final curve = math.sin(math.pi * lift);
    // 超過 90° 就看到紙背了。
    final verso = degrees.abs() > 90;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final matrix = Matrix4.identity()
          ..setEntry(3, 2, -_perspective)
          ..rotateY(degrees * math.pi / 180)
          ..rotateZ(-curve * 1.3 * math.pi / 180)
          ..translateByDouble(0.0, 0.0, curve * 12, 1.0);

        return Transform(
          transform: matrix,
          alignment: Alignment(width <= 0 ? -1 : (_hingeX / width) * 2 - 1, 0),
          child: IgnorePointer(
            // 翻動中的紙不吃點擊，避免手勢中途誤觸頁面上的按鈕。
            ignoring: degrees != 0,
            child: verso
                ? const _PageVerso()
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      child,
                      if (curve > 0)
                        IgnorePointer(
                          child: _PageGlare(lift: lift, curve: curve),
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

/// 翻頁時掃過紙面的反光：靠轉軸側壓暗、外緣泛白，強度隨曲率走。
class _PageGlare extends StatelessWidget {
  const _PageGlare({required this.lift, required this.curve});

  final double lift;
  final double curve;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(context.tokens.rLg);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            // 設計稿是 92deg + 曲率微調，接近水平、略往下斜。
            begin: const Alignment(-1, -0.05),
            end: const Alignment(1, 0.05),
            colors: [
              Color.fromRGBO(46, 30, 18, 0.30 * curve + 0.14 * lift),
              Color.fromRGBO(46, 30, 18, 0.05 * curve),
              Color.fromRGBO(255, 248, 232, 0.26 * curve),
              Color.fromRGBO(255, 252, 242, 0.44 * curve),
            ],
            stops: [0, (32 + curve * 12) / 100, 0.84, 1],
          ),
        ),
      ),
    );
  }
}

/// 紙背（`.nb-verso`）：只有橫線與右側裝訂孔，靠左緣壓一道暗邊。
class _PageVerso extends StatelessWidget {
  const _PageVerso();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LorescapeTokens>();
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(context.tokens.rLg);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens?.paperRaised ?? colorScheme.surfaceContainerLow,
          borderRadius: radius,
          border: Border.all(color: tokens?.line ?? colorScheme.outlineVariant),
          boxShadow: tokens?.e2,
        ),
        child: ClipRRect(
          borderRadius: radius,
          // 背面的內容是鏡像的，轉回來才不會看到反寫的紙紋。
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..rotateY(math.pi),
            child: const CustomPaint(painter: _VersoPainter()),
          ),
        ),
      ),
    );
  }
}

/// 畫紙背：橫線 → 右側裝訂孔 → 左緣暗邊。
class _VersoPainter extends CustomPainter {
  const _VersoPainter();

  static const Color _ruleColor = Color.fromRGBO(90, 66, 42, 0.045);
  static const Color _holeColor = Color.fromRGBO(60, 44, 32, 0.14);

  /// 孔帶距右緣 12px、每 26px 一顆（比正面密）。
  static const double _holeRightInset = 16;
  static const double _holeSpacing = 26;
  static const double _holeInset = 20;
  static const double _holeRadius = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    final rule = Paint()
      ..color = _ruleColor
      ..strokeWidth = 1;
    for (
      var y = JournalPaperPainter.firstRule;
      y <= size.height;
      y += JournalPaperPainter.ruleSpacing
    ) {
      canvas.drawLine(Offset(0, y + 0.5), Offset(size.width, y + 0.5), rule);
    }

    final hole = Paint()..color = _holeColor;
    final x = size.width - _holeRightInset;
    for (
      var y = _holeInset + 4;
      y <= size.height - _holeInset;
      y += _holeSpacing
    ) {
      canvas.drawCircle(Offset(x, y), _holeRadius, hole);
    }

    // 左緣暗邊：紙背靠近裝訂側本來就照不到光。
    final edge = Rect.fromLTWH(0, 0, size.width * 0.34, size.height);
    canvas.drawRect(
      edge,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color.fromRGBO(60, 40, 26, 0.16), Color(0x00000000)],
        ).createShader(edge),
    );
  }

  @override
  bool shouldRepaint(covariant _VersoPainter oldDelegate) => false;
}

/// 翻起的紙落在底下那頁的影子（`.nb-cast`）。
class _PageCastShadow extends StatelessWidget {
  const _PageCastShadow();

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(context.tokens.rLg);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: const LinearGradient(
            colors: [
              Color.fromRGBO(38, 24, 14, 0.55),
              Color.fromRGBO(38, 24, 14, 0.20),
              Color.fromRGBO(38, 24, 14, 0.05),
              Color(0x00000000),
            ],
            stops: [0, 0.26, 0.52, 0.72],
          ),
        ),
      ),
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
