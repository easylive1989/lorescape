import 'dart:convert';

import 'package:context_app/features/journey/data/services/wikidata_place_coords_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String _sparqlBody(List<(String qid, String point)> rows) => jsonEncode({
  'results': {
    'bindings': [
      for (final (qid, point) in rows)
        {
          'item': {
            'type': 'uri',
            'value': 'http://www.wikidata.org/entity/$qid',
          },
          'coord': {'type': 'literal', 'value': point},
        },
    ],
  },
});

void main() {
  group('WikidataPlaceCoordsService', () {
    test('given a WKT point in Wikidata order, when the response is parsed, '
        'then longitude comes first and latitude second', () async {
      // WDQS 回的是 `Point(<經度> <緯度>)`。把兩者對調的話台北會跑到南極圈。
      final service = WikidataPlaceCoordsService(
        client: MockClient(
          (_) async => http.Response(
            _sparqlBody([('Q1867', 'Point(121.5654 25.033)')]),
            200,
          ),
        ),
      );

      final coords = await service.resolve({'Q1867'});

      expect(coords['Q1867']!.latitude, closeTo(25.033, 0.0001));
      expect(coords['Q1867']!.longitude, closeTo(121.5654, 0.0001));
    });

    test('given negative coordinates, when the response is parsed, '
        'then the sign is kept', () async {
      final service = WikidataPlaceCoordsService(
        client: MockClient(
          (_) async => http.Response(
            _sparqlBody([('Q23548', 'Point(-43.2105 -22.9519)')]),
            200,
          ),
        ),
      );

      final coords = await service.resolve({'Q23548'});

      expect(coords['Q23548']!.latitude, closeTo(-22.9519, 0.0001));
      expect(coords['Q23548']!.longitude, closeTo(-43.2105, 0.0001));
    });

    test(
      'given a qid with no P625 in the result set, when the response is '
      'parsed, then it is absent rather than present with a zero coordinate',
      () async {
        final service = WikidataPlaceCoordsService(
          client: MockClient(
            (_) async =>
                http.Response(_sparqlBody([('Q1', 'Point(1 2)')]), 200),
          ),
        );

        final coords = await service.resolve({'Q1', 'Q2'});

        expect(coords.containsKey('Q2'), isFalse);
      },
    );

    test(
      'given more qids than fit one batch, when they are resolved, then every '
      'qid is queried across several requests',
      () async {
        final requested = <String>[];
        var calls = 0;
        final service = WikidataPlaceCoordsService(
          client: MockClient((request) async {
            calls++;
            final query = request.url.queryParameters['query']!;
            requested.addAll(
              RegExp(
                r'wd:(Q\d+)',
              ).allMatches(query).map((match) => match.group(1)!),
            );
            return http.Response(_sparqlBody(const []), 200);
          }),
        );

        final qids = {for (var i = 1; i <= 120; i++) 'Q$i'};
        await service.resolve(qids);

        expect(calls, 3, reason: '一批 50 個，120 個要切成三次');
        expect(requested.toSet(), qids, reason: '不能有 qid 在切批時掉了');
      },
    );

    test(
      'given WDQS answers with an error status, when coordinates are '
      'resolved, then an empty map comes back instead of an exception',
      () async {
        final service = WikidataPlaceCoordsService(
          client: MockClient((_) async => http.Response('rate limited', 429)),
        );

        expect(await service.resolve({'Q1'}), isEmpty);
      },
    );

    test('given the device is offline, when coordinates are resolved, '
        'then an empty map comes back instead of an exception', () async {
      final service = WikidataPlaceCoordsService(
        client: MockClient((_) async => throw const _OfflineException()),
      );

      expect(await service.resolve({'Q1'}), isEmpty);
    });
  });
}

class _OfflineException implements Exception {
  const _OfflineException();
}
