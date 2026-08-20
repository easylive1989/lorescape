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
final syncSessionProvider = Provider<SyncSession>((ref) {
  final user = ref.watch(currentUserProvider);
  // journey 與 trip 一律同步，不再是使用者可以關掉的選項，匿名帳號也算數：
  // App 一啟動就會建立匿名 session（main.dart 的 _ensureSignedIn），所以
  // 這裡幾乎永遠拿得到 id；RLS policy 是 `auth.uid() = user_id`，匿名使用者
  // 一樣過得了。
  //
  // 代價要知道：匿名 id 綁在裝置的 session 上，重裝 App 會拿到新的 id，舊
  // 的列就成為孤兒。真正的跨裝置價值仍然要升級成正式帳號（linkIdentity 會
  // 保留同一個 id，資料就接得上）。
  return SyncSession(enabled: user != null, userId: user?.id);
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
  if (!session.isActive) {
    // 沒有 id 就等於這次啟動完全不備份。啟動時的匿名登入是 best-effort
    // （main.dart 的 _ensureSignedIn 失敗只寫 log），最常見的原因是當下沒網
    // 路——所以這裡再試一次。成功的話 authStateChanges 會吐出新的 user，
    // session 變動，這個 listener 再被叫一次就走下面的 full sync；再失敗則沒
    // 有事件、不會有新的通知，也就不會打轉。
    ref.read(authServiceProvider).ensureSignedIn().ignore();
    return;
  }
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
