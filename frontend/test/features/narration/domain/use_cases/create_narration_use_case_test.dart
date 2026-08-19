import 'package:context_app/core/errors/app_error.dart';
import 'package:context_app/features/narration/domain/errors/narration_error.dart';
import 'package:context_app/features/explore/domain/models/place.dart';
import 'package:context_app/features/explore/domain/models/place_category.dart';
import 'package:context_app/features/explore/domain/models/place_location.dart';
import 'package:context_app/features/narration/domain/models/narration_content.dart';
import 'package:context_app/features/narration/domain/models/story_hook.dart';
import 'package:context_app/features/narration/domain/services/narration_service.dart';
import 'package:context_app/features/narration/domain/use_cases/create_narration_use_case.dart';
import 'package:context_app/features/settings/domain/models/language.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNarrationService extends Mock implements NarrationService {}

class FakePlace extends Fake implements Place {}

class FakeLanguage extends Fake implements Language {}

class FakeStoryHook extends Fake implements StoryHook {}

const _hook = StoryHook(
  id: 'hook-1',
  title: 'The fire of 1908',
  teaser: 'A spark in the kitchen almost took this place down...',
);

void main() {
  late CreateNarrationUseCase useCase;
  late MockNarrationService mockNarrationService;

  setUpAll(() {
    registerFallbackValue(FakePlace());
    registerFallbackValue(FakeLanguage());
    registerFallbackValue(FakeStoryHook());
  });

  setUp(() {
    mockNarrationService = MockNarrationService();
    useCase = CreateNarrationUseCase(mockNarrationService);
  });

  const testPlace = Place(
    id: 'test-place-id',
    name: 'Test Place',
    address: '123 Test St, Test City',
    location: PlaceLocation(latitude: 25.0, longitude: 121.0),
    tags: ['tourist_attraction'],
    photos: [],
    category: PlaceCategory.historicalCultural,
  );

  const testGeneratedText = '''
這是一個測試地點。這裡有豐富的歷史。
許多遊客來到這裡參觀。這是一個著名的景點。
''';

  test('成功生成導覽（with hook）', () async {
    when(
      () => mockNarrationService.generateNarration(
        place: testPlace,
        language: any(named: 'language'),
        hook: _hook,
      ),
    ).thenAnswer((_) async => (text: testGeneratedText, grounding: null));

    final narrationContent = await useCase.execute(
      place: testPlace,
      language: Language.traditionalChinese,
      hook: _hook,
    );

    expect(
      narrationContent,
      equals(
        NarrationContent.create(
          testGeneratedText,
          language: Language.traditionalChinese,
        ),
      ),
    );
  });

  test('沒有 hook 時也能生成（fallback 流程）', () async {
    when(
      () => mockNarrationService.generateNarration(
        place: testPlace,
        language: any(named: 'language'),
        hook: null,
      ),
    ).thenAnswer((_) async => (text: testGeneratedText, grounding: null));

    final narrationContent = await useCase.execute(
      place: testPlace,
      language: Language.traditionalChinese,
    );

    expect(narrationContent, isNotNull);
  });

  test('生成失敗時拋出 AppError', () async {
    when(
      () => mockNarrationService.generateNarration(
        place: any(named: 'place'),
        language: any(named: 'language'),
        hook: any(named: 'hook'),
      ),
    ).thenThrow(const AppError(type: NarrationError.serverError));

    await expectLater(
      useCase.execute(
        place: testPlace,
        language: Language.traditionalChinese,
        hook: _hook,
      ),
      throwsA(isA<AppError>()),
    );
  });
}
