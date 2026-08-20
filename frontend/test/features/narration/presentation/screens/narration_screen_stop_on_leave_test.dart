import 'package:context_app/features/explore/domain/models/place.dart';
import 'package:context_app/features/narration/domain/models/narration_content.dart';
import 'package:context_app/features/narration/presentation/screens/narration_screen.dart';
import 'package:context_app/features/narration/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fakes/fake_tts_service.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_data.dart';

/// Keeps [playerControllerProvider] alive for the whole test, mirroring the
/// app-wide `NarrationAnalyticsObserver` which `ref.listen`s the player for
/// its entire lifetime. With a permanent listener present the provider never
/// auto-disposes, so leaving the screen must stop TTS explicitly.
class _KeepPlayerAlive extends ConsumerWidget {
  const _KeepPlayerAlive();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(playerControllerProvider);
    return const SizedBox.shrink();
  }
}

class _Host extends StatefulWidget {
  const _Host({required this.place, required this.content});
  final Place place;
  final NarrationContent content;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool _showScreen = true;

  void leaveScreen() => setState(() => _showScreen = false);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _KeepPlayerAlive(),
        if (_showScreen)
          Expanded(
            child: NarrationScreen(
              place: widget.place,
              narrationContent: widget.content,
              autoPlay: true,
            ),
          ),
      ],
    );
  }
}

void main() {
  setUpAll(() async {
    await initTestEnvironment();
  });

  testWidgets('given playback started and the player provider is kept alive, '
      'when the narration screen is left (disposed), '
      'then TTS is stopped', (tester) async {
    final tts = FakeTtsService();
    await pumpScreen(
      tester,
      child: _Host(place: buildPlace(), content: buildNarrationContent()),
      overrides: [ttsServiceProvider.overrideWithValue(tts)],
    );
    // Let initializeWithContent() + autoPlay reach speak().
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));
    expect(tts.speakCount, greaterThanOrEqualTo(1));

    // Leave the screen.
    tester.state<_HostState>(find.byType(_Host)).leaveScreen();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(tts.stopCount, greaterThanOrEqualTo(1));
  });
}
