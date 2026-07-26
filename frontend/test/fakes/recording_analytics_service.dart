import 'package:context_app/features/analytics/domain/models/analytics_event.dart';
import 'package:context_app/features/analytics/domain/services/analytics_service.dart';

/// [AnalyticsService] that records every event it receives.
///
/// 埋點沒有 UI 產出，所以斷言只能落在「服務收到了什麼」。用計數/紀錄式 fake
/// 而不是 mock，與 test/fakes 其他假物件一致。
class RecordingAnalyticsService implements AnalyticsService {
  RecordingAnalyticsService({this.throwOnLog = false});

  /// 設為 true 時每次 [logEvent] 都丟錯，用來驗證埋點失敗不會影響使用者流程。
  final bool throwOnLog;

  final List<AnalyticsEvent> events = [];

  /// 依送出順序的事件名稱，斷言序列時比整個物件好讀。
  List<String> get types => events.map((e) => e.type).toList();

  /// 取第一個符合 [T] 的事件，找不到時回 null。
  T? firstOfType<T extends AnalyticsEvent>() {
    for (final event in events) {
      if (event is T) return event;
    }
    return null;
  }

  @override
  Future<void> logEvent(AnalyticsEvent event) async {
    events.add(event);
    if (throwOnLog) {
      throw StateError('analytics transport down');
    }
  }
}
