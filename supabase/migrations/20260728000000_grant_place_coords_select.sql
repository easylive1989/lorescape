-- `daily_story_places.latitude` / `longitude`（型別 numeric）早在
-- 20260521120000 就為 IG 圖卡功能加過，是 admin 人工填的欄位；
-- publisher/src/lorescape_publisher/card/mapper.py 讀這兩欄把座標渲染到
-- 圖卡上。20260527000000 曾明文把它們列為 operational、admin-only 欄位，
-- 刻意不 grant 給 anon/authenticated。
--
-- 這裡刻意推翻那個決定：v3 地球儀首頁要把每日故事釘在地圖上，App 端
-- 也需要讀這兩欄。座標本身沿用既有欄位、不新增欄位也不改型別，
-- 圖卡渲染與地球儀首頁共用同一組座標。
-- 既有列若還沒被圖卡流程填過座標，由
-- scripts/backfill_place_coords.py 依 wikidata_id 查 P625 補齊，
-- 補不到的維持 null——App 端會照常在卡片列顯示，只是不釘上地球儀。
grant select (latitude, longitude)
  on table public.daily_story_places to anon, authenticated;
