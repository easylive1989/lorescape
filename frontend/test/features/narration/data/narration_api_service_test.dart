import 'package:context_app/core/errors/app_error.dart';
import 'package:context_app/features/explore/domain/models/place.dart';
import 'package:context_app/features/explore/domain/models/place_category.dart';
import 'package:context_app/features/explore/domain/models/place_location.dart';
import 'package:context_app/features/narration/data/narration_api_client.dart';
import 'package:context_app/features/narration/data/narration_api_service.dart';
import 'package:context_app/features/narration/domain/errors/narration_error.dart';
import 'package:context_app/features/settings/domain/models/language.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockClient extends Mock implements NarrationApiClient {}

Place _place({required String id, String name = 'Macaron Park'}) {
  return Place(
    id: id,
    name: name,
    address: 'Taoyuan',
    location: const PlaceLocation(latitude: 25.0, longitude: 121.0),
    tags: const [],
    photos: const [],
    category: PlaceCategory.modernUrban,
  );
}

const _zhTw = Language('zh-TW');
const _en = Language('en');

NarrationApiResult _happyNarrationResult() {
  return const NarrationApiResult(
    placeName: 'Macaron Park',
    location: 'Taoyuan',
    era: '現代',
    paragraphs: ['段落一', '段落二', '段落三'],
    pullQuote: '「甜蜜的滋味」',
    insufficientSource: false,
  );
}

void main() {
  late _MockClient client;
  late NarrationApiService service;

  setUp(() {
    client = _MockClient();
    service = NarrationApiService(client);
  });

  test(
    'Given a Place with wikidata-prefixed id '
    'When service.generateNarration is called '
    'Then client receives wikidataId extracted from the id (no prefix)',
    () async {
      when(
        () => client.fetchNarration(
          wikidataId: any(named: 'wikidataId'),
          placeName: any(named: 'placeName'),
          location: any(named: 'location'),
          language: any(named: 'language'),
          hook: any(named: 'hook'),
        ),
      ).thenAnswer((_) async => _happyNarrationResult());

      await service.generateNarration(
        place: _place(id: 'wikidata:Q108234567'),
        language: _zhTw,
      );

      verify(
        () => client.fetchNarration(
          wikidataId: 'Q108234567',
          placeName: 'Macaron Park',
          location: any(named: 'location'),
          language: 'zh-TW',
          hook: any(named: 'hook'),
        ),
      ).called(1);
    },
  );

  test(
    'Given a Place whose id does NOT start with wikidata: prefix '
    'When service.generateNarration is called '
    'Then service short-circuits to insufficientSource error without calling the client',
    () async {
      await expectLater(
        service.generateNarration(
          place: _place(id: 'someOtherId'),
          language: _en,
        ),
        throwsA(
          isA<AppError>().having(
            (e) => e.type,
            'type',
            NarrationError.insufficientSource,
          ),
        ),
      );

      verifyNever(
        () => client.fetchNarration(
          wikidataId: any(named: 'wikidataId'),
          placeName: any(named: 'placeName'),
          location: any(named: 'location'),
          language: any(named: 'language'),
          hook: any(named: 'hook'),
        ),
      );
    },
  );
}
