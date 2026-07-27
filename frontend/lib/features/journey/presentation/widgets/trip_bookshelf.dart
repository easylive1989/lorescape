import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// 書架上的一本「旅程」。
@immutable
class ShelfBook {
  const ShelfBook({
    required this.title,
    required this.subtitle,
    required this.hasEntries,
    required this.onTap,
  });

  final String title;
  final String subtitle;

  /// 有沒有內容，決定書背上的小圖示（有內容＝書，空的＝無影像）。
  final bool hasEntries;
  final VoidCallback onTap;
}

/// 旅程書架，對應設計稿的 `.bookshelf`：凹槽背板 ＋ 一排立著的書 ＋ 木層板。
///
/// 書本高度刻意不齊（190 / 204 / 218 循環），跟設計稿一樣，避免看起來像
/// 一排等高的色塊。
///
/// 書放不下時不橫向捲動，而是往下長出新的一層書架——書櫃本來就是這樣長的，
/// 而且整頁本來就能上下捲，使用者不必為了看見第 8 本書去發現一個橫滑手勢。
class TripBookshelf extends StatelessWidget {
  const TripBookshelf({
    super.key,
    required this.books,
    required this.caption,
    required this.onAddTrip,
  });

  final List<ShelfBook> books;

  /// 書架上方的小標，例如「旅程書架 · 3 本」。
  final String caption;

  /// 按下書架末端那本虛線佔位書：建立新旅程。
  ///
  /// 這顆入口原本是頁首右上的 `+`，移到書架上是因為「新增一本書」的位置就
  /// 該在書架上——空位長什麼樣，使用者一眼就知道那裡可以放一本新的。
  final VoidCallback onAddTrip;

  static const List<double> _heights = [190, 204, 218];

  /// 書與書之間的間距，也用來算一層放得下幾本。
  static const double _gap = 11;

  /// 凹槽背板到書之間的內距（左右各一）。
  static const double _shelfPadding = 14;

  /// 書排相對於背板再內縮的距離（左右各一）。
  static const double _rowPadding = 12;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Text(
              caption,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.76,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final perShelf = _booksPerShelf(constraints.maxWidth);
              // 佔位書也佔一個位子，否則末層剛好排滿時它會擠爆該層。
              final slots = books.length + 1;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var start = 0; start < slots; start += perShelf)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: _Shelf(
                        books: books.sublist(
                          math.min(start, books.length),
                          math.min(start + perShelf, books.length),
                        ),
                        // 高度與配色沿用全域序號，換層時花色才會繼續變化。
                        firstIndex: start,
                        // 佔位書永遠掛在最後一層的尾巴。
                        showAddSlot: start + perShelf >= slots,
                        onAddTrip: onAddTrip,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// 一層書架放得下幾本；至少放 1 本，免得寬度極窄時除出 0。
  static int _booksPerShelf(double maxWidth) {
    final available = maxWidth - (_shelfPadding + _rowPadding) * 2 + _gap;
    return math.max(1, available ~/ (_Book._width + _gap));
  }
}

/// 一層書架：凹槽背板 ＋ 一排書 ＋ 木層板。
class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.books,
    required this.firstIndex,
    required this.showAddSlot,
    required this.onAddTrip,
  });

  final List<ShelfBook> books;

  /// 這層第一本書在整個書架裡的序號，用來延續高度與配色的循環。
  final int firstIndex;

  /// 這層尾端要不要放那本虛線佔位書。
  final bool showAddSlot;
  final VoidCallback onAddTrip;

  static const double _rowMinHeight = 214;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 凹槽背板：比書矮一截（底部留 14），讓層板壓在前面。
        const Positioned.fill(
          bottom: 14,
          child: CustomPaint(painter: _ShelfAlcovePainter()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TripBookshelf._shelfPadding,
            TripBookshelf._shelfPadding,
            TripBookshelf._shelfPadding,
            0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: _rowMinHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TripBookshelf._rowPadding,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < books.length; i++) ...[
                        if (i > 0) const SizedBox(width: TripBookshelf._gap),
                        _Book(
                          book: books[i],
                          height:
                              TripBookshelf._heights[(firstIndex + i) %
                                  TripBookshelf._heights.length],
                          palette: _BookPalette.values[(firstIndex + i) % 4],
                        ),
                      ],
                      if (showAddSlot) ...[
                        if (books.isNotEmpty)
                          const SizedBox(width: TripBookshelf._gap),
                        _AddBook(
                          // 跟同排最後一本書等高：空位要看起來是「這排少了
                          // 一本」，高度自己跳一級反而像另外擺上去的東西。
                          height: books.isEmpty
                              ? TripBookshelf._heights[firstIndex %
                                    TripBookshelf._heights.length]
                              : TripBookshelf._heights[(firstIndex +
                                        books.length -
                                        1) %
                                    TripBookshelf._heights.length],
                          onTap: onAddTrip,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const _ShelfPlank(),
            ],
          ),
        ),
      ],
    );
  }
}

