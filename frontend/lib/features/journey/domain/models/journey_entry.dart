import 'package:context_app/features/explore/domain/models/place.dart';
import 'package:context_app/features/journey/domain/models/saved_place.dart';
import 'package:context_app/features/narration/domain/models/narration_content.dart';
import 'package:context_app/features/narration/domain/models/story_hook.dart';
import 'package:context_app/features/settings/domain/models/language.dart';

class JourneyEntry {
  final String id;
  final SavedPlace place;
  final NarrationContent narrationContent;

  /// 使用者挑選的故事鉤子；舊資料或無鉤子流程下為 null。
  final StoryHook? storyHook;

  final DateTime createdAt;
  final DateTime updatedAt;
  final Language language;

  /// 所屬旅程的 id，`null` 代表尚未歸類（會顯示在「未分類」）。
  final String? tripId;

  const JourneyEntry({
    required this.id,
    required this.place,
    required this.narrationContent,
    required this.createdAt,
    required this.updatedAt,
    required this.language,
    this.storyHook,
    this.tripId,
  });

  /// 建立新的旅程記錄
  ///
  /// [id] 由呼叫端產生（例如 UUID），domain 層不負責 ID 生成策略。
  /// [tripId] 若提供則表示條目歸屬於該 Trip。
  factory JourneyEntry.create({
    required String id,
    required Place place,
    required NarrationContent content,
    required Language language,
    StoryHook? hook,
    String? tripId,
  }) {
    final String? imageUrl = place.primaryPhoto?.url;

    final savedPlace = SavedPlace(
      id: place.id,
      name: place.name,
      address: place.address,
      imageUrl: imageUrl,
      latitude: place.location.latitude,
      longitude: place.location.longitude,
    );

    final now = DateTime.now();
    return JourneyEntry(
      id: id,
      place: savedPlace,
      narrationContent: content,
      storyHook: hook,
      createdAt: now,
      updatedAt: now,
      language: language,
      tripId: tripId,
    );
  }

  /// 回傳套用了新 [tripId] 後的副本（`null` 代表移回未分類）。
  JourneyEntry copyWithTripId(String? tripId) => JourneyEntry(
    id: id,
    place: place,
    narrationContent: narrationContent,
    storyHook: storyHook,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
    language: language,
    tripId: tripId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'place_id': place.id,
    'place_name': place.name,
    'place_address': place.address,
    'place_image_url': place.imageUrl,
    'place_lat': place.latitude,
    'place_lng': place.longitude,
    'narration_text': narrationContent.text,
    if (storyHook != null) 'story_hook': storyHook!.toJson(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'language': language.code,
    'trip_id': tripId,
  };

  factory JourneyEntry.fromJson(Map<String, dynamic> json) {
    final languageStr = json['language'] as String? ?? 'zh-TW';
    final language = Language(languageStr);

    final place = SavedPlace(
      id: json['place_id'] as String,
      name: json['place_name'] as String,
      address: json['place_address'] as String,
      imageUrl: json['place_image_url'] as String?,
      latitude: (json['place_lat'] as num?)?.toDouble(),
      longitude: (json['place_lng'] as num?)?.toDouble(),
    );

    final narrationContent = NarrationContent.create(
      json['narration_text'] as String,
      language: language,
    );

    StoryHook? hook;
    final hookJson = json['story_hook'];
    if (hookJson is Map) {
      hook = StoryHook.fromJson(hookJson.cast<String, dynamic>());
    }

    final createdAt = DateTime.parse(json['created_at'] as String);
    final updatedAtRaw = json['updated_at'] as String?;
    final updatedAt = updatedAtRaw != null
        ? DateTime.parse(updatedAtRaw)
        : createdAt;

    return JourneyEntry(
      id: json['id'] as String,
      place: place,
      narrationContent: narrationContent,
      storyHook: hook,
      createdAt: createdAt,
      updatedAt: updatedAt,
      language: language,
      tripId: json['trip_id'] as String?,
    );
  }
}
