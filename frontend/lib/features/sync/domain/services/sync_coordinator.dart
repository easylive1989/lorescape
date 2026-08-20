import 'dart:async';

import 'package:context_app/features/journey/domain/models/journey_entry.dart';
import 'package:context_app/features/sync/domain/models/sync_status.dart';
import 'package:context_app/features/sync/domain/services/sync_engine.dart';
import 'package:context_app/features/trip/domain/models/trip.dart';
import 'package:logging/logging.dart';

/// Top-level driver that runs a full sync for every entity type.
class SyncCoordinator {
  SyncCoordinator({required this.journey, required this.trip});

  static final _log = Logger('SyncCoordinator');

  final SyncEngine<JourneyEntry> journey;
  final SyncEngine<Trip> trip;

  bool _running = false;

  /// Runs full sync for all entity types in parallel.
  ///
  /// Re-entry is guarded so toggling on/off rapidly does not pile up
  /// concurrent passes. 回傳這次的結果（含錯誤）——呼叫端把它記進
  /// SyncStatus，失敗才有痕跡可看。已在進行中時回 null。
  Future<SyncStatus?> runFullSync() async {
    if (_running) {
      _log.info('Full sync already in progress, skipping');
      return null;
    }
    _running = true;
    try {
      final results = await Future.wait([journey.fullSync(), trip.fullSync()]);
      return SyncStatus(
        finishedAt: DateTime.now(),
        pushed: results.fold(0, (sum, r) => sum + r.pushed),
        pulled: results.fold(0, (sum, r) => sum + r.pulled),
        errors: {for (final r in results) ...r.errors}.toList(),
      );
    } catch (e, stack) {
      _log.warning('Full sync failed', e, stack);
      return SyncStatus(
        finishedAt: DateTime.now(),
        pushed: 0,
        pulled: 0,
        errors: ['$e'],
      );
    } finally {
      _running = false;
    }
  }
}
