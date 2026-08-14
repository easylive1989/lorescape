import 'package:flutter_riverpod/flutter_riverpod.dart';
// 這個檔被 providers.dart re-export，形成循環——Dart 允許，但兩邊都要用具名
// `show`，否則會互相看見對方的 export，名稱衝突時的錯誤訊息很難讀。
// presentation/ 一律只 import providers.dart，這個檔也不例外。
//
// `advance`／`choose` 另外用 `as engine` 拉出一條 prefixed import：
// PlayController 自己就有同名的 advance()／choose(int) 方法，同一個 class
// 裡的裸名呼叫一律先解到 instance member（等於 this.advance/this.choose），
// 不會落到這個 import 裡的頂層函式——那不是「import 沒 show 乾淨」的問題，是
// Dart 的名稱解析規則，沒有 prefix 就無法在方法體內指名呼叫到引擎那兩個同名
// 函式。其餘沒有撞名的維持裸名 show。
import 'package:lorescape_vn/src/visual_novel/providers.dart'
    show
        PlayState,
        PlayStatus,
        SaveData,
        Story,
        initState,
        resume,
        saveStoreProvider,
        storyProvider;
import 'package:lorescape_vn/src/visual_novel/providers.dart' as engine show advance, choose;

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
        ? initState(story)
        : (resume(story, saved.toPlayState()) ?? initState(story));
    _persist(storyId, initial);
    return initial;
  }

  Story get _story => ref.read(storyProvider(arg)).requireValue;

  void advance() {
    if (state.status != PlayStatus.playing) return;
    _apply(engine.advance(_story, state));
  }

  void choose(int visibleIndex) {
    if (state.status != PlayStatus.choosing) return;
    _apply(engine.choose(_story, state, visibleIndex));
  }

  void restart() {
    final store = ref.read(saveStoreProvider);
    store.clearSave(arg);
    state = initState(_story);
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
