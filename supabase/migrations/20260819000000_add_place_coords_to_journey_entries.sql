-- 書架頁的地球儀要釘旅程停點，但 journey_entries 從來沒存過座標
-- （SavedPlace.toPlace() 一直是補 0）。補上兩個 nullable 欄位；舊記錄
-- 沒有座標可回填，維持 null，地球儀就不釘那些停點。
alter table public.journey_entries
  add column if not exists place_lat double precision,
  add column if not exists place_lng double precision;
