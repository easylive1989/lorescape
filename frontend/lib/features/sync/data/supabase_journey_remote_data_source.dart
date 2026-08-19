import 'package:context_app/features/journey/domain/models/journey_entry.dart';
import 'package:context_app/features/journey/domain/models/saved_place.dart';
import 'package:context_app/features/narration/domain/models/narration_content.dart';
import 'package:context_app/features/narration/domain/models/story_hook.dart';
import 'package:context_app/features/settings/domain/models/language.dart';
import 'package:context_app/features/sync/domain/services/remote_sync_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseJourneyRemoteDataSource
    implements RemoteSyncDataSource<JourneyEntry> {
  SupabaseJourneyRemoteDataSource(this._client);

  static const _table = 'journey_entries';
  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('SupabaseJourneyRemoteDataSource called without auth');
    }
    return id;
  }

  @override
  Future<List<JourneyEntry>> fetchAll() async {
    final rows = await _client.from(_table).select().eq('user_id', _userId);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> upsert(JourneyEntry item) async {
    await _client.from(_table).upsert(_toRow(item));
  }

  @override
  Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('user_id', _userId).eq('id', id);
  }

  Map<String, dynamic> _toRow(JourneyEntry entry) => {
    'id': entry.id,
    'user_id': _userId,
    'place_id': entry.place.id,
    'place_name': entry.place.name,
    'place_address': entry.place.address,
    'place_image_url': entry.place.imageUrl,
    'place_lat': entry.place.latitude,
    'place_lng': entry.place.longitude,
    'narration_text': entry.narrationContent.text,
    'story_hook': entry.storyHook?.toJson(),
    'language': entry.language.code,
    'trip_id': entry.tripId,
    'created_at': entry.createdAt.toIso8601String(),
    'updated_at': entry.updatedAt.toIso8601String(),
  };

  static JourneyEntry _fromRow(Map<String, dynamic> row) {
    final language = Language(row['language'] as String? ?? 'zh-TW');

    StoryHook? hook;
    final hookRaw = row['story_hook'];
    if (hookRaw is Map) {
      hook = StoryHook.fromJson(hookRaw.cast<String, dynamic>());
    }

    final createdAt = DateTime.parse(row['created_at'] as String);
    final updatedAt = row['updated_at'] != null
        ? DateTime.parse(row['updated_at'] as String)
        : createdAt;

    return JourneyEntry(
      id: row['id'] as String,
      place: SavedPlace(
        id: row['place_id'] as String,
        name: row['place_name'] as String,
        address: row['place_address'] as String,
        imageUrl: row['place_image_url'] as String?,
        latitude: (row['place_lat'] as num?)?.toDouble(),
        longitude: (row['place_lng'] as num?)?.toDouble(),
      ),
      narrationContent: NarrationContent.create(
        row['narration_text'] as String,
        language: language,
      ),
      storyHook: hook,
      createdAt: createdAt,
      updatedAt: updatedAt,
      language: language,
      tripId: row['trip_id'] as String?,
    );
  }
}
