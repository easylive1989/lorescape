import 'package:context_app/features/explore/domain/models/place.dart';
import 'package:context_app/features/explore/domain/models/place_category.dart';
import 'package:context_app/features/explore/domain/models/place_location.dart';
import 'package:context_app/features/explore/domain/repositories/places_repository.dart';
import 'package:context_app/features/settings/domain/models/language.dart';
import 'package:context_app/features/share/data/share_intent_handler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPlacesRepository extends Mock implements PlacesRepository {}

void main() {
  late MockPlacesRepository mockRepository;
  late ShareIntentHandler handler;

  const testPlace = Place(
    id: 'ChIJ_1',
    name: '台北101',
    address: '台北市信義區信義路五段7號',
    location: PlaceLocation(latitude: 25.03, longitude: 121.56),
    tags: ['tourist_attraction'],
    photos: [],
    category: PlaceCategory.modernUrban,
  );

  setUp(() {
    mockRepository = MockPlacesRepository();
    handler = ShareIntentHandler(mockRepository);
  });

  setUpAll(() {
    registerFallbackValue(const Language('zh-TW'));
  });

  group('ShareIntentHandler', () {
    test('resolves place from Google Maps share text', () async {
      when(
        () => mockRepository.searchPlaces(
          '台北101',
          language: any(named: 'language'),
        ),
      ).thenAnswer((_) async => [testPlace]);

      final result = await handler.resolveSharedText(
        '台北101\nhttps://maps.app.goo.gl/abc123',
        language: const Language('zh-TW'),
      );

      expect(result, isNotNull);
      expect(result!.name, '台北101');
      verify(
        () => mockRepository.searchPlaces(
          '台北101',
          language: any(named: 'language'),
        ),
      ).called(1);
    });

    test('returns null for non-Google Maps text', () async {
      final result = await handler.resolveSharedText(
        'Just some random text',
        language: const Language('zh-TW'),
      );

      expect(result, isNull);
      verifyNever(
        () => mockRepository.searchPlaces(
          any(),
          language: any(named: 'language'),
        ),
      );
    });

    test('falls back to URL-derived name when no text before URL', () async {
      when(
        () => mockRepository.searchPlaces(
          'Taipei 101',
          language: any(named: 'language'),
        ),
      ).thenAnswer((_) async => [testPlace]);

      final result = await handler.resolveSharedText(
        'https://www.google.com/maps/place/Taipei+101/@25.03,121.56',
        language: const Language('en'),
      );

      expect(result, isNotNull);
      expect(result!.name, '台北101');
    });

    test('extracts place name from ?q= query parameter', () async {
      // Reproduces iOS Google Maps "send to other app" flow:
      // the short link expands to `https://maps.google.com?q=NAME&ftid=...`.
      when(
        () => mockRepository.searchPlaces(
          '尋嚐人家',
          language: any(named: 'language'),
        ),
      ).thenAnswer((_) async => [testPlace]);

      final result = await handler.resolveSharedText(
        'https://maps.google.com?q=%E5%B0%8B%E5%9A%90%E4%BA%BA%E5%AE%B6'
        '&ftid=0x3469192045a2ac15:0xcab7b7a0e029a0c8',
        language: const Language('zh-TW'),
      );

      expect(result, isNotNull);
      verify(
        () => mockRepository.searchPlaces(
          '尋嚐人家',
          language: any(named: 'language'),
        ),
      ).called(1);
    });

    test('retries with trailing store name when full address fails', () async {
      // Real example: iOS Google Maps expands a short link into
      // `?q=406臺中市北屯區太順路77號尋嚐人家` which Places Text
      // Search doesn't match. The handler should retry with the
      // trailing non-numeric segment.
      const fullQuery = '406臺中市北屯區太順路77號尋嚐人家';
      when(
        () => mockRepository.searchPlaces(
          fullQuery,
          language: any(named: 'language'),
        ),
      ).thenAnswer((_) async => []);
      when(
        () => mockRepository.searchPlaces(
          '臺中市北屯區太順路77號尋嚐人家',
          language: any(named: 'language'),
        ),
      ).thenAnswer((_) async => []);
      when(
        () => mockRepository.searchPlaces(
          '尋嚐人家',
          language: any(named: 'language'),
        ),
      ).thenAnswer((_) async => [testPlace]);

      final result = await handler.resolveSharedText(
        'https://maps.google.com?q=406%E8%87%BA%E4%B8%AD%E5%B8%82'
        '%E5%8C%97%E5%B1%AF%E5%8D%80%E5%A4%AA%E9%A0%86%E8%B7%AF77'
        '%E8%99%9F%E5%B0%8B%E5%9A%90%E4%BA%BA%E5%AE%B6'
        '&ftid=0x3469192045a2ac15:0xcab7b7a0e029a0c8',
        language: const Language('zh-TW'),
      );

      expect(result, isNotNull);
    });

    test('returns null when place not found', () async {
      when(
        () => mockRepository.searchPlaces(
          any(),
          language: any(named: 'language'),
        ),
      ).thenAnswer((_) async => []);

      final result = await handler.resolveSharedText(
        '不存在的地方\nhttps://maps.app.goo.gl/xyz',
        language: const Language('zh-TW'),
      );

      expect(result, isNull);
    });
  });
}
