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

/// 書架上每一本書一個釘點：那本旅程**最早**、而且有座標的那個故事的地點。
///
/// 不是「選中那本書的所有停點」——地球儀在這裡的角色是整個書架的鳥瞰，一本
/// 書一個點，選中哪本就把地球轉過去（見 [globePinIdForTrip]）。
///
/// 「最早」用 createdAt 判斷，也就是那趟旅程的起點。最早那筆沒有座標時往後
/// 找下一筆有座標的——否則整本書只因為第一個故事缺座標就從地球上消失。
///
/// 跟著 [myJourneyProvider] 一起 autoDispose：非 autoDispose 的 provider 會把
/// 它 watch 的 autoDispose provider 一路釘活，等於讓記錄快取在整個 App 生命
/// 週期裡再也不會失效、sync 完也不重取。
final shelfGlobePinsProvider = Provider.autoDispose<List<GlobePin>>((ref) {
  final entries = ref.watch(myJourneyProvider).valueOrNull ?? const [];

  final firstByTrip = <String?, JourneyEntry>{};
  for (final entry in entries) {
    if (entry.place.latitude == null || entry.place.longitude == null) continue;
    final current = firstByTrip[entry.tripId];
    if (current == null || entry.createdAt.isBefore(current.createdAt)) {
      firstByTrip[entry.tripId] = entry;
    }
  }

  final firsts = firstByTrip.entries.toList()
    ..sort((a, b) => a.value.createdAt.compareTo(b.value.createdAt));
  return [
    for (final MapEntry(key: tripId, value: entry) in firsts)
      GlobePin(
        id: globePinIdForTrip(tripId),
        coordinate: LatLng(entry.place.latitude!, entry.place.longitude!),
        label: entry.place.name,
      ),
  ];
});

/// 釘點 id ↔ 旅程 id 的對應。未分類那本的 tripId 是 null，得換一個不會跟真
/// 實 id 相撞的字串，點釘點才回得去正確的那本書。
const String unassignedGlobePinId = '__unassigned__';

String globePinIdForTrip(String? tripId) => tripId ?? unassignedGlobePinId;

String? tripIdForGlobePin(String pinId) =>
    pinId == unassignedGlobePinId ? null : pinId;
