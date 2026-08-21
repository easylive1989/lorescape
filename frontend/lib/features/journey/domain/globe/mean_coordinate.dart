import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// 一組座標在球面上的平均位置。
///
/// 不是把經緯度各自相加除以個數——那個做法一跨換日線就會把兩個相鄰的
/// 地點平均到地球的另一邊（東經 179 與西經 179 的算術平均是經度 0）。
/// 這裡改把每個點當成單位向量，相加取質心後再投影回球面，換日線與極區
/// 都不會出事。
///
/// [points] 為空時回 `null`。
LatLng? meanCoordinate(Iterable<LatLng> points) {
  var x = 0.0;
  var y = 0.0;
  var z = 0.0;
  var count = 0;
  for (final point in points) {
    final lat = point.latitudeInRad;
    final lng = point.longitudeInRad;
    final cosLat = math.cos(lat);
    x += cosLat * math.cos(lng);
    y += cosLat * math.sin(lng);
    z += math.sin(lat);
    count++;
  }
  if (count == 0) return null;

  final hypotenuse = math.sqrt(x * x + y * y);
  // 幾個點剛好對稱相消（例如地球兩端各一個），質心落在球心，沒有唯一的平均
  // 方向。與其回一個由浮點誤差決定的隨機方向，不如回第一個點。
  if (hypotenuse < 1e-9 && z.abs() < 1e-9) return points.first;

  return LatLng(
    radianToDeg(math.atan2(z, hypotenuse)),
    radianToDeg(math.atan2(y, x)),
  );
}
