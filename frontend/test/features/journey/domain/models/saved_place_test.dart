import 'package:context_app/features/journey/domain/models/saved_place.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SavedPlace.toPlace', () {
    test('given a saved place with an image, when converted for playback, '
        'then identity is kept and the image becomes the primary photo', () {
      const saved = SavedPlace(
        id: 'kinkakuji',
        name: 'Kinkaku-ji',
        address: '1 Kinkakujicho',
        imageUrl: 'https://example.com/photo.jpg',
      );

      final place = saved.toPlace();

      expect(place.id, 'kinkakuji');
      expect(place.name, 'Kinkaku-ji');
      expect(place.address, '1 Kinkakujicho');
      expect(place.primaryPhoto?.url, 'https://example.com/photo.jpg');
    });

    test('given a saved place without an image, when converted for playback, '
        'then it carries no photos', () {
      const saved = SavedPlace(
        id: 'nophoto',
        name: 'No Photo',
        address: 'Somewhere',
      );

      final place = saved.toPlace();

      expect(place.photos, isEmpty);
      expect(place.primaryPhoto, isNull);
    });

    test('given a saved place with coordinates, '
        'when converting it back to a Place, '
        'then the real coordinates are used', () {
      const place = SavedPlace(
        id: 'wikidata:Q1',
        name: '龐貝',
        address: '義大利',
        latitude: 40.7497,
        longitude: 14.4869,
      );

      final result = place.toPlace();

      expect(result.location.latitude, 40.7497);
      expect(result.location.longitude, 14.4869);
    });

    test('given a saved place without coordinates, '
        'when converting it back to a Place, '
        'then it falls back to zero', () {
      const place = SavedPlace(id: 'wikidata:Q1', name: '龐貝', address: '義大利');

      final result = place.toPlace();

      expect(result.location.latitude, 0);
      expect(result.location.longitude, 0);
    });
  });
}
