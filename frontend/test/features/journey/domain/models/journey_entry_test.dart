// JourneyEntry encapsulates two non-trivial behaviours worth testing
// in isolation:
//
//   1. create(): maps a rich Place (+ its primary photo) into the
//      slimmer SavedPlace projection that journeys persist.
//   2. fromJson(): tolerates legacy rows written before story_hook /
//      trip_id existed.
//
// Pure constructor / parameter-pass-through cases were removed: they
// only restated the model definition and would pass even when the
// behaviour above was broken. Real tripId usage is exercised
// end-to-end in trip_lifecycle_flow_test and narration integration
// tests.

import 'package:context_app/features/explore/domain/models/place.dart';
import 'package:context_app/features/explore/domain/models/place_category.dart';
import 'package:context_app/features/explore/domain/models/place_location.dart';
import 'package:context_app/features/explore/domain/models/place_photo.dart';
import 'package:context_app/features/journey/domain/models/journey_entry.dart';
import 'package:context_app/features/journey/domain/models/saved_place.dart';
import 'package:context_app/features/narration/domain/models/narration_content.dart';
import 'package:context_app/features/narration/domain/models/story_hook.dart';
import 'package:context_app/features/settings/domain/models/language.dart';
import 'package:flutter_test/flutter_test.dart';

const _hook = StoryHook(
  id: 'hook-1',
  title: 'The fire of 1908',
  teaser: 'A spark in the kitchen almost took this place down...',
);

void main() {
  group('JourneyEntry.create projects Place onto SavedPlace', () {
    test(
      'given a place with no photos, when creating an entry, '
      'then SavedPlace has no imageUrl',
      () {
        const place = Place(
          id: 'place-1',
          name: 'Test Place',
          address: 'Test Address',
          location: PlaceLocation(latitude: 25.0, longitude: 121.0),
          tags: [],
          photos: [],
          category: PlaceCategory.historicalCultural,
        );
        final content = NarrationContent.create(
          'Test narration',
          language: Language.traditionalChinese,
        );

        final entry = JourneyEntry.create(
          id: 'test-id',
          place: place,
          content: content,
          hook: _hook,
          language: Language.traditionalChinese,
        );

        expect(
          entry.place,
          equals(
            const SavedPlace(
              id: 'place-1',
              name: 'Test Place',
              address: 'Test Address',
              latitude: 25.0,
              longitude: 121.0,
            ),
          ),
        );
        expect(entry.narrationContent, equals(content));
        expect(entry.storyHook, equals(_hook));
        expect(entry.language, equals(Language.traditionalChinese));
      },
    );

    test(
      'given a place with photos, when creating an entry, '
      'then SavedPlace.imageUrl is taken from the primary photo',
      () {
        const placePhoto = PlacePhoto(
          url: 'https://example.com/photo.jpg',
          width: 800,
          height: 600,
          attributions: ['Author Name'],
        );
        const place = Place(
          id: 'place-2',
          name: 'Place With Photo',
          address: 'Address 2',
          location: PlaceLocation(latitude: 25.0, longitude: 121.0),
          tags: [],
          photos: [placePhoto],
          category: PlaceCategory.naturalLandscape,
        );
        final content = NarrationContent.create(
          'Story narration',
          language: Language.traditionalChinese,
        );

        final entry = JourneyEntry.create(
          id: 'test-id-2',
          place: place,
          content: content,
          hook: _hook,
          language: Language.traditionalChinese,
        );

        expect(
          entry.place,
          equals(
            const SavedPlace(
              id: 'place-2',
              name: 'Place With Photo',
              address: 'Address 2',
              imageUrl: 'https://example.com/photo.jpg',
              latitude: 25.0,
              longitude: 121.0,
            ),
          ),
        );
      },
    );
  });

  group('JourneyEntry.fromJson legacy handling', () {
    test(
      'given a legacy row written before story_hook existed, '
      'when deserialising, then storyHook is null',
      () {
        const place = Place(
          id: 'p-legacy',
          name: 'Legacy',
          address: 'Addr',
          location: PlaceLocation(latitude: 0, longitude: 0),
          tags: [],
          photos: [],
          category: PlaceCategory.modernUrban,
        );
        final content = NarrationContent.create(
          'legacy text',
          language: Language.traditionalChinese,
        );
        final entry = JourneyEntry.create(
          id: 'legacy-id',
          place: place,
          content: content,
          language: Language.traditionalChinese,
        );

        final json = entry.toJson();
        json['narration_styles'] = ['historical_background'];

        final restored = JourneyEntry.fromJson(json);

        expect(restored.storyHook, isNull);
      },
    );

    test(
      'given a legacy row missing trip_id, when deserialising, '
      'then tripId is null',
      () {
        const place = Place(
          id: 'p1',
          name: 'Test',
          address: 'Addr',
          location: PlaceLocation(latitude: 0, longitude: 0),
          tags: [],
          photos: [],
          category: PlaceCategory.modernUrban,
        );
        final content = NarrationContent.create(
          'Some narration text for testing.',
          language: Language.traditionalChinese,
        );
        final entry = JourneyEntry.create(
          id: 'legacy-id',
          place: place,
          content: content,
          language: Language.traditionalChinese,
          tripId: 'will-be-removed',
        );
        final legacyJson = entry.toJson()..remove('trip_id');

        final restored = JourneyEntry.fromJson(legacyJson);

        expect(restored.tripId, isNull);
      },
    );

    test('given a journey entry with place coordinates, '
        'when round-tripping through JSON, '
        'then the coordinates survive', () {
      const place = SavedPlace(
        id: 'wikidata:Q1',
        name: '龐貝',
        address: '義大利',
        latitude: 40.7497,
        longitude: 14.4869,
      );
      final entry = JourneyEntry(
        id: 'e1',
        place: place,
        narrationContent: NarrationContent.create(
          '一段關於龐貝古城的精彩故事',
          language: const Language('zh-TW'),
        ),
        createdAt: DateTime.utc(2026, 8, 19),
        updatedAt: DateTime.utc(2026, 8, 19),
        language: const Language('zh-TW'),
      );

      final restored = JourneyEntry.fromJson(entry.toJson());

      expect(restored.place.latitude, 40.7497);
      expect(restored.place.longitude, 14.4869);
    });

    test('given legacy JSON without coordinates, '
        'when parsing it, '
        'then the coordinates are null rather than an error', () {
      final restored = JourneyEntry.fromJson({
        'id': 'e1',
        'place_id': 'wikidata:Q1',
        'place_name': '龐貝',
        'place_address': '義大利',
        'place_image_url': null,
        'narration_text': '一段關於龐貝古城的精彩故事',
        'created_at': '2026-08-19T00:00:00.000Z',
        'updated_at': '2026-08-19T00:00:00.000Z',
        'language': 'zh-TW',
        'trip_id': null,
      });

      expect(restored.place.latitude, isNull);
      expect(restored.place.longitude, isNull);
    });
  });
}
