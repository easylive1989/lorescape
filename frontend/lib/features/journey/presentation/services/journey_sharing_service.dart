import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:context_app/features/journey/presentation/widgets/journey_sharing_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

final _log = Logger('JourneySharingService');

/// Captures a [JourneySharingCard] as a PNG image and shares it
/// via the platform share sheet.
class JourneySharingService {
  JourneySharingService._();

  /// Shares a journey entry as a beautifully designed card image.
  ///
  /// Renders the [JourneySharingCard] off-screen, captures it to a
  /// PNG, writes it to a temp file, and opens the system share sheet.
  static Future<void> shareJourneyCard({
    required BuildContext context,
    required String placeName,
    required String placeAddress,
    required String narrationExcerpt,
    required DateTime visitedAt,
    String? imageUrl,
    Uint8List? imageBytes,
    VoidCallback? onSheetPresented,
    Rect? sharePositionOrigin,
  }) async {
    try {
      final pngBytes = await _captureCardImage(
        context: context,
        placeName: placeName,
        placeAddress: placeAddress,
        narrationExcerpt: narrationExcerpt,
        visitedAt: visitedAt,
        imageUrl: imageUrl,
        imageBytes: imageBytes,
      );

      if (pngBytes == null) {
        _log.warning('Failed to capture card image');
        onSheetPresented?.call();
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/journey_card_$timestamp.png');
      await file.writeAsBytes(pngBytes);

      final shareText = '${'share_card.share_text'.tr()} — $placeName';

      onSheetPresented?.call();
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: shareText,
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e, stack) {
      _log.severe('Error sharing journey card', e, stack);
      onSheetPresented?.call();
    }
  }

  /// Renders the card widget off-screen and captures it as PNG bytes.
  static Future<Uint8List?> _captureCardImage({
    required BuildContext context,
    required String placeName,
    required String placeAddress,
    required String narrationExcerpt,
    required DateTime visitedAt,
    String? imageUrl,
    Uint8List? imageBytes,
  }) async {
    final key = GlobalKey();

    final widget = RepaintBoundary(
      key: key,
      child: MediaQuery(
        data: MediaQuery.of(context),
        child: Directionality(
          textDirection: ui.TextDirection.ltr,
          child: Localizations.override(
            context: context,
            child: Material(
              color: Colors.transparent,
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
    );

    // Build the widget in an overlay so it renders off-screen.
    final overlay = OverlayEntry(
      builder: (_) => Positioned(left: -1000, top: -1000, child: widget),
    );

    final overlayState = Overlay.of(context);
    overlayState.insert(overlay);

    // Wait for the widget tree and any image loading to settle.
    await Future<void>.delayed(const Duration(milliseconds: 500));

    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } finally {
      overlay.remove();
    }
  }
}
