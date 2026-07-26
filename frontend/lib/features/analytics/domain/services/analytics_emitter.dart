import 'package:logging/logging.dart';

import 'package:context_app/features/analytics/domain/models/analytics_event.dart';
import 'package:context_app/features/analytics/domain/services/analytics_service.dart';

final Logger _log = Logger('AnalyticsEmitter');

/// Consent-gated entry point for emitting analytics events.
///
/// 存在的理由是「不要再複製一次 consent 檢查」：narration 埋點曾經因為
/// consent provider 在 `AsyncLoading` 期間丟 `StateError`，而 emit 是
/// fire-and-forget 沒人 await，例外落進 unhandled async gap——整個 container
/// 生命週期內每個事件都靜默失敗，兩個月完全沒有資料（見 BACKLOG F13 T1a）。
/// 解法收在一處：consent 怎麼讀由 [consentEnabled] 注入，失敗一定寫 log。
class AnalyticsEmitter {
  AnalyticsEmitter({
    required Future<bool> Function() consentEnabled,
    required AnalyticsService service,
  }) : _consentEnabled = consentEnabled,
       _service = service;

  final Future<bool> Function() _consentEnabled;
  final AnalyticsService _service;

  /// Fire-and-forget emit. Never throws——失敗只留 warning。
  ///
  /// 呼叫端多半在 UI 或 controller 流程中，不該為了埋點去 await 網路/磁碟。
  void emit(AnalyticsEvent event) {
    emitAndWait(event).catchError((Object error, StackTrace stackTrace) {
      _log.warning('Failed to emit ${event.type}', error, stackTrace);
    });
  }

  /// Awaitable emit, for callers that need to know the event was handed off
  /// (tests, or shutdown paths). Consent off ⇒ silently skipped.
  Future<void> emitAndWait(AnalyticsEvent event) async {
    if (!await _consentEnabled()) return;
    await _service.logEvent(event);
  }
}
