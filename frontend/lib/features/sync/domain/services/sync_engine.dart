import 'package:context_app/features/sync/domain/services/remote_sync_data_source.dart';
import 'package:context_app/features/sync/domain/services/sync_merger.dart';
import 'package:logging/logging.dart';

/// 一次 fullSync 的結果。
class SyncRunResult {
  const SyncRunResult({
    required this.pushed,
    required this.pulled,
    required this.errors,
  });

  final int pushed;
  final int pulled;
  final List<String> errors;
}

/// Per-entity descriptor that explains how to identify and order items.
class SyncEntityDescriptor<T> {
  final String name;
  final String Function(T item) idOf;
  final DateTime Function(T item) updatedAtOf;

  const SyncEntityDescriptor({
    required this.name,
    required this.idOf,
    required this.updatedAtOf,
  });
}

/// Orchestrates push/pull of a single entity type between the local
/// store (represented by callbacks) and a [RemoteSyncDataSource].
///
/// Callbacks keep the engine framework-agnostic so it can wrap any
/// repository abstraction.
class SyncEngine<T> {
  SyncEngine({
    required this.descriptor,
    required this.remote,
    required this.loadLocal,
    required this.saveLocal,
  });

  static final _log = Logger('SyncEngine');

  final SyncEntityDescriptor<T> descriptor;
  final RemoteSyncDataSource<T> remote;
  final Future<List<T>> Function() loadLocal;
  final Future<void> Function(T item) saveLocal;

  /// Pull from remote, merge with local by `updatedAt`, then write back
  /// local-only or newer items to both sides.
  ///
  /// 逐筆的錯誤照舊不會中斷整批，但會被收集進 [SyncRunResult.errors]——只寫
  /// log 的話，整條同步壞掉在畫面上是完全看不出來的（見 SyncStatus 的說明）。
  Future<SyncRunResult> fullSync() async {
    final errors = <String>[];
    final List<T> local;
    final List<T> remoteItems;
    try {
      local = await loadLocal();
      remoteItems = await remote.fetchAll();
    } catch (e, stack) {
      // 讀不到就整批做不了，這是最該被看見的一種失敗。
      _log.warning('Failed to load ${descriptor.name} for sync', e, stack);
      return SyncRunResult(pushed: 0, pulled: 0, errors: ['$e']);
    }

    final result = SyncMerger.merge<T>(
      local: local,
      remote: remoteItems,
      idOf: descriptor.idOf,
      updatedAtOf: descriptor.updatedAtOf,
    );

    var pulled = 0;
    for (final item in result.toApplyLocally) {
      try {
        await saveLocal(item);
        pulled++;
      } catch (e, stack) {
        _log.warning('Failed to apply ${descriptor.name} locally', e, stack);
        errors.add('$e');
      }
    }
    var pushed = 0;
    for (final item in result.toPush) {
      try {
        await remote.upsert(item);
        pushed++;
      } catch (e, stack) {
        _log.warning('Failed to push ${descriptor.name}', e, stack);
        errors.add('$e');
      }
    }
    return SyncRunResult(pushed: pushed, pulled: pulled, errors: errors);
  }

  /// Best-effort single-item push. Errors are logged, not thrown.
  Future<void> push(T item) async {
    try {
      await remote.upsert(item);
    } catch (e, stack) {
      _log.warning('Failed to push ${descriptor.name}', e, stack);
    }
  }

  /// Best-effort single-item delete. Errors are logged, not thrown.
  Future<void> deleteRemote(String id) async {
    try {
      await remote.delete(id);
    } catch (e, stack) {
      _log.warning('Failed to delete ${descriptor.name} remotely', e, stack);
    }
  }
}
