/// 導覽播放狀態錯誤類型
///
/// Presentation 層專用，用於 UI 顯示
/// 統一來自 Service 和 UseCase 層的錯誤
enum NarrationStateErrorType {
  /// 免費使用額度已用完（用戶訂閱層面）
  freeQuotaExceeded,

  /// 網路連線錯誤
  networkError,

  /// API 配置錯誤（API key 無效或缺失）
  configurationError,

  /// 伺服器錯誤（API 伺服器內部錯誤）
  serverError,

  /// 地理位置不支援
  unsupportedLocation,

  /// 內容生成失敗（生成的內容為空或無效）
  contentGenerationFailed,

  /// TTS 播放錯誤
  ttsPlaybackError,

  /// 未知錯誤
  unknown,
}

/// NarrationStateErrorType 擴展 - 提供 UI 相關功能
extension NarrationStateErrorTypeExtension on NarrationStateErrorType {
  /// 取得用戶友善的錯誤訊息（繁體中文）
  String get message {
    switch (this) {
      case NarrationStateErrorType.freeQuotaExceeded:
        return '今日的免費導覽已使用完畢，訂閱後可無限收聽。';
      case NarrationStateErrorType.networkError:
        return '網路連線失敗，請檢查您的網路連線後重試。';
      case NarrationStateErrorType.configurationError:
        return '應用程式配置錯誤，請聯絡技術支援。';
      case NarrationStateErrorType.serverError:
        return '伺服器暫時無法處理您的請求，請稍後再試。';
      case NarrationStateErrorType.unsupportedLocation:
        return '很抱歉，此服務在您所在的地區尚未開放。';
      case NarrationStateErrorType.contentGenerationFailed:
        return '無法生成導覽內容，請重試或選擇其他地點。';
      case NarrationStateErrorType.ttsPlaybackError:
        return '語音播放失敗，請檢查設備設定。';
      case NarrationStateErrorType.unknown:
        return '發生未預期的錯誤，請重試。';
    }
  }

  /// 是否為可重試的錯誤
  bool get isRetryable {
    switch (this) {
      case NarrationStateErrorType.networkError:
      case NarrationStateErrorType.serverError:
      case NarrationStateErrorType.contentGenerationFailed:
        return true;
      default:
        return false;
    }
  }

  /// 建議的重試等待時間（秒）
  int? get suggestedRetryDelay {
    switch (this) {
      case NarrationStateErrorType.networkError:
        return 5;
      case NarrationStateErrorType.serverError:
        return 30;
      case NarrationStateErrorType.contentGenerationFailed:
        return 3;
      default:
        return null;
    }
  }
}
