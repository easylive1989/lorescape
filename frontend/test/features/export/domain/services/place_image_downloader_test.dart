import 'dart:typed_data';

import 'package:context_app/features/export/domain/services/place_image_downloader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final Uint8List _placeholder = Uint8List.fromList([0xAA, 0xBB, 0xCC]);
final Uint8List _realImage = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);

void main() {
  group('PlaceImageDownloader', () {
    test('returns image bytes on 200', () async {
      final mockClient = MockClient((req) async {
        return http.Response.bytes(_realImage, 200);
      });
      final downloader = PlaceImageDownloader(
        placeholderBytes: _placeholder,
        client: mockClient,
      );

      final result = await downloader.download('https://example.com/a.jpg');

      expect(result.bytes, equals(_realImage));
      expect(result.usedPlaceholder, isFalse);
    });

    test('returns placeholder on 404', () async {
      final mockClient = MockClient(
        (_) async => http.Response.bytes(const [], 404),
      );
      final downloader = PlaceImageDownloader(
        placeholderBytes: _placeholder,
        client: mockClient,
      );

      final result = await downloader.download('https://example.com/a.jpg');

      expect(result.bytes, equals(_placeholder));
      expect(result.usedPlaceholder, isTrue);
    });

    test('returns placeholder on timeout', () async {
      final mockClient = MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response.bytes(_realImage, 200);
      });
      final downloader = PlaceImageDownloader(
        placeholderBytes: _placeholder,
        client: mockClient,
        timeout: const Duration(milliseconds: 50),
      );

      final result = await downloader.download('https://example.com/a.jpg');

      expect(result.usedPlaceholder, isTrue);
      expect(result.bytes, equals(_placeholder));
    });

    test('returns placeholder on ClientException', () async {
      final mockClient = MockClient((_) async {
        throw http.ClientException('boom');
      });
      final downloader = PlaceImageDownloader(
        placeholderBytes: _placeholder,
        client: mockClient,
      );

      final result = await downloader.download('https://example.com/a.jpg');

      expect(result.usedPlaceholder, isTrue);
    });

    test(
      'returns placeholder for null or empty url without hitting client',
      () async {
        var called = false;
        final mockClient = MockClient((_) async {
          called = true;
          return http.Response.bytes(const [], 200);
        });
        final downloader = PlaceImageDownloader(
          placeholderBytes: _placeholder,
          client: mockClient,
        );

        final nullResult = await downloader.download(null);
        final emptyResult = await downloader.download('');

        expect(nullResult.usedPlaceholder, isTrue);
        expect(emptyResult.usedPlaceholder, isTrue);
        expect(called, isFalse);
      },
    );

    test('returns placeholder when body is empty even on 200', () async {
      final mockClient = MockClient(
        (_) async => http.Response.bytes(const [], 200),
      );
      final downloader = PlaceImageDownloader(
        placeholderBytes: _placeholder,
        client: mockClient,
      );

      final result = await downloader.download('https://example.com/a.jpg');

      expect(result.usedPlaceholder, isTrue);
    });
  });
}
