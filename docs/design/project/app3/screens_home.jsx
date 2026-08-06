// screens_home.jsx — v3 home: search + globe (daily story) + story card rail
(function(){
  const { useState, useRef } = React;
  const Icon = window.Icon;
  const { StatusBar, GlobeView, SearchLoader } = window;
  const { STORIES } = window.LS_DATA;
  const { STORY_GEO, searchSuggest } = window.LS3;

  const GEO_STORIES = STORIES.filter(s=>STORY_GEO[s.id]);
  const PINS = GEO_STORIES.map(s=>({ id:s.id, coord:STORY_GEO[s.id].coord, label:STORY_GEO[s.id].short }));
  const STRIDE = 324; // card 312 + gap 12

  function HomeScreen({ go }){
    const [active, setActive] = useState(0);
    const [q, setQ] = useState("");
    const [zoom, setZoom] = useState(false);
    const [loading, setLoading] = useState(null);
    const rowRef = useRef(null);
    const sugs = searchSuggest(q);

    function enterMap(params){
      if(zoom) return;
      setZoom(true);
      setTimeout(()=>go("map", params), 640);
    }
    function onScroll(e){
      const i = Math.max(0, Math.min(GEO_STORIES.length-1, Math.round(e.target.scrollLeft/STRIDE)));
      if(i!==active) setActive(i);
    }
    function onCard(i, s){
      if(i===active){ go("reader", { story:s }); }
      else if(rowRef.current){ rowRef.current.scrollTo({ left:i*STRIDE, behavior:"smooth" }); }
    }

    return (
      <div className={"screen home fade-enter"+(zoom?" is-zoom":"")}>
        <StatusBar dark time="19:16"/>
        {loading && <SearchLoader name={loading}/>}

        <div className="hm-globe">
          <GlobeView pins={PINS} activeId={GEO_STORIES[active].id}/>
        </div>

        <div className="hm-top">
          <div className="hm-brandrow">
            <div>
              <div className="masthead__eyebrow">每日故事 · Daily Lore</div>
              <div className="hm-brand">Lorescape</div>
            </div>
            <div className="hm-acts">
              <button className="iconbtn hm-ib" onClick={()=>go("history")} aria-label="歷程書架"><Icon name="book" size={21}/></button>
              <button className="iconbtn hm-ib" onClick={()=>go("settings")} aria-label="設定"><Icon name="settings" size={21}/></button>
            </div>
          </div>
          <div className="search hm-search">
            <Icon name="search" size={20}/>
            <input placeholder="搜尋地點、城市或地標……" value={q} onChange={e=>setQ(e.target.value)}/>
            {q && <button className="hm-clear" onClick={()=>setQ("")} aria-label="清除"><Icon name="x" size={18}/></button>}
          </div>
          {sugs.length>0 && (
            <div className="hm-sug">
              {sugs.map(it=>(
                <div key={it.key} className="hm-sug__row"
                     onClick={()=>{ setQ(""); setLoading(it.label); enterMap({ mode:"focus", coord:it.coord, name:it.label, placeId:it.placeId }); }}>
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

        <div className="globe-side">
          <button className="gsbtn gsbtn--clay" onClick={()=>enterMap({mode:"locate"})}>
            <Icon name="locate" size={22}/><span>定位</span></button>
        </div>

        <div className="hm-deck">
          <div className="hm-deck__lab">每日故事</div>
          <div className="hm-cards" ref={rowRef} onScroll={onScroll}>
            {GEO_STORIES.map((s,i)=>(
              <div key={s.id} className={"hm-card"+(i===active?" is-on":"")} onClick={()=>onCard(i,s)}>
                <div className="hm-card__thumb"><img src={s.img} alt="" draggable="false"/></div>
                <div className="hm-card__b">
                  <div className="hm-card__tag"><span>{s.date}</span></div>
                  <div className="hm-card__t">{s.title}</div>
                  <div className="hm-card__m">{s.place}</div>
                </div>
                <Icon name="chevron-right" size={20} style={{color:"var(--ink-3)",flex:"none"}}/>
              </div>
            ))}
          </div>
          <div className="deck-progress hm-dots">
            {GEO_STORIES.map((_,i)=>(<i key={i} className={i===active?"is-on":""}/>))}
          </div>
        </div>
      </div>
    );
  }
  window.HomeScreen = HomeScreen;
})();
