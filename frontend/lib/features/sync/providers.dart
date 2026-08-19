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
import 'package:context_app/features/sync/presentation/controllers/sync_settings_notifier.dart';
import 'package:context_app/features/trip/domain/models/trip.dart';
import 'package:context_app/features/trip/domain/repositories/trip_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Sync preference (toggle state) and session.
// ---------------------------------------------------------------------------

final syncSettingsProvider = NotifierProvider<SyncSettingsNotifier, bool>(
  SyncSettingsNotifier.new,
);

/// Combined live snapshot: toggle is on AND user is signed in.
final syncSessionProvider = Provider<SyncSession>((ref) {
  final enabled = ref.watch(syncSettingsProvider);
  final user = ref.watch(currentUserProvider);
  // Cloud sync requires a permanent account; anonymous users are local-only.
  final syncUserId = (user != null && !user.isAnonymous) ? user.id : null;
  return SyncSession(enabled: enabled, userId: syncUserId);
});

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
