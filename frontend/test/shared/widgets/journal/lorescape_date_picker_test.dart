import 'package:context_app/shared/widgets/journal/lorescape_date_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

void main() {
  setUpAll(() async {
    await initTestEnvironment();
  });

  group('showLorescapeDatePicker', () {
    testWidgets('given the sheet is open, when a day is tapped and confirmed, '
        'then it resolves with that date', (tester) async {
      DateTime? result;
      await _pumpHost(
        tester,
        onOpen: (context) async {
          result = await showLorescapeDatePicker(
            context: context,
            initialDate: DateTime(2026, 5, 15),
            firstDate: DateTime(2026, 5, 1),
            lastDate: DateTime(2026, 5, 31),
          );
        },
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('date_picker.title'), findsOneWidget);

      await tester.tap(find.text('20'));
      await tester.pump();
      await tester.tap(find.text('date_picker.confirm'));
      await tester.pumpAndSettle();

      expect(result, equals(DateTime(2026, 5, 20)));
    });

    testWidgets(
      'given the sheet is open, when cancelled, then it resolves with null',
      (tester) async {
        DateTime? result = DateTime(2000);
        var didReturn = false;
        await _pumpHost(
          tester,
          onOpen: (context) async {
            result = await showLorescapeDatePicker(
              context: context,
              initialDate: DateTime(2026, 5, 15),
              firstDate: DateTime(2026, 5, 1),
              lastDate: DateTime(2026, 5, 31),
            );
            didReturn = true;
          },
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('date_picker.cancel'));
        await tester.pumpAndSettle();

        expect(didReturn, isTrue);
        expect(result, isNull);
      },
    );

    testWidgets('given the previous-month nav, when tapped, '
        'then the grid moves to the previous month', (tester) async {
      await _pumpHost(
        tester,
        onOpen: (context) async {
          await showLorescapeDatePicker(
            context: context,
            initialDate: DateTime(2026, 5, 15),
            firstDate: DateTime(2026, 1, 1),
            lastDate: DateTime(2026, 12, 31),
          );
        },
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // May has 31 days, April has 30 — tapping prev then '31' should
      // find nothing if we are on April (regression guard on month shift).
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      expect(find.text('31'), findsNothing);
      expect(find.text('30'), findsOneWidget);
    });
  });
}

Future<void> _pumpHost(
  WidgetTester tester, {
  required Future<void> Function(BuildContext) onOpen,
}) async {
  await pumpScreen(
    tester,
    child: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => onOpen(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}
