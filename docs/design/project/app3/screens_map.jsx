// screens_map.jsx — v3 detail map mode (米金色調, bottom place cards, saved FAB)
(function(){
  const { useState, useRef, useEffect } = React;
  const Icon = window.Icon;
  const { StatusBar, CategoryTag, GlyphThumb, SearchLoader } = window;
  const { PLACES } = window.LS_DATA;
  const { USER_LOC, searchSuggest } = window.LS3;

  const isLocal = p => p.coord && p.coord[0]>20 && p.coord[0]<26 && p.coord[1]>118 && p.coord[1]<123;

  function MapScreen({ params={}, back, go, openSheet, saved }){
    const elRef=useRef(null), mapRef=useRef(null);
    const [q, setQ] = useState("");
    const [loading, setLoading] = useState(params.mode==="focus" ? (params.name||"") : params.mode==="locate" ? "" : null);
    const sugs = searchSuggest(q);

    function pick(it){
      setQ("");
      setLoading(it.label);
      if(mapRef.current) mapRef.current.flyTo(it.coord, 14, {duration:1.1});
      setTimeout(()=>setLoading(null), 1150);
    }

    useEffect(()=>{
      const L=window.L;
      if(!L || mapRef.current || !elRef.current) return;
      const map=L.map(elRef.current,{ zoomControl:false, worldCopyJump:true, minZoom:2 });
      mapRef.current=map;
      L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        { attribution:'© OpenStreetMap contributors', maxZoom:18 }).addTo(map);
      PLACES.filter(p=>p.coord).forEach(p=>{
        const cls="map-pin"+((p.cat==="urban"||p.cat==="heritage")?(" map-pin--"+p.cat):"");
        const icon=L.divIcon({ className:"", html:'<div class="'+cls+'"><i></i></div>', iconSize:[30,30], iconAnchor:[15,30] });
        L.marker(p.coord,{icon}).addTo(map).on("click",()=>go("place",{id:p.id}));
      });
      if(params.mode==="locate"){
        const uicon=L.divIcon({ className:"", html:'<div class="uloc"><i></i></div>', iconSize:[20,20], iconAnchor:[10,10] });
        L.marker(USER_LOC,{icon:uicon}).addTo(map);
        map.setView(USER_LOC, 13);
      } else if(params.mode==="focus" && params.coord){
        map.setView(params.coord, 14);
      } else {
        fitLocal(map, L, false);
      }
      const t=setTimeout(()=>map.invalidateSize(), 260);
      const t2=setTimeout(()=>setLoading(null), 900);
      return ()=>{ clearTimeout(t); clearTimeout(t2); map.remove(); mapRef.current=null; };
    },[]);

    function fitLocal(map, L, fly){
      const g=L.featureGroup(PLACES.filter(isLocal).map(p=>L.marker(p.coord)));
      const b=g.getBounds().pad(.3);
      fly ? map.flyToBounds(b,{maxZoom:13}) : map.fitBounds(b,{maxZoom:13});
    }
    function focus(p){
      if(mapRef.current && p.coord) mapRef.current.flyTo(p.coord, 14, { duration:1.1 });
    }

    return (
      <div className="screen mapv3 fade-enter">
        <StatusBar dark time="19:16"/>
        <div className="map-el" ref={elRef}></div>
        {loading!==null && <SearchLoader label={params.mode==="locate"&&!loading?"定位中":"搜尋地點中"} name={loading||null}/>}
        <div className="map-top">
          <div className="map-hd">
            <div>
              <div className="map-hd__eyebrow">{params.mode==="locate" ? "以目前位置探索 · Nearby" : PLACES.length+" 個地點 · Atlas"}</div>
              <h1>探索</h1>
            </div>
            <div className="map-hd__acts">
              <button className="iconbtn" style={{background:"var(--paper-raised)",boxShadow:"var(--e1)",position:"relative"}}
                      onClick={()=>openSheet("saved")} aria-label="儲存的地點">
                <Icon name="bookmark-fill" size={20}/>
                {saved.length>0 && <span className="fab__badge">{saved.length}</span>}
              </button>
              <button className="iconbtn" style={{background:"var(--paper-raised)",boxShadow:"var(--e1)"}}
                      onClick={()=>openSheet("filter")} aria-label="篩選"><Icon name="sliders" size={21}/></button>
              <button className="iconbtn" style={{background:"var(--clay)",color:"#fff",boxShadow:"var(--e1)"}}
                      onClick={()=>{ const m=mapRef.current, L=window.L; if(m&&L) fitLocal(m,L,true); }} aria-label="重新整理">
                <Icon name="refresh" size={19}/></button>
            </div>
          </div>
          <div className="search map-search" style={{margin:"0 6px"}}>
            <Icon name="search" size={20}/>
            <input placeholder="搜尋地點、城市或地標……" value={q} onChange={e=>setQ(e.target.value)}/>
            {q && <button className="hm-clear" onClick={()=>setQ("")} aria-label="清除"><Icon name="x" size={18}/></button>}
          </div>
          {sugs.length>0 && (
            <div className="hm-sug">
              {sugs.map(it=>(
                <div key={it.key} className="hm-sug__row"
                     onClick={()=>pick(it)}>
                  <div className="hm-sug__ic"><Icon name={it.kind==="story"?"book-open":"location"} size={17}/></div>
                  <div className="hm-sug__b">
                    <div className="hm-sug__t">{it.label}</div>
                    {it.sub && <div className="hm-sug__s">{it.sub}</div>}
                  </div>
                  <Icon name="chevron-right" size={18} style={{color:"var(--ink-3)"}}/>
                </div>
              ))}
            </div>
          )}
        </div>
        <div className="map-cards">
          {[...PLACES].sort((a,b)=> (isLocal(b)?1:0)-(isLocal(a)?1:0)).map(p=>(
            <div key={p.id} className="map-card" onClick={()=>focus(p)}>
              <div className="map-card__thumb">
                {p.glyph ? <GlyphThumb cat={p.cat}/> : <img src={p.img} alt=""/>}
              </div>
              <div className="map-card__b">
                <div className="map-card__name">{p.name}</div>
                {p.latin && <div className="map-card__latin">{p.latin.split(" · ")[0]}</div>}
                <div><CategoryTag cat={p.cat}/></div>
              </div>
              <button className="map-card__go" onClick={(e)=>{ e.stopPropagation(); go("place",{id:p.id}); }} aria-label="查看地點">
                <Icon name="chevron-right" size={20}/></button>
            </div>
          ))}
        </div>
        <button className="fab" onClick={back} aria-label="返回地球儀">
          <Icon name="globe" size={24}/>
        </button>
      </div>
    );
  }
  window.MapScreen = MapScreen;
})();
