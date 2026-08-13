import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_vn/src/visual_novel/domain/cursor.dart';
import 'package:lorescape_vn/src/visual_novel/domain/play_state.dart';
import 'package:lorescape_vn/src/visual_novel/domain/save_data.dart';

void main() {
  test('存檔往返：游標、變數、台上立繪都一致', () {
    const state = PlayState(
      cursor: Cursor(sceneId: 'S06', path: <CursorStep>[CursorStep(12, 'then'), CursorStep(3)]),
      vars: <String, Object?>{'affection': 2, 'deal': 'wait', 'bread': true},
      stage: <SpriteOnStage>[SpriteOnStage(who: 'vibia', sprite: 'softened')],
      status: PlayStatus.playing,
      bgmId: 'quiet',
    );
    final save = SaveData.from('pompeii_01_harbour_stranger', state, DateTime.utc(2026, 8, 13));
    final restored = SaveData.fromJson(save.toJson()).toPlayState();

    expect(restored.cursor.toTokens(), state.cursor.toTokens());
    expect(restored.vars, state.vars);
    expect(restored.stage.single.who, 'vibia');
    expect(restored.stage.single.sprite, 'softened');
    expect(restored.bgmId, 'quiet');
  });

  test('存檔 JSON 的欄位符合規範 §6', () {
    final save = SaveData.from(
      'pompeii_01_harbour_stranger',
      PlayState(
        cursor: Cursor.atSceneStart('S01'),
        vars: const <String, Object?>{'affection': 0},
        stage: const <SpriteOnStage>[],
        status: PlayStatus.playing,
      ),
      DateTime.utc(2026, 8, 13),
    );
    final json = save.toJson();
    expect(json['storyId'], 'pompeii_01_harbour_stranger');
    expect((json['cursor'] as Map<String, dynamic>)['sceneId'], 'S01');
    expect((json['cursor'] as Map<String, dynamic>)['path'], <String>['0']);
    expect(json['updatedAt'], '2026-08-13T00:00:00.000Z');
  });
}
