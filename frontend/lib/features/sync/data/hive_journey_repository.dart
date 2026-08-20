import 'dart:convert';

import 'package:context_app/features/journey/domain/models/journey_entry.dart';
import 'package:context_app/features/journey/domain/repositories/journey_repository.dart';
import 'package:context_app/features/sync/data/local_ownership.dart';
import 'package:hive/hive.dart';
import 'package:logging/logging.dart';

/// Hive-based local implementation of [JourneyRepository].
///
/// Stores each [JourneyEntry] as a JSON string with key = entry.id, tagged
/// with the account that owns it（見 [LocalOwnershipStore] 與
/// `local_ownership.dart` 的說明）。box 是整台裝置共用的，所以讀寫都要過
/// 擁有者這一關。
class HiveJourneyRepository implements JourneyRepository, LocalOwnershipStore {
  HiveJourneyRepository({required String? Function() currentUserId})
    : _currentUserId = currentUserId;

  static const String _boxName = 'journey_entries';
  static final _log = Logger('HiveJourneyRepository');

  final String? Function() _currentUserId;

  Future<Box<dynamic>> _getBox() => Hive.openBox<dynamic>(_boxName);

  @override
  Future<List<JourneyEntry>> getAll() async {
    try {
      final box = await _getBox();
      final userId = _currentUserId();
      return box.values
          .map((v) => jsonDecode(v as String) as Map<String, dynamic>)
          .where((json) => isVisibleTo(ownerIdOf(json), userId))
          .map(JourneyEntry.fromJson)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e, stack) {
      _log.warning('Failed to load journey entries', e, stack);
      return [];
    }
  }

  @override
  Future<void> save(JourneyEntry entry) async {
    final box = await _getBox();
    await box.put(
      entry.id,
      jsonEncode(withOwner(entry.toJson(), _currentUserId())),
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
      _log.warning('Failed to claim unowned journey entries', e, stack);
      return 0;
    }
  }

  @override
  Future<void> clearAll() async {
    final box = await _getBox();
    await box.clear();
  }
}
