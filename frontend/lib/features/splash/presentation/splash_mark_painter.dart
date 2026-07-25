import 'dart:math' as math;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

/// 依 Claude Design 的 splash mark 幾何繪製（viewBox 512）：
/// 藍色山形輪廓（靜態、接續原生 splash）＋淡入的山體填色與雪頂＋逐一彈入的
/// 5 枚中空足跡。座標直接取自設計稿。
class SplashMarkPainter extends CustomPainter {
  const SplashMarkPainter({
    required this.strokeProgress,
    required this.fillOpacity,
    required this.dashPops,
    required this.brand,
    required this.slope,
    required this.snow,
  });

  /// 山形輪廓描線進度（0→1）。
  final double strokeProgress;

  /// 山體填色與雪頂的淡入透明度（0→1）。
  final double fillOpacity;

  /// 5 枚足跡各自的彈入進度（0→1）。
  final List<double> dashPops;

  final Color brand;
  final Color slope;
  final Color snow;

  // 山形輪廓折點（512 座標，底部 233→316 為開口，不相連）。
  static const _outline = <Offset>[
    Offset(316, 366),
    Offset(422, 366),
    Offset(300, 145),
    Offset(248, 256),
    Offset(197, 176),
    Offset(90, 366),
    Offset(233, 366),
  ];

  static const _snowCapLeft = <Offset>[
    Offset(197, 178),
    Offset(164, 234),
    Offset(178, 224),
    Offset(190, 235),
    Offset(206, 224),
    Offset(220, 234),
    Offset(234, 231),
  ];
  static const _snowCapRight = <Offset>[
    Offset(300, 148),
    Offset(271, 207),
    Offset(284, 197),
    Offset(295, 208),
    Offset(310, 196),
    Offset(322, 207),
    Offset(334, 205),
  ];

  // 足跡中心（512 座標）、弧心、尺寸。
  static const _cx = 279.0, _cy = 319.0, _tw = 25.0, _th = 17.0;
  static const _tiles = <Offset>[
    Offset(272, 272),
    Offset(308, 288),
    Offset(326, 316),
    Offset(298, 345),
    Offset(260, 362),
  ];

  Path _poly(List<Offset> pts, double s, {bool close = false}) {
    final p = Path()..moveTo(pts.first.dx * s, pts.first.dy * s);
    for (final o in pts.skip(1)) {
      p.lineTo(o.dx * s, o.dy * s);
    }
    if (close) p.close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 512.0;

    // 山體填色（淡入）。
    if (fillOpacity > 0) {
      canvas.drawPath(
        _poly(_outline, s, close: true),
        Paint()
          ..style = PaintingStyle.fill
          ..color = slope.withValues(alpha: fillOpacity),
      );
      final snowPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = snow.withValues(alpha: fillOpacity);
      canvas.drawPath(_poly(_snowCapLeft, s, close: true), snowPaint);
      canvas.drawPath(_poly(_snowCapRight, s, close: true), snowPaint);
    }

    // 足跡（中空圓角、逐一彈入）。
    for (var i = 0; i < _tiles.length; i++) {
      final p = i < dashPops.length ? dashPops[i] : 1.0;
      if (p <= 0) continue;
      // pop：0→.62 放大到 1.14，.62→1 回到 1；透明度前段快速淡入。
      final scale = p < 0.62
          ? 0.35 + (1.14 - 0.35) * (p / 0.62)
          : 1.14 + (1.0 - 1.14) * ((p - 0.62) / 0.38);
      final opacity = (p * 3).clamp(0.0, 1.0);
      final c = _tiles[i];
      final angle = math.atan2(c.dy - _cy, c.dx - _cx) + math.pi / 2;
      canvas.save();
      canvas.translate(c.dx * s, c.dy * s);
      canvas.rotate(angle);
      canvas.scale(scale);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: _tw * s,
        height: _th * s,
      );
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(6.5 * s));
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.fill
          ..color = snow.withValues(alpha: opacity),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * s
          ..color = brand.withValues(alpha: opacity),
      );
      canvas.restore();
    }

    // 山形輪廓描線（依 strokeProgress 逐段畫出）。
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = brand;
    final outline = _poly(_outline, s);
    final p = strokeProgress.clamp(0.0, 1.0);
    if (p >= 1.0) {
      canvas.drawPath(outline, strokePaint);
    } else if (p > 0) {
      for (final metric in outline.computeMetrics()) {
        canvas.drawPath(metric.extractPath(0, metric.length * p), strokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(SplashMarkPainter old) =>
      old.strokeProgress != strokeProgress ||
      old.fillOpacity != fillOpacity ||
      !listEquals(old.dashPops, dashPops) ||
      old.brand != brand ||
      old.slope != slope ||
      old.snow != snow;
}
