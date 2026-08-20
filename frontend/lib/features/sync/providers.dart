import 'package:context_app/features/auth/providers.dart';
import 'package:context_app/features/journey/domain/models/journey_entry.dart';
import 'package:context_app/features/journey/domain/repositories/journey_repository.dart';
import 'package:context_app/features/sync/data/hive_journey_repository.dart';
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
  // Re-entry 由 SyncCoordinator 自己擋，重複觸發不會疊起來。
  ref.read(syncCoordinatorProvider).runFullSync();
}

// ---------------------------------------------------------------------------
// Local Hive repositories (always used for reads).
// ---------------------------------------------------------------------------

final localJourneyRepositoryProvider = Provider<JourneyRepository>((ref) {
  return HiveJourneyRepository();
});

final localTripRepositoryProvider = Provider<TripRepository>((ref) {
  return HiveTripRepository();
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
