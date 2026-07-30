import 'dart:async';
import 'dart:typed_data';

import 'package:context_app/core/errors/app_error.dart';
import 'package:context_app/features/analytics/domain/models/analytics_event.dart';
import 'package:context_app/features/analytics/domain/models/hooks_outcome.dart';
import 'package:context_app/features/analytics/providers.dart';
import 'package:context_app/features/narration/domain/errors/narration_error.dart';
import 'package:context_app/features/explore/domain/models/place.dart';
import 'package:context_app/features/journey/providers.dart';
import 'package:context_app/features/narration/domain/models/story_hook.dart';
import 'package:context_app/features/narration/domain/services/story_hook_service.dart';
import 'package:context_app/features/narration/presentation/screens/select_story_hook_screen.dart';
import 'package:context_app/features/narration/presentation/widgets/story_generating.dart';
import 'package:context_app/features/narration/providers.dart';
import 'package:context_app/features/settings/domain/models/language.dart';
import 'package:context_app/features/usage/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../fakes/fake_narration_service.dart';
import '../../../../fakes/in_memory_journey_repository.dart';
import '../../../../fakes/in_memory_usage_repository.dart';
import '../../../../fakes/recording_analytics_service.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_data.dart';

/// Fake [StoryHookService] returning a fixed list (or throwing).
///
/// When [gate] is provided, the future stays pending until the gate is
/// completed — useful for asserting the loading state.
class _FakeStoryHookService implements StoryHookService {
  final List<StoryHook> hooks;
  final Object? error;
  final Completer<void>? gate;

  _FakeStoryHookService({this.hooks = const [], this.error, this.gate});

  @override
  Future<List<StoryHook>> generateHooks({
    required Place place,
    required Language language,
  }) async {
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return hooks;
  }
}

const _hook1 = StoryHook(
  id: 'fire-1908',
  title: '1908 大火',
  teaser: '一場廚房裡的火，差點燒掉整座廟。',
);
const _hook2 = StoryHook(
  id: 'monk-tale',
  title: '住持的傳說',
  teaser: '住持的女兒和一位日本軍官的故事。',
);

