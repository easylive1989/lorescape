import 'package:context_app/features/explore/data/dto/wiki_geo_search_result_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WikiGeoSearchResultDto.fromPage', () {
    test('parses page with thumbnail and wikidata id', () {
      final page = {
        'pageid': 7253,
        'title': '台北101',
        'coordinates': [
          {'lat': 25.0336, 'lon': 121.5644, 'primary': ''},
        ],
        'thumbnail': {
          'source': 'https://upload.wikimedia.org/x.jpg',
          'width': 400,
          'height': 300,
        },
        'pageprops': {'wikibase_item': 'Q83101'},
      };

      final dto = WikiGeoSearchResultDto.fromPage(page)!;

      expect(dto.pageId, 7253);
      expect(dto.title, '台北101');
      expect(dto.lat, 25.0336);
      expect(dto.lon, 121.5644);
      expect(dto.thumbnailUrl, 'https://upload.wikimedia.org/x.jpg');
      expect(dto.thumbnailWidth, 400);
      expect(dto.thumbnailHeight, 300);
      expect(dto.wikidataId, 'Q83101');
    });

    test('handles missing thumbnail and wikidata id', () {
      final page = {
        'pageid': 1,
        'title': 'No data place',
        'coordinates': [
          {'lat': 10.0, 'lon': 20.0},
        ],
      };

      final dto = WikiGeoSearchResultDto.fromPage(page)!;

      expect(dto.thumbnailUrl, isNull);
      expect(dto.wikidataId, isNull);
    });

    test('returns null when both coordinates and wikidataId are missing', () {
      final page = {'pageid': 1, 'title': 'Bad page'};
      expect(WikiGeoSearchResultDto.fromPage(page), isNull);
    });

    test('returns DTO with null coords when no coords but has wikidataId', () {
      final page = {
        'pageid': 99,
        'title': 'No-Coord Place',
        'pageprops': {'wikibase_item': 'Q999'},
      };

      final dto = WikiGeoSearchResultDto.fromPage(page)!;

      expect(dto.lat, isNull);
      expect(dto.lon, isNull);
      expect(dto.wikidataId, 'Q999');
    });
  });
}
