import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_story/src/visual_novel/data/save_store.dart';
import 'package:lorescape_story/src/visual_novel/domain/cursor.dart';
import 'package:lorescape_story/src/visual_novel/domain/play_state.dart';
import 'package:lorescape_story/src/visual_novel/domain/save_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late SharedPreferencesSaveStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    store = SharedPreferencesSaveStore(prefs);
  });

  test('沒有存檔時回 null', () {
    expect(store.loadSave('pompeii_01_harbour_stranger'), isNull);
  });

  test('存檔往返', () async {
    final data = SaveData(
      storyId: 'pompeii_01_harbour_stranger',
      cursor: const Cursor(sceneId: 'S03', path: <CursorStep>[CursorStep(7)]),
      vars: const <String, Object?>{'affection': 1},
      stage: const <SpriteOnStage>[],
      updatedAt: DateTime.utc(2026, 8, 13),
    );
    await store.writeSave(data);
    final loaded = store.loadSave('pompeii_01_harbour_stranger')!;
    expect(loaded.cursor.toTokens(), <String>['7']);
    expect(loaded.vars['affection'], 1);
  });

  test('已讀節點跨故事累積', () async {
    await store.markRead('S01#0');
    await store.markRead('S01#1');
    await store.markRead('S01#0');
    expect(store.readNodes(), <String>{'S01#0', 'S01#1'});
  });

  test('結局收藏以 storyId#endingId 記錄', () async {
    await store.markEnding('pompeii_01_harbour_stranger', 'A');
    expect(store.endingsSeen(), contains('pompeii_01_harbour_stranger#A'));
  });

  test('設定有預設值且可改', () async {
    expect(store.textSpeed(), 28);
    expect(store.fontScale(), 1.0);
    await store.setTextSpeed(12);
    await store.setFontScale(1.2);
    expect(SharedPreferencesSaveStore(prefs).textSpeed(), 12);
    expect(SharedPreferencesSaveStore(prefs).fontScale(), 1.2);
  });

  test('清存檔不影響已讀與結局', () async {
    await store.markRead('S01#0');
    await store.markEnding('pompeii_01_harbour_stranger', 'A');
    await store.clearSave('pompeii_01_harbour_stranger');
    expect(store.readNodes(), isNotEmpty);
    expect(store.endingsSeen(), isNotEmpty);
  });
}
