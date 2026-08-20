import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:context_app/features/explore/domain/models/place.dart';
import 'package:context_app/features/narration/domain/models/grounding_info.dart';
import 'package:context_app/features/narration/domain/models/narration_content.dart';
import 'package:context_app/features/narration/presentation/screens/narration_screen.dart';
import 'package:context_app/features/narration/presentation/widgets/editorial_hero.dart';
import 'package:context_app/features/narration/presentation/widgets/narration_control_panel.dart';
import 'package:context_app/features/narration/presentation/widgets/narration_transcript_area.dart';
import 'package:context_app/features/narration/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fakes/fake_tts_service.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_data.dart';

void main() {
  setUpAll(() async {
    await initTestEnvironment();
  });

  group('NarrationScreen', () {
    testWidgets('given a place and narration content, when the screen loads, '
        'then the place name and transcript area are rendered', (tester) async {
      final place = buildPlace(name: 'Kinkaku-ji');
      final content = buildNarrationContent();

      await _givenNarrationScreen(tester, place: place, content: content);

      _thenPlaceNameIsVisible(place.name);
      _thenTranscriptAreaIsVisible();
      _thenControlPanelIsVisible();
    });

    testWidgets(
      'given narration grounded on web sources, when the reader renders, '
      'then the source footer closes the article instead of a floating button',
      (tester) async {
        await _givenNarrationScreen(
          tester,
          place: buildPlace(),
          content: buildNarrationContent(
            grounding: const GroundingInfo(
              renderedContent: null,
              webSearchQueries: ['kinkakuji history'],
              sources: [
                GroundingSource(uri: 'https://a.example', title: 'A'),
                GroundingSource(uri: 'https://b.example', title: 'B'),
              ],
            ),
          ),
        );
        await tester.scrollUntilVisible(
          find.text('narration.grounding_footer'),
          200,
          scrollable: find.byType(Scrollable).first,
        );

        expect(find.text('narration.grounding_footer'), findsOneWidget);
        expect(find.byIcon(Icons.info_outline), findsNothing);
      },
    );

    testWidgets('given narration without grounding, when the reader renders, '
        'then no source footer is shown', (tester) async {
      await _givenNarrationScreen(
        tester,
        place: buildPlace(),
        content: buildNarrationContent(),
      );

      expect(find.text('narration.grounding_footer'), findsNothing);
    });

    testWidgets(
      'given autoPlay is true, when the screen finishes initialising, '
      'then the TTS fake receives a speak command',
      (tester) async {
        final tts = FakeTtsService();
        final content = buildNarrationContent();

        await _givenNarrationScreen(
          tester,
          place: buildPlace(),
          content: content,
          autoPlay: true,
          tts: tts,
        );
        await _whenInitializationCompletes(tester);

        _thenTtsReceivedSpeakCommand(tts);
      },
    );

    testWidgets('given the player loads, when rendered, '
        'then the reading surface is warm paper, not night black', (
      tester,
    ) async {
      await _givenNarrationScreen(
        tester,
        place: buildPlace(name: 'Kinkaku-ji'),
        content: buildNarrationContent(),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      // Without the theme extension the reader falls back to the canonical
      // warm reading surface (paper), never the dark night chrome.
      expect(scaffold.backgroundColor, equals(LorescapeTokens.fallback.readBg));
      expect(scaffold.backgroundColor, isNot(LorescapeTokens.fallback.inkBg));
    });

    testWidgets(
      'given autoPlay is false, when the screen finishes initialising, '
      'then the TTS fake is not asked to speak',
      (tester) async {
        final tts = FakeTtsService();

        await _givenNarrationScreen(
          tester,
          place: buildPlace(),
          content: buildNarrationContent(),
          tts: tts,
        );
        await _whenInitializationCompletes(tester);

        _thenTtsDidNotSpeak(tts);
      },
    );

    testWidgets('given a story title, when the player loads, '
        'then the hero shows the story title plus the place name overline', (
      tester,
    ) async {
      await _givenNarrationScreen(
        tester,
        place: buildPlace(name: 'St Peters'),
        content: buildNarrationContent(),
        storyTitle: 'The Hundred-Year Gamble',
      );

      expect(find.byType(EditorialHeroBackground), findsOneWidget);
      expect(find.text('The Hundred-Year Gamble'), findsOneWidget);
      // Place name appears in the fixed top bar AND in the hero overline.
      expect(find.text('St Peters'), findsNWidgets(2));
    });

    testWidgets('given no story title, when the player loads, '
        'then the hero main title falls back to the place name', (
      tester,
    ) async {
      await _givenNarrationScreen(
        tester,
        place: buildPlace(name: 'St Peters'),
        content: buildNarrationContent(),
      );

      // Place name appears in the top bar AND as the hero main title.
      expect(find.text('St Peters'), findsNWidgets(2));
    });
  });
}

Future<void> _givenNarrationScreen(
  WidgetTester tester, {
  required Place place,
  required NarrationContent content,
  bool autoPlay = false,
  String? storyTitle,
  FakeTtsService? tts,
}) async {
  final resolvedTts = tts ?? FakeTtsService();
  await pumpScreen(
    tester,
    child: NarrationScreen(
      place: place,
      narrationContent: content,
      storyTitle: storyTitle,
      autoPlay: autoPlay,
    ),
    overrides: [ttsServiceProvider.overrideWithValue(resolvedTts)],
  );
  // Initial addPostFrameCallback schedules initializeWithContent.
  await tester.pump(const Duration(milliseconds: 10));
}

Future<void> _whenInitializationCompletes(WidgetTester tester) async {
  // initializeWithContent awaits initialize() and setLanguage() before
  // transitioning to the ready state.
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 20));
}

void _thenPlaceNameIsVisible(String name) {
  expect(find.text(name), findsAtLeastNWidgets(1));
}

void _thenTranscriptAreaIsVisible() {
  expect(find.byType(NarrationTranscriptArea), findsOneWidget);
}

void _thenControlPanelIsVisible() {
  expect(find.byType(NarrationControlPanel), findsOneWidget);
}

void _thenTtsReceivedSpeakCommand(FakeTtsService tts) {
  expect(tts.speakCount, greaterThanOrEqualTo(1));
}

void _thenTtsDidNotSpeak(FakeTtsService tts) {
  expect(tts.speakCount, equals(0));
}
