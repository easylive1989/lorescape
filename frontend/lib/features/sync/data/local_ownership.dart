/// 本機資料的擁有者標記。
///
/// Hive 的兩個 box（journey_entries / trips）是整台裝置共用一份、不依帳號分
/// 割的。沒有這個標記的話，A 登出、B 登入之後 `fullSync` 會把 A 留在本機的
/// 記錄推進 B 的帳號——那是寫入層級的污染，事後只能手動去 DB 清。
///
/// 標記存在 Hive 的 JSON envelope 裡，不進 domain model，也不會上傳：
/// remote data source 自己組 row（`_toRow`），不是用 `toJson()`。
library;

/// envelope 裡放擁有者 id 的欄位名。
const String ownerIdKey = 'owner_id';

/// 這筆本機資料的擁有者。`null` 代表「無主」——既有資料與未登入期間存下來
/// 的都落在這裡，登入時會被認領（見 [claimUnownedIn]）。
String? ownerIdOf(Map<String, dynamic> json) => json[ownerIdKey] as String?;

/// 目前這個帳號看不看得到這筆資料。
///
/// 無主的大家都看得到；有主的只有本人看得到。未登入時（[currentUserId] 為
/// null）看不到任何有主的資料——包含自己登入時存的，那些要重新登入才會回
/// 來。這是刻意的：登出之後就不該再從畫面上讀得到那個帳號的內容。
bool isVisibleTo(String? ownerId, String? currentUserId) =>
    ownerId == null || ownerId == currentUserId;

/// 把 envelope 蓋上擁有者。`userId` 為 null（未登入）時不寫欄位，維持無主。
Map<String, dynamic> withOwner(Map<String, dynamic> json, String? userId) => {
  ...json,
  if (userId != null) ownerIdKey: userId,
};

/// 本機儲存中與「擁有者」有關的維護動作。
///
/// 跟 domain 的 repository 介面分開：這些是儲存層自己的事，
/// journey / trip 的 domain 不需要知道裝置上還躺著誰的資料。
abstract class LocalOwnershipStore {
  /// 把所有無主資料認領給 [userId]，回傳認領的筆數。
  Future<int> claimUnowned(String userId);

  /// 清掉這台裝置上的全部本機資料（不分擁有者）。共用裝置用。
  Future<void> clearAll();
}
