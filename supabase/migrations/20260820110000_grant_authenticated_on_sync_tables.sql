-- 這才是「同步從來沒成功過」的根因。
--
-- 20260511000000 建這四張表時給了完整的 RLS policy（每張表 select / insert /
-- update / delete 各一條，都以 auth.uid() = user_id 為條件），但**沒有給任何
-- 角色 grant**。RLS 只決定「看得到哪些列」，table 層級的權限是另一回事：沒有
-- grant，PostgreSQL 在 RLS 之前就先擋下來，App 拿到的是
--   PostgrestException(message: permission denied for table journey_entries,
--                      code: 42501)
-- 而 SyncEngine 把它吞成 log，所以四張表長期 0 筆卻沒有任何徵兆。
--
-- 20260820000000 補過同樣的洞，但只補了 service_role——那是當時 debug 用的角
-- 色。App 走的是 authenticated（匿名登入拿到的 JWT 也是這個角色），要另外給。
--
-- 不給 anon：沒有 JWT 的請求本來就不該碰到使用者資料，而且 App 一啟動就會先
-- 建立 session（main.dart 的 _ensureSignedIn），不存在以 anon 讀寫的情況。
grant select, insert, update, delete
  on table public.journey_entries to authenticated;
grant select, insert, update, delete
  on table public.quick_guide_entries to authenticated;
grant select, insert, update, delete
  on table public.trips to authenticated;
grant select, insert, update, delete
  on table public.saved_locations to authenticated;
