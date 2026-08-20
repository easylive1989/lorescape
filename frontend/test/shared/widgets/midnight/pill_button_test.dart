import 'package:context_app/shared/widgets/midnight/pill_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('PillButton', () {
    testWidgets('renders label', (tester) async {
      await tester.pumpWidget(
        host(PillButton(label: 'Action', onPressed: () {})),
      );
      expect(find.text('Action'), findsOneWidget);
    });

    testWidgets('invokes onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(PillButton(label: 'Action', onPressed: () => taps++)),
      );
      await tester.tap(find.text('Action'));
      expect(taps, 1);
    });

    testWidgets('disabled when onPressed is null', (tester) async {
      await tester.pumpWidget(
        host(const PillButton(label: 'Action', onPressed: null)),
      );
      await tester.tap(find.text('Action'));
      // No callback registered, no exception.
    });

    testWidgets('renders leading icon', (tester) async {
      await tester.pumpWidget(
        host(PillButton(label: 'Save', icon: Icons.save, onPressed: () {})),
      );
      expect(find.byIcon(Icons.save), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('uses StadiumBorder shape', (tester) async {
      await tester.pumpWidget(
        host(PillButton(label: 'Action', onPressed: () {})),
      );
      final button = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(PillButton),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(button.shape, isA<StadiumBorder>());
    });

    testWidgets('secondary variant renders', (tester) async {
      await tester.pumpWidget(
        host(
          PillButton(
            label: 'Action',
            variant: PillButtonVariant.secondary,
            onPressed: () {},
          ),
        ),
      );
      expect(find.text('Action'), findsOneWidget);
    });

    testWidgets('ghost variant renders', (tester) async {
      await tester.pumpWidget(
        host(
          PillButton(
            label: 'Action',
            variant: PillButtonVariant.ghost,
            onPressed: () {},
          ),
        ),
      );
      expect(find.text('Action'), findsOneWidget);
    });
  });
}
