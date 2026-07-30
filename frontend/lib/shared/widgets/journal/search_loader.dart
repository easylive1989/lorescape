import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:flutter/material.dart';

/// 搜尋／定位進行中的全螢幕遮罩，對應設計稿的 `.search-loader`：
/// 半透明墨色底加輕微模糊，中央一張浮起紙卡，左側雙環 spinner，
/// 右側是主標與（可選的）搜尋關鍵字小字。
///
/// 設計上蓋住整個畫面、吃掉所有觸控——搜尋中不該再拖地圖或連按重新整理。
/// 只能放在全螢幕的 [Stack] 裡（自帶 [Positioned.fill]）。
class SearchLoader extends StatelessWidget {
  const SearchLoader({super.key, required this.label, this.name});

  /// 主標（「搜尋地點中」／「定位中」）。沒有 [name] 時尾端補上刪節號。
  final String label;

  /// 搜尋關鍵字；設計稿以全大寫小字顯示在主標下方。
  final String? name;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 200),
        builder: (context, t, child) => Opacity(opacity: t, child: child),
        child: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(
              color: const Color.fromRGBO(23, 18, 13, 0.24),
              alignment: Alignment.center,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutBack,
                builder: (context, t, child) =>
                    Transform.scale(scale: 0.9 + 0.1 * t, child: child),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 24, 18),
                  decoration: BoxDecoration(
                    color: tokens.paperRaised,
                    border: Border.all(color: tokens.line),
                    borderRadius: BorderRadius.circular(tokens.rLg),
                    boxShadow: tokens.e3,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _DualRing(
                        outerColor: tokens.clay,
                        innerColor: tokens.clayDeep.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name == null ? '$label……' : label,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontSize: 16, letterSpacing: 0.3),
                          ),
                          if (name case final name?)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                name.toUpperCase(),
                                key: const Key('search-loader-name'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.3,
                                  color: tokens.clay,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 設計稿 `.search-loader__ring`：40px 內外兩圈四分之一弧，外圈 clay 順時針
/// 0.8s 一圈、內圈 clay-deep 半透明逆時針 1.1s 一圈。
///
/// 用一支 8.8 秒（0.8 與 1.1 的最小公倍數）的 controller 驅動兩圈：外圈轉
/// 11 圈、內圈反向轉 8 圈，週期交界處角度連續，repeat 不會跳格。
class _DualRing extends StatefulWidget {
  const _DualRing({required this.outerColor, required this.innerColor});

  final Color outerColor;
  final Color innerColor;

  @override
  State<_DualRing> createState() => _DualRingState();
}

class _DualRingState extends State<_DualRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 8800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: const Size(40, 40),
        painter: _DualRingPainter(
          outerAngle: _controller.value * 11 * 2 * math.pi,
          innerAngle: -_controller.value * 8 * 2 * math.pi,
          outerColor: widget.outerColor,
          innerColor: widget.innerColor,
        ),
      ),
    );
  }
}

class _DualRingPainter extends CustomPainter {
  const _DualRingPainter({
    required this.outerAngle,
    required this.innerAngle,
    required this.outerColor,
    required this.innerColor,
  });

  final double outerAngle;
  final double innerAngle;
  final Color outerColor;
  final Color innerColor;

  static const double _stroke = 3;

  /// CSS 圓形只上 border-top-color 時，上色的是頂端四分之一圈。
  static const double _sweep = math.pi / 2;

  void _arc(Canvas canvas, Size size, double inset, double angle, Color color) {
    final rect = Offset(inset, inset) & Size.square(size.width - inset * 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = color;
    canvas.drawArc(
      rect.deflate(_stroke / 2),
      angle - math.pi / 2 - _sweep / 2,
      _sweep,
      false,
      paint,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    _arc(canvas, size, 0, outerAngle, outerColor);
    _arc(canvas, size, 7, innerAngle, innerColor);
  }

  @override
  bool shouldRepaint(_DualRingPainter oldDelegate) =>
      oldDelegate.outerAngle != outerAngle ||
      oldDelegate.innerAngle != innerAngle ||
      oldDelegate.outerColor != outerColor ||
      oldDelegate.innerColor != innerColor;
}
