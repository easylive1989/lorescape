import 'package:context_app/features/journey/domain/models/saved_place.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SavedPlace.toPlace', () {
    test(
      'given a saved place with an image, when converted for playback, '
      'then identity is kept and the image becomes the primary photo',
      () {
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
      },
    );

    test(
      'given a saved place without an image, when converted for playback, '
      'then it carries no photos',
      () {
        const saved = SavedPlace(
          id: 'nophoto',
          name: 'No Photo',
          address: 'Somewhere',
        );

        final place = saved.toPlace();

        expect(place.photos, isEmpty);
        expect(place.primaryPhoto, isNull);
      },
    );
  });
}
