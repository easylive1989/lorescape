import 'package:context_app/features/explore/data/dto/wikidata_entity_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WikidataEntityDto.fromEntity', () {
    test('extracts P31 class ids', () {
      final entity = {
        'id': 'Q221716',
        'claims': {
          'P31': [
            {
              'mainsnak': {
                'datavalue': {
                  'value': {'id': 'Q5393308'},
                },
              },
            },
          ],
        },
      };

      final dto = WikidataEntityDto.fromEntity(entity);

      expect(dto.id, 'Q221716');
      expect(dto.p31ClassIds, ['Q5393308']);
    });

    test('handles multiple P31 values', () {
      final entity = {
        'id': 'Q11574990',
        'claims': {
          'P31': [
            {
              'mainsnak': {
                'datavalue': {
                  'value': {'id': 'Q79007'},
                },
              },
            },
            {
              'mainsnak': {
                'datavalue': {
                  'value': {'id': 'Q667783'},
                },
              },
            },
          ],
        },
      };

      final dto = WikidataEntityDto.fromEntity(entity);

      expect(dto.p31ClassIds, ['Q79007', 'Q667783']);
    });

    test('returns empty list when P31 missing', () {
      final entity = {'id': 'Q1', 'claims': <String, dynamic>{}};
      final dto = WikidataEntityDto.fromEntity(entity);
      expect(dto.p31ClassIds, isEmpty);
    });

    test('extracts P625 coordinates', () {
      final entity = {
        'id': 'Q221716',
        'claims': {
          'P31': [
            {
              'mainsnak': {
                'datavalue': {
                  'value': {'id': 'Q5393308'},
                },
              },
            },
          ],
          'P625': [
            {
              'mainsnak': {
                'datavalue': {
                  'value': {'latitude': 25.037222, 'longitude': 121.499722},
                },
              },
            },
          ],
        },
      };

      final dto = WikidataEntityDto.fromEntity(entity);

      expect(dto.coordinates, isNotNull);
      expect(dto.coordinates!.$1, closeTo(25.037222, 0.000001));
      expect(dto.coordinates!.$2, closeTo(121.499722, 0.000001));
    });

    test('returns null coordinates when P625 missing', () {
      final entity = {'id': 'Q1', 'claims': <String, dynamic>{}};

      final dto = WikidataEntityDto.fromEntity(entity);

      expect(dto.coordinates, isNull);
    });

    test('skips malformed P31 claims without raising', () {
      final entity = {
        'id': 'Q1',
        'claims': {
          'P31': [
            {'mainsnak': {}},
            {
              'mainsnak': {
                'datavalue': {
                  'value': {'id': 'Q33506'},
                },
              },
            },
          ],
        },
      };

      final dto = WikidataEntityDto.fromEntity(entity);
      expect(dto.p31ClassIds, ['Q33506']);
    });
  });
}
