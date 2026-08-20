import 'package:context_app/features/explore/data/mappers/wikidata_category_mapper.dart';
import 'package:context_app/features/explore/domain/models/place_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WikidataCategoryMapper.categorize', () {
    test('Buddhist temple (Q5393308) → historicalCultural', () {
      expect(
        WikidataCategoryMapper.categorize(['Q5393308']),
        PlaceCategory.historicalCultural,
      );
    });

    test('Shinto shrine (Q845945) → historicalCultural', () {
      expect(
        WikidataCategoryMapper.categorize(['Q845945']),
        PlaceCategory.historicalCultural,
      );
    });

    test('Chinese temple (Q2680845) → historicalCultural', () {
      expect(
        WikidataCategoryMapper.categorize(['Q2680845']),
        PlaceCategory.historicalCultural,
      );
    });

    test('museum (Q33506) → museumArt', () {
      expect(
        WikidataCategoryMapper.categorize(['Q33506']),
        PlaceCategory.museumArt,
      );
    });

    test('art museum (Q207694) → museumArt', () {
      expect(
        WikidataCategoryMapper.categorize(['Q207694']),
        PlaceCategory.museumArt,
      );
    });

    test('mountain (Q8502) → naturalLandscape', () {
      expect(
        WikidataCategoryMapper.categorize(['Q8502']),
        PlaceCategory.naturalLandscape,
      );
    });

    test('park (Q22698) → naturalLandscape', () {
      expect(
        WikidataCategoryMapper.categorize(['Q22698']),
        PlaceCategory.naturalLandscape,
      );
    });

    test('forest park (Q6629955) → naturalLandscape', () {
      expect(
        WikidataCategoryMapper.categorize(['Q6629955']),
        PlaceCategory.naturalLandscape,
      );
    });

    test('public aquarium (Q2281788) → naturalLandscape', () {
      expect(
        WikidataCategoryMapper.categorize(['Q2281788']),
        PlaceCategory.naturalLandscape,
      );
    });

    test('tourist attraction (Q570116) → modernUrban', () {
      expect(
        WikidataCategoryMapper.categorize(['Q570116']),
        PlaceCategory.modernUrban,
      );
    });

    test('urban park (Q22746) → modernUrban', () {
      expect(
        WikidataCategoryMapper.categorize(['Q22746']),
        PlaceCategory.modernUrban,
      );
    });

    test('urban park + forest park (e.g. Wenxin Forest Park Q5507841) → '
        'modernUrban', () {
      expect(
        WikidataCategoryMapper.categorize(['Q22746', 'Q6629955']),
        PlaceCategory.modernUrban,
      );
    });

    test('returns first whitelist hit when multiple P31 values', () {
      // street (not in WL) + sandō (in WL, cultural)
      expect(
        WikidataCategoryMapper.categorize(['Q79007', 'Q667783']),
        PlaceCategory.historicalCultural,
      );
    });

    test('returns null for high school (Q56351315, not whitelisted)', () {
      expect(WikidataCategoryMapper.categorize(['Q56351315']), isNull);
    });

    test('returns null for police station (Q861951)', () {
      expect(WikidataCategoryMapper.categorize(['Q861951']), isNull);
    });

    test('returns null for district court (Q75029)', () {
      expect(WikidataCategoryMapper.categorize(['Q75029']), isNull);
    });

    test('returns null for empty list', () {
      expect(WikidataCategoryMapper.categorize([]), isNull);
    });
  });
}