void main() {
  setUpAll(() async {
    await initTestEnvironment();
  });

  group('SelectStoryHookScreen', () {
    testWidgets(
      'given a place, when the screen loads, '
      'then the place name is rendered',
      (tester) async {
        final place = buildPlace(name: 'Fushimi Inari');

        await _pumpScreen(tester, place: place);

        expect(find.text(place.name), findsOneWidget);
      },
    );

    testWidgets(
      'given the hook service is still loading, '
      'then the scan-phase generating animation shows the digging copy '
      'and its step checklist',
      (tester) async {
        final gate = Completer<void>();
        await _pumpScreen(
          tester,
          hookService: _FakeStoryHookService(
            hooks: const [_hook1, _hook2],
            gate: gate,
          ),
          settle: false,
        );
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(StoryGenerating), findsOneWidget);
        expect(find.text('story_generating.scan_title'), findsOneWidget);
        expect(find.text('story_generating.scan_sub'), findsOneWidget);
        expect(find.text('story_generating.scan_step_1'), findsOneWidget);
        expect(find.text('story_generating.scan_step_3'), findsOneWidget);

        // Release the gate so autoDispose teardown doesn't leak a pending
        // future into the next test.
        gate.complete();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'given the generating animation runs, when the step interval elapses, '
      'then the first step is marked done with a check',
      (tester) async {
        final gate = Completer<void>();
        await _pumpScreen(
          tester,
          hookService: _FakeStoryHookService(gate: gate),
          settle: false,
        );
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byIcon(Icons.check), findsNothing);

        await tester.pump(const Duration(seconds: 3));

        expect(find.byIcon(Icons.check), findsOneWidget);

        gate.complete();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'given a hook is tapped and generation is in flight, '
      'then the write-phase animation shows the writing copy, '
      'and the player opens once generation completes',
      (tester) async {
        final narrationService = FakeNarrationService()
          ..gate = Completer<void>();

        await _pumpScreenWithRouter(
          tester,
          hookService: _FakeStoryHookService(hooks: const [_hook1]),
          narrationService: narrationService,
        );

        await tester.tap(find.text(_hook1.title));
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(StoryGenerating), findsOneWidget);
        expect(find.text('story_generating.write_title'), findsOneWidget);
        expect(find.text('story_generating.write_step_1'), findsOneWidget);

        narrationService.gate!.complete();
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('player-screen')), findsOneWidget);
      },
    );

    testWidgets(
      'given hooks load successfully, '
      'then both hook titles and teasers are rendered',
      (tester) async {
        await _pumpScreen(
          tester,
          hookService: _FakeStoryHookService(hooks: const [_hook1, _hook2]),
        );

        expect(find.text('story_hook.title'), findsOneWidget);
        expect(find.text(_hook1.title), findsOneWidget);
        expect(find.text(_hook1.teaser), findsOneWidget);
        expect(find.text(_hook2.title), findsOneWidget);
      },
    );

    testWidgets(
      'given the service returns an empty list, '
      'then the fallback "play default story" button is shown',
      (tester) async {
        await _pumpScreen(
          tester,
          hookService: _FakeStoryHookService(hooks: const []),
        );

        expect(find.text('story_hook.listen_default_button'), findsOneWidget);
      },
    );

    testWidgets(
      'given the service throws, '
      'then the fallback "play default story" button is shown',
      (tester) async {
        await _pumpScreen(
          tester,
          hookService: _FakeStoryHookService(
            error: const AppError(type: NarrationError.networkError),
          ),
        );

        expect(find.text('story_hook.listen_default_button'), findsOneWidget);
      },
    );

    testWidgets(
      'given the service throws insufficientSource, '
      'then the no-story message is shown and the listen button is NOT',
      (tester) async {
        await _pumpScreen(
          tester,
          hookService: _FakeStoryHookService(
            error: const AppError(type: NarrationError.insufficientSource),
          ),
        );

        expect(
          find.text('story_hook.insufficient_source_title'),
          findsOneWidget,
        );
        expect(
          find.text('story_hook.insufficient_source_body'),
          findsOneWidget,
        );
        expect(find.text('story_hook.listen_default_button'), findsNothing);
      },
    );

    testWidgets(
      'given a hook card, when tapped, '
      'then narration generation is triggered with that hook',
      (tester) async {
        final narrationService = FakeNarrationService();

        await _pumpScreenWithRouter(
          tester,
          hookService: _FakeStoryHookService(hooks: const [_hook1]),
          narrationService: narrationService,
        );

        await tester.tap(find.text(_hook1.title));
        await tester.pumpAndSettle();

        expect(narrationService.lastHook, equals(_hook1));
      },
    );

    testWidgets(
      'given the fallback state, when the listen button is tapped, '
      'then narration generation is triggered without a hook',
      (tester) async {
        final narrationService = FakeNarrationService();

        await _pumpScreenWithRouter(
          tester,
          hookService: _FakeStoryHookService(hooks: const []),
          narrationService: narrationService,
        );

        await tester.tap(find.text('story_hook.listen_default_button'));
        await tester.pumpAndSettle();

        expect(narrationService.lastHook, isNull);
        expect(narrationService.lastPlace, isNotNull);
      },
    );

    testWidgets(
      'given two hooks are returned, when the user taps the second one, '
      'then requested / returned / selected are recorded with its index',
      (tester) async {
        final analytics = RecordingAnalyticsService();

        await _pumpScreenWithRouter(
          tester,
          hookService: _FakeStoryHookService(hooks: const [_hook1, _hook2]),
          analytics: analytics,
        );

        await tester.tap(find.text(_hook2.title));
        await tester.pumpAndSettle();

        expect(analytics.types, [
          'hooks_requested',
          'hooks_returned',
          'hook_selected',
        ]);

        final returned = analytics.firstOfType<HooksReturned>()!;
        expect(returned.outcome, HooksOutcome.success);
        expect(returned.hookCount, 2);

        final selected = analytics.firstOfType<HookSelected>()!;
        expect(selected.hookIndex, 1);
        expect(selected.hookCount, 2);
        expect(selected.placeId, isNotEmpty);
        expect(selected.language, 'zh-TW');
      },
    );

    testWidgets(
      'given no hooks were returned, when the user listens anyway, '
      'then the outcome is empty and the selection is flagged as default',
      (tester) async {
        final analytics = RecordingAnalyticsService();

        await _pumpScreenWithRouter(
          tester,
          hookService: _FakeStoryHookService(hooks: const []),
          analytics: analytics,
        );

        await tester.tap(find.text('story_hook.listen_default_button'));
        await tester.pumpAndSettle();

        expect(analytics.firstOfType<HooksReturned>()!.outcome, HooksOutcome.empty);
        // 沒挑角度時不送假的位置，靠 hook_index == null 分流。
        expect(analytics.firstOfType<HookSelected>()!.hookIndex, isNull);
      },
    );

    testWidgets(
      'given the source is insufficient, when the screen loads, '
      'then the outcome is recorded as insufficient_source',
      (tester) async {
        final analytics = RecordingAnalyticsService();

        await _pumpScreen(
          tester,
          hookService: _FakeStoryHookService(
            error: const AppError(type: NarrationError.insufficientSource),
          ),
          analytics: analytics,
        );

        // 「沒給角度」與「給了角度沒人挑」必須分得出來，否則漏斗無法解讀。
        expect(analytics.types, ['hooks_requested', 'hooks_returned']);
        expect(
          analytics.firstOfType<HooksReturned>()!.outcome,
          HooksOutcome.insufficientSource,
        );
      },
    );

    testWidgets(
      'given the backend reports quota exhausted (402), when a hook is '
      'tapped, then the subscription screen is shown',
      (tester) async {
        await pumpRouterApp(
          tester,
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => SelectStoryHookScreen(place: buildPlace()),
            ),
            GoRoute(
              name: 'subscription',
              path: '/subscription',
              builder: (_, __) => const Scaffold(
                key: Key('subscription-screen'),
                body: SizedBox.shrink(),
              ),
            ),
          ],
          overrides: _overrides(
            hookService: _FakeStoryHookService(hooks: const [_hook1]),
            narrationService: FakeNarrationService(
              error: const AppError(type: NarrationError.freeQuotaExceeded),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(_hook1.title));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('subscription-screen')), findsOneWidget);
      },
    );

    testWidgets(
      'given capturedImageBytes are provided, when the screen renders, '
      'then the background uses an Image.memory with those bytes',
      (tester) async {
        await _pumpScreen(
          tester,
          capturedImageBytes: _transparentPngBytes(),
          hookService: _FakeStoryHookService(hooks: const [_hook1]),
        );

        expect(
          find.byWidgetPredicate(
            (w) => w is Image && w.image is MemoryImage,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'given a router, when a hook is tapped and generation succeeds, '
      'then the player route is pushed with the narration content',
      (tester) async {
        final extras = <Object?>[];
        final journeyRepo = InMemoryJourneyRepository();

        await pumpRouterApp(
          tester,
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) =>
                  SelectStoryHookScreen(place: buildPlace()),
            ),
            GoRoute(
              name: 'player',
              path: '/player',
              builder: (_, state) {
                extras.add(state.extra);
                return const Scaffold(
                  key: Key('player-screen'),
                  body: SizedBox.shrink(),
                );
              },
            ),
          ],
          overrides: [
            narrationServiceProvider.overrideWithValue(FakeNarrationService()),
            storyHookServiceProvider.overrideWithValue(
              _FakeStoryHookService(hooks: const [_hook1]),
            ),
            journeyRepositoryProvider.overrideWithValue(journeyRepo),
            usageRepositoryProvider.overrideWithValue(InMemoryUsageRepository()),
          ],
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(_hook1.title));
        await tester.pumpAndSettle();

        expect(extras, hasLength(1));
        final extra = extras.single as Map<String, dynamic>;
        expect(extra['place'], isNotNull);
        expect(extra['narrationContent'], isNotNull);
        expect(extra['autoPlay'], isTrue);
        expect(extra['storyTitle'], equals(_hook1.title));

        final saved = await journeyRepo.getAll();
        expect(saved, hasLength(1));
        expect(saved.single.storyHook, equals(_hook1));
      },
    );
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  Place? place,
  _FakeStoryHookService? hookService,
  FakeNarrationService? narrationService,
  InMemoryUsageRepository? usageRepo,
  Uint8List? capturedImageBytes,
  bool settle = true,
  RecordingAnalyticsService? analytics,
}) async {
  await pumpScreen(
    tester,
    child: SelectStoryHookScreen(
      place: place ?? buildPlace(),
      capturedImageBytes: capturedImageBytes,
    ),
    overrides: _overrides(
      hookService: hookService,
      narrationService: narrationService,
      usageRepo: usageRepo,
      analytics: analytics,
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  }
}

/// Pumps the screen under a GoRouter with a stub `player` route, so that
/// the screen's success-listener can navigate without throwing.
Future<void> _pumpScreenWithRouter(
  WidgetTester tester, {
  Place? place,
  _FakeStoryHookService? hookService,
  FakeNarrationService? narrationService,
  InMemoryUsageRepository? usageRepo,
  RecordingAnalyticsService? analytics,
}) async {
  await pumpRouterApp(
    tester,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) =>
            SelectStoryHookScreen(place: place ?? buildPlace()),
      ),
      GoRoute(
        name: 'player',
        path: '/player',
        builder: (_, __) => const Scaffold(
          key: Key('player-screen'),
          body: SizedBox.shrink(),
        ),
      ),
    ],
    overrides: _overrides(
      hookService: hookService,
      narrationService: narrationService,
      usageRepo: usageRepo,
      analytics: analytics,
    ),
  );
  await tester.pumpAndSettle();
}

List<Override> _overrides({
  _FakeStoryHookService? hookService,
  FakeNarrationService? narrationService,
  InMemoryUsageRepository? usageRepo,
  RecordingAnalyticsService? analytics,
}) {
  return [
    // 一律 override：畫面載入就會送 hooks_requested，不攔的話會摸到真的
    // FirebaseAnalytics.instance（測試環境沒有 Firebase，直接炸）。
    analyticsServiceProvider.overrideWithValue(
      analytics ?? RecordingAnalyticsService(),
    ),
    narrationServiceProvider.overrideWithValue(
      narrationService ?? FakeNarrationService(),
    ),
    storyHookServiceProvider.overrideWithValue(
      hookService ?? _FakeStoryHookService(hooks: const [_hook1]),
    ),
    journeyRepositoryProvider.overrideWithValue(InMemoryJourneyRepository()),
    usageRepositoryProvider.overrideWithValue(
      usageRepo ?? InMemoryUsageRepository(),
    ),
  ];
}

/// 1x1 transparent PNG bytes for Image.memory.
Uint8List _transparentPngBytes() {
  return Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ]);
}
