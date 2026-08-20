import 'dart:convert';

import 'package:context_app/core/errors/app_error.dart';
import 'package:context_app/features/explore/data/services/wikidata_landmark_query_service.dart';
import 'package:context_app/features/explore/domain/errors/place_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('WikidataLandmarkQueryService.findLandmarkIdsForQuery', () {
    test(
      'resolves query via wbsearchentities then runs SPARQL with the Q-id',
      () async {
        final capturedUris = <Uri>[];
        final mockClient = MockClient((req) async {
          capturedUris.add(req.url);
          if (req.url.host == 'www.wikidata.org') {
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'search': [
                    {'id': 'Q664', 'label': '紐西蘭'},
                  ],
                }),
              ),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'results': {
                  'bindings': [
                    {
                      'place': {
                        'value': 'http://www.wikidata.org/entity/Q190077',
                      },
                      'sitelinks': {'value': '95'},
                    },
                    {
                      'place': {
                        'value': 'http://www.wikidata.org/entity/Q47481',
                      },
                      'sitelinks': {'value': '60'},
                    },
                  ],
                },
              }),
            ),
            200,
            headers: {
              'content-type': 'application/sparql-results+json; charset=utf-8',
            },
          );
        });

        final service = WikidataLandmarkQueryService(client: mockClient);

        final ids = await service.findLandmarkIdsForQuery(
          '紐西蘭',
          wikiLang: 'zh',
        );

        expect(ids, ['Q190077', 'Q47481']);
        expect(capturedUris, hasLength(2));

        final searchUri = capturedUris[0];
        expect(searchUri.host, 'www.wikidata.org');
        expect(searchUri.queryParameters['action'], 'wbsearchentities');
        expect(searchUri.queryParameters['search'], '紐西蘭');
        expect(searchUri.queryParameters['language'], 'zh');
        expect(searchUri.queryParameters['type'], 'item');

        final sparqlUri = capturedUris[1];
        expect(sparqlUri.host, 'query.wikidata.org');
        expect(sparqlUri.path, '/sparql');
        expect(sparqlUri.queryParameters['format'], 'json');
        expect(sparqlUri.queryParameters['query'], contains('wd:Q664'));
        expect(sparqlUri.queryParameters['query'], contains('wdt:P17'));
        expect(sparqlUri.queryParameters['query'], contains('wdt:P131'));
        expect(sparqlUri.queryParameters['query'], contains('ORDER BY'));
      },
    );

    test('returns empty when query does not resolve to any entity', () async {
      var sparqlCalled = false;
      final mockClient = MockClient((req) async {
        if (req.url.host == 'query.wikidata.org') sparqlCalled = true;
        return http.Response.bytes(
          utf8.encode(jsonEncode({'search': []})),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final service = WikidataLandmarkQueryService(client: mockClient);

      final ids = await service.findLandmarkIdsForQuery(
        'nonexistent xyzzyx',
        wikiLang: 'en',
      );

      expect(ids, isEmpty);
      expect(sparqlCalled, isFalse);
    });

    test('returns empty when SPARQL bindings are empty', () async {
      final mockClient = MockClient((req) async {
        if (req.url.host == 'www.wikidata.org') {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'search': [
                  {'id': 'Q42'},
                ],
              }),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'results': {'bindings': []},
            }),
          ),
          200,
          headers: {
            'content-type': 'application/sparql-results+json; charset=utf-8',
          },
        );
      });
      final service = WikidataLandmarkQueryService(client: mockClient);

      final ids = await service.findLandmarkIdsForQuery(
        'Douglas Adams',
        wikiLang: 'en',
      );

      expect(ids, isEmpty);
    });

    test('throws AppError when wbsearchentities returns non-200', () async {
      final mockClient = MockClient((_) async => http.Response('boom', 503));
      final service = WikidataLandmarkQueryService(client: mockClient);

      expect(
        () => service.findLandmarkIdsForQuery('x', wikiLang: 'en'),
        throwsA(
          isA<AppError>().having(
            (e) => e.type,
            'type',
            PlaceError.searchFailed,
          ),
        ),
      );
    });

    test('throws AppError when SPARQL endpoint returns non-200', () async {
      final mockClient = MockClient((req) async {
        if (req.url.host == 'www.wikidata.org') {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'search': [
                  {'id': 'Q664'},
                ],
              }),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('sparql down', 500);
      });
      final service = WikidataLandmarkQueryService(client: mockClient);

      expect(
        () => service.findLandmarkIdsForQuery('NZ', wikiLang: 'en'),
        throwsA(
          isA<AppError>().having(
            (e) => e.type,
            'type',
            PlaceError.searchFailed,
          ),
        ),
      );
    });

    test('deduplicates Q-ids returned by SPARQL', () async {
      final mockClient = MockClient((req) async {
        if (req.url.host == 'www.wikidata.org') {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'search': [
                  {'id': 'Q664'},
                ],
              }),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'results': {
                'bindings': [
                  {
                    'place': {'value': 'http://www.wikidata.org/entity/Q1'},
                  },
                  {
                    'place': {'value': 'http://www.wikidata.org/entity/Q1'},
                  },
                  {
                    'place': {'value': 'http://www.wikidata.org/entity/Q2'},
                  },
                ],
              },
            }),
          ),
          200,
          headers: {
            'content-type': 'application/sparql-results+json; charset=utf-8',
          },
        );
      });
      final service = WikidataLandmarkQueryService(client: mockClient);

      final ids = await service.findLandmarkIdsForQuery('NZ', wikiLang: 'en');

      expect(ids, ['Q1', 'Q2']);
    });
  });
}
