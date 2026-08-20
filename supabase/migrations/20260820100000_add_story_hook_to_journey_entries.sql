-- App 端每次上傳 journey entry 都帶著 story_hook 欄位
-- （supabase_journey_remote_data_source.dart 的 _toRow），但這張表從
-- 20260511000000 建立以來就沒有這個欄位。PostgREST 對付不存在的欄位是直接
-- 退回整個請求（42703 / PGRST204），而 SyncEngine 的 push 與 fullSync 只
-- 寫 log 不拋出——所以每一筆上傳都靜默失敗，四張 sync 表從頭到尾 0 筆。
--
-- 型別用 jsonb：_toRow 送的是 StoryHook.toJson() 的物件，_fromRow 也是當成
-- Map 讀回來。nullable，因為沒有 hook 的流程（舊記錄、快速導覽）送 null。
alter table public.journey_entries
  add column if not exists story_hook jsonb;
