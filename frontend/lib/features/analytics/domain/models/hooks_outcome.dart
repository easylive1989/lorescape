/// 一次故事鉤子請求的結果，對應 `StoryHookStatus` 的終端狀態。
///
/// 用來在 GA4 上分開「沒給角度」與「給了角度但沒人挑」——只看
/// `hooks_requested` 與 `hook_selected` 的差額分不出這兩件事。
///
/// 值以 [wireName]（snake_case）送出，改名等於改壞下游報表。
enum HooksOutcome {
  /// 後端回了至少一個角度。
  success,

  /// 後端有資料但挑不出明確角度（仍可「直接聽故事」）。
  empty,

  /// 來源內容不足，不該再勸使用者重試。
  insufficientSource,

  /// 請求失敗（網路、後端錯誤）。
  error;

  /// Wire-format identifier (snake_case).
  String get wireName {
    switch (this) {
      case HooksOutcome.success:
        return 'success';
      case HooksOutcome.empty:
        return 'empty';
      case HooksOutcome.insufficientSource:
        return 'insufficient_source';
      case HooksOutcome.error:
        return 'error';
    }
  }
}
