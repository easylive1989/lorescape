-- 四張 sync 表（20260511000000 建的）當初沒下任何 grant，service_role 因此
-- 連 select 都被擋：
--   {"code":"42501","message":"permission denied for table journey_entries"}
-- 其他表（daily_stories 等）沒這個問題，是 Supabase 的 default privileges
-- 有蓋到；這四張漏掉了。
--
-- 影響的不是 App——App 走 authenticated ＋ RLS policy，一直都正常。是伺服器
-- 側的 ops 工具全部查不動這四張表：lorescape-debug skill 的「Per-user sync
-- data」recipe、以及需要回填舊列的 script（例如 backfill_journey_entry_coords.py
-- 要把舊記錄的 place_lat / place_lng 從 Wikidata 補回來）。
--
-- service_role 本來就設計成繞過 RLS 的伺服器側角色，key 只在 VPS 的 .env 與
-- 本機 ops 環境，不隨 App 出貨，所以補上 grant 不改變 App 端的安全邊界。
grant all on table public.journey_entries to service_role;
grant all on table public.quick_guide_entries to service_role;
grant all on table public.trips to service_role;
grant all on table public.saved_locations to service_role;
