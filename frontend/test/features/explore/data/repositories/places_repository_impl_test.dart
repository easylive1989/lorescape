import 'package:context_app/core/errors/app_error.dart';
import 'package:context_app/features/explore/data/dto/wiki_geo_search_result_dto.dart';
import 'package:context_app/features/explore/data/dto/wikidata_entity_dto.dart';
import 'package:context_app/features/explore/data/repositories/places_repository_impl.dart';
import 'package:context_app/features/explore/data/services/wikidata_landmark_query_service.dart';
import 'package:context_app/features/explore/data/services/wikipedia_places_service.dart';
import 'package:context_app/features/explore/domain/errors/place_error.dart';
import 'package:context_app/features/explore/domain/models/place_category.dart';
import 'package:context_app/features/explore/domain/models/place_location.dart';
import 'package:context_app/features/settings/domain/models/language.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWikipediaPlacesService extends Mock
    implements WikipediaPlacesService {}

class MockWikidataLandmarkQueryService extends Mock
    implements WikidataLandmarkQueryService {}

void main() {
  late PlacesRepositoryImpl repository;
  late MockWikipediaPlacesService mockService;
  late MockWikidataLandmarkQueryService mockLandmarkService;

  const testLocation = PlaceLocation(latitude: 25.0336, longitude: 121.5644);
  const testLanguage = Language.traditionalChinese;
  const testRadius = 1000.0;

  setUp(() {
    mockService = MockWikipediaPlacesService();
    mockLandmarkService = MockWikidataLandmarkQueryService();
    repository = PlacesRepositoryImpl(
      mockService,
      landmarkService: mockLandmarkService,
    );

    when(
      () => mockLandmarkService.findLandmarkIdsForQuery(
        any(),
        wikiLang: any(named: 'wikiLang'),
      ),
    ).thenAnswer((_) async => const []);
  });

  WikiGeoSearchResultDto geoDto({
    required String title,
    required String wikidataId,
    String? thumb = 'https://img/x.jpg',
  }) {
    return WikiGeoSearchResultDto(
      pageId: title.hashCode,
      title: title,
      lat: 25.0,
      lon: 121.0,
      thumbnailUrl: thumb,
      thumbnailWidth: thumb == null ? null : 400,
      thumbnailHeight: thumb == null ? null : 300,
      wikidataId: wikidataId,
    );
  }

  group('getNearbyPlaces', () {
    test(
      'calls geoSearch with zh, then wbgetentities, builds Place list',
      () async {
        when(
          () => mockService.geoSearch(
            lat: any(named: 'lat'),
            lon: any(named: 'lon'),
            radiusMeters: any(named: 'radiusMeters'),
            wikiLang: any(named: 'wikiLang'),
          ),
        ).thenAnswer(
          (_) async => [
            geoDto(title: '清水寺', wikidataId: 'Q221716'),
            geoDto(title: '小学校', wikidataId: 'Q17219693'),
          ],
        );

        when(() => mockService.fetchEntities(any())).thenAnswer(
          (_) async => {
            'Q221716': const WikidataEntityDto(
              id: 'Q221716',
              p31ClassIds: ['Q5393308'], // temple → kept
            ),
            'Q17219693': const WikidataEntityDto(
              id: 'Q17219693',
              p31ClassIds: ['Q5358913'], // elementary school → dropped
            ),
          },
        );

        final result = await repository.getNearbyPlaces(
          testLocation,
          language: testLanguage,
          radius: testRadius,
        );

        expect(result, hasLength(1));
        expect(result.first.name, '清水寺');
        expect(result.first.id, 'wikidata:Q221716');
        expect(result.first.category, PlaceCategory.historicalCultural);
        expect(result.first.photos.first.url, 'https://img/x.jpg');

        verify(
          () => mockService.geoSearch(
            lat: 25.0336,
            lon: 121.5644,
            radiusMeters: 1000.0,
            wikiLang: 'zh',
          ),
        ).called(1);
      },
    );

    test('skips results with no wikidata id', () async {
      when(
        () => mockService.geoSearch(
          lat: any(named: 'lat'),
          lon: any(named: 'lon'),
          radiusMeters: any(named: 'radiusMeters'),
          wikiLang: any(named: 'wikiLang'),
        ),
      ).thenAnswer(
        (_) async => [
          const WikiGeoSearchResultDto(
            pageId: 1,
            title: 'orphan',
            lat: 0.0,
            lon: 0.0,
            // no wikidataId
          ),
        ],
      );
      when(() => mockService.fetchEntities(any())).thenAnswer((_) async => {});

      final result = await repository.getNearbyPlaces(
        testLocation,
        language: testLanguage,
        radius: testRadius,
      );

      expect(result, isEmpty);
    });

    test('Place.photos is empty when no thumbnail', () async {
      when(
        () => mockService.geoSearch(
          lat: any(named: 'lat'),
          lon: any(named: 'lon'),
          radiusMeters: any(named: 'radiusMeters'),
          wikiLang: any(named: 'wikiLang'),
        ),
      ).thenAnswer(
        (_) async => [geoDto(title: 't', wikidataId: 'Q1', thumb: null)],
      );
      when(() => mockService.fetchEntities(any())).thenAnswer(
        (_) async => {
          'Q1': const WikidataEntityDto(id: 'Q1', p31ClassIds: ['Q33506']),
        },
      );

      final result = await repository.getNearbyPlaces(
        testLocation,
        language: testLanguage,
        radius: testRadius,
      );

      expect(result.first.photos, isEmpty);
    });
  });

  group('getNearbyPlaces dynamic radius', () {
    test('retries once with radius*5 when <3 kept places', () async {
      final calls = <double>[];

      when(
        () => mockService.geoSearch(
          lat: any(named: 'lat'),
          lon: any(named: 'lon'),
          radiusMeters: any(named: 'radiusMeters'),
          wikiLang: any(named: 'wikiLang'),
        ),
      ).thenAnswer((inv) async {
        calls.add(inv.namedArguments[#radiusMeters] as double);
        if (calls.length == 1) {
          return [geoDto(title: 'a', wikidataId: 'Q1')];
        }
        return [
          geoDto(title: 'a', wikidataId: 'Q1'),
          geoDto(title: 'b', wikidataId: 'Q2'),
          geoDto(title: 'c', wikidataId: 'Q3'),
        ];
      });

      when(() => mockService.fetchEntities(any())).thenAnswer((inv) async {
        final ids = inv.positionalArguments.first as List<String>;
        return {
          for (final id in ids)
            id: WikidataEntityDto(id: id, p31ClassIds: const ['Q33506']),
        };
      });

      final result = await repository.getNearbyPlaces(
        testLocation,
        language: testLanguage,
        radius: 1000,
      );

      expect(calls, [1000.0, 5000.0]);
      expect(result, hasLength(3));
    });

    test('does not retry when >=3 kept places', () async {
      final calls = <double>[];
      when(
        () => mockService.geoSearch(
          lat: any(named: 'lat'),
          lon: any(named: 'lon'),
          radiusMeters: any(named: 'radiusMeters'),
          wikiLang: any(named: 'wikiLang'),
        ),
      ).thenAnswer((inv) async {
        calls.add(inv.namedArguments[#radiusMeters] as double);
        return [
          geoDto(title: 'a', wikidataId: 'Q1'),
          geoDto(title: 'b', wikidataId: 'Q2'),
          geoDto(title: 'c', wikidataId: 'Q3'),
        ];
      });
      when(() => mockService.fetchEntities(any())).thenAnswer((inv) async {
        final ids = inv.positionalArguments.first as List<String>;
        return {
          for (final id in ids)
            id: WikidataEntityDto(id: id, p31ClassIds: const ['Q33506']),
        };
      });

      await repository.getNearbyPlaces(
        testLocation,
        language: testLanguage,
        radius: 1000,
      );

      expect(calls, [1000.0]);
    });
  });

  group('getNearbyPlaces language fallback', () {
    test('falls back to en.wiki on zero results', () async {
      final langs = <String>[];
      when(
        () => mockService.geoSearch(
          lat: any(named: 'lat'),
          lon: any(named: 'lon'),
          radiusMeters: any(named: 'radiusMeters'),
          wikiLang: any(named: 'wikiLang'),
        ),
      ).thenAnswer((inv) async {
        final lang = inv.namedArguments[#wikiLang] as String;
        langs.add(lang);
        if (lang == 'zh') return [];
        return [geoDto(title: 'en place', wikidataId: 'Q1')];
      });
      when(() => mockService.fetchEntities(any())).thenAnswer(
        (_) async => {
          'Q1': const WikidataEntityDto(id: 'Q1', p31ClassIds: ['Q33506']),
        },
      );

      final result = await repository.getNearbyPlaces(
        testLocation,
        language: testLanguage,
        radius: 1000,
      );

      expect(langs, contains('zh'));
      expect(langs, contains('en'));
      expect(result.first.name, 'en place');
    });

    test('does not fall back when language is already en', () async {
      final langs = <String>[];
      when(
        () => mockService.geoSearch(
          lat: any(named: 'lat'),
          lon: any(named: 'lon'),
          radiusMeters: any(named: 'radiusMeters'),
          wikiLang: any(named: 'wikiLang'),
        ),
      ).thenAnswer((inv) async {
        langs.add(inv.namedArguments[#wikiLang] as String);
        return [];
      });
      when(() => mockService.fetchEntities(any())).thenAnswer((_) async => {});

      await repository.getNearbyPlaces(
        testLocation,
        language: Language.english,
        radius: 1000,
      );

      expect(langs.every((l) => l == 'en'), isTrue);
    });
  });

  group('searchPlaces', () {
    test('uses P625 coords from entity when DTO has null lat/lon', () async {
      when(
        () => mockService.searchByText(any(), wikiLang: any(named: 'wikiLang')),
      ).thenAnswer(
        (_) async => [
          const WikiGeoSearchResultDto(
            pageId: 1,
            title: 'No-Coord Temple',
            wikidataId: 'Q123',
            // lat and lon are null
          ),
        ],
      );
      when(() => mockService.fetchEntities(any())).thenAnswer(
        (_) async => {
          'Q123': const WikidataEntityDto(
            id: 'Q123',
            p31ClassIds: ['Q5393308'], // temple → kept
            coordinates: (25.1, 121.5),
          ),
        },
      );

      final result = await repository.searchPlaces(
        'temple',
        language: testLanguage,
      );

      expect(result, hasLength(1));
      expect(result.first.location.latitude, 25.1);
      expect(result.first.location.longitude, 121.5);
    });

    test('calls searchByText and applies P31 filter', () async {
      when(
        () => mockService.searchByText(any(), wikiLang: any(named: 'wikiLang')),
      ).thenAnswer(
        (_) async => [
          geoDto(title: '清水寺', wikidataId: 'Q221716'),
          geoDto(title: '小学校', wikidataId: 'Q17219693'),
        ],
      );
      when(() => mockService.fetchEntities(any())).thenAnswer(
        (_) async => {
          'Q221716': const WikidataEntityDto(
            id: 'Q221716',
            p31ClassIds: ['Q5393308'],
          ),
          'Q17219693': const WikidataEntityDto(
            id: 'Q17219693',
            p31ClassIds: ['Q5358913'],
          ),
        },
      );

      final result = await repository.searchPlaces(
        '清水寺',
        language: testLanguage,
      );

      expect(result, hasLength(1));
      expect(result.first.name, '清水寺');
    });

    test('uses region landmark path when query resolves to a region', () async {
      when(
        () => mockLandmarkService.findLandmarkIdsForQuery(
          any(),
          wikiLang: any(named: 'wikiLang'),
        ),
      ).thenAnswer((_) async => ['Q190077', 'Q47481']);

      when(
        () => mockService.fetchPagesByWikidataIds(
          any(),
          wikiLang: any(named: 'wikiLang'),
        ),
      ).thenAnswer(
        (_) async => [
          geoDto(title: '米爾福德峽灣', wikidataId: 'Q190077'),
          geoDto(title: '皇后鎮', wikidataId: 'Q47481'),
        ],
      );

      when(() => mockService.fetchEntities(any())).thenAnswer(
        (_) async => {
          'Q190077': const WikidataEntityDto(
            id: 'Q190077',
            p31ClassIds: ['Q46169'],
          ),
          'Q47481': const WikidataEntityDto(
            id: 'Q47481',
            p31ClassIds: ['Q570116'],
          ),
        },
      );

      final result = await repository.searchPlaces(
        '紐西蘭',
        language: testLanguage,
      );

      expect(result.map((p) => p.name).toList(), ['米爾福德峽灣', '皇后鎮']);
      verifyNever(
        () => mockService.searchByText(any(), wikiLang: any(named: 'wikiLang')),
      );
    });

    test(
      'falls back to text search when landmark service returns empty',
      () async {
        when(
          () =>
              mockService.searchByText(any(), wikiLang: any(named: 'wikiLang')),
        ).thenAnswer(
          (_) async => [geoDto(title: '清水寺', wikidataId: 'Q221716')],
        );
        when(() => mockService.fetchEntities(any())).thenAnswer(
          (_) async => {
            'Q221716': const WikidataEntityDto(
              id: 'Q221716',
              p31ClassIds: ['Q5393308'],
            ),
          },
        );

        final result = await repository.searchPlaces(
          '清水寺',
          language: testLanguage,
        );

        expect(result.map((p) => p.name).toList(), ['清水寺']);
        verify(
          () =>
              mockService.searchByText(any(), wikiLang: any(named: 'wikiLang')),
        ).called(1);
      },
    );

    test(
      'falls back to text search when landmark service throws AppError',
      () async {
        when(
          () => mockLandmarkService.findLandmarkIdsForQuery(
            any(),
            wikiLang: any(named: 'wikiLang'),
          ),
        ).thenThrow(
          const AppError(
            type: PlaceError.searchFailed,
            message: 'sparql failed',
          ),
        );
        when(
          () =>
              mockService.searchByText(any(), wikiLang: any(named: 'wikiLang')),
        ).thenAnswer(
          (_) async => [geoDto(title: '清水寺', wikidataId: 'Q221716')],
        );
        when(() => mockService.fetchEntities(any())).thenAnswer(
          (_) async => {
            'Q221716': const WikidataEntityDto(
              id: 'Q221716',
              p31ClassIds: ['Q5393308'],
            ),
          },
        );

        final result = await repository.searchPlaces(
          '紐西蘭',
          language: testLanguage,
        );

        expect(result.map((p) => p.name).toList(), ['清水寺']);
      },
    );
  });

  group('getPlaceById', () {
    test('returns Place for valid wikidata:Q id', () async {
      when(
        () => mockService.fetchEntityById(
          any(),
          wikiLang: any(named: 'wikiLang'),
        ),
      ).thenAnswer(
        (_) async => WikiEntityWithPage(
          dto: geoDto(title: '清水寺', wikidataId: 'Q221716'),
          entity: const WikidataEntityDto(
            id: 'Q221716',
            p31ClassIds: ['Q5393308'],
          ),
        ),
      );

      final place = await repository.getPlaceById(
        'wikidata:Q221716',
        language: testLanguage,
      );

      expect(place, isNotNull);
      expect(place!.id, 'wikidata:Q221716');
      expect(place.category, PlaceCategory.historicalCultural);
    });

    test('returns null when service returns null', () async {
      when(
        () => mockService.fetchEntityById(
          any(),
          wikiLang: any(named: 'wikiLang'),
        ),
      ).thenAnswer((_) async => null);

      expect(
        await repository.getPlaceById('wikidata:Q999', language: testLanguage),
        isNull,
      );
    });

    test('returns null when P31 not in whitelist', () async {
      when(
        () => mockService.fetchEntityById(
          any(),
          wikiLang: any(named: 'wikiLang'),
        ),
      ).thenAnswer(
        (_) async => WikiEntityWithPage(
          dto: geoDto(title: 'school', wikidataId: 'Q17219693'),
          entity: const WikidataEntityDto(
            id: 'Q17219693',
            p31ClassIds: ['Q5358913'],
          ),
        ),
      );

      expect(
        await repository.getPlaceById(
          'wikidata:Q17219693',
          language: testLanguage,
        ),
        isNull,
      );
    });

    test('returns null when id lacks wikidata: prefix', () async {
      expect(
        await repository.getPlaceById('ChIJN1t_xxxx', language: testLanguage),
        isNull,
      );
    });
  });
}
