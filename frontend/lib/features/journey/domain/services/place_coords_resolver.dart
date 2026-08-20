import 'package:context_app/features/explore/domain/models/place_location.dart';

/// 依 Wikidata Q-id 反查地點座標。
///
/// 只有回填舊記錄會用到：探索頁存記錄時座標本來就跟著 [PlaceLocation] 一起
/// 寫進去，不需要再查一次。
abstract class PlaceCoordsResolver {
  /// 回傳 `qid -> 座標`。查不到座標的 qid 不會出現在結果裡（而不是給 null
  /// 值），呼叫端據此判斷「這個地點補不了」。
  ///
  /// 整批查不到（例如離線）時回傳空 map，不丟例外——回填是加分功能，失敗只
  /// 代表地球儀少幾個點，不該讓畫面壞掉。
  Future<Map<String, PlaceLocation>> resolve(Set<String> qids);
}
