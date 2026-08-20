import 'dart:ui' as ui;

import 'package:flutter/material.dart';
// latlong2 也匯出一個泛型 Path<T>，會跟 dart:ui 的 Path（畫布路徑）撞名，
// 這裡只需要經緯度型別，把它的 Path 隱藏掉。
import 'package:latlong2/latlong.dart' hide Path;

import 'package:context_app/features/journey/domain/globe/globe_rotation.dart';
import 'package:context_app/features/journey/domain/globe/orthographic_projection.dart';
import 'package:context_app/features/journey/domain/globe/world_outline.dart';
import 'package:context_app/features/journey/domain/models/globe_pin.dart';
import 'package:context_app/features/journey/presentation/widgets/globe_palette.dart';

/// 畫那顆手繪風地球：海、經緯網格、陸地、打光，最後是旅程停點的釘點。
///
/// 被選中的那個點不畫在這裡——它是疊在上層的 Flutter widget（水滴 pin 與
/// 紙卡 chip），這樣才能用 App 的字體與陰影，不必在 canvas 裡重刻一份。
class GlobePainter extends CustomPainter {
  GlobePainter({
    required this.outline,
    required this.pins,
    required this.rotation,
    required this.focusId,
  });

  final WorldOutline outline;
  final List<GlobePin> pins;
  final GlobeRotation rotation;
  final String? focusId;

  /// 網格線的間隔（度）。
  static const double _graticuleStep = 10;

  /// 釘點可見的角距上限（弧度）。太靠近球緣的點視覺上已貼在邊上，標籤會
  /// 壓到球外，不畫也不參與點擊命中（GlobeView 的 tap 判定共用這個值）。
  static const double maxPinAngularDistance = 1.4;

  /// 釘點與對焦標記共用的書本圖示，與書架上「有記錄的書」同一個
  /// （trip_bookshelf 的 ShelfBook）。
  static const IconData bookIcon = Icons.menu_book;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2 - 3;
    final center = Offset(size.width / 2, size.height / 2);
    final projection = OrthographicProjection(
      rotation: rotation,
      center: center,
      radius: radius,
    );

    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    );

    canvas.drawCircle(center, radius, Paint()..color = GlobePalette.ocean);
    _paintGraticule(canvas, projection);
    _paintLand(canvas, projection);
    _paintShading(canvas, center, radius);

    canvas.restore();

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = GlobePalette.rim,
    );

    _paintPins(canvas, projection);
  }

  void _paintGraticule(Canvas canvas, OrthographicProjection projection) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = GlobePalette.graticule;

    for (var lat = -80.0; lat <= 80; lat += _graticuleStep) {
      _strokePath(canvas, projection, [
        for (var lng = -180.0; lng <= 180; lng += 5) LatLng(lat, lng),
      ], paint);
    }
    for (var lng = -180.0; lng < 180; lng += _graticuleStep) {
      _strokePath(canvas, projection, [
        for (var lat = -90.0; lat <= 90; lat += 5) LatLng(lat, lng),
      ], paint);
    }
  }

  /// 畫一條非閉合的線（網格用）。跨到背面就斷開重起，不要連過球心。
  void _strokePath(
    Canvas canvas,
    OrthographicProjection projection,
    List<LatLng> points,
    Paint paint,
  ) {
    final path = Path();
    var started = false;
    for (final point in points) {
      final offset = projection.project(point);
      if (offset == null) {
        started = false;
        continue;
      }
      if (started) {
        path.lineTo(offset.dx, offset.dy);
      } else {
        path.moveTo(offset.dx, offset.dy);
        started = true;
      }
    }
    canvas.drawPath(path, paint);
  }

  void _paintLand(Canvas canvas, OrthographicProjection projection) {
    final path = Path();
    for (final ring in outline.rings) {
      for (final clipped in projection.clipRing(ring)) {
        if (clipped.length < 3) continue;
        path.addPolygon(clipped, true);
      }
    }
    canvas.drawPath(path, Paint()..color = GlobePalette.land);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = GlobePalette.landStroke,
    );
  }

  /// 左上打光：中央偏亮、邊緣壓暗，讓平面的圓看起來像一顆球。
  void _paintShading(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(center.dx - radius * 0.28, center.dy - radius * 0.4),
          radius,
          const [
            Color.fromRGBO(255, 255, 255, 0.5),
            Color.fromRGBO(255, 255, 255, 0),
            GlobePalette.shadeEdge,
          ],
          const [0, 0.55, 1],
        ),
    );
  }

  void _paintPins(Canvas canvas, OrthographicProjection projection) {
    // 釘點代表的是書架上的一本旅程，所以畫書、不畫點。底下墊一圈海色，書
    // 才不會糊在抹茶綠的陸地上。
    final halo = Paint()..color = GlobePalette.pinDotStroke;

    for (final pin in pins) {
      if (pin.id == focusId) continue;
      if (projection.angularDistanceTo(pin.coordinate) >
          maxPinAngularDistance) {
        continue;
      }
      final offset = projection.project(pin.coordinate);
      if (offset == null) continue;

      canvas.drawCircle(offset, 9, halo);
      _paintBookIcon(canvas, offset);
      _paintLabel(canvas, projection, offset, pin.label);
    }
  }

  /// 用 icon font 直接畫字形——在 CustomPaint 裡沒有 widget 可用，
  /// TextPainter 加上 [IconData] 的 codePoint 與 fontFamily 就是標準作法。
  void _paintBookIcon(Canvas canvas, Offset offset) {
    const icon = bookIcon;
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 13,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: GlobePalette.pinDot,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      offset - Offset(painter.width / 2, painter.height / 2),
    );
  }

  void _paintLabel(
    Canvas canvas,
    OrthographicProjection projection,
    Offset offset,
    String label,
  ) {
    final flipToLeft =
        offset.dx > projection.center.dx + projection.radius * 0.24;
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: GlobePalette.pinLabel,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        flipToLeft ? offset.dx - 10 - painter.width : offset.dx + 10,
        offset.dy - painter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(GlobePainter oldDelegate) =>
      oldDelegate.rotation.lambda != rotation.lambda ||
      oldDelegate.rotation.phi != rotation.phi ||
      oldDelegate.focusId != focusId ||
      oldDelegate.pins != pins ||
      oldDelegate.outline != outline;
}
