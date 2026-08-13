import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_vn/src/visual_novel/domain/cursor.dart';

void main() {
  group('Cursor', () {
    test('場開頭是單層的 index 0', () {
      final cursor = Cursor.atSceneStart('S01');
      expect(cursor.sceneId, 'S01');
      expect(cursor.path, hasLength(1));
      expect(cursor.last.index, 0);
      expect(cursor.last.branch, isNull);
    });

    test('序列化成規範 §6 的 token 形狀', () {
      const cursor = Cursor(sceneId: 'S06', path: <CursorStep>[
        CursorStep(12, 'then'),
        CursorStep(3),
      ]);
      expect(cursor.toTokens(), <String>['12', 'then', '3']);
      expect(cursor.readKey, 'S06#12.then.3');
    });

    test('token 往返後是同一個游標', () {
      const original = Cursor(sceneId: 'S06', path: <CursorStep>[
        CursorStep(12, 'then'),
        CursorStep(4, 'opt1'),
        CursorStep(0),
      ]);
      final restored = Cursor.fromTokens('S06', original.toTokens());
      expect(restored.toTokens(), original.toTokens());
      expect(restored.path.map((s) => s.index), <int>[12, 4, 0]);
      expect(restored.path.map((s) => s.branch), <String?>['then', 'opt1', null]);
    });

    test('push 在最後一層記下分支並開新的一層', () {
      final pushed = Cursor.atSceneStart('S01').withLastIndex(5).push('then');
      expect(pushed.toTokens(), <String>['5', 'then', '0']);
    });

    test('pop 收掉最後一層並清掉上一層的分支標記', () {
      final popped = Cursor.atSceneStart('S01').withLastIndex(5).push('then').pop();
      expect(popped.toTokens(), <String>['5']);
      expect(popped.last.branch, isNull);
    });
  });
}