/// 畫凹槽背板（`.shelf::before`）：底色 → 上緣內陰影 → 下緣內陰影 → 內描邊。
///
/// 三道都是 `inset box-shadow`，Flutter 的 [BoxDecoration] 只做得到外陰影，
/// 所以整片自己畫；上緣比下緣重，凹槽才會有「往裡收」的深度。
class _ShelfAlcovePainter extends CustomPainter {
  const _ShelfAlcovePainter();

  /// 上緣內陰影（`inset 0 10px 22px`）。
  static const double _topShadowHeight = 26;
  static const Color _topShadowColor = Color(0x335A422A);

  /// 下緣內陰影（`inset 0 -6px 14px`），比上緣淺。
  static const double _bottomShadowHeight = 16;
  static const Color _bottomShadowColor = Color(0x1F5A422A);

  /// 內描邊（`inset 0 0 0 1px`）。
  static const Color _ringColor = Color(0x24977850);

  static const BorderRadius _radius = BorderRadius.vertical(
    top: Radius.circular(8),
    bottom: Radius.circular(3),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = _radius.toRRect(rect);
    canvas.save();
    canvas.clipRRect(rrect);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEFE3CA), Color(0xFFE3D3B4)],
        ).createShader(rect),
    );

    final topRect = Rect.fromLTWH(0, 0, size.width, _topShadowHeight);
    canvas.drawRect(
      topRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_topShadowColor, Color(0x005A422A)],
        ).createShader(topRect),
    );

    final bottomRect = Rect.fromLTWH(
      0,
      size.height - _bottomShadowHeight,
      size.width,
      _bottomShadowHeight,
    );
    canvas.drawRect(
      bottomRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [_bottomShadowColor, Color(0x005A422A)],
        ).createShader(bottomRect),
    );

    canvas.restore();

    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _ringColor,
    );
  }

  @override
  bool shouldRepaint(covariant _ShelfAlcovePainter oldDelegate) => false;
}

/// 四種書皮配色，對應設計稿的 `.book--a` ～ `.book--d`。
enum _BookPalette {
  a(Color(0xFF7A3320), Color(0xFF9C4F37)),
  c(Color(0xFF524E34), Color(0xFF706A45)),
  b(Color(0xFF332B25), Color(0xFF4F4033)),
  d(Color(0xFF654529), Color(0xFF856541));

  const _BookPalette(this.left, this.right);

  final Color left;
  final Color right;
}

class _Book extends StatelessWidget {
  const _Book({
    required this.book,
    required this.height,
    required this.palette,
  });

  final ShelfBook book;
  final double height;
  final _BookPalette palette;

