import 'dart:convert';

import 'package:context_app/features/daily_story/data/supabase_daily_story_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// `rowToStory` is a public static helper used by the repository to convert
// joined Supabase rows into DailyStory objects. Testing it directly proves
// that the row parser handles all the field shapes correctly (full / sparse
// card fields, partial place join, etc.) without spinning up a real client.
//
// `fetchByDate` additionally needs coverage of the HTTP round-trip (query
// params -> response -> row mapping / empty-to-null branch). Rather than
// mocking Supabase's internal query-builder chain (not done anywhere else in
// this codebase), we inject a `SupabaseClient` backed by a `MockClient` from
// `package:http/testing.dart` so the request never touches the network but
// the real query-building and parsing code still runs.

void main() {
  group('SupabaseDailyStoryRepository.rowToStory', () {
    test('given a row with all card fields and joined place fields, '
        'when parsed, '
        'then DailyStory carries every value', () {
      final row = <String, dynamic>{
        'publish_date': '2026-05-25',
        'language': 'zh-TW',
        'place_name': '羅馬競技場',
        'place_location': '義大利羅馬',
        'era': '公元 70-80 年',
        'story': 'p1\n\np2\n\np3',
        'image_url': null,
        'wikipedia_url': 'https://zh.wikipedia.org/wiki/Colosseum',
        'card_title': '血腥的盛宴',
        'card_title_sub': '從石灰岩堆砌的命運舞台',
        'card_paragraphs': ['p1', 'p2', 'p3'],
        'card_pull_quote': '「他們將死之人向您致敬」',
        'card_pull_quote_attrib': '── 蘇埃托尼烏斯，西元 121 年',
        'card_anno_roman': 'LXXX',
        'daily_story_places': {
          'card_location_en': 'COLOSSEUM',
          'card_city_ch': '羅馬',
          'card_city_en': 'Rome',
        },
      };
      final story = SupabaseDailyStoryRepository.rowToStory(row);
      expect(story.cardTitle, '血腥的盛宴');
      expect(story.cardParagraphs, ['p1', 'p2', 'p3']);
      expect(story.cardLocationEn, 'COLOSSEUM');
      expect(story.cardCityCh, '羅馬');
      expect(story.cardCityEn, 'Rome');
    });

    test('given a row missing card fields and place join, '
        'when parsed, '
        'then card_* fields are null', () {
      final row = <String, dynamic>{
        'publish_date': '2026-05-25',
        'language': 'en',
        'place_name': 'Colosseum',
        'place_location': 'Rome, Italy',
        'era': '70-80 CE',
        'story': 'A plain text story.',
        'image_url': 'https://example.com/img.jpg',
        'wikipedia_url': 'https://en.wikipedia.org/wiki/Colosseum',
      };
      final story = SupabaseDailyStoryRepository.rowToStory(row);
      expect(story.cardTitle, isNull);
      expect(story.cardParagraphs, isNull);
      expect(story.cardLocationEn, isNull);
    });

    test('given a place join with some null city fields, '
        'when parsed, '
        'then nulls propagate without crashing', () {
      final row = <String, dynamic>{
        'publish_date': '2026-05-25',
        'language': 'zh-TW',
        'place_name': '羅馬競技場',
        'place_location': '義大利羅馬',
        'era': '公元 70-80 年',
        'story': 'x',
        'image_url': null,
        'wikipedia_url': 'https://zh.wikipedia.org/wiki/Colosseum',
        'daily_story_places': {
          'card_location_en': null,
          'card_city_ch': '羅馬',
          'card_city_en': null,
        },
      };
      final story = SupabaseDailyStoryRepository.rowToStory(row);
      expect(story.cardLocationEn, isNull);
      expect(story.cardCityCh, '羅馬');
      expect(story.cardCityEn, isNull);
    });

    test('given a place join with wikidata_id, '
        'when parsed, '
        'then DailyStory.wikidataId carries it', () {
      final row = <String, dynamic>{
        'publish_date': '2026-05-25',
        'language': 'zh-TW',
        'place_name': '羅馬競技場',
        'place_location': '義大利羅馬',
        'era': '公元 70-80 年',
        'story': 'x',
        'image_url': null,
        'wikipedia_url': 'https://zh.wikipedia.org/wiki/Colosseum',
        'daily_story_places': {
          'card_location_en': 'COLOSSEUM',
          'card_city_ch': '羅馬',
          'card_city_en': 'Rome',
          'wikidata_id': 'Q10285',
        },
      };
      final story = SupabaseDailyStoryRepository.rowToStory(row);
      expect(story.wikidataId, 'Q10285');
    });

    test('given a row with image_attribution, '
        'when parsed, '
        'then DailyStory.imageAttribution carries it', () {
      final row = <String, dynamic>{
        'publish_date': '2026-05-25',
        'language': 'en',
        'place_name': 'Colosseum',
        'place_location': 'Rome, Italy',
        'era': '70-80 CE',
        'story': 'x',
        'image_url': 'https://example.com/img.jpg',
        'image_attribution': 'Jane Doe / CC BY-SA 4.0 (via Wikimedia Commons)',
        'wikipedia_url': 'https://en.wikipedia.org/wiki/Colosseum',
      };
      final story = SupabaseDailyStoryRepository.rowToStory(row);
      expect(
        story.imageAttribution,
        'Jane Doe / CC BY-SA 4.0 (via Wikimedia Commons)',
      );
    });

    test('given a row without image_attribution, '
        'when parsed, '
        'then DailyStory.imageAttribution is null', () {
      final row = <String, dynamic>{
        'publish_date': '2026-05-25',
        'language': 'en',
        'place_name': 'Colosseum',
        'place_location': 'Rome, Italy',
        'era': '70-80 CE',
        'story': 'x',
        'image_url': null,
        'wikipedia_url': 'https://en.wikipedia.org/wiki/Colosseum',
      };
      final story = SupabaseDailyStoryRepository.rowToStory(row);
      expect(story.imageAttribution, isNull);
    });

    test('given a row without place join, '
        'when parsed, '
        'then DailyStory.wikidataId is null', () {
      final row = <String, dynamic>{
        'publish_date': '2026-05-25',
        'language': 'en',
        'place_name': 'Colosseum',
        'place_location': 'Rome, Italy',
        'era': '70-80 CE',
        'story': 'x',
        'image_url': null,
        'wikipedia_url': 'https://en.wikipedia.org/wiki/Colosseum',
      };
      final story = SupabaseDailyStoryRepository.rowToStory(row);
      expect(story.wikidataId, isNull);
    });

    test(
      'given a row whose place join carries coordinates, '
      'when rowToStory parses it, '
      'then latitude and longitude are mapped',
      () {
        final story = SupabaseDailyStoryRepository.rowToStory({
          'publish_date': '2026-07-28',
          'language': 'zh-TW',
          'place_name': '聖伯多祿大殿',
          'place_location': '義大利羅馬',
          'era': '公元 1506-1626 年',
          'story': '內文',
          'image_url': null,
          'wikipedia_url': 'https://zh.wikipedia.org/wiki/聖伯多祿大殿',
          'daily_story_places': {'latitude': 41.9022, 'longitude': 12.4539},
        });

        expect(story.latitude, 41.9022);
        expect(story.longitude, 12.4539);
      },
    );

    test(
      'given a row with no place join, '
      'when rowToStory parses it, '
      'then latitude and longitude are null',
      () {
        final story = SupabaseDailyStoryRepository.rowToStory({
          'publish_date': '2026-07-28',
          'language': 'zh-TW',
          'place_name': '聖伯多祿大殿',
          'place_location': '義大利羅馬',
          'era': '公元 1506-1626 年',
          'story': '內文',
          'image_url': null,
          'wikipedia_url': 'https://zh.wikipedia.org/wiki/聖伯多祿大殿',
        });

        expect(story.latitude, isNull);
        expect(story.longitude, isNull);
      },
    );
  });

  group('SupabaseDailyStoryRepository.fetchByDate', () {
    test('given a row matching the language + publish_date, '
        'when fetchByDate is called, '
        'then it sends the matching filters and maps the row into a '
        'DailyStory', () async {
      final row = _sampleRow(publishDate: '2026-07-01', language: 'zh-TW');
      final client = _clientAssertingQuery(
        rows: [row],
        expectedLanguageFilter: 'eq.zh-TW',
        expectedDateFilter: 'eq.2026-07-01',
      );
      final repo = SupabaseDailyStoryRepository(client);

      final story = await repo.fetchByDate(
        language: 'zh-TW',
        date: DateTime(2026, 7, 1),
      );

      expect(story, isNotNull);
      expect(story!.publishDate, DateTime(2026, 7, 1));
      expect(story.language, 'zh-TW');
    });

    test('given no row matches the language + publish_date, '
        'when fetchByDate is called, '
        'then it sends the matching filters and returns null', () async {
      final client = _clientAssertingQuery(
        rows: <Map<String, dynamic>>[],
        expectedLanguageFilter: 'eq.en',
        expectedDateFilter: 'eq.2026-01-01',
      );
      final repo = SupabaseDailyStoryRepository(client);

      final story = await repo.fetchByDate(
        language: 'en',
        date: DateTime(2026, 1, 1),
      );

      expect(story, isNull);
    });
  });
}

