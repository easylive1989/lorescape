/// 節點指標。這份路徑同時就是呼叫堆疊的投影——每一層記「在哪個 index」與
/// 「從那個 index 的節點往哪個分支鑽進去」，因此讀檔時不必另存 stack，
/// 從場的根節點陣列依路徑重走一次就回到原位。
final class CursorStep {
  const CursorStep(this.index, [this.branch]);

  final int index;

  /// 'then' / 'else' / `opt<n>`；null ＝ 沒有再往下鑽（這是最後一層）。
  final String? branch;

  CursorStep withIndex(int value) => CursorStep(value, branch);
  CursorStep withBranch(String? value) => CursorStep(index, value);
}

final class Cursor {
  const Cursor({required this.sceneId, required this.path});

  factory Cursor.atSceneStart(String sceneId) =>
      Cursor(sceneId: sceneId, path: const <CursorStep>[CursorStep(0)]);

  /// ['12','then','3'] → [(12,'then'), (3,null)]
  factory Cursor.fromTokens(String sceneId, List<String> tokens) {
    final steps = <CursorStep>[];
    for (final token in tokens) {
      final index = int.tryParse(token);
      if (index != null) {
        steps.add(CursorStep(index));
      } else {
        if (steps.isEmpty) throw FormatException('分支 token 前面沒有 index：$tokens');
        steps[steps.length - 1] = steps.last.withBranch(token);
      }
    }
    if (steps.isEmpty) throw FormatException('空的游標路徑：$tokens');
    return Cursor(sceneId: sceneId, path: steps);
  }

  final String sceneId;
  final List<CursorStep> path;

  CursorStep get last => path.last;

  List<String> toTokens() => <String>[
        for (final step in path) ...<String>[
          '${step.index}',
          if (step.branch != null) step.branch!,
        ],
      ];

  String get readKey => '$sceneId#${toTokens().join('.')}';

  Cursor withLastIndex(int index) => Cursor(
        sceneId: sceneId,
        path: <CursorStep>[...path.take(path.length - 1), last.withIndex(index)],
      );

  /// 在最後一層記下要往哪個分支鑽，並開新的一層（index 0）。
  Cursor push(String branch) => Cursor(
        sceneId: sceneId,
        path: <CursorStep>[
          ...path.take(path.length - 1),
          last.withBranch(branch),
          const CursorStep(0),
        ],
      );

  /// 收掉最後一層，回到呼叫端（上一層），並清掉上一層的分支標記。
  Cursor pop() {
    if (path.length <= 1) throw StateError('已經在最外層，不能再 pop');
    final parent = path[path.length - 2].withBranch(null);
    return Cursor(
      sceneId: sceneId,
      path: <CursorStep>[...path.take(path.length - 2), parent],
    );
  }
}
