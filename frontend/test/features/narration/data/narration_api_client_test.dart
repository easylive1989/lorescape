import 'dart:convert';
import 'dart:io';

import 'package:context_app/core/errors/app_error.dart';
import 'package:context_app/features/narration/data/narration_api_client.dart';
import 'package:context_app/features/narration/domain/errors/narration_error.dart';
import 'package:context_app/features/narration/domain/models/story_hook.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('NarrationApiClient', () {
    test('fetchHooks 解析後端回傳的 hooks 陣列', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/narration/hooks');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['place_name'], 'Arles');
        expect(body['location'], 'Provence');
        expect(body['wikidata_id'], 'Q12345');
        expect(body['language'], 'zh-TW');
        expect(body.containsKey('wikipedia_title'), isFalse);
        return http.Response(
          jsonEncode({
            'hooks': [
              {'id': 'h1', 'title': 'T1', 'teaser': 'Te1'},
              {'id': 'h2', 'title': 'T2', 'teaser': 'Te2'},
            ],
            'insufficient_source': false,
          }),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      });

      final client = NarrationApiClient(
        baseUrl: 'https://api.test',
        httpClient: mockClient,
      );

      final result = await client.fetchHooks(
        placeName: 'Arles',
        location: 'Provence',
        wikidataId: 'Q12345',
        language: 'zh-TW',
      );

      expect(result.hooks, hasLength(2));
      expect(result.hooks.first.id, 'h1');
      expect(result.hooks.first.title, 'T1');
      expect(result.insufficientSource, isFalse);
    });

    test('fetchHooks 解析 insufficient_source=true 與空 hooks', () async {
      final mockClient = MockClient((_) async {
        return http.Response(
          jsonEncode({'hooks': [], 'insufficient_source': true}),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      });

      final client = NarrationApiClient(
        baseUrl: 'https://api.test',
        httpClient: mockClient,
      );

      final result = await client.fetchHooks(
        placeName: 'Fake',
        location: '',
        wikidataId: 'Q99999',
        language: 'zh-TW',
      );

      expect(result.hooks, isEmpty);
      expect(result.insufficientSource, isTrue);
    });

    test('fetchNarration 解析後端回傳的長故事', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/narration');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['place_name'], 'Arles');
        expect(body['language'], 'zh-TW');
        expect(body['wikidata_id'], 'Q12345');
        expect(body.containsKey('wikipedia_title'), isFalse);
        expect(body['hook'], {'id': 'h', 'title': '梵谷', 'teaser': '444 天'});
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'place_name': '亞爾',
              'location': '法國普羅旺斯',
              'era': '十九世紀末',
              'paragraphs': ['一', '二', '三'],
              'pull_quote': '「我看見麥田」',
              'insufficient_source': false,
            }),
          ),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      });

      final client = NarrationApiClient(
        baseUrl: 'https://api.test',
        httpClient: mockClient,
      );

      final result = await client.fetchNarration(
        placeName: 'Arles',
        location: 'Provence',
        wikidataId: 'Q12345',
        language: 'zh-TW',
        hook: const StoryHook(id: 'h', title: '梵谷', teaser: '444 天'),
      );

      expect(result.placeName, '亞爾');
      expect(result.paragraphs, ['一', '二', '三']);
      expect(result.text, '一\n\n二\n\n三');
      expect(result.pullQuote, '「我看見麥田」');
      expect(result.insufficientSource, false);
    });

    test('400 回應拋出 AppError', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Unsupported language'}),
          400,
        );
      });

      final client = NarrationApiClient(
        baseUrl: 'https://api.test',
        httpClient: mockClient,
      );

      await expectLater(
        client.fetchNarration(
          placeName: 'x',
          location: '',
          wikidataId: 'Q1',
          language: 'ja',
        ),
        throwsA(isA<AppError>()),
      );
    });

    test('402 回應映射為 freeQuotaExceeded', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Daily free quota exhausted'}),
          402,
        );
      });

      final client = NarrationApiClient(
        baseUrl: 'https://api.test',
        httpClient: mockClient,
      );

      try {
        await client.fetchNarration(
          placeName: 'x',
          location: '',
          wikidataId: 'Q1',
          language: 'en',
        );
        fail('expected AppError');
      } on AppError catch (e) {
        expect(e.type, NarrationError.freeQuotaExceeded);
      }
    });

    test('500 回應映射為 serverError', () async {
      final mockClient = MockClient((request) async {
        return http.Response('boom', 500);
      });

      final client = NarrationApiClient(
        baseUrl: 'https://api.test',
        httpClient: mockClient,
      );

      try {
        await client.fetchHooks(
          placeName: 'x',
          location: '',
          wikidataId: 'Q1',
          language: 'en',
        );
        fail('expected AppError');
      } on AppError catch (e) {
        expect(e.type, NarrationError.serverError);
      }
    });

    test('SocketException 映射為 networkError', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('no route to host');
      });

      final client = NarrationApiClient(
        baseUrl: 'https://api.test',
        httpClient: mockClient,
      );

      try {
        await client.fetchHooks(
          placeName: 'x',
          location: '',
          wikidataId: 'Q1',
          language: 'en',
        );
        fail('expected AppError');
      } on AppError catch (e) {
        expect(e.type, NarrationError.networkError);
      }
    });

    test('提供 accessToken 時帶上 Authorization Bearer 標頭', () async {
      String? seenAuth;
      final mockClient = MockClient((request) async {
        seenAuth = request.headers['Authorization'];
        return http.Response(
          jsonEncode({'hooks': [], 'insufficient_source': false}),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      });

      final client = NarrationApiClient(
        baseUrl: 'https://api.test',
        httpClient: mockClient,
        accessToken: () async => 'jwt-token-123',
      );

      await client.fetchHooks(
        placeName: 'x',
        location: '',
        wikidataId: 'Q1',
        language: 'en',
      );

      expect(seenAuth, 'Bearer jwt-token-123');
    });

    test('未提供 accessToken 時不帶 Authorization 標頭', () async {
      var hasAuth = true;
      final mockClient = MockClient((request) async {
        hasAuth = request.headers.containsKey('Authorization');
        return http.Response(
          jsonEncode({'hooks': [], 'insufficient_source': false}),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      });

      final client = NarrationApiClient(
        baseUrl: 'https://api.test',
        httpClient: mockClient,
      );

      await client.fetchHooks(
        placeName: 'x',
        location: '',
        wikidataId: 'Q1',
        language: 'en',
      );

      expect(hasAuth, isFalse);
    });

    test('未設定 baseUrl 時拋出可辨識的 AppError', () async {
      final client = NarrationApiClient(baseUrl: '');

      try {
        await client.fetchHooks(
          placeName: 'x',
          location: '',
          wikidataId: 'Q1',
          language: 'en',
        );
        fail('expected AppError');
      } on AppError catch (e) {
        expect(e.type, NarrationError.unknown);
        expect(e.message, contains('BACKEND_BASE_URL'));
      }
    });
  });
}