/// A minimal row shape that satisfies [SupabaseDailyStoryRepository
/// .rowToStory] (no card fields / place join needed for these tests).
Map<String, dynamic> _sampleRow({
  required String publishDate,
  required String language,
}) {
  return <String, dynamic>{
    'publish_date': publishDate,
    'language': language,
    'place_name': '羅馬競技場',
    'place_location': '義大利羅馬',
    'era': '公元 70-80 年',
    'story': 'x',
    'image_url': null,
    'wikipedia_url': 'https://zh.wikipedia.org/wiki/Colosseum',
  };
}

/// A [SupabaseClient] used only by `fetchByDate` tests. Asserts that the
/// outgoing PostgREST request actually carries the `language` and
/// `publish_date` equality filters (e.g. `eq.zh-TW`, `eq.2026-07-01`)
/// before responding with [rows], so a regression that swaps/drops a
/// `.eq()` filter fails the test even though the canned response would
/// otherwise still map correctly.
SupabaseClient _clientAssertingQuery({
  required List<Map<String, dynamic>> rows,
  required String expectedLanguageFilter,
  required String expectedDateFilter,
}) {
  final mockHttpClient = MockClient((request) async {
    final query = request.url.queryParameters;
    expect(query['language'], expectedLanguageFilter);
    expect(query['publish_date'], expectedDateFilter);
    return http.Response(
      jsonEncode(rows),
      200,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  });
  return SupabaseClient(
    'https://example.supabase.co',
    'anon-key',
    httpClient: mockHttpClient,
  );
}
