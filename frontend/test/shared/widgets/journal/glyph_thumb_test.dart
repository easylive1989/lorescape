import 'package:context_app/shared/widgets/journal/glyph_thumb.dart';
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

  group('GlyphThumb', () {
    testWidgets('fills with the category background and shows its glyph', (
      tester,
    ) async {
      await pump(
        tester,
        const GlyphThumb(category: JournalCategory.coast, size: 64),
      );

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('glyph-thumb-surface')),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, JournalCategory.coast.bg);

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, JournalCategory.coast.icon);
      expect(icon.color, JournalCategory.coast.ink);
    });
  });
}
