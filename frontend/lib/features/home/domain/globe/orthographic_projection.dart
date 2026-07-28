import 'dart:math' as math;
import 'dart:ui';

import 'package:latlong2/latlong.dart';

import 'package:context_app/features/home/domain/globe/globe_rotation.dart';

/// 正射投影：把球面上的經緯度投到畫布座標，看起來就是從遠處看一顆球。
///
/// 公式是教科書版本（Snyder, Map Projections §20）：
///   x = R cos(φ) sin(λ − λ₀)
///   y = R [cos(φ₀) sin(φ) − sin(φ₀) cos(φ) cos(λ − λ₀)]
/// 其中 (φ₀, λ₀) 是視線中心。y 是「北為正」，畫布 y 軸向下，所以要反號。
class OrthographicProjection {
  const OrthographicProjection({
    required this.rotation,
    required this.center,
    required this.radius,
  });

  final GlobeRotation rotation;

  /// 球心在畫布上的位置。
  final Offset center;

  /// 球在畫布上的半徑（px）。
  final double radius;

  double _cosAngularDistance(LatLng point) {
    final viewCenter = rotation.viewCenter;
    final phi0 = viewCenter.latitude * math.pi / 180;
    final lambda0 = viewCenter.longitude * math.pi / 180;
    final phi = point.latitude * math.pi / 180;
    final lambda = point.longitude * math.pi / 180;
    return math.sin(phi0) * math.sin(phi) +
        math.cos(phi0) * math.cos(phi) * math.cos(lambda - lambda0);
  }

  /// [point] 是否落在面向鏡頭的半球上。剛好在地平線上算可見。
  bool isVisible(LatLng point) => _cosAngularDistance(point) >= 0;

  /// [point] 距離視線中心的大圓角距離（弧度，0 到 π）。
  double angularDistanceTo(LatLng point) =>
      math.acos(_cosAngularDistance(point).clamp(-1.0, 1.0));

  /// 投影到畫布座標。背面的點回傳 null。
  Offset? project(LatLng point) {
    if (!isVisible(point)) return null;
    return _projectUnchecked(point);
  }

  /// 不檢查可見性的投影。背面的點會鏡射到正面，只有在裁切演算法內部、
  /// 已經確認過可見性時才可以用。
  Offset _projectUnchecked(LatLng point) {
    final viewCenter = rotation.viewCenter;
    final phi0 = viewCenter.latitude * math.pi / 180;
    final lambda0 = viewCenter.longitude * math.pi / 180;
    final phi = point.latitude * math.pi / 180;
    final lambda = point.longitude * math.pi / 180;

    final x = math.cos(phi) * math.sin(lambda - lambda0);
    final y =
        math.cos(phi0) * math.sin(phi) -
        math.sin(phi0) * math.cos(phi) * math.cos(lambda - lambda0);
    return Offset(center.dx + radius * x, center.dy - radius * y);
  }
}
