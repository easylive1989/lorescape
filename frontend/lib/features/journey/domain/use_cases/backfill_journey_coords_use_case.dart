import 'package:context_app/features/journey/domain/models/journey_entry.dart';
import 'package:context_app/features/journey/domain/repositories/journey_repository.dart';
import 'package:context_app/features/journey/domain/services/place_coords_resolver.dart';
import 'package:logging/logging.dart';

/// 把舊記錄缺的地點座標補回來，讓書架頁的地球儀釘得出停點。
///
/// `place_lat` / `place_lng` 是 2026-08-19 才加的欄位（migration
/// 20260819000000 明文不回填），寫入端也是同一天才進 App，所以在那之前存下
/// 來的記錄座標全是 null，`shelfGlobePinsProvider` 會整批跳過——地球儀因此一
/// 個點都沒有。
///
/// 記錄的 `place.id` 是探索頁存下來的 `wikidata:Q…`，所以座標救得回來：拿
/// Q-id 查 P625 就好。伺服器端補不了（sync 是選用的，沒開同步的使用者資料只
/// 存在裝置本機的 Hive），所以回填只能在 App 裡做。
class BackfillJourneyCoordsUseCase {
  BackfillJourneyCoordsUseCase({
    required JourneyRepository repository,
    required PlaceCoordsResolver resolver,
  }) : _repository = repository,
       _resolver = resolver;

  static final _log = Logger('BackfillJourneyCoordsUseCase');

  static const String _wikidataPrefix = 'wikidata:';

  final JourneyRepository _repository;
  final PlaceCoordsResolver _resolver;

  /// 回傳實際補上座標的筆數。沒有待補的記錄時不打任何網路。
  Future<int> call() async {
    final entries = await _repository.getAll();

    final targets = <JourneyEntry, String>{};
    for (final entry in entries) {
      if (entry.place.latitude != null && entry.place.longitude != null) {
        continue;
      }
      final qid = _qidOf(entry.place.id);
      // 2026-04-25 之前的記錄存的是 Google Places id，查不了 Wikidata；
      // 那些就維持沒座標，地球儀上不會有它們。
      if (qid != null) targets[entry] = qid;
    }
    if (targets.isEmpty) return 0;

    final coords = await _resolver.resolve(targets.values.toSet());
    if (coords.isEmpty) return 0;

    var filled = 0;
    for (final MapEntry(key: entry, value: qid) in targets.entries) {
      final location = coords[qid];
      if (location == null) continue;
      try {
        await _repository.save(entry.copyWithCoordinates(location));
        filled++;
      } catch (e, stack) {
        // 單筆寫失敗不該讓整批停下來——下次開 App 會再補一次。
        _log.warning('Failed to backfill coords for ${entry.id}', e, stack);
      }
    }
    return filled;
  }

  static String? _qidOf(String placeId) {
    if (!placeId.startsWith(_wikidataPrefix)) return null;
    final qid = placeId.substring(_wikidataPrefix.length);
    return qid.startsWith('Q') ? qid : null;
  }
}
