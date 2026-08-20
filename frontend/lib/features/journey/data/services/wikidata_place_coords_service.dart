import 'dart:convert';

import 'package:context_app/features/explore/domain/models/place_location.dart';
import 'package:context_app/features/journey/domain/services/place_coords_resolver.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

/// 用 Wikidata Query Service（SPARQL）一次查一批 Q-id 的 P625 座標。
///
/// 走 SPARQL 而不是 `wbgetentities`：後者會把整個 entity 的 claims 都吐回來，
/// 知名景點動輒數百 KB，而這裡只要兩個數字。
class WikidataPlaceCoordsService implements PlaceCoordsResolver {
  WikidataPlaceCoordsService({http.Client? client})
    : _client = client ?? http.Client();

  static final _log = Logger('WikidataPlaceCoordsService');

  static const String _userAgent =
      'Lorescape/1.0 (https://lorescape.app; ops@lorescape.app)';

  /// 一次查幾個 qid。WDQS 對 URL 長度與查詢複雜度都有限制，切小批比較穩。
  static const int _batchSize = 50;

  final http.Client _client;

  @override
  Future<Map<String, PlaceLocation>> resolve(Set<String> qids) async {
    final result = <String, PlaceLocation>{};
    final ids = qids.toList();
    for (var i = 0; i < ids.length; i += _batchSize) {
      final batch = ids.sublist(
        i,
        i + _batchSize > ids.length ? ids.length : i + _batchSize,
      );
      result.addAll(await _resolveBatch(batch));
    }
    return result;
  }

  Future<Map<String, PlaceLocation>> _resolveBatch(List<String> qids) async {
    final values = qids.map((qid) => 'wd:$qid').join(' ');
    final uri = Uri.https('query.wikidata.org', '/sparql', {
      'query':
          '''
SELECT ?item ?coord WHERE {
  VALUES ?item { $values }
  ?item wdt:P625 ?coord .
}
''',
      'format': 'json',
    });

    try {
      final response = await _client.get(
        uri,
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/sparql-results+json',
        },
      );
      if (response.statusCode != 200) {
        _log.warning('WDQS coords query failed: ${response.statusCode}');
        return const {};
      }
      return _parse(response.body);
    } catch (e, stack) {
      // 離線、逾時、WDQS 限流都走這裡：回填失敗不是錯誤狀態，下次開 App 再試。
      _log.warning('WDQS coords query error', e, stack);
      return const {};
    }
  }

  Map<String, PlaceLocation> _parse(String body) {
    final data = jsonDecode(body) as Map<String, dynamic>;
    final bindings = (data['results'] as Map?)?['bindings'];
    if (bindings is! List) return const {};

    final result = <String, PlaceLocation>{};
    for (final binding in bindings) {
      if (binding is! Map) continue;
      final qid = _qidFromUri((binding['item'] as Map?)?['value']);
      final location = _pointToLocation((binding['coord'] as Map?)?['value']);
      if (qid == null || location == null) continue;
      // 同一個 item 有多組座標時取第一組，與 backfill_place_coords.py 一致。
      result.putIfAbsent(qid, () => location);
    }
    return result;
  }

  static String? _qidFromUri(Object? value) {
    if (value is! String) return null;
    final qid = value.split('/').last;
    return qid.startsWith('Q') ? qid : null;
  }

  /// WKT 點字面值：`Point(<經度> <緯度>)`——經度在前，緯度在後。
  static PlaceLocation? _pointToLocation(Object? value) {
    if (value is! String) return null;
    final match = RegExp(
      r'^Point\(\s*(-?[\d.]+)\s+(-?[\d.]+)\s*\)$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return null;
    final lng = double.tryParse(match.group(1)!);
    final lat = double.tryParse(match.group(2)!);
    if (lat == null || lng == null) return null;
    return PlaceLocation(latitude: lat, longitude: lng);
  }
}
