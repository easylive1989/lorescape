import 'dart:convert';

import 'package:context_app/features/sync/data/local_ownership.dart';
import 'package:context_app/features/trip/domain/models/trip.dart';
import 'package:context_app/features/trip/domain/repositories/trip_repository.dart';
import 'package:hive/hive.dart';
import 'package:logging/logging.dart';

/// Hive-based local implementation of [TripRepository].
///
/// Stores each [Trip] as a JSON string with key = trip.id, tagged with the
/// account that owns it（見 `local_ownership.dart`）。
class HiveTripRepository implements TripRepository, LocalOwnershipStore {
  HiveTripRepository({required String? Function() currentUserId})
    : _currentUserId = currentUserId;

  static const String _boxName = 'trips';
  static final _log = Logger('HiveTripRepository');

  final String? Function() _currentUserId;

  Future<Box<dynamic>> _getBox() => Hive.openBox<dynamic>(_boxName);

  @override
  Future<List<Trip>> getAll() async {
    try {
      final box = await _getBox();
      final userId = _currentUserId();
      return box.values
          .map((v) => jsonDecode(v as String) as Map<String, dynamic>)
          .where((json) => isVisibleTo(ownerIdOf(json), userId))
          .map(Trip.fromJson)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e, stack) {
      _log.warning('Failed to load trips', e, stack);
      return [];
    }
  }

  @override
  Future<Trip?> getById(String id) async {
    try {
      final box = await _getBox();
      final raw = box.get(id);
      if (raw is! String) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      // 別人的旅程要當作不存在——只擋 getAll 的話，任何拿得到 id 的路徑
      // （深連結、殘留的 currentTripId）就繞過了過濾。
      if (!isVisibleTo(ownerIdOf(json), _currentUserId())) return null;
      return Trip.fromJson(json);
    } catch (e, stack) {
      _log.warning('Failed to load trip $id', e, stack);
      return null;
    }
  }

  @override
  Future<void> save(Trip trip) async {
    final box = await _getBox();
    await box.put(
      trip.id,
      jsonEncode(withOwner(trip.toJson(), _currentUserId())),
    );
  }

  @override
  Future<void> delete(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  @override
  Future<int> claimUnowned(String userId) async {
    try {
      final box = await _getBox();
      var claimed = 0;
      for (final key in box.keys.toList()) {
        final raw = box.get(key);
        if (raw is! String) continue;
        final json = jsonDecode(raw) as Map<String, dynamic>;
        if (ownerIdOf(json) != null) continue;
        await box.put(key, jsonEncode(withOwner(json, userId)));
        claimed++;
      }
      return claimed;
    } catch (e, stack) {
      _log.warning('Failed to claim unowned trips', e, stack);
      return 0;
    }
  }

  @override
  Future<void> clearAll() async {
    final box = await _getBox();
    await box.clear();
  }
}
