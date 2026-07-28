-- 地球儀首頁需要把每日故事釘在地圖上，所以景點要有經緯度。
-- 既有列由 scripts/backfill_place_coords.py 依 wikidata_id 查 P625 補齊，
-- 補不到的維持 null——App 端會照常在卡片列顯示，只是不釘上地球儀。
alter table public.daily_story_places
  add column if not exists latitude double precision,
  add column if not exists longitude double precision;

-- daily_story_places 沒有開放整表讀取，只逐欄 grant（見
-- 20260527000000_grant_daily_story_places_card_select.sql）。App 的
-- `daily_story_places!left(...)` join 要讀這兩欄，所以一併 grant。
grant select (latitude, longitude)
  on table public.daily_story_places to anon, authenticated;
