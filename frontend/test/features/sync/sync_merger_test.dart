import 'package:context_app/features/sync/domain/services/sync_merger.dart';
import 'package:flutter_test/flutter_test.dart';

class _Item {
  _Item(this.id, this.updatedAt);
  final String id;
  final DateTime updatedAt;
}

SyncMergeResult<_Item> _merge({
  required List<_Item> local,
  required List<_Item> remote,
}) {
  return SyncMerger.merge<_Item>(
    local: local,
    remote: remote,
    idOf: (it) => it.id,
    updatedAtOf: (it) => it.updatedAt,
  );
}

void main() {
  group('SyncMerger.merge', () {
    test('given disjoint local and remote items, all show up in merged', () {
      final local = [_Item('a', DateTime(2026, 1, 1))];
      final remote = [_Item('b', DateTime(2026, 1, 2))];

      final result = _merge(local: local, remote: remote);

      expect(result.merged.map((i) => i.id).toSet(), {'a', 'b'});
      expect(result.toPush.map((i) => i.id), ['a']);
      expect(result.toApplyLocally.map((i) => i.id), ['b']);
    });

    test('given a local item newer than remote, local wins and is pushed', () {
      final localItem = _Item('shared', DateTime(2026, 5, 10));
      final remoteItem = _Item('shared', DateTime(2026, 5, 1));

      final result = _merge(local: [localItem], remote: [remoteItem]);

      expect(result.merged.single, same(localItem));
      expect(result.toPush, [localItem]);
      expect(result.toApplyLocally, isEmpty);
    });

    test('given a remote item newer than local, remote wins locally', () {
      final localItem = _Item('shared', DateTime(2026, 5, 1));
      final remoteItem = _Item('shared', DateTime(2026, 5, 10));

      final result = _merge(local: [localItem], remote: [remoteItem]);

      expect(result.merged.single, same(remoteItem));
      expect(result.toApplyLocally, [remoteItem]);
      expect(result.toPush, isEmpty);
    });

    test(
      'given identical timestamps, remote is used as the canonical copy',
      () {
        final ts = DateTime(2026, 5, 5);
        final localItem = _Item('shared', ts);
        final remoteItem = _Item('shared', ts);

        final result = _merge(local: [localItem], remote: [remoteItem]);

        expect(result.merged.single, same(remoteItem));
        expect(result.toPush, isEmpty);
        expect(result.toApplyLocally, isEmpty);
      },
    );

    test('given empty inputs, returns empty merge result', () {
      final result = _merge(local: const [], remote: const []);
      expect(result.merged, isEmpty);
      expect(result.toPush, isEmpty);
      expect(result.toApplyLocally, isEmpty);
    });
  });
}
