import 'package:context_app/features/journey/domain/globe/world_outline.dart';
import 'package:context_app/features/journey/domain/models/globe_pin.dart';
import 'package:context_app/features/journey/domain/models/journey_entry.dart';
import 'package:context_app/features/journey/domain/models/journey_item.dart';
import 'package:context_app/features/journey/data/services/wikidata_place_coords_service.dart';
import 'package:context_app/features/journey/domain/repositories/journey_repository.dart';
import 'package:context_app/features/journey/domain/services/place_coords_resolver.dart';
import 'package:context_app/features/journey/domain/use_cases/backfill_journey_coords_use_case.dart';
import 'package:context_app/features/sync/providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

// Feature 公開介面：trip 詳情頁重用的時間軸元件與手記分享。
export 'presentation/services/journey_sharing_service.dart';
export 'presentation/widgets/timeline_entry.dart';

final journeyRepositoryProvider = Provider<JourneyRepository>((ref) {
  return ref.watch(syncingJourneyRepositoryProvider);
});

final myJourneyProvider = FutureProvider.autoDispose<List<JourneyEntry>>((ref) {
  return ref.watch(journeyRepositoryProvider).getAll();
});

/// Combined provider returning all journey items sorted newest first.
final allJourneyItemsProvider = FutureProvider.autoDispose<List<JourneyItem>>((
  ref,
) async {
  final narrationEntries = await ref.watch(journeyRepositoryProvider).getAll();

  final items = <JourneyItem>[...narrationEntries.map(NarrationJourneyItem.new)]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  return items;
});

/// 舊記錄的座標回填。書架頁進來時跑一次（provider 不是 autoDispose，所以
/// 一個 App 生命週期只跑一次），補完才 invalidate 記錄清單讓地球儀重畫。
///
/// 補不到（離線、WDQS 掛了）就回 0，畫面維持現狀，下次開 App 再試。
final journeyCoordsBackfillProvider = FutureProvider<int>((ref) async {
  final filled = await BackfillJourneyCoordsUseCase(
    repository: ref.read(journeyRepositoryProvider),
    resolver: ref.read(placeCoordsResolverProvider),
  )();
  if (filled > 0) ref.invalidate(myJourneyProvider);
  return filled;
});

final placeCoordsResolverProvider = Provider<PlaceCoordsResolver>(
  (ref) => WikidataPlaceCoordsService(),
);

/// 地球儀的世界輪廓。只解析一次，書架頁共用。
final worldOutlineProvider = FutureProvider<WorldOutline>(
  (ref) => WorldOutline.load(rootBundle),
);

/// 某本旅程的停點，只取有座標的記錄。`tripId` 為 `null` 代表未分類那本。
///
/// 舊記錄沒存座標（見 20260819000000 migration），那些就不釘——補 (0,0)
/// 會在幾內亞灣外海長出一排根本沒去過的點。
///
/// 跟著 [myJourneyProvider] 一起 autoDispose：非 autoDispose 的 provider 會把
/// 它 watch 的 autoDispose provider 一路釘活，等於讓記錄快取在整個 App 生命
/// 週期裡再也不會失效、sync 完也不重取。
final tripGlobePinsProvider = Provider.autoDispose
    .family<List<GlobePin>, String?>((ref, tripId) {
      final entries = ref.watch(myJourneyProvider).valueOrNull ?? const [];
      return [
        for (final entry in entries)
          if (entry.tripId == tripId)
            if (entry.place.latitude case final lat?)
              if (entry.place.longitude case final lng?)
                GlobePin(
                  id: entry.id,
                  coordinate: LatLng(lat, lng),
                  label: entry.place.name,
                ),
      ];
    });
