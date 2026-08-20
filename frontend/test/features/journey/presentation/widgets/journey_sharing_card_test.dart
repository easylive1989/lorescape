import 'dart:typed_data';

import 'package:context_app/features/journey/presentation/widgets/journey_sharing_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  setUpAll(() async {
    await initTestEnvironment();
  });

  group('JourneySharingCard', () {
    testWidgets('given no image, when the card is rendered, '
        'then the placeholder header, place name, address, narration, '
        'formatted date and footer copy are all visible', (tester) async {
      await _pumpCard(
        tester,
        placeName: 'Senso-ji Temple',
        placeAddress: '2-3-1 Asakusa, Taito',
        narrationExcerpt: 'A beloved Buddhist temple in Asakusa.',
        visitedAt: DateTime(2026, 4, 20),
      );

      expect(find.text('Senso-ji Temple'), findsOneWidget);
      expect(find.text('2-3-1 Asakusa, Taito'), findsOneWidget);
      expect(
        find.text('A beloved Buddhist temple in Asakusa.'),
        findsOneWidget,
      );
      expect(find.text('2026.04.20'), findsOneWidget);
      expect(find.text('已訪'), findsOneWidget);
      expect(find.text('App'), findsOneWidget);
      expect(find.text('Go'), findsOneWidget);
      expect(find.text('更多'), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);
    });

    testWidgets('given an empty place address, when the card is rendered, '
        'then the address row is omitted', (tester) async {
      await _pumpCard(
        tester,
        placeName: 'Mystery Spot',
        placeAddress: '',
        narrationExcerpt: 'No address given.',
        visitedAt: DateTime(2026, 1, 5),
      );

      expect(find.text('Mystery Spot'), findsOneWidget);
      expect(find.byIcon(Icons.location_on_outlined), findsNothing);
    });

    testWidgets('given imageBytes are provided, when the card is rendered, '
        'then an Image.memory header replaces the placeholder', (tester) async {
      final bytes = _transparentPngBytes();

      await _pumpCard(
        tester,
        placeName: 'Meiji Shrine',
        placeAddress: 'Shibuya',
        narrationExcerpt: 'Shinto shrine surrounded by forest.',
        visitedAt: DateTime(2026, 3, 1),
        imageBytes: bytes,
      );

      final memoryImages = find.byWidgetPredicate(
        (w) => w is Image && w.image is MemoryImage,
      );
      expect(memoryImages, findsOneWidget);
      expect(find.byIcon(Icons.image_not_supported), findsNothing);
    });

    testWidgets('given only an imageUrl, when the card is rendered, '
        'then the placeholder header is not used', (tester) async {
      await _pumpCard(
        tester,
        placeName: 'Kinkaku-ji',
        placeAddress: 'Kyoto',
        narrationExcerpt: 'Golden Pavilion.',
        visitedAt: DateTime(2026, 2, 14),
        imageUrl: 'https://example.com/image.jpg',
      );

      // Placeholder uses a decorative explore icon with very low alpha —
      // absence means the real-image branch ran instead.
      expect(find.byIcon(Icons.explore), findsOneWidget); // footer only
    });

    testWidgets('given a long narration excerpt, when the card is rendered, '
        'then the excerpt is truncated to five lines with ellipsis', (
      tester,
    ) async {
      final longText = List.filled(20, 'lorem ipsum dolor sit amet').join(' ');

      await _pumpCard(
        tester,
        placeName: 'Long Narration',
        placeAddress: 'Anywhere',
        narrationExcerpt: longText,
        visitedAt: DateTime(2026, 1, 1),
      );

      final excerpt = tester.widget<Text>(find.text(longText));
      expect(excerpt.maxLines, 5);
      expect(excerpt.overflow, TextOverflow.ellipsis);
    });
  });
}

/// Short translations keep the fixed-width card's footer from overflowing
/// so layout assertions can focus on what each test cares about.
class _ShortTranslationsLoader extends AssetLoader {
  const _ShortTranslationsLoader();

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async =>
      const <String, dynamic>{
        'share_card': {'visited': '已訪', 'explore_more': '更多'},
        'app': {'name': 'App', 'tagline': 'Go'},
      };
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required String placeName,
  required String placeAddress,
  required String narrationExcerpt,
  required DateTime visitedAt,
  String? imageUrl,
  Uint8List? imageBytes,
}) async {
  const locale = Locale('zh', 'TW');
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [locale, Locale('en')],
      path: 'assets/translations',
      fallbackLocale: locale,
      startLocale: locale,
      assetLoader: const _ShortTranslationsLoader(),
      useOnlyLangCode: false,
      child: ProviderScope(
        child: Builder(
          builder: (context) => MaterialApp(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            home: Material(
              color: Colors.transparent,
              child: Center(
                child: JourneySharingCard(
                  placeName: placeName,
                  placeAddress: placeAddress,
                  narrationExcerpt: narrationExcerpt,
                  visitedAt: visitedAt,
                  imageUrl: imageUrl,
                  imageBytes: imageBytes,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 3; i += 1) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

/// 1x1 transparent PNG — minimal valid bytes to feed Image.memory.
Uint8List _transparentPngBytes() {
  return Uint8List.fromList(const [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0x00,
    0x01,
    0x00,
    0x00,
    0x05,
    0x00,
    0x01,
    0x0D,
    0x0A,
    0x2D,
    0xB4,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ]);
}
