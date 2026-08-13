import 'package:lorescape_vn/src/visual_novel/domain/cursor.dart';
import 'package:lorescape_vn/src/visual_novel/domain/play_state.dart';
import 'package:lorescape_vn/src/visual_novel/domain/story.dart';

/// 劇本執行器：在劇本樹上走，直到停在一個玩家要看到的節點。
///
/// 節點分兩類：會停頓的（n / d / cg / choice，UI 要畫出來、等玩家點）與
/// 副作用型的（sfx / bgm / add / set / show / hide，套用後不停頓，自動往下走）。
/// `playing` / `choosing` 狀態下 cursor 一定指向會停頓的節點——這是整份 UI
/// 依賴的不變式，由 [_settle] 維持。

final class VisibleOption {
  const VisibleOption(this.index, this.option);

  /// 在 ChoiceNode.options 裡的**原始**索引。游標的 'opt' 分支標記用這個，
  /// 用可見索引會在條件變動後指到別的選項。
  final int index;
  final ChoiceOption option;
}

/// 劇本開場：游標指到起始場第 0 個節點，變數用宣告的初始值，再一路套用
/// 副作用節點直到停下。
PlayState initState(Story story) {
  final scene = _scene(story, story.start);
  final state = PlayState(
    cursor: Cursor.atSceneStart(story.start),
    vars: <String, Object?>{
      for (final entry in story.variables.entries) entry.key: entry.value.initial,
    },
    stage: const <SpriteOnStage>[],
    status: PlayStatus.playing,
    bgmId: scene.bgm,
  );
  return _settle(story, state);
}

/// 游標目前指著的節點。`playing` / `choosing` 狀態下必為會停頓的節點。
StoryNode currentNode(Story story, PlayState state) {
  final list = _listAt(story, state.cursor, state.cursor.path.length - 1);
  return list[state.cursor.last.index];
}

/// 這個 choice 節點在目前變數下可以顯示的選項，index 保留原始位置。
List<VisibleOption> visibleOptions(ChoiceNode node, Map<String, Object?> vars) => <VisibleOption>[
      for (var i = 0; i < node.options.length; i++)
        if (node.options[i].cond?.evaluate(vars) ?? true) VisibleOption(i, node.options[i]),
    ];

/// 游標往前一格，再套用副作用節點直到停下。
PlayState advance(Story story, PlayState state) {
  // choosing 時推進會靜默跳過整個選擇、不套用任何選項的 vars——那是最難查的一
  // 種 bug（玩家的選擇無聲消失）。這裡直接擋掉，不倚賴 UI 自律。
  if (state.status != PlayStatus.playing) return state;
  return _settle(story, _moveNext(story, state));
}

/// 讀檔還原用。存檔只記 cursor 與 vars，不記 status（`SaveData.toPlayState()`
/// 一律回 playing），但游標可能正停在一個 choice 上。那種情況下把 status 當成
/// playing 會讓 UI 不畫選項、而點擊直接 advance 過去——玩家的選擇被無聲跳過。
/// 因此 status 一律由「游標指著什麼節點」重算。
PlayState? resume(Story story, PlayState restored) {
  if (!_cursorResolvable(story, restored.cursor)) return null;
  // 交給 _settle 重算：它本來就負責「走到下一個會停頓的節點」與「場走完了要跳
  // 場還是結束」。讀檔與播放因此走同一條路，不會有第二套狀態推導邏輯。
  return _settle(story, restored);
}

/// 游標的每一層都要對得上現在的劇本結構。**最後一層允許越界**——那是「這個場
/// 走完了」的合法狀態（結局狀態的游標必然越界），由 _settle 處理成跳場或結局。
bool _cursorResolvable(Story story, Cursor cursor) {
  final scene = story.scenes[cursor.sceneId];
  if (scene == null) return false;
  var list = scene.nodes;
  for (var i = 0; i < cursor.path.length; i++) {
    final step = cursor.path[i];
    final isLast = i == cursor.path.length - 1;
    if (step.index < 0 || step.index >= list.length) return isLast;
    if (isLast) return true;
    final node = list[step.index];
    final branch = step.branch;
    if (branch == 'then' && node is IfNode) {
      list = node.then;
    } else if (branch == 'else' && node is IfNode) {
      list = node.orElse;
    } else if (branch != null && branch.startsWith('opt') && node is ChoiceNode) {
      final index = int.tryParse(branch.substring(3));
      if (index == null || index >= node.options.length) return false;
      list = node.options[index].then;
    } else {
      return false;
    }
  }
  return true;
}

