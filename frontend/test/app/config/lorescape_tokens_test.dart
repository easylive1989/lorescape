import 'package:context_app/app/config/appearance_options.dart';
import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LorescapeTokens.forAppearance', () {
    test('terracotta accent resolves clay family', () {
      final t = LorescapeTokens.forAppearance(
        accent: BrandAccent.terracotta,
        reading: ReadingSurface.paper,
      );
      expect(t.clay, const Color(0xFFBC5E3E));
      expect(t.clayDeep, const Color(0xFF97442A));
      expect(t.paper, const Color(0xFFF7F1E6));
    });

    test('sage accent swaps the clay family', () {
      final t = LorescapeTokens.forAppearance(
        accent: BrandAccent.sage,
        reading: ReadingSurface.paper,
      );
      expect(t.clay, const Color(0xFF5F7148));
    });

    test('night reading surface swaps read fields and keeps accent cap', () {
      final t = LorescapeTokens.forAppearance(
        accent: BrandAccent.terracotta,
        reading: ReadingSurface.night,
      );
      expect(t.readBg, const Color(0xFF1B1611));
      expect(t.readInk, const Color(0xFFE9E1D2));
      expect(t.readCap, const Color(0xFF97442A));
    });

    test('lerp at t=0 returns the start values', () {
      final a = LorescapeTokens.forAppearance(
        accent: BrandAccent.terracotta,
        reading: ReadingSurface.paper,
      );
      final b = LorescapeTokens.forAppearance(
        accent: BrandAccent.sage,
        reading: ReadingSurface.paper,
      );
      final mid = a.lerp(b, 0);
      expect(mid.clay, a.clay);
    });

    test('lerp at t=1 returns the end values', () {
      final a = LorescapeTokens.forAppearance(
        accent: BrandAccent.terracotta,
        reading: ReadingSurface.paper,
      );
      final b = LorescapeTokens.forAppearance(
        accent: BrandAccent.sage,
        reading: ReadingSurface.night,
      );
      final end = a.lerp(b, 1);
      expect(end.clay, b.clay);
      expect(end.readBg, b.readBg);
    });

    test('is retrievable from a ThemeData that registers it', () {
      final tokens = LorescapeTokens.forAppearance(
        accent: BrandAccent.amber,
        reading: ReadingSurface.paper,
      );
      final theme = ThemeData(extensions: [tokens]);
      expect(theme.extension<LorescapeTokens>()!.clay, const Color(0xFFB7842B));
    });
  });
}
