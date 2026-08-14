import 'package:lorescape_vn/src/visual_novel/domain/story.dart';

/// story.json → Story。未知的節點型別一律丟 FormatException——靜默忽略會讓
/// 劇本默默少走一段，那種錯到播放時才看得出來，而且看起來像文案問題。
Story parseStory(Map<String, dynamic> json) {
  final meta = json['meta'] as Map<String, dynamic>;
  return Story(
    meta: StoryMeta(
      id: meta['id'] as String,
      pack: meta['pack'] as String,
      order: meta['order'] as int,
      title: meta['title'] as String,
      subtitle: (meta['subtitle'] as String?) ?? '',
      estimatedMinutes: meta['estimatedMinutes'] as int,
      locale: (meta['locale'] as String?) ?? 'zh-Hant',
    ),
    variables: (json['variables'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, _variable(value as Map<String, dynamic>)),
    ),
    characters: (json['characters'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, _character(value as Map<String, dynamic>)),
    ),
    backgrounds: (json['backgrounds'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, value as String),
    ),
    missingAssets: _missingAssets(json['missingAssets'] as List<dynamic>?),
    start: json['start'] as String,
    scenes: (json['scenes'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, _scene(key, value as Map<String, dynamic>)),
    ),
    endings: (json['endings'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(
        key,
        EndingSpec(
          title: (value as Map<String, dynamic>)['title'] as String,
          note: (value['note'] as String?) ?? '',
        ),
      ),
    ),
  );
}

VariableSpec _variable(Map<String, dynamic> json) => VariableSpec(
  label: (json['label'] as String?) ?? '',
  initial: (json['initial'] as num?) ?? 0,
  min: (json['min'] as num?) ?? double.negativeInfinity,
  max: (json['max'] as num?) ?? double.infinity,
);

CharacterSpec _character(Map<String, dynamic> json) {
  final sprites = json['sprites'] as Map<String, dynamic>?;
  return CharacterSpec(
    name: json['name'] as String,
    isPlayer: (json['isPlayer'] as bool?) ?? false,
    sprites: sprites?.map((key, value) => MapEntry(key, value as String)),
  );
}

Map<String, Set<String>> _missingAssets(List<dynamic>? json) {
  final result = <String, Set<String>>{};
  for (final entry in json ?? const <dynamic>[]) {
    final map = entry as Map<String, dynamic>;
    // 大部分條目用複數 ids（List），但 filter 類型（如 memory_desaturate）
    // 用單數 id（String）——規範漏寫，資料在用，兩種都要接住。
    final idsField = map['ids'] as List<dynamic>?;
    final ids = idsField != null
        ? idsField.cast<String>()
        : <String>[map['id'] as String];
    result.putIfAbsent(map['type'] as String, () => <String>{}).addAll(ids);
  }
  return result;
}

Scene _scene(String id, Map<String, dynamic> json) => Scene(
  id: id,
  title: (json['title'] as String?) ?? '',
  background: json['background'] as String,
  bgm: json['bgm'] as String?,
  nodes: _nodes(json['nodes'] as List<dynamic>),
  next: json['next'] as String?,
  isEnding: (json['isEnding'] as bool?) ?? false,
  endingId: json['endingId'] as String?,
);

List<StoryNode> _nodes(List<dynamic>? json) => (json ?? const <dynamic>[])
    .map((e) => _node(e as Map<String, dynamic>))
    .toList();

StoryNode _node(Map<String, dynamic> json) {
  final type = json['t'] as String?;
  return switch (type) {
    'n' => NarrationNode(
      text: json['text'] as String,
      style: json['style'] as String?,
    ),
    'd' => DialogueNode(
      who: json['who'] as String,
      text: json['text'] as String,
      sprite: json['sprite'] as String?,
    ),
    'show' => ShowNode(
      who: json['who'] as String,
      // 無立繪角色（characters[who].sprites 為 null）登場時 sprite 為 null。
      sprite: json['sprite'] as String?,
      filter: json['filter'] as String?,
    ),
    'hide' => const HideNode(),
    'sfx' => SfxNode(json['id'] as String),
    'bgm' => BgmNode(json['id'] as String?),
    'cg' => CgNode(
      id: json['id'] as String,
      fullscreen: (json['fullscreen'] as bool?) ?? true,
      hideDialogue: (json['hideDialogue'] as bool?) ?? true,
    ),
    'add' => AddNode(_numVars(json['vars'] as Map<String, dynamic>)),
    'set' => SetNode(
      Map<String, Object?>.from(json['vars'] as Map<String, dynamic>),
    ),
    'if' => IfNode(
      cond: _condition(json['cond'] as Map<String, dynamic>),
      then: _nodes(json['then'] as List<dynamic>?),
      orElse: _nodes(json['else'] as List<dynamic>?),
    ),
    'choice' => ChoiceNode(
      (json['options'] as List<dynamic>)
          .map((e) => _option(e as Map<String, dynamic>))
          .toList(),
    ),
    _ => throw FormatException('未知的節點型別：$type'),
  };
}

Map<String, num> _numVars(Map<String, dynamic> json) =>
    json.map((key, value) => MapEntry(key, value as num));

Condition _condition(Map<String, dynamic> json) => Condition(
  varName: json['var'] as String,
  op: json['op'] as String,
  value: json['value'],
);

ChoiceOption _option(Map<String, dynamic> json) {
  final cond = json['cond'] as Map<String, dynamic>?;
  final add = json['add'] as Map<String, dynamic>?;
  final set = json['set'] as Map<String, dynamic>?;
  return ChoiceOption(
    text: json['text'] as String,
    cond: cond == null ? null : _condition(cond),
    addVars: add == null ? const <String, num>{} : _numVars(add),
    setVars: set == null
        ? const <String, Object?>{}
        : Map<String, Object?>.from(set),
    then: _nodes(json['then'] as List<dynamic>?),
    goto: json['goto'] as String?,
    branch: ((json['branch'] as List<dynamic>?) ?? const <dynamic>[])
        .map((e) => _branchRule(e as Map<String, dynamic>))
        .toList(),
  );
}

BranchRule _branchRule(Map<String, dynamic> json) {
  final cond = json['cond'] as Map<String, dynamic>?;
  return BranchRule(
    cond: cond == null ? null : _condition(cond),
    goto: json['goto'] as String,
  );
}