/// 玩家選了 choice 節點裡第 [visibleIndex] 個可見選項。
PlayState choose(Story story, PlayState state, int visibleIndex) {
  final node = currentNode(story, state) as ChoiceNode;
  final visible = visibleOptions(node, state.vars);
  final picked = visible[visibleIndex];
  final option = picked.option;

  final next = state.copyWith(
    vars: _applyVars(story, state.vars, add: option.addVars, set: option.setVars),
    status: PlayStatus.playing,
  );

  if (option.then.isNotEmpty) {
    return _settle(story, next.copyWith(cursor: next.cursor.push('opt${picked.index}')));
  }
  final target = option.branch.isNotEmpty ? _resolveBranch(option.branch, next.vars) : option.goto;
  if (target != null) return _settle(story, _enterScene(story, next, target));
  return _settle(story, _moveNext(story, next));
}

// ─────────────────────────────────────────────────────────────────────────

Scene _scene(Story story, String id) {
  final scene = story.scenes[id];
  if (scene == null) throw StateError('場不存在：$id');
  return scene;
}

/// 走到 cursor 第 depth 層所在的節點陣列。
List<StoryNode> _listAt(Story story, Cursor cursor, int depth) {
  var list = _scene(story, cursor.sceneId).nodes;
  for (var i = 0; i < depth; i++) {
    final step = cursor.path[i];
    final node = list[step.index];
    final branch = step.branch;
    if (branch == 'then') {
      list = (node as IfNode).then;
    } else if (branch == 'else') {
      list = (node as IfNode).orElse;
    } else if (branch != null && branch.startsWith('opt')) {
      list = (node as ChoiceNode).options[int.parse(branch.substring(3))].then;
    } else {
      throw StateError('游標第 $i 層沒有分支標記：${cursor.toTokens()}');
    }
  }
  return list;
}

String? _resolveBranch(List<BranchRule> rules, Map<String, Object?> vars) {
  for (final rule in rules) {
    if (rule.cond == null || rule.cond!.evaluate(vars)) return rule.goto;
  }
  return null;
}

Map<String, Object?> _applyVars(
  Story story,
  Map<String, Object?> vars, {
  Map<String, num> add = const <String, num>{},
  Map<String, Object?> set = const <String, Object?>{},
}) {
  final next = Map<String, Object?>.from(vars);
  add.forEach((key, delta) {
    final current = next[key];
    final base = current is num ? current : 0;
    final spec = story.variables[key];
    final value = base + delta;
    next[key] = spec == null ? value : value.clamp(spec.min, spec.max);
  });
  next.addAll(set);
  return next;
}

PlayState _enterScene(Story story, PlayState state, String sceneId) {
  final scene = _scene(story, sceneId);
  // 場沒有宣告 bgm ＝ **未指定，沿用上一場**，不是停止播放。劇本要靜下來時是明
  // 寫 `bgm: "silence"` 的（多場在用）；若把「沒有欄位」當成停止，8 篇的結局場
  // 會全部無聲進場，而 01 篇的 E_A 明明寫了 `bgm: "sea"`。停止只由 `bgm` 節點
  // 帶 `id: null` 觸發。
  return state.copyWith(
    cursor: Cursor.atSceneStart(sceneId),
    bgmId: scene.bgm,
    status: PlayStatus.playing,
  );
}

/// 游標往前一格；走出當層就 pop 回上一層再往前，直到回到還有節點的層。
/// 全部走完（path 只剩一層且越界）就交給 _settle 決定跳場或結束。
PlayState _moveNext(Story story, PlayState state) {
  var cursor = state.cursor.withLastIndex(state.cursor.last.index + 1);
  while (cursor.path.length > 1 &&
      cursor.last.index >= _listAt(story, cursor, cursor.path.length - 1).length) {
    cursor = cursor.pop();
    cursor = cursor.withLastIndex(cursor.last.index + 1);
  }
  return state.copyWith(cursor: cursor);
}

