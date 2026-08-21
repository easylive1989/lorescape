// 播放頁的返回鍵回上一頁，而不是一律回首頁——從旅程手記按重聽進來的要回到
// 那本旅程。堆疊裡沒有上一頁（深連結直接開播放頁）時才退回首頁。

import 'package:context_app/features/narration/presentation/screens/narration_screen.dart';
import 'package:context_app/features/narration/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../fakes/fake_tts_service.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_data.dart';

Widget _player() => NarrationScreen(
  place: buildPlace(name: 'Kinkaku-ji'),
  narrationContent: buildNarrationContent(),
);

List<RouteBase> _routes() => [
  GoRoute(
    path: '/',
    builder: (context, state) => const Scaffold(body: Text('home')),
  ),
  GoRoute(
    path: '/trip/t1',
    builder: (context, state) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => context.push('/player'),
          child: const Text('replay'),
        ),
      ),
    ),
  ),
  GoRoute(path: '/player', builder: (context, state) => _player()),
];

Future<void> _pump(WidgetTester tester, {required String at}) async {
  await pumpRouterApp(
    tester,
    routes: _routes(),
    initialLocation: at,
    overrides: [ttsServiceProvider.overrideWithValue(FakeTtsService())],
  );
  await tester.pump(const Duration(milliseconds: 10));
}

Future<void> _tapBack(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initTestEnvironment);

  group('NarrationScreen back button', () {
    testWidgets('given the player was pushed from a trip, when the user taps '
        'back, then they land back on that trip, not on the home screen', (
      tester,
    ) async {
      await _pump(tester, at: '/trip/t1');
      await tester.tap(find.text('replay'));
      await tester.pumpAndSettle();
      expect(find.byType(NarrationScreen), findsOneWidget);

      await _tapBack(tester);

      expect(find.text('replay'), findsOneWidget);
      expect(find.text('home'), findsNothing);
    });

    testWidgets('given the player is the only route on the stack, when the '
        'user taps back, then they land on the home screen', (tester) async {
      await _pump(tester, at: '/player');

      await _tapBack(tester);

      expect(find.text('home'), findsOneWidget);
    });
  });
}
