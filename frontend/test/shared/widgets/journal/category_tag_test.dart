import 'package:context_app/shared/widgets/journal/category_tag.dart';
import 'package:context_app/shared/widgets/journal/journal_category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  group('CategoryTag', () {
    testWidgets('shows the category label and icon', (tester) async {
      await pump(tester, const CategoryTag(category: JournalCategory.nature));

      expect(find.text('自然景觀'), findsOneWidget);
      expect(find.byIcon(Icons.terrain_outlined), findsOneWidget);
    });

    testWidgets('uses the category background colour by default', (
      tester,
    ) async {
      await pump(tester, const CategoryTag(category: JournalCategory.urban));

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('category-tag-surface')),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, JournalCategory.urban.bg);
    });

    testWidgets('onPhoto variant uses a dark translucent surface', (
      tester,
    ) async {
      await pump(
        tester,
        const CategoryTag(category: JournalCategory.urban, onPhoto: true),
      );

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('category-tag-surface')),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, const Color(0x80141008));
    });
  });
}
