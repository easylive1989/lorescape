import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Global test harness setup applied to every test under `test/`.
///
/// The theme layer builds [TextStyle]s via `google_fonts`, which lazily
/// loads font files. The hermetic test sandbox has no network access, so a
/// real fetch would fail and surface as an unhandled async error that fails
/// otherwise-passing logic tests.
///
/// To stay hermetic we disable runtime fetching and serve a real font
/// from a stubbed asset bundle: `google_fonts` finds the family in an
/// enriched asset manifest (real app assets + injected Noto font entries)
/// and loads the bundled Roboto TTF as a stand-in. All other asset
/// requests (images, real fonts) are forwarded to the real platform
/// delegate unchanged.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final fontBytes = _loadBundledRobotoBytes();
  if (fontBytes != null) {
    final messenger = TestWidgetsFlutterBinding.instance.defaultBinaryMessenger;

    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(
        message!.buffer.asUint8List(
          message.offsetInBytes,
          message.lengthInBytes,
        ),
      );

      // Serve stub TTF bytes for any Noto font variant request.
      if (key.endsWith('.ttf') && _isNotoFontKey(key)) {
        return ByteData.view(fontBytes.buffer);
      }

      // For the asset manifest, merge real assets with injected font entries
      // so both widget tests (need real images) and google_fonts (needs font
      // entries) work correctly.
      if (key == 'AssetManifest.bin') {
        final realManifest = await messenger.delegate.send(
          'flutter/assets',
          message,
        );
        return _mergeManifestWithFonts(realManifest);
      }

      // All other assets (images, other fonts) → real platform.
      return messenger.delegate.send('flutter/assets', message);
    });
  }

  await testMain();
}

/// Returns true when the asset key is for a Noto font family variant
/// that google_fonts might request.
bool _isNotoFontKey(String key) {
  return key.contains('NotoSerifTC') || key.contains('NotoSansTC');
}

/// Merges [realManifestData] (from the platform) with injected Noto font
/// entries so the combined manifest satisfies both the app's widget tests
/// and google_fonts' asset lookup.
ByteData _mergeManifestWithFonts(ByteData? realManifestData) {
  Map<Object?, Object?> existing = {};
  if (realManifestData != null) {
    try {
      final decoded = const StandardMessageCodec().decodeMessage(
        realManifestData,
      );
      if (decoded is Map) {
        existing = decoded as Map<Object?, Object?>;
      }
    } catch (_) {
      // Ignore parse errors; start from an empty manifest.
    }
  }

  const families = ['NotoSerifTC', 'NotoSansTC'];
  const variants = ['Regular', 'Medium', 'SemiBold', 'Bold'];
  final merged = Map<Object, Object>.from(existing.cast<Object, Object>());
  for (final family in families) {
    for (final variant in variants) {
      final assetKey = 'fonts/$family-$variant.ttf';
      merged[assetKey] = <Object>[
        <String, Object>{'asset': assetKey},
      ];
    }
  }

  return const StandardMessageCodec().encodeMessage(merged)!;
}

/// Reads the Roboto TTF shipped with the active Flutter SDK, if available.
///
/// Walks up from the running test executable to the SDK `cache` directory
/// and locates the bundled material fonts, so the lookup is independent of
/// the exact Flutter version path.
Uint8List? _loadBundledRobotoBytes() {
  try {
    Directory? dir = File(Platform.resolvedExecutable).parent;
    while (dir != null && dir.path != dir.parent.path) {
      final font = File(
        '${dir.path}/artifacts/material_fonts/Roboto-Regular.ttf',
      );
      if (font.existsSync()) {
        return font.readAsBytesSync();
      }
      dir = dir.parent;
    }
    return null;
  } catch (_) {
    return null;
  }
}
