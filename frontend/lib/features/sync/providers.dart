import 'package:context_app/features/auth/providers.dart';
import 'package:context_app/features/journey/domain/models/journey_entry.dart';
import 'package:context_app/features/journey/domain/repositories/journey_repository.dart';
import 'package:context_app/features/sync/data/hive_journey_repository.dart';
import 'package:context_app/features/sync/data/local_ownership.dart';
import 'package:context_app/features/sync/data/hive_trip_repository.dart';
import 'package:context_app/features/sync/data/supabase_journey_remote_data_source.dart';
import 'package:context_app/features/sync/data/supabase_trip_remote_data_source.dart';
import 'package:context_app/features/sync/data/syncing_journey_repository.dart';
import 'package:context_app/features/sync/data/syncing_trip_repository.dart';
import 'package:context_app/features/sync/domain/services/remote_sync_data_source.dart';
import 'package:context_app/features/sync/domain/services/sync_coordinator.dart';
import 'package:context_app/features/sync/domain/services/sync_engine.dart';
import 'package:context_app/features/sync/domain/services/sync_session.dart';
import 'package:context_app/features/trip/domain/models/trip.dart';
import 'package:context_app/features/trip/domain/repositories/trip_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Sync session.
// ---------------------------------------------------------------------------

/// 目前這台裝置能不能同步。
///
/// 有正式帳號就同步，沒有就完全不上傳——**沒有開關**，登入本身就是那個開關。
///
/// 匿名帳號（App 啟動時 main.dart 的 _ensureSignedIn 建的那個）刻意排除：它的
/// id 綁在這次安裝上，重裝就換一個，備份上去也拿不回來，等於把資料送上伺服器
/// 卻換不到任何好處。資料留在本機、要跨裝置就登入，是比較誠實的交換。
final syncSessionProvider = Provider<SyncSession>((ref) {
  final user = ref.watch(currentUserProvider);
  final syncUserId = (user != null && !user.isAnonymous) ? user.id : null;
  return SyncSession(enabled: syncUserId != null, userId: syncUserId);
});

/// 同步的啟動點：session 一有效就跑一次 full sync，之後 session 換人（匿名
/// 升級成正式帳號，id 會保留；或登出再登入）時再跑一次。
///
/// 搬進 provider 而不是留在 app.dart，是因為 WidgetRef.listen 沒有
/// fireImmediately，而冷啟動時 session **第一次 build 就已經是 active**——匿
/// 名登入是在 main() 的 init() 裡 await 完才建 widget tree，
/// currentUserProvider 又會同步 fallback 到 authService.currentUser。只聽
/// 「非啟用 → 啟用」的轉換的話那個轉換根本不會發生，本機記錄一筆都不會上
/// 傳，而且是無聲失敗。
///
/// 回傳值刻意沒有意義：watch 它只是為了讓它活著（與
/// narrationAnalyticsObserverProvider 同一個慣例）。
final syncBootstrapProvider = Provider<void>((ref) {
  // 用 ref.listen(fireImmediately) 而不是 ref.watch：watch 的話這個 provider
  // 本身要被重算才會有動作，而 Provider<void> 每次算出來都是 null，重算時機
  // 取決於誰在訂閱、值有沒有變——不該把「資料會不會上傳」壓在那個細節上。
  // listen 則明確：現在先跑一次，之後 session 每次變動再跑。
  ref.listen<SyncSession>(syncSessionProvider, fireImmediately: true, (
    _,
    session,
  ) {
    _onSession(ref, session);
  });
});

void _onSession(Ref ref, SyncSession session) {
  // 還沒登入（或只有匿名 session）就什麼都不做。這裡刻意不去催匿名登入：
  // 匿名 session 是給後端 API 認證用的，由 main.dart 負責，與同步無關。
  if (!session.isActive) return;
  _claimThenSync(ref, session.userId!);
}

/// 先認領無主資料，再同步。
///
/// 順序不能顛倒：fullSync 會把「遠端沒有的本機項目」推上去，而無主資料在
/// 認領之前對每個帳號都是可見的——先同步的話，未登入期間累積的東西會被推
/// 給當下這個帳號，之後換帳號再推一次給下一個人。認領等於把「這批東西屬於
/// 第一個登入的帳號」這件事釘下來。
Future<void> _claimThenSync(Ref ref, String userId) async {
  for (final store in ref.read(localOwnershipStoresProvider)) {
    await store.claimUnowned(userId);
  }
  // Re-entry 由 SyncCoordinator 自己擋，重複觸發不會疊起來。
  await ref.read(syncCoordinatorProvider).runFullSync();
}

