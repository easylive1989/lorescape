import 'package:context_app/shared/widgets/journal/journal_category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JournalCategory', () {
    test('nature maps to pine-green ink on soft-green bg', () {
      expect(JournalCategory.nature.ink, const Color(0xFF4E6138));
      expect(JournalCategory.nature.bg, const Color(0xFFE6E8D5));
      expect(JournalCategory.nature.label, '自然景觀');
    });

    test('every category has a non-placeholder icon and distinct bg', () {
      final bgs = JournalCategory.values.map((c) => c.bg.toARGB32()).toSet();
      expect(bgs.length, JournalCategory.values.length);
      for (final c in JournalCategory.values) {
        expect(c.icon, isA<IconData>());
        expect(c.label.isNotEmpty, isTrue);
      }
    });

    test('sacred maps to plum ink', () {
      expect(JournalCategory.sacred.ink, const Color(0xFF6E4A63));
      expect(JournalCategory.sacred.bg, const Color(0xFFECDCE6));
    });
  });
}
