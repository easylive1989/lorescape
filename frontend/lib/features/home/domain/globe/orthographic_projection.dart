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

  /// 把一條球面環裁切到可見半球，回傳可以直接填色的畫布多邊形。
  ///
  /// 作法是 Weiler–Atherton：沿著環走一圈，記下每次穿過地平線的交點，把連
  /// 續可見的一段收成一條「run」（從進入點走到離開點）。缺口沿著球緣圓弧
  /// 補——從一條 run 的離開點朝球緣自己的環繞方向走，走到下一個進入點為止。
  ///
  /// 兩件事不能便宜行事：
  ///
  /// 一是補的方向要看環自己怎麼繞（見 [_windingSign]），不能就近走短弧、
  /// 也不能從最後一段可見邊去猜。方向決定的是缺口補在球緣的哪一側，也就
  /// 是陸地補在極冠那側還是反過來填掉整片海。
  ///
  /// 二是配對不能照 run 在環上的先後順序接。一條環可能分成好幾段可見的
  /// run，離開點該接的是「沿球緣往前走遇到的下一個進入點」，不見得是下一
  /// 條 run 的開頭。接錯的話整個圓盤會被填成陸地——南極洲在視線中心北緯
  /// 5～15 度時就是這個情形。
  List<List<Offset>> clipRing(List<LatLng> ring) {
    if (ring.length < 3) return const [];

    final runs = <List<Offset>>[];
    List<Offset>? current;

    for (var i = 0; i < ring.length; i++) {
      final a = ring[i];
      final b = ring[(i + 1) % ring.length];
      final aVisible = isVisible(a);
      final bVisible = isVisible(b);

      if (aVisible) {
        current ??= <Offset>[];
        current.add(_projectUnchecked(a));
      }
      if (aVisible != bVisible) {
        final crossing = _horizonCrossing(a, b);
        if (aVisible) {
          current!.add(crossing);
          runs.add(current);
          current = null;
        } else {
          current = <Offset>[crossing];
        }
      }
    }

    if (current != null) {
      if (runs.isEmpty) {
        runs.add(current);
      } else {
        // 環是閉合的，最後一段其實接在第一段前面。
        runs.first.insertAll(0, current);
      }
    }

    if (runs.isEmpty) return const [];
    // 整條環都看得見時原封不動回傳。輪廓資料靠環繞方向慣例搭配 nonZero
    // 填法挖洞（裡海是歐亞大陸那條環裡的一個反向內環），點序一旦被重排或
    // 反向，洞就會被填成陸地。沒有交點就沒得裁，直接原樣送回最安全。
    if (runs.length == 1 && ring.every(isVisible)) {
      return [runs.single];
    }

    // 走到這裡的每條 run 都是「進入點 → 離開點」，兩端都在球緣上。
    final sweepSign = _windingSign(ring);
    final entryAngles = [
      for (final run in runs) (run.first - center).direction,
    ];
    final visited = List<bool>.filled(runs.length, false);
    final polygons = <List<Offset>>[];

    for (var start = 0; start < runs.length; start++) {
      if (visited[start]) continue;
      final polygon = <Offset>[];
      var i = start;
      while (!visited[i]) {
        visited[i] = true;
        polygon.addAll(runs[i]);
        final next = _nextEntry(runs[i].last, entryAngles, sweepSign);
        polygon.addAll(_rimArc(runs[i].last, runs[next].first, sweepSign));
        i = next;
      }
      polygons.add(polygon);
    }
    return polygons;
  }

  /// 環的環繞方向：順時針（外環）回 +1，逆時針（洞環）回 -1。
  ///
  /// 用球面有號面積（Chamberlain–Duquette）而不是把經緯度當平面算：常數項
  /// 那個 2 讓包住極點的環（南極洲）也算得出來，Δλ 取最短差則讓跨換日線的
  /// 環不會爆掉。
  ///
  /// 補弧的方向必須跟著環自己的方向走。裁切算的是「環所圍的區域 ∩ 可見半
  /// 球」，而洞環圍的是湖的補集——方向若一律照外環來，裡海一跨過球緣就會
  /// 裁出「整個圓盤扣掉湖」，nonZero 疊起來剛好把整塊歐亞大陸消成空白。
  static double _windingSign(List<LatLng> ring) {
    var total = 0.0;
    for (var i = 0; i < ring.length; i++) {
      final a = ring[i];
      final b = ring[(i + 1) % ring.length];
      var deltaLambda = (b.longitude - a.longitude) * math.pi / 180;
      deltaLambda = (deltaLambda + 3 * math.pi) % (2 * math.pi) - math.pi;
      total +=
          deltaLambda *
          (2 +
              math.sin(a.latitude * math.pi / 180) +
              math.sin(b.latitude * math.pi / 180));
    }
    return total >= 0 ? 1.0 : -1.0;
  }

  /// 從球緣上的離開點 [exit] 出發，朝 [sweepSign] 的方向沿球緣走，遇到的
  /// 第一個進入點。
  ///
  /// 進出點沿著球緣必然交錯出現（封閉曲線每穿過球緣一次，圓周上的內外就
  /// 翻一次），所以這個「下一個」是唯一且成雙的，每條 run 恰好被接一次。
  int _nextEntry(Offset exit, List<double> entryAngles, double sweepSign) {
    final exitAngle = (exit - center).direction;
    var best = 0;
    var bestGap = double.infinity;
    for (var i = 0; i < entryAngles.length; i++) {
      final gap = ((entryAngles[i] - exitAngle) * sweepSign) % (2 * math.pi);
      if (gap < bestGap) {
        bestGap = gap;
        best = i;
      }
    }
    return best;
  }

  /// 在 [a] 與 [b]（一端可見、另一端不可見）之間用二分法找出地平線交點。
  ///
  /// 沒有解析解可用：可見性看的是與視線中心的大圓角距離，沿著大圓走時它
  /// 是單調變化的，所以二分法必然收斂，20 次就遠小於一個像素。
  Offset _horizonCrossing(LatLng a, LatLng b) {
    var lo = 0.0;
    var hi = 1.0;
    final startVisible = isVisible(a);
    for (var i = 0; i < 20; i++) {
      final mid = (lo + hi) / 2;
      final point = _interpolate(a, b, mid);
      if (isVisible(point) == startVisible) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final crossing = _interpolate(a, b, (lo + hi) / 2);
    // 數值上可能差幾個 1e-6，直接投影後推回球緣，避免留下毛邊。
    final projected = _projectUnchecked(crossing) - center;
    return center + projected * (radius / projected.distance);
  }

  /// 沿著大圓在 [a] 與 [b] 之間取 [t] 比例的點（slerp）。
  ///
  /// 用 slerp 而不是對經緯度做線性內插：經緯度是球面的座標而非歐氏空間，
  /// 線性內插在高緯度或跨換日線時走的不是真正的最短路徑，找出來的交點會
  /// 偏離地平線。
  LatLng _interpolate(LatLng a, LatLng b, double t) {
    final av = _toVector(a);
    final bv = _toVector(b);
    final dot = (av[0] * bv[0] + av[1] * bv[1] + av[2] * bv[2]).clamp(
      -1.0,
      1.0,
    );
    final omega = math.acos(dot);
    if (omega < 1e-9) return a;
    final sinOmega = math.sin(omega);
    final ka = math.sin((1 - t) * omega) / sinOmega;
    final kb = math.sin(t * omega) / sinOmega;
    return _toLatLng([
      ka * av[0] + kb * bv[0],
      ka * av[1] + kb * bv[1],
      ka * av[2] + kb * bv[2],
    ]);
  }

  static List<double> _toVector(LatLng p) {
    final phi = p.latitude * math.pi / 180;
    final lambda = p.longitude * math.pi / 180;
    return [
      math.cos(phi) * math.cos(lambda),
      math.cos(phi) * math.sin(lambda),
      math.sin(phi),
    ];
  }

  static LatLng _toLatLng(List<double> v) {
    final length = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    final x = v[0] / length, y = v[1] / length, z = v[2] / length;
    return LatLng(
      math.asin(z) * 180 / math.pi,
      math.atan2(y, x) * 180 / math.pi,
    );
  }

  /// 產生從 [from] 沿球緣走到 [to] 的圓弧取樣點，方向由 [sweepSign] 決定
  /// （+1 是角度遞增，畫布 y 軸向下，看起來就是順時針）。
  ///
  /// 方向來自環自己的環繞方向（見 [_windingSign]），不是從最後一段可見邊
  /// 去猜：邊在球緣附近幾乎是徑向的，切向分量小到正負號由捨入誤差決定，
  /// 猜出來的方向會隨著地球儀轉動忽正忽負。
  ///
  /// 走的長度因此可能超過半圈——包住遠端極點的陸塊本來就該補一大段，一律
  /// 走短弧會把該是陸地的地方留白。
  List<Offset> _rimArc(Offset from, Offset to, double sweepSign) {
    final fromAngle = (from - center).direction;
    final toAngle = (to - center).direction;
    final delta = ((toAngle - fromAngle) * sweepSign) % (2 * math.pi);

    const step = math.pi / 90; // 2 度取樣，肉眼看不出折線
    final count = math.max(1, (delta / step).ceil());
    return [
      for (var i = 1; i <= count; i++)
        center +
            Offset.fromDirection(
              fromAngle + sweepSign * delta * (i / count),
              radius,
            ),
    ];
  }
}
