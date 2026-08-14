import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lorescape_vn/src/visual_novel/domain/play_state.dart';
import 'package:lorescape_vn/src/visual_novel/domain/save_data.dart';
import 'package:lorescape_vn/src/visual_novel/domain/story.dart';
import 'package:lorescape_vn/src/visual_novel/domain/story_player.dart' as player;
import 'package:lorescape_vn/src/visual_novel/providers.dart' show saveStoreProvider, storyProvider;

/// ⚠️ 這個檔被 providers.dart re-export，因此**只能**具名 import 它需要的兩個
/// provider，不可整份 import——整份 import 會讓兩個檔互相看見對方的 export，
/// 名稱衝突時的錯誤訊息會很難讀。
class PlayController extends FamilyNotifier<PlayState, String> {
  @override
  PlayState build(String storyId) {
    final story = ref.watch(storyProvider(storyId)).requireValue;
    final saved = ref.read(saveStoreProvider).loadSave(storyId);
    // 讀檔一律經過 resume：存檔沒記 status，停在選項上的存檔若當成 playing，
    // 點一下就會把那個選擇跳過。
    // resume 回 null ＝ 存檔對現在的劇本已失效（劇本改版後路徑位移），退回開頭
    // 重來，而不是崩在玩家臉上。
    final initial = saved == null
        ? player.initState(story)
        : (player.resume(story, saved.toPlayState()) ?? player.initState(story));
    _persist(storyId, initial);
    return initial;
  }

  Story get _story => ref.read(storyProvider(arg)).requireValue;

  void advance() {
    if (state.status != PlayStatus.playing) return;
    _apply(player.advance(_story, state));
  }

  void choose(int visibleIndex) {
    if (state.status != PlayStatus.choosing) return;
    _apply(player.choose(_story, state, visibleIndex));
  }

  void restart() {
    final store = ref.read(saveStoreProvider);
    store.clearSave(arg);
    state = player.initState(_story);
  }

  void _apply(PlayState next) {
    state = next;
    _persist(arg, next);
  }

  void _persist(String storyId, PlayState value) {
    final store = ref.read(saveStoreProvider);
    store.markRead(value.readKey);
    if (value.status == PlayStatus.ended) {
      final endingId = value.endingId;
      if (endingId != null) store.markEnding(storyId, endingId);
      store.clearSave(storyId);
      return;
    }
    store.writeSave(SaveData.from(storyId, value, DateTime.now()));
  }
}

final NotifierProviderFamily<PlayController, PlayState, String> playControllerProvider =
    NotifierProvider.family<PlayController, PlayState, String>(PlayController.new);