// ---------------------------------------------------------------------------
// Local Hive repositories (always used for reads).
// ---------------------------------------------------------------------------

/// 讀寫本機資料時「我是誰」。
///
/// 這裡用的是**登入身分**（含匿名 session 的 id 為 null 的情況），不是
/// syncSessionProvider——後者代表「能不能同步」。未登入時存下來的資料是無
/// 主的，登入時才被認領（見 local_ownership.dart）。
String? _localOwnerId(Ref ref) {
  final user = ref.read(currentUserProvider);
  return (user != null && !user.isAnonymous) ? user.id : null;
}

final localJourneyRepositoryProvider = Provider<HiveJourneyRepository>((ref) {
  return HiveJourneyRepository(currentUserId: () => _localOwnerId(ref));
});

final localTripRepositoryProvider = Provider<HiveTripRepository>((ref) {
  return HiveTripRepository(currentUserId: () => _localOwnerId(ref));
});

/// 需要做擁有者維護的本機儲存。認領與清空都要兩個 box 一起動，漏掉一個就
/// 會出現「旅程還在、記錄不見」這種半套狀態。
final localOwnershipStoresProvider = Provider<List<LocalOwnershipStore>>((ref) {
  return [
    ref.watch(localJourneyRepositoryProvider),
    ref.watch(localTripRepositoryProvider),
  ];
});

// ---------------------------------------------------------------------------
// Remote data sources (Supabase).
// ---------------------------------------------------------------------------

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final journeyRemoteDataSourceProvider =
    Provider<RemoteSyncDataSource<JourneyEntry>>((ref) {
      return SupabaseJourneyRemoteDataSource(ref.watch(supabaseClientProvider));
    });

final tripRemoteDataSourceProvider = Provider<RemoteSyncDataSource<Trip>>((
  ref,
) {
  return SupabaseTripRemoteDataSource(ref.watch(supabaseClientProvider));
});

// ---------------------------------------------------------------------------
// Sync engines.
// ---------------------------------------------------------------------------

final journeySyncEngineProvider = Provider<SyncEngine<JourneyEntry>>((ref) {
  final local = ref.watch(localJourneyRepositoryProvider);
  return SyncEngine<JourneyEntry>(
    descriptor: SyncEntityDescriptor<JourneyEntry>(
      name: 'journey_entry',
      idOf: (e) => e.id,
      updatedAtOf: (e) => e.updatedAt,
    ),
    remote: ref.watch(journeyRemoteDataSourceProvider),
    loadLocal: local.getAll,
    saveLocal: local.save,
  );
});

final tripSyncEngineProvider = Provider<SyncEngine<Trip>>((ref) {
  final local = ref.watch(localTripRepositoryProvider);
  return SyncEngine<Trip>(
    descriptor: SyncEntityDescriptor<Trip>(
      name: 'trip',
      idOf: (t) => t.id,
      updatedAtOf: (t) => t.updatedAt,
    ),
    remote: ref.watch(tripRemoteDataSourceProvider),
    loadLocal: local.getAll,
    saveLocal: local.save,
  );
});

// ---------------------------------------------------------------------------
// Public repositories — wrapped versions used by feature providers.
// ---------------------------------------------------------------------------

final syncingJourneyRepositoryProvider = Provider<JourneyRepository>((ref) {
  return SyncingJourneyRepository(
    local: ref.watch(localJourneyRepositoryProvider),
    engine: ref.watch(journeySyncEngineProvider),
    session: () => ref.read(syncSessionProvider),
  );
});

final syncingTripRepositoryProvider = Provider<TripRepository>((ref) {
  return SyncingTripRepository(
    local: ref.watch(localTripRepositoryProvider),
    engine: ref.watch(tripSyncEngineProvider),
    session: () => ref.read(syncSessionProvider),
  );
});

// ---------------------------------------------------------------------------
// Coordinator (used to trigger initial full sync).
// ---------------------------------------------------------------------------

final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  return SyncCoordinator(
    journey: ref.watch(journeySyncEngineProvider),
    trip: ref.watch(tripSyncEngineProvider),
  );
});