  static const double _width = 60;
  static const Color _gilt = Color(0xFFF6E6C2);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${book.title}｜${book.subtitle}',
      child: GestureDetector(
        onTap: book.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: _width,
          height: height,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.horizontal(
              left: Radius.circular(2),
              right: Radius.circular(7),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x6B1C140A),
                offset: Offset(-5, 9),
                blurRadius: 17,
              ),
            ],
          ),
          // 書皮、書口、脊上的光影與裝訂棱全部畫在這層，文字與 icon 疊上去。
          child: CustomPaint(
            painter: _BookSpinePainter(palette),
            child: Stack(
              children: [
                Positioned(
                  top: 17,
                  left: 0,
                  right: 0,
                  child: Icon(
                    book.hasEntries
                        ? Icons.menu_book_outlined
                        : Icons.image_not_supported_outlined,
                    size: 13,
                    color: const Color(0xEBFFEECE),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 12,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0x57FFE8C4)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      // 書名一律畫在框線內：實機 iOS 上曾出現字影跑到框外、
                      // 落在書脊左緣的鬼影字，這層 clip 是最後一道保險。
                      child: ClipRect(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 10,
                          ),
                          child: _VerticalTitle(text: book.title),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Text(
                    book.subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.6,
                      color: Color(0xB8FFEBC8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 畫書脊（`.book` 的三層背景 ＋ 六道 inset ＋ 兩條裝訂棱）。
///
/// CSS 那邊靠 `background-image` 疊三層、`box-shadow` 疊六道、再用
/// `::before/::after` 生兩條棱；Flutter 沒有 inset shadow 也沒有多重
/// background，全部按同樣的順序自己畫。
class _BookSpinePainter extends CustomPainter {
  const _BookSpinePainter(this.palette);

  final _BookPalette palette;

  static const BorderRadius _radius = BorderRadius.horizontal(
    left: Radius.circular(2),
    right: Radius.circular(7),
  );

  /// 書口：頂端書頁斷面（`inset 0 4px 0 rgba(247,238,214,.75)`）。
  static const double _foreEdgeHeight = 4;
  static const Color _foreEdgeColor = Color(0xBFF7EED6);

  /// 左脊高光與右脊暗面的寬度（由 `inset` 的 blur/spread 換算的近似值）。
  static const double _leftHighlightWidth = 5;
  static const double _rightShadeWidth = 7;

  /// 上下鍍金帶：距書口一點點、貼著書底各一條。
  static const double _giltHeight = 2;
  static const Color _giltColor = Color(0x8CFFEBC8);

  /// 裝訂棱（`::before` / `::after`）：距上下緣 30px、7px 高。
  static const double _ridgeInset = 30;
  static const double _ridgeHeight = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(_radius.toRRect(rect));

    // 1. 主色：書皮左深右淺。
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [palette.left, palette.right],
        ).createShader(rect),
    );

    // 2. 左上方的柔光，讓皮面不是死板的一片色。
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.76),
          radius: 1.2,
          colors: [Color(0x24FFDCBE), Color(0x00FFDCBE)],
        ).createShader(rect),
    );

    // 3. 斜向明暗（overlay）：靠上偏亮、六成之後壓暗。
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.overlay
        ..shader = const LinearGradient(
          begin: Alignment(-1, -0.2),
          end: Alignment(1, 0.2),
          colors: [Color(0x1AFFFFFF), Color(0x24000000)],
          stops: [0, 0.6],
        ).createShader(rect),
    );

    // 4. 左脊高光。
    final leftRect = Rect.fromLTWH(0, 0, _leftHighlightWidth, size.height);
    canvas.drawRect(
      leftRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x4DFFFFFF), Color(0x00FFFFFF)],
        ).createShader(leftRect),
    );

    // 5. 右脊暗面：書脊往內收的圓弧。
    final rightRect = Rect.fromLTWH(
      size.width - _rightShadeWidth,
      0,
      _rightShadeWidth,
      size.height,
    );
    canvas.drawRect(
      rightRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x00000000), Color(0x73000000)],
        ).createShader(rightRect),
    );

    // 6. 兩條裝訂棱：上白下黑的凸起，各自帶一道往外的暗影。
    _paintRidge(canvas, size, top: _ridgeInset, shadowAbove: true);
    _paintRidge(
      canvas,
      size,
      top: size.height - _ridgeInset - _ridgeHeight,
      shadowAbove: false,
    );

    // 7. 上下鍍金帶。
    final giltPaint = Paint()..color = _giltColor;
    canvas.drawRect(
      Rect.fromLTWH(0, _foreEdgeHeight, size.width, _giltHeight),
      giltPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - _giltHeight, size.width, _giltHeight),
      giltPaint,
    );

    // 8. 書口疊在最上層，蓋住鍍金帶的上緣。
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, _foreEdgeHeight),
      Paint()..color = _foreEdgeColor,
    );

    canvas.restore();
  }

  void _paintRidge(
    Canvas canvas,
    Size size, {
    required double top,
    required bool shadowAbove,
  }) {
    final ridge = Rect.fromLTWH(0, top, size.width, _ridgeHeight);
    canvas.drawRect(
      ridge,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x29FFFFFF), Color(0x38000000)],
        ).createShader(ridge),
    );
    // 棱外側再壓一條窄暗影，凸起才有厚度。
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        shadowAbove ? top - 2 : top + _ridgeHeight,
        size.width,
        2,
      ),
      Paint()..color = const Color(0x2E000000),
    );
  }

  @override
  bool shouldRepaint(covariant _BookSpinePainter oldDelegate) =>
      oldDelegate.palette != palette;
}

