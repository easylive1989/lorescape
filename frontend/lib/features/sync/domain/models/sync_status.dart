/// 最近一次同步的結果。
///
/// 這個型別存在的理由是一個代價高昂的教訓：同步的每一層（SyncEngine 的
/// per-item try/catch、SyncCoordinator 的外層 catch）都把錯誤吞成 log，於是
/// 「App 每次上傳都被 PostgREST 退回」這件事在畫面上完全看不出來，四張 sync
/// 表長期 0 筆卻被誤判成「沒人開同步」。失敗可以不吵，但不能沒有痕跡。
class SyncStatus {
  const SyncStatus({
    required this.finishedAt,
    required this.pushed,
    required this.pulled,
    required this.errors,
  });

  final DateTime finishedAt;

  /// 這次推上去與拉下來的筆數。
  final int pushed;
  final int pulled;

  /// 這次遇到的錯誤訊息（每筆一則，已去重）。空的代表全部成功。
  final List<String> errors;

  bool get isHealthy => errors.isEmpty;

  /// 顯示給使用者看的第一則錯誤，過長會截斷。
  String? get firstError {
    if (errors.isEmpty) return null;
    final message = errors.first;
    return message.length <= 160 ? message : '${message.substring(0, 160)}…';
  }
}
