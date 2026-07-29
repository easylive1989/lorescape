import 'package:context_app/features/daily_story/domain/models/daily_story.dart';
import 'package:context_app/features/daily_story/domain/repositories/daily_story_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseDailyStoryRepository implements DailyStoryRepository {
  final SupabaseClient _client;

  SupabaseDailyStoryRepository(this._client);

  static const _table = 'daily_stories';
  // Pull the daily_story_places row alongside each story so the App can
  // render card spine / footer fields without a second round-trip.
  // `!left` so we still get the story row even if the place join is empty.
  // ignore: lines_longer_than_80_chars
  static const _select =
      '*, daily_story_places!left(card_location_en, card_city_ch, card_city_en, wikidata_id, latitude, longitude)';

  @override
  Future<DailyStory?> fetchLatest({required String language}) async {
    final rows = await _client
        .from(_table)
        .select(_select)
        .eq('language', language)
        .order('publish_date', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return rowToStory(rows.first);
  }

  @override
  Future<List<DailyStory>> fetchHistory({
    required String language,
    required DateTime before,
    int limit = 30,
  }) async {
    final rows = await _client
        .from(_table)
        .select(_select)
        .eq('language', language)
        .lt('publish_date', _isoDate(before))
        .order('publish_date', ascending: false)
        .limit(limit);
    return rows.map(rowToStory).toList();
  }

  @override
  Future<DailyStory?> fetchByDate({
    required String language,
    required DateTime date,
  }) async {
    final rows = await _client
        .from(_table)
        .select(_select)
        .eq('language', language)
        .eq('publish_date', _isoDate(date))
        .limit(1);
    if (rows.isEmpty) return null;
    return rowToStory(rows.first);
  }

  /// Public for testability. Parses a single row (possibly with the
  /// `daily_story_places` join expanded) into a [DailyStory].
  static DailyStory rowToStory(Map<String, dynamic> row) {
    final place = row['daily_story_places'] as Map<String, dynamic>?;
    final paragraphsRaw = row['card_paragraphs'];
    return DailyStory(
      publishDate: DateTime.parse(row['publish_date'] as String),
      language: row['language'] as String,
      placeName: row['place_name'] as String,
      placeLocation: row['place_location'] as String,
      era: row['era'] as String,
      story: row['story'] as String,
      imageUrl: row['image_url'] as String?,
      imageAttribution: row['image_attribution'] as String?,
      wikipediaUrl: row['wikipedia_url'] as String,
      cardTitle: row['card_title'] as String?,
      cardTitleSub: row['card_title_sub'] as String?,
      cardParagraphs: paragraphsRaw == null
          ? null
          : (paragraphsRaw as List).cast<String>(),
      cardPullQuote: row['card_pull_quote'] as String?,
      cardPullQuoteAttrib: row['card_pull_quote_attrib'] as String?,
      cardAnnoRoman: row['card_anno_roman'] as String?,
      cardLocationEn: place?['card_location_en'] as String?,
      cardCityCh: place?['card_city_ch'] as String?,
      cardCityEn: place?['card_city_en'] as String?,
      wikidataId: place?['wikidata_id'] as String?,
      latitude: (place?['latitude'] as num?)?.toDouble(),
      longitude: (place?['longitude'] as num?)?.toDouble(),
    );
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