/// 書架末端的佔位書：一個虛線圍出來的空書位，中間一個 `+`。
///
/// 尺寸與真書一致（同寬、同一組高度循環），才像書架上「還空著的一格」，而
/// 不是一顆貼在書旁邊的按鈕。
class _AddBook extends StatelessWidget {
  const _AddBook({required this.height, required this.onTap});

  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'trip.create_action'.tr(),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: CustomPaint(
          painter: const _DashedBookPainter(),
          child: SizedBox(
            width: _Book._width,
            height: height,
            child: Center(
              child: Icon(
                Icons.add,
                size: 22,
                color: const Color(0xFF6B5334).withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 佔位書的虛線外框，圓角與真書的書脊一致（左 2、右 7）。
///
/// Flutter 沒有內建虛線邊框，用 `PathMetric` 沿著圓角路徑切段落畫。
class _DashedBookPainter extends CustomPainter {
  const _DashedBookPainter();

  static const double _dash = 5;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          Offset.zero & size,
          topLeft: const Radius.circular(2),
          bottomLeft: const Radius.circular(2),
          topRight: const Radius.circular(7),
          bottomRight: const Radius.circular(7),
        ),
      );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF8A6C43).withValues(alpha: 0.6);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + _dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBookPainter oldDelegate) => false;
}

/// 直排書名。
///
/// CJK 的 `writing-mode: vertical-rl` 是「字元直立堆疊」而不是把整行轉 90°，
/// 所以這裡逐字堆疊，而不是用 `RotatedBox`——後者會讓中文躺著，完全不對。
///
/// 每個字各自是一個單行 `Text`，而不是把字用 `\n` 接成一個多行 paragraph：
/// 多行版本在實機 iOS 上會有某一行的字影被畫到框線左外側（偏移量剛好等於一個
/// 行高），變成書脊上的鬼影字。單行 paragraph 沒有跨行版面，結構上不可能發生。
class _VerticalTitle extends StatelessWidget {
  const _VerticalTitle({required this.text});

  final String text;

  /// 對應設計稿 `max-height:132px`：超出的字捨去，避免長名字把書撐爛。
  static const int _maxCharacters = 7;

  static const TextStyle _style = TextStyle(
    fontSize: 15,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    color: _Book._gilt,
    shadows: [
      Shadow(color: Color(0x66000000), offset: Offset(0, 1), blurRadius: 1),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final characters = text.characters.toList();
    final visible = characters.length > _maxCharacters
        ? [...characters.take(_maxCharacters - 1), '…']
        : characters;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final character in visible)
          Text(character, textAlign: TextAlign.center, style: _style),
      ],
    );
  }
}

