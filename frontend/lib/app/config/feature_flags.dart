/// 編譯期功能開關。只放「暫時關掉、日後可能整組打開」的旗標，
/// 不做通用的 remote config 機制。
library;

/// 書架（旅程／歷程）功能暫時隱藏（2026-08-11）。
///
/// 關掉時：首頁不顯示書架入口按鈕，且 `/journey`、`/trip*` 六條路由不註冊
/// ——殘留的 deep link 會落到 router 的 errorBuilder 導回首頁。
/// `features/journey/`、`features/trip/` 的程式碼與測試都保留，改回 `true`
/// 即整組復活，歷史記錄也還在（narration 播完仍照常寫入 journey）。
const bool kBookshelfEnabled = false;
