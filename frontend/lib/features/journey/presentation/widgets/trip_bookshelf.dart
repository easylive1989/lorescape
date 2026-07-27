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
        Positioned.fill(
          bottom: 14,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEFE3CA), Color(0xFFE3D3B4)],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
                bottom: Radius.circular(3),
              ),
              border: Border.all(color: const Color(0x24977850)),
            ),
          ),
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
                          height:
                              TripBookshelf._heights[(firstIndex +
                                      books.length) %
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
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [palette.left, palette.right]),
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(2),
              right: Radius.circular(7),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x6B1C140A),
                offset: Offset(-5, 9),
                blurRadius: 17,
              ),
            ],
          ),
          child: Stack(
            children: [
              // 書口：頂端一條奶油色，模擬書頁疊起來的斷面。
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: 4,
                  child: ColoredBox(color: Color(0xBFF7EED6)),
                ),
              ),
              // 書脊右側的暗面，做出圓弧感。
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0x4DFFFFFF),
                        Color(0x00000000),
                        Color(0x73000000),
                      ],
                      stops: [0, 0.35, 1],
                    ),
                  ),
                ),
              ),
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
    );
  }
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

/// 木層板（`.shelf__plank`）：橫向細紋＋前緣厚度。
class _ShelfPlank extends StatelessWidget {
  const _ShelfPlank();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 20,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFCFA670), Color(0xFFBB9058), Color(0xFFA2794A)],
              stops: [0, 0.55, 1],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x571C140A),
                offset: Offset(0, 16),
                blurRadius: 22,
              ),
            ],
          ),
        ),
        // 前緣：讓層板看起來有厚度而不是一條色帶。
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            height: 7,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF9A7343), Color(0xFF835F38)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(4)),
            ),
          ),
        ),
      ],
    );
  }
}
