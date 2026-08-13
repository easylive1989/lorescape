/// 劇本的領域模型。**不得 import package:flutter/***——這一層要能用 dart test 跑。
sealed class StoryNode {
  const StoryNode();
}

final class NarrationNode extends StoryNode {
  const NarrationNode({required this.text, this.style});
  final String text;
  final String? style;
}

final class DialogueNode extends StoryNode {
  const DialogueNode({required this.who, required this.text, this.sprite});
  final String who;
  final String text;
  final String? sprite;
}

final class ShowNode extends StoryNode {
  const ShowNode({required this.who, this.sprite, this.filter});
  final String who;

  /// null ＝ 無立繪角色登場（該角色 characters[who].sprites 為 null 時常見）。
  final String? sprite;
  final String? filter;
}

final class HideNode extends StoryNode {
  const HideNode();
}

final class SfxNode extends StoryNode {
  const SfxNode(this.id);
  final String id;
}

final class BgmNode extends StoryNode {
  /// null ＝ 停止背景音樂。
  const BgmNode(this.id);
  final String? id;
}

final class CgNode extends StoryNode {
  const CgNode({required this.id, required this.fullscreen, required this.hideDialogue});
  final String id;
  final bool fullscreen;
  final bool hideDialogue;
}

final class AddNode extends StoryNode {
  const AddNode(this.vars);
  final Map<String, num> vars;
}

final class SetNode extends StoryNode {
  const SetNode(this.vars);
  final Map<String, Object?> vars;
}

final class IfNode extends StoryNode {
  const IfNode({required this.cond, required this.then, this.orElse = const <StoryNode>[]});
  final Condition cond;
  final List<StoryNode> then;
  final List<StoryNode> orElse;
}

final class ChoiceNode extends StoryNode {
  const ChoiceNode(this.options);
  final List<ChoiceOption> options;
}

/// 條件。未宣告的變數取 null（規範 §3.3）。
final class Condition {
  const Condition({required this.varName, required this.op, required this.value});
  final String varName;
  final String op;
  final Object? value;

  bool evaluate(Map<String, Object?> vars) {
    final actual = vars[varName];
    final expected = value;
    if (op == '==') return actual == expected;
    if (op == '!=') return actual != expected;
    // 大小比較只在兩邊都是數字時成立；型別不符一律 false，不丟例外。
    if (actual is! num || expected is! num) return false;
    return switch (op) {
      '>=' => actual >= expected,
      '<=' => actual <= expected,
      '>' => actual > expected,
      '<' => actual < expected,
      _ => false,
    };
  }
}

/// 選項的跳轉規則，依序求值，第一個成立者生效。cond 為 null ＝ default。
final class BranchRule {
  const BranchRule({this.cond, required this.goto});
  final Condition? cond;
  final String goto;
}

final class ChoiceOption {
  const ChoiceOption({
    required this.text,
    this.cond,
    this.addVars = const <String, num>{},
    this.setVars = const <String, Object?>{},
    this.then = const <StoryNode>[],
    this.goto,
    this.branch = const <BranchRule>[],
  });

  /// cond 不成立時這個選項不顯示（規範漏寫，資料有 4 處在用）。
  final Condition? cond;
  final String text;
  final Map<String, num> addVars;
  final Map<String, Object?> setVars;
  final List<StoryNode> then;
  final String? goto;
  final List<BranchRule> branch;
}

final class Scene {
  const Scene({
    required this.id,
    required this.title,
    required this.background,
    required this.nodes,
    this.bgm,
    this.next,
    this.isEnding = false,
    this.endingId,
  });
  final String id;
  final String title;
  final String background;
  final String? bgm;
  final List<StoryNode> nodes;
  final String? next;
  final bool isEnding;
  final String? endingId;
}

final class VariableSpec {
  const VariableSpec({
    required this.label,
    required this.initial,
    required this.min,
    required this.max,
  });
  final String label;
  final num initial;
  final num min;
  final num max;
}

final class CharacterSpec {
  const CharacterSpec({required this.name, required this.isPlayer, this.sprites});
  final String name;
  final bool isPlayer;

  /// null ＝ 無立繪角色（主角或只有名字的路人）。
  final Map<String, String>? sprites;
}

final class EndingSpec {
  const EndingSpec({required this.title, required this.note});
  final String title;
  final String note;
}

final class StoryMeta {
  const StoryMeta({
    required this.id,
    required this.pack,
    required this.order,
    required this.title,
    required this.subtitle,
    required this.estimatedMinutes,
    required this.locale,
  });
  final String id;
  final String pack;
  final int order;
  final String title;
  final String subtitle;
  final int estimatedMinutes;
  final String locale;
}

final class Story {
  const Story({
    required this.meta,
    required this.variables,
    required this.characters,
    required this.backgrounds,
    required this.missingAssets,
    required this.start,
    required this.scenes,
    required this.endings,
  });
  final StoryMeta meta;
  final Map<String, VariableSpec> variables;
  final Map<String, CharacterSpec> characters;

  /// key → 檔名（不含路徑）。
  final Map<String, String> backgrounds;

  /// 尚未產出的資產：type（'bgm' / 'sfx' / 'cg'）→ id 集合。
  final Map<String, Set<String>> missingAssets;
  final String start;
  final Map<String, Scene> scenes;
  final Map<String, EndingSpec> endings;
}
