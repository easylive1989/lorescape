import 'dart:math' as math;

import 'package:context_app/features/home/domain/globe/globe_rotation.dart';
import 'package:context_app/features/home/domain/globe/orthographic_projection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

const _center = Offset(100, 100);
const _radius = 100.0;
const _discArea = math.pi * _radius * _radius;

OrthographicProjection _facing(LatLng point) => OrthographicProjection(
  rotation: GlobeRotation.facing(point, tilt: 0),
  center: _center,
  radius: _radius,
);

/// 一條沿著固定緯度繞行整圈的環，用來模擬南極洲那種包住極點的陸塊。
List<LatLng> _ringAtLatitude(double latitude) => [
  for (var lng = -180.0; lng <= 180.0; lng += 10) LatLng(latitude, lng),
];

/// 畫布座標的 shoelace 有號面積。正負代表環繞方向——洞環必須跟外環反號，
/// nonZero 填法才挖得出洞。
double _signedArea(List<Offset> ring) {
  var total = 0.0;
  for (var i = 0; i < ring.length; i++) {
    final a = ring[i];
    final b = ring[(i + 1) % ring.length];
    total += a.dx * b.dy - b.dx * a.dy;
  }
  return total / 2;
}

double _signedAreaOf(List<List<Offset>> rings) =>
    rings.fold<double>(0, (sum, ring) => sum + _signedArea(ring));

/// 射線法判斷點在不在多邊形內。
bool _contains(List<Offset> polygon, Offset point) {
  var inside = false;
  for (var i = 0; i < polygon.length; i++) {
    final a = polygon[i];
    final b = polygon[(i + 1) % polygon.length];
    if ((a.dy > point.dy) != (b.dy > point.dy)) {
      final x = a.dx + (point.dy - a.dy) / (b.dy - a.dy) * (b.dx - a.dx);
      if (x > point.dx) inside = !inside;
    }
  }
  return inside;
}

void main() {
  test(
    'given a ring wholly on the near hemisphere, '
    'when clipping it, '
    'then every original vertex survives as one ring',
    () {
      final projection = _facing(const LatLng(0, 0));
      final ring = [
        const LatLng(0, 0),
        const LatLng(10, 0),
        const LatLng(10, 10),
        const LatLng(0, 10),
      ];

      final clipped = projection.clipRing(ring);

      expect(clipped, hasLength(1));
      expect(clipped.single, hasLength(4));
    },
  );

  test(
    'given a ring wholly on the far hemisphere, '
    'when clipping it, '
    'then nothing is returned',
    () {
      final projection = _facing(const LatLng(0, 0));
      final ring = [
        const LatLng(0, 170),
        const LatLng(10, 170),
        const LatLng(10, 180),
        const LatLng(0, 180),
      ];

      expect(projection.clipRing(ring), isEmpty);
    },
  );

  test(
    'given a ring straddling the horizon, '
    'when clipping it, '
    'then the result stays inside the globe and touches the rim',
    () {
      final projection = _facing(const LatLng(0, 0));
      final ring = [
        const LatLng(0, 60),
        const LatLng(20, 60),
        const LatLng(20, 120),
        const LatLng(0, 120),
      ];

      final clipped = projection.clipRing(ring);

      expect(clipped, hasLength(1));
      final points = clipped.single;
      expect(
        points.every((p) => (p - _center).distance <= _radius + 0.01),
        isTrue,
        reason: '裁切後不該有任何點跑到球外',
      );
      expect(
        points.any((p) => ((p - _center).distance - _radius).abs() < 0.01),
        isTrue,
        reason: '跨過地平線的環一定有點落在球緣上',
      );
    },
  );

  test(
    'given a ring bounding the far polar cap, '
    'when clipping it, '
    'then the cap side of the rim is filled and the rest of the globe is not',
    () {
      // 視線中心在北緯 20 度，南緯 60 度那一圈只有靠近我們的一段可見。
      // 缺口要沿球緣補在極冠那一側；補錯邊會把整個北半球填成陸地。
      final projection = _facing(const LatLng(20, 0));

      final clipped = projection.clipRing(_ringAtLatitude(-60));

      expect(clipped, hasLength(1));
      final points = clipped.single;
      expect(
        points.every((p) => p.dy >= _center.dy),
        isTrue,
        reason: '填的是南極那一側，不該有任何點跑到球心以北',
      );
      expect(
        _contains(points, _center + const Offset(0, 99.3)),
        isTrue,
        reason: '南極那側緊貼球緣的一小條要被填起來',
      );
      expect(
        _contains(points, _center + const Offset(0, -99.3)),
        isFalse,
        reason: '北邊緊貼球緣處是海，不能被填',
      );
    },
  );

  test(
    'given a hole ring straddling the horizon, '
    'when clipping it, '
    'then it keeps the opposite winding to the same ring wound as land',
    () {
      // 裡海是歐亞大陸那條環裡的反向內環。它跨過球緣時若裁成「整個圓盤扣
      // 掉湖」，nonZero 疊起來會把整塊大陸消成空白。
      final projection = _facing(const LatLng(0, 0));
      const land = [
        LatLng(0, 60),
        LatLng(20, 60),
        LatLng(20, 120),
        LatLng(0, 120),
      ];
      final hole = land.reversed.toList();

      final landArea = _signedAreaOf(projection.clipRing(land));
      final holeArea = _signedAreaOf(projection.clipRing(hole));

      expect(landArea * holeArea, lessThan(0), reason: '兩者必須反號');
      expect(
        (landArea.abs() - holeArea.abs()).abs(),
        lessThan(0.01 * landArea.abs()),
        reason: '同一塊區域，面積大小應該一樣',
      );
      expect(
        holeArea.abs() / _discArea,
        lessThan(0.1),
        reason: '裁出來的該是湖本身，不是圓盤扣掉湖',
      );
    },
  );

  test(
    'given a ring that crosses the horizon twice, '
    'when clipping it, '
    'then the visible runs are paired along the rim instead of in ring order',
    () {
      // 一條沿赤道往東、再沿北緯 10 度往西的長條，會被地平線切成兩段可見
      // 的 run。離開點要接「沿球緣往前走遇到的下一個進入點」，照 run 在環
      // 上的先後順序接會把整個圓盤填成陸地。
      final projection = _facing(const LatLng(5, 0));
      final ring = [
        for (var lng = -100.0; lng <= 100.0; lng += 10) LatLng(0, lng),
        for (var lng = 100.0; lng >= -100.0; lng -= 10) LatLng(10, lng),
      ];

      final clipped = projection.clipRing(ring);

      expect(
        clipped.every(
          (poly) =>
              poly.every((p) => (p - _center).distance <= _radius + 0.01),
        ),
        isTrue,
        reason: '裁切後不該有任何點跑到球外',
      );
      expect(
        _signedAreaOf(clipped).abs() / _discArea,
        lessThan(0.25),
        reason: '這條長條很細，填色面積不該接近整個圓盤',
      );
    },
  );
}
