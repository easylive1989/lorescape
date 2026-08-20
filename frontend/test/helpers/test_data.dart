import 'package:context_app/features/explore/domain/models/place.dart';
import 'package:context_app/features/explore/domain/models/place_category.dart';
import 'package:context_app/features/explore/domain/models/place_location.dart';
import 'package:context_app/features/explore/domain/models/place_photo.dart';
import 'package:context_app/features/journey/domain/models/journey_entry.dart';
import 'package:context_app/features/journey/domain/models/saved_place.dart';
import 'package:context_app/features/narration/domain/models/grounding_info.dart';
import 'package:context_app/features/narration/domain/models/narration_content.dart';
import 'package:context_app/features/narration/domain/models/story_hook.dart';
import 'package:context_app/features/settings/domain/models/language.dart';
import 'package:context_app/features/trip/domain/models/trip.dart';

/// Builds a [Place] with sensible defaults. Override any field as needed.
Place buildPlace({
  String id = 'place-1',
  String name = 'Test Place',
  String address = '123 Test Street',
  double latitude = 25.0,
  double longitude = 121.0,
  PlaceCategory category = PlaceCategory.modernUrban,
  List<PlacePhoto> photos = const [],
  List<String> tags = const [],
}) {
  return Place(
    id: id,
    name: name,
    address: address,
    location: PlaceLocation(latitude: latitude, longitude: longitude),
    tags: tags,
    photos: photos,
    category: category,
  );
}

/// Builds a [Trip] with sensible defaults.
Trip buildTrip({
  String id = 'trip-1',
  String name = 'Kyoto Adventure',
  DateTime? startDate,
  DateTime? endDate,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final resolvedCreatedAt = createdAt ?? DateTime(2024, 1, 1);
  return Trip(
    id: id,
    name: name,
    startDate: startDate,
    endDate: endDate,
    createdAt: resolvedCreatedAt,
    updatedAt: updatedAt ?? resolvedCreatedAt,
  );
}

/// Builds a [NarrationContent] from a raw text body.
NarrationContent buildNarrationContent({
  String text =
      'This is a sample narration body. It has multiple sentences! '
      'The third line rounds it off.',
  Language language = Language.english,
  GroundingInfo? grounding,
}) {
  return NarrationContent.create(
    text,
    language: language,
    grounding: grounding,
  );
}

/// Builds a [StoryHook] with sensible defaults.
StoryHook buildStoryHook({
  String id = 'hook-1',
  String title = 'A test story',
  String teaser = 'Something interesting happened here...',
}) {
  return StoryHook(id: id, title: title, teaser: teaser);
}

/// Builds a [JourneyEntry] with a deterministic [createdAt].
JourneyEntry buildJourneyEntry({
  String id = 'journey-1',
  Place? place,
  NarrationContent? content,
  StoryHook? hook,
  DateTime? createdAt,
  DateTime? updatedAt,
  Language language = Language.english,
  String? tripId,
}) {
  final resolvedPlace = place ?? buildPlace();
  final resolvedContent = content ?? buildNarrationContent();
  final resolvedCreatedAt = createdAt ?? DateTime(2024, 1, 2, 10);
  return JourneyEntry(
    id: id,
    place: SavedPlace(
      id: resolvedPlace.id,
      name: resolvedPlace.name,
      address: resolvedPlace.address,
      imageUrl: resolvedPlace.primaryPhoto?.url,
    ),
    narrationContent: resolvedContent,
    storyHook: hook,
    createdAt: resolvedCreatedAt,
    updatedAt: updatedAt ?? resolvedCreatedAt,
    language: language,
    tripId: tripId,
  );
}
