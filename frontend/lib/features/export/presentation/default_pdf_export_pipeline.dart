import 'dart:io';
import 'dart:typed_data';

import 'package:context_app/core/utils/share_position_origin.dart';
import 'package:context_app/features/export/domain/models/pdf_export_result.dart';
import 'package:context_app/features/export/domain/services/place_image_downloader.dart';
import 'package:context_app/features/export/domain/services/trip_pdf_export_service.dart';
import 'package:context_app/features/export/presentation/cover_renderer.dart';
import 'package:context_app/features/export/presentation/pdf_builder/trip_pdf_document_builder.dart';
import 'package:context_app/features/trip/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// Wires together the production dependencies for [TripPdfExportService]
/// and runs the export end-to-end.
///
/// Uses:
/// * `path_provider` for the temporary file location
/// * `printing` (Google Fonts) to load a CJK-capable font pair
/// * `share_plus` for the share sheet
Future<PdfExportResult> exportTripAsPdf({
  required WidgetRef ref,
  required BuildContext context,
  required String tripId,
  required TripPdfExportStrings strings,
}) async {
  final service = TripPdfExportService(
    tripRepository: ref.read(tripRepositoryProvider),
    fetchItems: (id) => ref.read(journeyItemsForTripProvider(id).future),
    imageDownloader: PlaceImageDownloader(placeholderBytes: Uint8List(0)),
    renderCover: (request) => renderPdfCoverOffscreen(
      context,
      request,
      stampLabel: strings.stampLabel,
      appName: strings.appName,
      tagline: strings.tagline,
      entryCountLabel: strings.entryCountLabel,
    ),
    loadFonts: () async => PdfFontPair(
      regular: await PdfGoogleFonts.notoSansTCRegular(),
      bold: await PdfGoogleFonts.notoSansTCBold(),
    ),
    buildDocument:
        ({
          required trip,
          required entries,
          required coverPngBytes,
          required fonts,
          required labels,
        }) => TripPdfDocumentBuilder(
          regularFont: fonts.regular,
          boldFont: fonts.bold,
          labels: labels,
        ).build(trip: trip, entries: entries, coverPngBytes: coverPngBytes),
    writeToTemp: _writeToTemp,
    // Resolved at share time rather than up front: the export runs for
    // seconds and the screen may have scrolled since it started.
    share: (filePath) => _sharePdf(
      filePath,
      context.mounted ? sharePositionOriginOf(context) : null,
    ),
  );

  return service.export(tripId: tripId, strings: strings);
}

Future<String> _writeToTemp(Uint8List bytes, String fileName) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);
  return file.path;
}

Future<void> _sharePdf(String filePath, Rect? sharePositionOrigin) async {
  await Share.shareXFiles([
    XFile(filePath, mimeType: 'application/pdf'),
  ], sharePositionOrigin: sharePositionOrigin);
}
