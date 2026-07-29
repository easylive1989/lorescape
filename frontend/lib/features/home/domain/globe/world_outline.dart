import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

/// 地球儀要畫的陸地輪廓。
///
/// 資料由 `tool/build_world_outline.py` 從 Natural Earth 110m 產生，
/// 存成 `{"rings": [[lng, lat, lng, lat, ...], ...]}` 的緊湊格式——一條環
/// 一個扁平陣列，省掉每個點一組中括號的體積。
class WorldOutline {
  const WorldOutline(this.rings);

  /// 每條環是一個閉合多邊形的頂點序列。
  final List<List<LatLng>> rings;

  static const String assetPath = 'assets/geo/world_land_110m.json';

  static WorldOutline parse(String source) {
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    final rings = <List<LatLng>>[];
    for (final ring in decoded['rings'] as List) {
      final flat = (ring as List).cast<num>();
      final points = <LatLng>[];
      for (var i = 0; i + 1 < flat.length; i += 2) {
        points.add(LatLng(flat[i + 1].toDouble(), flat[i].toDouble()));
      }
      rings.add(points);
    }
    return WorldOutline(rings);
  }

  /// 從 asset bundle 載入。解析放在背景 isolate，避免擋住第一幀。
  static Future<WorldOutline> load(AssetBundle bundle) async {
    final source = await bundle.loadString(assetPath);
    return compute(parse, source);
  }
}