/// 一路套用副作用節點，直到停在 n / d / cg / choice，或走完整個場。
PlayState _settle(Story story, PlayState state) {
  var current = state;
  while (true) {
    final list = _listAt(story, current.cursor, current.cursor.path.length - 1);
    if (current.cursor.last.index >= list.length) {
      final scene = _scene(story, current.cursor.sceneId);
      if (scene.isEnding) {
        return current.copyWith(status: PlayStatus.ended, endingId: scene.endingId);
      }
      final next = scene.next;
      if (next == null) {
        throw StateError('場 ${scene.id} 走到底，但既沒有 next 也不是結局');
      }
      current = _enterScene(story, current, next);
      continue;
    }

    final node = list[current.cursor.last.index];
    switch (node) {
      case NarrationNode() || DialogueNode() || CgNode():
        // 規範 §3.3：`d` 的 sprite 存在時「同時切換該角色表情並顯示」。
        if (node is DialogueNode && node.sprite != null) {
          current = current.copyWith(
            stage: _switchExpression(current.stage, node.who, node.sprite!),
          );
        }
        return current.copyWith(status: PlayStatus.playing);
      case ChoiceNode():
        return current.copyWith(status: PlayStatus.choosing);
      case ShowNode(:final who, :final sprite, :final filter):
        // sprite 為 null ＝ 無立繪角色登場，台上沒有東西要加。
        if (sprite != null) {
          current = current.copyWith(stage: _showSprite(current.stage, who, sprite, filter));
        }
      case HideNode():
        current = current.copyWith(stage: const <SpriteOnStage>[]);
      case BgmNode(:final id):
        current = current.copyWith(bgmId: id, clearBgm: id == null);
      case SfxNode():
        break; // 音效由 presentation 在進入節點時播；引擎只負責不停頓地走過去
      case AddNode(:final vars):
        current = current.copyWith(vars: _applyVars(story, current.vars, add: vars));
      case SetNode(:final vars):
        current = current.copyWith(vars: _applyVars(story, current.vars, set: vars));
      case IfNode(:final cond, :final then, :final orElse):
        final taken = cond.evaluate(current.vars);
        final branch = taken ? 'then' : 'else';
        final target = taken ? then : orElse;
        if (target.isEmpty) {
          current = _moveNext(story, current);
          continue;
        }
        current = current.copyWith(cursor: current.cursor.push(branch));
        continue;
    }
    current = _moveNext(story, current);
  }
}

/// `show`：設定某角色的立繪與濾鏡。既有角色**原位取代**，新角色才 append。
List<SpriteOnStage> _showSprite(
  List<SpriteOnStage> stage,
  String who,
  String sprite,
  String? filter,
) {
  final next = <SpriteOnStage>[...stage];
  final at = next.indexWhere((s) => s.who == who);
  final entry = SpriteOnStage(who: who, sprite: sprite, filter: filter);
  if (at < 0) {
    next.add(entry);
  } else {
    next[at] = entry;
  }
  return next;
}

/// `d` 切表情：**只換表情**，保留該角色現有的濾鏡與台上位置。
///
/// 兩個都是實際會被看見的：8 篇裡唯一一次 `show ... filter: memory_desaturate`
/// （08/S04）之後 vibia 還會講帶 sprite 的台詞，濾鏡若被洗掉，那整段回憶就失去
/// 視覺區隔；而「移除再 append」會讓雙人同台的兩人在對話中途左右對調
/// （07/S02、07/S03 各一次）。
List<SpriteOnStage> _switchExpression(List<SpriteOnStage> stage, String who, String sprite) {
  final next = <SpriteOnStage>[...stage];
  final at = next.indexWhere((s) => s.who == who);
  if (at < 0) {
    next.add(SpriteOnStage(who: who, sprite: sprite));
  } else {
    next[at] = SpriteOnStage(who: who, sprite: sprite, filter: next[at].filter);
  }
  return next;
}
