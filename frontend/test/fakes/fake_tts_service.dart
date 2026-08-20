import 'dart:async';

import 'package:context_app/features/narration/domain/services/tts_service.dart';
import 'package:context_app/features/settings/domain/models/language.dart';

/// Fake [TtsService] that records calls and exposes controllable event streams.
class FakeTtsService implements TtsService {
  final StreamController<TtsProgress> _progress =
      StreamController<TtsProgress>.broadcast();
  final StreamController<void> _complete = StreamController<void>.broadcast();
  final StreamController<void> _start = StreamController<void>.broadcast();
  final StreamController<void> _pause = StreamController<void>.broadcast();
  final StreamController<String> _error = StreamController<String>.broadcast();

  bool initialized = false;
  String? lastSpokenText;
  Language? lastLanguage;
  int speakCount = 0;
  int pauseCount = 0;
  int stopCount = 0;

  @override
  Stream<TtsProgress> get onProgress => _progress.stream;

  @override
  Stream<void> get onComplete => _complete.stream;

  @override
  Stream<void> get onStart => _start.stream;

  @override
  Stream<void> get onPause => _pause.stream;

  @override
  Stream<String> get onError => _error.stream;

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<bool> speak(String text) async {
    lastSpokenText = text;
    speakCount += 1;
    _start.add(null);
    return true;
  }

  @override
  Future<void> pause() async {
    pauseCount += 1;
    _pause.add(null);
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
  }

  @override
  Future<void> setLanguage(Language language) async {
    lastLanguage = language;
  }

  @override
  Future<void> setRate(double rate) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setPitch(double pitch) async {}

  @override
  Future<void> dispose() async {
    await _progress.close();
    await _complete.close();
    await _start.close();
    await _pause.close();
    await _error.close();
  }

  /// Simulates TTS reaching the end of the current text.
  void emitComplete() => _complete.add(null);

  /// Simulates a TTS error.
  void emitError(String message) => _error.add(message);
}
