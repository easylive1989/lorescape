import 'dart:convert';
import 'dart:typed_data';

import 'package:context_app/features/export/domain/models/pdf_export_result.dart';
import 'package:context_app/features/export/domain/models/pdf_labels.dart';
import 'package:context_app/features/export/domain/services/place_image_downloader.dart';
import 'package:context_app/features/export/domain/services/trip_pdf_export_service.dart';
import 'package:context_app/features/export/presentation/pdf_builder/trip_pdf_document_builder.dart';
import 'package:context_app/features/journey/domain/models/journey_entry.dart';
import 'package:context_app/features/journey/domain/models/journey_item.dart';
import 'package:context_app/features/journey/domain/models/saved_place.dart';
import 'package:context_app/features/narration/domain/models/narration_content.dart';
import 'package:context_app/features/narration/domain/models/story_hook.dart';
import 'package:context_app/features/settings/domain/models/language.dart';
import 'package:context_app/features/trip/domain/models/trip.dart';
import 'package:context_app/features/trip/domain/repositories/trip_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pdf/widgets.dart' as pw;

class _MockTripRepo extends Mock implements TripRepository {}

final Uint8List _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==',
);

Trip _trip({
  String id = 't1',
  String name = 'Kyoto Getaway',
  DateTime? createdAt,
}) {
  final resolved = createdAt ?? DateTime(2026, 4, 10);
  return Trip(id: id, name: name, createdAt: resolved, updatedAt: resolved);
}

JourneyItem _narrationItem({
  String id = 'j1',
  String placeName = 'Kinkaku-ji',
  String? imageUrl = 'https://example.com/a.jpg',
  DateTime? createdAt,
}) {
  return NarrationJourneyItem(
    JourneyEntry(
      id: id,
      place: SavedPlace(
        id: 'p1',
        name: placeName,
        address: '京都市',
        imageUrl: imageUrl,
      ),
      narrationContent: NarrationContent.create(
        'A long enough body of narration for testing.',
        language: const Language('zh-TW'),
      ),
      storyHook: const StoryHook(
        id: 'hook-1',
        title: 'Test hook',
        teaser: 'Something happened here...',
      ),
      createdAt: createdAt ?? DateTime(2026, 4, 10, 12),
      updatedAt: createdAt ?? DateTime(2026, 4, 10, 12),
      language: const Language('zh-TW'),
      tripId: 't1',
    ),
  );
}

TripPdfExportStrings _strings() => const TripPdfExportStrings(
  stampLabel: 'VISITED',
  appName: 'Context',
  tagline: 'Explore instantly',
  entryCountLabel: '{count} places',
  pdfLabels: PdfLabels(pageOfTotal: 'Place {index} / {total}'),
);

void main() {
  late _MockTripRepo tripRepo;
  late PlaceImageDownloader downloader;
  Uint8List capturedPdfBytes = Uint8List(0);
  String? capturedFileName;
  String? sharedPath;

  TripPdfExportService build({
    required Future<List<JourneyItem>> Function(String) fetchItems,
    MockClient? httpClient,
  }) {
    downloader = PlaceImageDownloader(
      placeholderBytes: _tinyPng,
      client:
          httpClient ??
          MockClient((_) async => http.Response.bytes(_tinyPng, 200)),
    );
    return TripPdfExportService(
      tripRepository: tripRepo,
      fetchItems: fetchItems,
      imageDownloader: downloader,
      renderCover: (_) async => _tinyPng,
      loadFonts: () async => PdfFontPair(
        regular: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
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
      writeToTemp: (bytes, fileName) async {
        capturedPdfBytes = bytes;
        capturedFileName = fileName;
        return '/tmp/$fileName';
      },
      share: (path) async {
        sharedPath = path;
      },
    );
  }

  setUp(() {
    tripRepo = _MockTripRepo();
    capturedPdfBytes = Uint8List(0);
    capturedFileName = null;
    sharedPath = null;
  });

  test('exports a trip with one narration entry and shares the file', () async {
    when(() => tripRepo.getById('t1')).thenAnswer((_) async => _trip());
    final service = build(fetchItems: (_) async => [_narrationItem()]);

    final result = await service.export(tripId: 't1', strings: _strings());

    expect(result.filePath, equals('/tmp/Kyoto Getaway.pdf'));
    expect(capturedFileName, equals('Kyoto Getaway.pdf'));
    expect(sharedPath, equals('/tmp/Kyoto Getaway.pdf'));
    expect(capturedPdfBytes.length, greaterThan(1000));
    expect(result.missingImagePlaceNames, isEmpty);
  });

  test('records missing images when download fails', () async {
    when(() => tripRepo.getById('t1')).thenAnswer((_) async => _trip());
    final failingClient = MockClient(
      (_) async => http.Response.bytes(const [], 500),
    );
    final service = build(
      fetchItems: (_) async => [_narrationItem(placeName: 'Failed Place')],
      httpClient: failingClient,
    );

    final result = await service.export(tripId: 't1', strings: _strings());

    expect(result.missingImagePlaceNames, equals(['Failed Place']));
    expect(result.hasMissingImages, isTrue);
  });

  test('throws EmptyTripExportException when trip has no items', () async {
    when(() => tripRepo.getById('t1')).thenAnswer((_) async => _trip());
    final service = build(fetchItems: (_) async => []);

    await expectLater(
      service.export(tripId: 't1', strings: _strings()),
      throwsA(isA<EmptyTripExportException>()),
    );
    expect(sharedPath, isNull);
  });

  test('throws ArgumentError when trip id cannot be resolved', () async {
    when(() => tripRepo.getById('missing')).thenAnswer((_) async => null);
    final service = build(fetchItems: (_) async => []);

    await expectLater(
      service.export(tripId: 'missing', strings: _strings()),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('uses fallback file name when trip name is empty', () async {
    when(
      () => tripRepo.getById('t1'),
    ).thenAnswer((_) async => _trip(name: '   '));
    final service = build(fetchItems: (_) async => [_narrationItem()]);

    await service.export(tripId: 't1', strings: _strings());

    expect(capturedFileName, equals('journey_2026-04-10.pdf'));
  });

  test('sanitizes reserved characters in file name', () async {
    when(
      () => tripRepo.getById('t1'),
    ).thenAnswer((_) async => _trip(name: 'Trip/2026:best?'));
    final service = build(fetchItems: (_) async => [_narrationItem()]);

    await service.export(tripId: 't1', strings: _strings());

    expect(capturedFileName, equals('Trip_2026_best_.pdf'));
  });
}
