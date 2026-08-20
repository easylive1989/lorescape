import 'package:context_app/features/narration/domain/models/grounding_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GroundingInfo.fromRaw', () {
    test('returns null when every field is empty', () {
      expect(GroundingInfo.fromRaw(), isNull);
      expect(GroundingInfo.fromRaw(renderedContent: ''), isNull);
    });

    test('keeps rendered content, queries, and sources', () {
      final info = GroundingInfo.fromRaw(
        renderedContent: '<div>chip</div>',
        webSearchQueries: const ['taipei 101 history'],
        sources: const [
          GroundingSource(uri: 'https://example.com/a', title: 'A'),
        ],
      );

      expect(info, isNotNull);
      expect(info!.renderedContent, '<div>chip</div>');
      expect(info.webSearchQueries, ['taipei 101 history']);
      expect(info.sources.single.uri, 'https://example.com/a');
      expect(info.hasGrounding, isTrue);
    });

    test('is still non-null when only sources exist', () {
      final info = GroundingInfo.fromRaw(
        sources: const [
          GroundingSource(uri: 'https://example.com', title: 'example.com'),
        ],
      );
      expect(info, isNotNull);
      expect(info!.renderedContent, isNull);
    });
  });
}
