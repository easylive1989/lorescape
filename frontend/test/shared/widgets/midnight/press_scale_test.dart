import 'package:context_app/shared/widgets/midnight/_press_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PressScale', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PressScale(child: Text('hello'))),
      );
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('invokes onTap when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PressScale(
              onTap: () => taps++,
              child: const SizedBox(width: 100, height: 50, child: Text('tap')),
            ),
          ),
        ),
      );
      await tester.tap(find.text('tap'));
      expect(taps, 1);
    });

    testWidgets('does not invoke onTap when null (disabled)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PressScale(
              onTap: null,
              child: SizedBox(width: 100, height: 50, child: Text('tap')),
            ),
          ),
        ),
      );
      await tester.tap(find.text('tap'));
      // No exception, no callback expected.
    });

    testWidgets('animates scale on press', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PressScale(
              onTap: () {},
              child: const SizedBox(width: 100, height: 50, child: Text('tap')),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('tap')),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final scaleWidget = tester.widget<AnimatedScale>(
        find.byType(AnimatedScale),
      );
      expect(scaleWidget.scale, lessThan(1.0));

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });
}
