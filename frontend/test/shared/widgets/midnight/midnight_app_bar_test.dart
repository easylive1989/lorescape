import 'package:context_app/shared/widgets/midnight/midnight_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MidnightAppBar', () {
    testWidgets('renders title uppercased when uppercaseTitle is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(appBar: MidnightAppBar(title: Text('explore'))),
        ),
      );
      expect(find.text('EXPLORE'), findsOneWidget);
    });

    testWidgets('preserves casing when uppercaseTitle is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: MidnightAppBar(
              title: Text('Explore'),
              uppercaseTitle: false,
            ),
          ),
        ),
      );
      expect(find.text('Explore'), findsOneWidget);
    });

    testWidgets('renders leading and actions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: MidnightAppBar(
              title: Text('Title'),
              leading: Icon(Icons.menu),
              actions: [Icon(Icons.search)],
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('preferredSize is kToolbarHeight', (tester) async {
      const bar = MidnightAppBar(title: Text('x'));
      expect(bar.preferredSize.height, kToolbarHeight);
    });
  });
}
