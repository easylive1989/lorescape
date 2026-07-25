import 'package:flutter/material.dart';

/// 雙峰山形連續輪廓（正規化座標 * size）。座標系 y 向下。
/// 由左下角起：左峰 → 谷 → 右峰 → 右下角 → 沿底線收回。
Path buildMountainPath(Size size) {
  final w = size.width;
  final h = size.height;
  Offset p(double nx, double ny) => Offset(nx * w, ny * h);

  return Path()
    ..moveTo(p(0.10, 0.82).dx, p(0.10, 0.82).dy) // 左下角
    ..lineTo(p(0.34, 0.30).dx, p(0.34, 0.30).dy) // 左峰
    ..lineTo(p(0.46, 0.52).dx, p(0.46, 0.52).dy) // 谷
    ..lineTo(p(0.60, 0.16).dx, p(0.60, 0.16).dy) // 右峰（較高）
    ..lineTo(p(0.86, 0.82).dx, p(0.86, 0.82).dy) // 右下角
    ..lineTo(p(0.10, 0.82).dx, p(0.10, 0.82).dy); // 底線收回
}

/// 6 段足跡，沿一條由 (0.42,0.62) 往右上 (0.64,0.34) 的緩弧排列。
List<RRect> buildFootprints(Size size) {
  final w = size.width;
  final h = size.height;
  const centers = <Offset>[
    Offset(0.44, 0.60),
    Offset(0.49, 0.55),
    Offset(0.54, 0.50),
    Offset(0.58, 0.45),
    Offset(0.61, 0.40),
    Offset(0.63, 0.35),
  ];
  final dashW = 0.045 * w;
  final dashH = 0.028 * h;
  return [
    for (final c in centers)
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(c.dx * w, c.dy * h),
          width: dashW,
          height: dashH,
        ),
        Radius.circular(0.012 * w),
      ),
  ];
}

/// 描線動畫 painter：山形輪廓依 [strokeProgress] 0→1 逐段畫出；
/// 足跡依 [footprintProgress] 0→1 逐段淡入。
class MountainPainter extends CustomPainter {
  const MountainPainter({
    required this.strokeProgress,
    required this.footprintProgress,
    required this.color,
  });

  final double strokeProgress;
  final double footprintProgress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.035
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    // 山形描線：沿 PathMetric 取 0..len*progress 的子路徑。
    final full = buildMountainPath(size);
    for (final metric in full.computeMetrics()) {
      final sub = metric.extractPath(
        0,
        metric.length * strokeProgress.clamp(0.0, 1.0),
      );
      canvas.drawPath(sub, stroke);
    }

    // 足跡逐段淡入：把 [0,1] 切成 6 段，每段負責一枚足跡的 alpha。
    final prints = buildFootprints(size);
    final fill = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < prints.length; i++) {
      final segStart = i / prints.length;
      final segEnd = (i + 1) / prints.length;
      final t = ((footprintProgress - segStart) / (segEnd - segStart)).clamp(
        0.0,
        1.0,
      );
      if (t <= 0) continue;
      canvas.drawRRect(prints[i], fill..color = color.withValues(alpha: t));
    }
  }

  @override
  bool shouldRepaint(MountainPainter old) =>
      old.strokeProgress != strokeProgress ||
      old.footprintProgress != footprintProgress ||
      old.color != color;
}