/// 木層板（`.shelf__plank`）：直向木紋條紋＋上下 inset 明暗＋前緣厚度。
///
/// 條紋與 inset 陰影 Flutter 都沒有現成對應（`repeating-linear-gradient`
/// 與 `inset box-shadow`），所以板面整片交給 [_ShelfPlankPainter] 畫。
class _ShelfPlank extends StatelessWidget {
  const _ShelfPlank();

  /// 板面厚度，對應設計稿的 `height:20px`。
  static const double _height = 20;

  /// 前緣（`::after`）高度與左右內縮（設計稿為 1.5%，此處以固定值近似）。
  static const double _lipHeight = 7;
  static const double _lipInset = 4;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 板面下方的落地陰影畫在 Container，條紋與 inset 交給 painter。
        Container(
          height: _height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x571C140A),
                offset: Offset(0, 16),
                blurRadius: 22,
              ),
            ],
          ),
          child: const CustomPaint(
            painter: _ShelfPlankPainter(),
            size: Size.fromHeight(_height),
          ),
        ),
        // 前緣：讓層板看起來有厚度而不是一條色帶。
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _lipInset),
          child: Container(
            height: _lipHeight,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF866438), Color(0xFF725431)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(4)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x521C140A),
                  offset: Offset(0, 10),
                  blurRadius: 14,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 畫層板板面：底色漸層 → 直向木紋 → 頂緣高光 → 底部內陰影。
///
/// 四層的疊法與順序都照設計稿的 `.shelf__plank`；條紋走 7px 一個週期
/// （深 3px、淺 4px），是木紋而不是等寬斑馬線，所以兩段寬度不同。
class _ShelfPlankPainter extends CustomPainter {
  const _ShelfPlankPainter();

  /// 木紋週期與深色段寬度。
  static const double _grainPeriod = 7;
  static const double _grainDark = 3;

  static const Color _grainDarkColor = Color(0x1A5A3719);
  static const Color _grainLightColor = Color(0x0AFFFFFF);

  /// 頂緣高光（`inset 0 2px 0`）：實色、不模糊。
  static const double _highlightHeight = 2;
  static const Color _highlightColor = Color(0x73FFF7E8);

  /// 底部內陰影（`inset 0 -5px 9px`）：往上暈開，讓板面前緣收得下去。
  static const double _innerShadowHeight = 11;
  static const Color _innerShadowColor = Color(0x733C2814);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(2));
    canvas.save();
    canvas.clipRRect(rrect);

    // 1. 底色：上亮下暗的木頭本色。
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB49061), Color(0xFFA37D4D), Color(0xFF8D6940)],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );

    // 2. 直向木紋：深淺相間，整片鋪滿。
    final darkPaint = Paint()..color = _grainDarkColor;
    final lightPaint = Paint()..color = _grainLightColor;
    for (var x = 0.0; x < size.width; x += _grainPeriod) {
      canvas.drawRect(Rect.fromLTWH(x, 0, _grainDark, size.height), darkPaint);
      canvas.drawRect(
        Rect.fromLTWH(
          x + _grainDark,
          0,
          _grainPeriod - _grainDark,
          size.height,
        ),
        lightPaint,
      );
    }

    // 3. 頂緣高光：一條實色細線，木板的上稜。
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, _highlightHeight),
      Paint()..color = _highlightColor,
    );

    // 4. 底部內陰影：由下往上淡出。
    final shadowRect = Rect.fromLTWH(
      0,
      size.height - _innerShadowHeight,
      size.width,
      _innerShadowHeight,
    );
    canvas.drawRect(
      shadowRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [_innerShadowColor, Color(0x003C2814)],
        ).createShader(shadowRect),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShelfPlankPainter oldDelegate) => false;
}
