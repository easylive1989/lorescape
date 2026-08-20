import 'package:context_app/shared/widgets/midnight/glass_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GlassCard', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: GlassCard(child: Text('content'))),
        ),
      );
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('contains a BackdropFilter', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: GlassCard(child: SizedBox.shrink())),
        ),
      );
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('triggers onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassCard(
              onTap: () => taps++,
              child: const SizedBox(
                width: 200,
                height: 100,
                child: Text('tap'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('tap'));
      expect(taps, 1);
    });

    testWidgets('does not crash without onTap', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassCard(
              child: SizedBox(width: 200, height: 100, child: Text('tap')),
            ),
          ),
        ),
      );
      await tester.tap(find.text('tap'));
    });
  });
}
