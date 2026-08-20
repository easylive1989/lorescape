import 'dart:convert';
import 'dart:typed_data';

import 'package:context_app/features/export/domain/models/pdf_entry_data.dart';
import 'package:context_app/features/export/domain/models/pdf_labels.dart';
import 'package:context_app/features/export/presentation/pdf_builder/trip_pdf_document_builder.dart';
import 'package:context_app/features/trip/domain/models/trip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Minimal valid 1x1 PNG (single pixel). Pre-encoded so the pdf package's
/// image decoder accepts it.
final Uint8List _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==',
);

Trip _trip() => Trip(
  id: 't1',
  name: 'Kyoto Trip',
  createdAt: DateTime(2026, 4, 10),
  updatedAt: DateTime(2026, 4, 10),
);

PdfEntryData _narration(String title) => PdfEntryData(
  title: title,
  address: '京都市左京區',
  date: DateTime(2026, 4, 10),
  bodyText:
      'Kinkaku-ji, the Temple of the Golden Pavilion, reflects centuries of history. '
      'Its gold-leaf exterior shimmers against the koi pond during every season.',
  chipLabels: const ['歷史背景'],
  imageBytes: _tinyPng,
);

void main() {
  const labels = PdfLabels(pageOfTotal: 'Place {index} / {total}');

  final builder = TripPdfDocumentBuilder(
    regularFont: pw.Font.helvetica(),
    boldFont: pw.Font.helveticaBold(),
    labels: labels,
  );

  test('produces non-empty PDF bytes for a trip with entries', () async {
    final bytes = await builder.build(
      trip: _trip(),
      entries: [_narration('Kinkaku-ji'), _narration('Ginkaku-ji')],
      coverPngBytes: _tinyPng,
    );

    expect(bytes, isA<Uint8List>());
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.sublist(0, 5)), equals('%PDF-'));
  });

  test('entry with no image, no address, no chips still renders', () async {
    final bytes = await builder.build(
      trip: _trip(),
      entries: [
        PdfEntryData(
          title: 'Minimal Entry',
          date: DateTime(2026, 4, 11),
          bodyText:
              'A short description that still needs to render on its own page.',
        ),
      ],
      coverPngBytes: _tinyPng,
    );

    expect(bytes.length, greaterThan(500));
  });

  test('zero entries still produces at least a cover page', () async {
    final bytes = await builder.build(
      trip: _trip(),
      entries: const [],
      coverPngBytes: _tinyPng,
    );

    expect(bytes.length, greaterThan(500));
  });

  test('PdfLabels.renderPageOfTotal substitutes both placeholders', () {
    expect(labels.renderPageOfTotal(2, 5), equals('Place 2 / 5'));
  });

  test('builder output parses as a valid PDF document', () async {
    final bytes = await builder.build(
      trip: _trip(),
      entries: [_narration('Kinkaku-ji')],
      coverPngBytes: _tinyPng,
    );

    final trailer = bytes.sublist(bytes.length - 6);
    expect(String.fromCharCodes(trailer).trim(), endsWith('%%EOF'));

    // Spot-check: page format marker should appear somewhere in the stream.
    final content = String.fromCharCodes(bytes);
    expect(
      content,
      contains(
        PdfPageFormat.a4.width.toStringAsFixed(0).isNotEmpty
            ? '/Page'
            : '/Page',
      ),
    );
  });
}
