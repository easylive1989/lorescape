import 'dart:async';

import 'package:context_app/features/journey/domain/models/journey_entry.dart';
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
  /// concurrent passes.
  Future<void> runFullSync() async {
    if (_running) {
      _log.info('Full sync already in progress, skipping');
      return;
    }
    _running = true;
    try {
      await Future.wait([journey.fullSync(), trip.fullSync()]);
    } catch (e, stack) {
      _log.warning('Full sync failed', e, stack);
    } finally {
      _running = false;
    }
  }
}
