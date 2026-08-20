import 'package:context_app/shared/widgets/midnight/pill_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('PillIconButton', () {
    testWidgets('renders icon', (tester) async {
      await tester.pumpWidget(
        host(PillIconButton(icon: Icons.add, onPressed: () {})),
      );
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('invokes onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(PillIconButton(icon: Icons.add, onPressed: () => taps++)),
      );
      await tester.tap(find.byIcon(Icons.add));
      expect(taps, 1);
    });

    testWidgets('disabled when onPressed is null', (tester) async {
      await tester.pumpWidget(
        host(const PillIconButton(icon: Icons.add, onPressed: null)),
      );
      await tester.tap(find.byIcon(Icons.add));
    });

    testWidgets('shows tooltip when provided', (tester) async {
      await tester.pumpWidget(
        host(PillIconButton(icon: Icons.add, tooltip: 'Add', onPressed: () {})),
      );
      expect(find.byTooltip('Add'), findsOneWidget);
    });

    testWidgets('uses CircleBorder shape', (tester) async {
      await tester.pumpWidget(
        host(PillIconButton(icon: Icons.add, onPressed: () {})),
      );
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(PillIconButton),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.shape, isA<CircleBorder>());
    });

    testWidgets('ghost variant renders', (tester) async {
      await tester.pumpWidget(
        host(
          PillIconButton(
            icon: Icons.favorite,
            variant: PillIconButtonVariant.ghost,
            onPressed: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });
  });
}
