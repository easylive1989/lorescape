import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// 地球儀的旋轉角，沿用 d3.geoOrthographic 的慣例：
/// `rotate([lambda, phi])` 把球轉過去，視線中心因此落在 `(-phi, -lambda)`。
///
/// 只有兩個自由度——第三個滾轉角固定為 0，地球儀不會歪頭。
class GlobeRotation {
  const GlobeRotation(this.lambda, this.phi);

  /// 經度方向的旋轉（度）。可以超出 ±180，投影公式用的是差值。
  final double lambda;

  /// 緯度方向的旋轉（度）。
  final double phi;

  /// 目前正對鏡頭的那個點。
  LatLng get viewCenter => LatLng(-phi, -lambda);

  /// 轉到正對 [point]。[tilt] 把視線中心往北推幾度，讓 pin 落在球體偏上
  /// 的位置，底下才有空間放紙卡 chip（設計稿用 8 度）。
  static GlobeRotation facing(LatLng point, {double tilt = 8}) =>
      GlobeRotation(-point.longitude, -(point.latitude - tilt));

  /// 拖曳時把俯仰夾在 ±78 度，避免轉到極點附近整顆球看起來翻過去。
  GlobeRotation clampedPhi() =>
      GlobeRotation(lambda, phi.clamp(-78.0, 78.0).toDouble());

  /// 往 [other] 內插。經度走最短路徑，不會為了差 350 度而繞一大圈。
  GlobeRotation lerpTo(GlobeRotation other, double t) {
    var deltaLambda = other.lambda - lambda;
    deltaLambda = (deltaLambda % 360 + 540) % 360 - 180;
    return GlobeRotation(lambda + deltaLambda * t, phi + (other.phi - phi) * t);
  }

  double get lambdaRadians => lambda * math.pi / 180;

  double get phiRadians => phi * math.pi / 180;

  @override
  String toString() => 'GlobeRotation($lambda, $phi)';
}
