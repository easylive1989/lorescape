import 'dart:async';

import 'package:context_app/features/explore/domain/models/place.dart';
import 'package:context_app/features/narration/domain/models/story_hook.dart';
import 'package:context_app/features/narration/domain/services/narration_service.dart';
import 'package:context_app/features/settings/domain/models/language.dart';

/// Fake [NarrationService] that returns a seeded text result.
class FakeNarrationService implements NarrationService {
  final String text;
  final Exception? error;

  /// 設定後 [generateNarration] 會停在 pending 直到 gate 完成——用來在
  /// 測試裡觀察「生成中」的畫面。
  Completer<void>? gate;

  Place? lastPlace;
  StoryHook? lastHook;
  Language? lastLanguage;

  FakeNarrationService({
    this.text =
        'This is a fake narration used for widget tests. '
        'It contains multiple sentences. How are you? Great!',
    this.error,
  });

  @override
  Future<NarrationGenerationResult> generateNarration({
    required Place place,
    required Language language,
    StoryHook? hook,
  }) async {
    lastPlace = place;
    lastHook = hook;
    lastLanguage = language;
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return (text: text, grounding: null);
  }
}
