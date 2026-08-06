// data3.jsx — v3 geo data: story coordinates, user location, search index
(function(){
  const { PLACES, STORIES } = window.LS_DATA;
  // [lat, lng] + short label for the globe
  const STORY_GEO = {
    "ahwar":         { coord:[30.95, 47.05],   short:"阿瓦爾沼澤" },
    "agra":          { coord:[27.18, 78.02],   short:"阿格拉紅堡" },
    "stpeters-card": { coord:[41.902, 12.453], short:"聖伯多祿大殿" },
    "temple":        { coord:[24.062, 120.545],short:"四面佛寺" },
    "park":          { coord:[24.162, 120.647],short:"廊子公園" },
  };
  const USER_LOC = [24.151, 120.664]; // 台中

  const SEARCH_INDEX = [
    ...PLACES.filter(p=>p.coord).map(p=>({
      key:"pl-"+p.id, label:p.name, sub:(p.latin||"").split(" · ")[0], coord:p.coord, kind:"place", cat:p.cat, placeId:p.id })),
    ...STORIES.filter(s=>STORY_GEO[s.id]).map(s=>({
      key:"st-"+s.id, label:s.place, sub:(s.latin||"").split(" · ")[0], coord:STORY_GEO[s.id].coord, kind:"story" })),
  ];
  function searchSuggest(q){
    const s = q.trim().toLowerCase();
    if(!s) return [];
    const seen = new Set();
    return SEARCH_INDEX.filter(it=>{
      if(!(it.label.toLowerCase().includes(s) || (it.sub||"").toLowerCase().includes(s))) return false;
      if(seen.has(it.label)) return false;
      seen.add(it.label);
      return true;
    }).slice(0,5);
  }
  window.LS3 = { STORY_GEO, USER_LOC, SEARCH_INDEX, searchSuggest };
})();
