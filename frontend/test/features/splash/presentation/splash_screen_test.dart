import 'package:context_app/features/splash/presentation/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

GoRouter _testRouter() => GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/', builder: (_, __) => const Text('HOME')),
      ],
    );

void main() {
  testWidgets('播放約 2.4s 後導向 /（顯示 HOME）', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _testRouter()));
    // 一開始在 splash，不是 HOME。
    expect(find.text('HOME'), findsNothing);
    // 推進超過動畫時長。
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('動畫未播完就離開，不丟例外', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _testRouter()));
    await tester.pump(const Duration(milliseconds: 300));
    // 換掉整棵樹（模擬提前 dispose）。
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 2000));
    expect(tester.takeException(), isNull);
  });
}
