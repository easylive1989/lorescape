import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:context_app/features/splash/presentation/mountain_painter.dart';

void main() {
  group('buildMountainPath', () {
    test('落在 size 範圍內、且非空', () {
      const size = Size(200, 200);
      final path = buildMountainPath(size);
      final b = path.getBounds();
      expect(path.computeMetrics().isNotEmpty, isTrue);
      expect(b.left, greaterThanOrEqualTo(0));
      expect(b.top, greaterThanOrEqualTo(0));
      expect(b.right, lessThanOrEqualTo(size.width));
      expect(b.bottom, lessThanOrEqualTo(size.height));
    });

    test('隨 size 等比縮放', () {
      final small = buildMountainPath(const Size(100, 100)).getBounds();
      final big = buildMountainPath(const Size(200, 200)).getBounds();
      expect(big.width, closeTo(small.width * 2, 0.01));
    });
  });

  group('buildFootprints', () {
    test('回傳 6 段、都在 size 內', () {
      const size = Size(200, 200);
      final prints = buildFootprints(size);
      expect(prints.length, 6);
      for (final r in prints) {
        expect(r.left, greaterThanOrEqualTo(0));
        expect(r.right, lessThanOrEqualTo(size.width));
        expect(r.top, greaterThanOrEqualTo(0));
        expect(r.bottom, lessThanOrEqualTo(size.height));
      }
    });
  });

  group('MountainPainter.shouldRepaint', () {
    test('進度改變時要重繪', () {
      const c = Color(0xFFF7F1E6);
      const a = MountainPainter(strokeProgress: 0.2, footprintProgress: 0, color: c);
      const b = MountainPainter(strokeProgress: 0.5, footprintProgress: 0, color: c);
      expect(b.shouldRepaint(a), isTrue);
    });
    test('完全相同時不重繪', () {
      const c = Color(0xFFF7F1E6);
      const a = MountainPainter(strokeProgress: 0.5, footprintProgress: 0.3, color: c);
      const b = MountainPainter(strokeProgress: 0.5, footprintProgress: 0.3, color: c);
      expect(b.shouldRepaint(a), isFalse);
    });
  });
}
