import 'dart:convert';

import 'package:context_app/features/explore/data/services/wikipedia_places_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('given an opensearch response, '
      'when suggesting titles, '
      'then the title array is returned in order', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'zh.wikipedia.org');
      expect(request.url.queryParameters['action'], 'opensearch');
      expect(request.url.queryParameters['search'], '京都');
      return http.Response(
        jsonEncode([
          '京都',
          ['京都市', '京都府', '京都御所'],
          [],
          [],
        ]),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final titles = await WikipediaPlacesService(
      client: client,
    ).suggestTitles('京都', wikiLang: 'zh');

    expect(titles, ['京都市', '京都府', '京都御所']);
  });

  test('given a non-200 response, '
      'when suggesting titles, '
      'then an empty list is returned instead of throwing', () async {
    final client = MockClient((_) async => http.Response('nope', 503));

    final titles = await WikipediaPlacesService(
      client: client,
    ).suggestTitles('京都', wikiLang: 'zh');

    expect(titles, isEmpty);
  });
}
