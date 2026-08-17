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
import 'package:lorescape_story/src/visual_novel/providers.dart'
    show
        DialogueNode,
        NarrationNode,
        PlayState,
        PlayStatus,
        SaveData,
        Story,
        currentNode,
        initState,
        resume,
        saveStoreProvider,
        storyProvider;
import 'package:lorescape_story/src/visual_novel/providers.dart'
    as engine
    show advance, choose;

/// 回顧列表裡的一筆——旁白沒有說話者，`speakerName` 為 null。
final class BacklogEntry {
  const BacklogEntry({required this.speakerName, required this.text});
  final String? speakerName;
  final String text;
}

class PlayController extends FamilyNotifier<PlayState, String> {
  final List<BacklogEntry> _backlog = <BacklogEntry>[];

  List<BacklogEntry> get backlog => List<BacklogEntry>.unmodifiable(_backlog);

  /// 選項畫面要顯示的上一句。`choice` 節點本身沒有文字，玩家在沒有上下文的
  /// 情況下做選擇很難受——把剛讀完的那句留在對話框裡。
  BacklogEntry? _lastEntry;
  BacklogEntry? get lastEntry => _lastEntry;

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
    _record(initial);
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
    // 重玩是新的一輪，上一輪殘留的回顧會誤導玩家（例如剛看完結局按重新開
    // 始，回顧卻還顯示結局台詞）。清掉之後改走 _apply()，讓新的第一句立刻
    // 記進 backlog，跟其餘推進路徑一致，不用等玩家點第一下才補上。
    _backlog.clear();
    _lastEntry = null;
    _apply(initState(_story));
  }

  /// 已讀集合的鍵。**一定要帶 storyId。**
  ///
  /// `Cursor.readKey` 只有 `<場>#<路徑>`，而 8 篇的場 id 全都是 S01…S12 與
  /// E_A/E_B/E_C——實測 8 篇加總 2,123 個鍵、跨篇聯集只有 749，**碰撞
  /// 64.7%**。少了 storyId 的話，玩家讀完第 1 篇再進第 2 篇按快進，會沿著
  /// 碰撞鍵一路衝過從沒看過的劇情（實測其他七篇各有 43–57% 的節點被誤判成
  /// 已讀），直接違反規範 §5.3「只跳已讀節點，碰到未讀即停」。
  ///
  String _readKey(PlayState value) => '$arg#${value.readKey}';

  /// 只跳已讀節點。未讀、選項、結局都要停——這是規範 §5.3 的硬要求。
  void skipRead() {
    final read = ref.read(saveStoreProvider).readNodes();
    var guard = 2000; // 8 篇裡最長的一場約幾百個節點，2000 步保底防呆迴圈失控。
    var next = state;
    while (guard-- > 0) {
      if (next.status != PlayStatus.playing) break;
      if (!read.contains(_readKey(next))) break;
      final candidate = engine.advance(_story, next);
      // 跳過的內容仍然要進回顧——快進之後正是最可能想回頭查看的時候，
      // backlog 有洞會讓「回顧」名不副實。
      _record(candidate);
      if (candidate.status != PlayStatus.playing ||
          !read.contains(_readKey(candidate))) {
        next = candidate;
        break;
      }
      next = candidate;
    }
    _apply(next);
  }

  void _record(PlayState value) {
    // 結局狀態的游標必然越界（`_settle` 的不變式），沒有「目前節點」可記；
    // 硬呼叫 currentNode 會 RangeError，而且是在 _apply() 呼叫鏈裡丟出，
    // 發生在 _persist() 之前——結束後的存檔因此無法清除。已實測重現（RangeError: index
    // should be less than <scene 節點數>），這裡直接擋掉才是對的：結局沒有
    // 對白／旁白要記進回顧。
    if (value.status == PlayStatus.ended) return;
    final node = currentNode(_story, value);
    final entry = switch (node) {
      NarrationNode(:final text) => BacklogEntry(speakerName: null, text: text),
      DialogueNode(:final who, :final text) => BacklogEntry(
        speakerName: _story.characters[who]?.name ?? who,
        text: text,
      ),
      _ => null,
    };
    if (entry == null) return;
    _lastEntry = entry;
    _backlog.add(entry);
    // 一篇約 300 個節點，留 200 筆足夠往回捲，也不會讓記憶體無限長。
    if (_backlog.length > 200) _backlog.removeAt(0);
  }

  void _apply(PlayState next) {
    state = next;
    _record(next);
    _persist(arg, next);
  }

  void _persist(String storyId, PlayState value) {
    final store = ref.read(saveStoreProvider);
    // 結局狀態的游標必然越界，那個鍵不對應任何節點、之後也永遠查不到——
    // 寫進已讀集合只是污染。
    if (value.status != PlayStatus.ended) store.markRead(_readKey(value));
    if (value.status == PlayStatus.ended) {
      store.clearSave(storyId);
      return;
    }
    store.writeSave(SaveData.from(storyId, value, DateTime.now()));
  }
}

final NotifierProviderFamily<PlayController, PlayState, String>
playControllerProvider =
    NotifierProvider.family<PlayController, PlayState, String>(
      PlayController.new,
    );
