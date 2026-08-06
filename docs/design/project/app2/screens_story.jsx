// screens_story.jsx — Place flow (loading / options / empty) + editorial Reader
(function(){
  const { useState, useEffect } = React;
  const Icon = window.Icon;
  const { StatusBar, CategoryTag } = window;
  const { PLACES, STPETERS_STORY, CAT, genStory, genOptions } = window.LS_DATA;

  // ---------- Editorial reader (shared) ----------
  function ReaderView({ story, onBack, onExplore }){
    const [playing, setPlaying] = useState(false);
    const c = CAT[story.cat] || CAT.urban;
    const heroStyle = story.glyph
      ? { background:"linear-gradient(160deg, var(--cat-"+c.cls+"-ink), var(--ink-bg))" } : {};
    return (
      <div className="screen fade-enter" style={{background:"var(--read-bg)"}}>
        <StatusBar light time="8:20"/>
        <div className="topbar is-dark" style={{background:"var(--ink-bg)"}}>
          <button className="iconbtn" onClick={onBack} aria-label="返回"
                  style={{color:"var(--clay)"}}><Icon name="chevron-left" size={26}/></button>
          <div className="topbar__title is-left" style={{color:"var(--on-dark)"}}>{story.place}</div>
          <div className="topbar__spacer"/>
        </div>
        <div className="screen__scroll" style={{paddingTop:0}}>
          <div className="reader">
            <div className="reader__hero" style={heroStyle}>
              {!story.glyph && <img src={story.img} alt=""/>}
              {story.glyph && <div className="glyph-thumb" style={{color:"rgba(255,255,255,.5)"}}><Icon name={c.glyph} size={120} stroke={1.1}/></div>}
              <div className="hero__scrim"/>
              <div className="hero__overline"><span className="chapter-badge">{story.chapter}</span></div>
              <div className="hero__place-latin overline" style={{color:"rgba(255,255,255,.8)"}}>{story.latin}</div>
              <div className="hero__cap">
                <h2>{story.title}</h2>
                {!story.audio && <div className="serif" style={{fontSize:16,opacity:.9,fontStyle:"italic"}}>{story.sub}</div>}
              </div>
            </div>
            <div className="reader__body" style={{paddingBottom: story.audio?120:48}}>
              <p className="reader__lede">
                <span className="dropcap">{story.dropcap}</span>{story.body[0]}
              </p>
              {story.body.slice(1).map((para,i)=><p key={i}>{para}</p>)}
              <div className="reader__quote">
                <div className="q">{story.quote.q}</div>
                <div className="by">{story.quote.by}</div>
              </div>
              <div className="reader__footer">{story.footer} · {story.date}</div>
              {onExplore && (
                <div className="reader__more">
                  <div className="reader__more-eyebrow overline">想知道更多嗎?</div>
                  <button className="btn btn--primary reader__more-btn" onClick={onExplore}>
                    <Icon name="sparkle" size={20}/>
                    探索更多故事
                  </button>
                </div>
              )}
            </div>
          </div>
        </div>
        {story.audio && (
          <div className="audiobar">
            <button className="audiobar__sk"><Icon name="skip-back" size={20}/></button>
            <button className="audiobar__play" onClick={()=>setPlaying(p=>!p)}>
              <Icon name={playing?"pause":"play"} size={22}/></button>
            <button className="audiobar__sk"><Icon name="skip-fwd" size={20}/></button>
            <div className="audiobar__track">
              <div className="audiobar__fill" style={{width:(playing?34:4)+"%"}}/>
            </div>
            <div className="audiobar__pct">{playing?34:4}%</div>
          </div>
        )}
      </div>
    );
  }

  function ReaderScreen({ params, back, go }){
    const s = params.story;
    const explore = go ? () => go("place", { place:{
      id:"gen-"+(s.id||"loc"), name:s.place, cat:s.cat||"heritage",
      img:s.img, glyph:s.glyph, latin:s.latin, state:"loading",
    } }) : null;
    return <ReaderView story={s} onBack={back} onExplore={explore}/>;
  }

  // ---------- Place flow ----------
  function PlaceScreen({ params, back }){
    const place = params.place || PLACES.find(p=>p.id===params.id);
    const c = CAT[place.cat];
    const [phase, setPhase] = useState(place.state==="empty" ? "empty" : "scan");
    const [story, setStory] = useState(null);
    const [chosen, setChosen] = useState(null);
    const opts = genOptions(place);
    const GMS = window.GEN_MS || 3600;

    useEffect(()=>{
      if(phase==="scan"){
        const t = setTimeout(()=>setPhase("options"), GMS);
        return ()=>clearTimeout(t);
      }
      if(phase==="writing"){
        const t = setTimeout(()=>{
          const base = place.id==="stpeters" ? STPETERS_STORY : genStory(place);
          setStory(chosen ? { ...base, title:chosen.t, sub:place.name } : base);
          setPhase("reader");
        }, GMS);
        return ()=>clearTimeout(t);
      }
    }, [phase]);

    if(phase==="reader") return <ReaderView story={story||STPETERS_STORY} onBack={back}/>;

    if(phase==="scan" || phase==="writing"){
      const writing = phase==="writing";
      return (
        <div className="screen genscr fade-enter">
          <StatusBar light time="8:07"/>
          <button className="iconbtn on-photo" onClick={back} aria-label="返回"
                  style={{position:"absolute",top:"calc(var(--safe-top) + 6px)",left:14,zIndex:40}}>
            <Icon name="chevron-left" size={26}/></button>
          <div className="genscr__hd" style={place.glyph ? { background:"linear-gradient(160deg, var(--cat-"+c.cls+"-ink), var(--ink-bg))" } : {}}>
            {!place.glyph && <img src={place.img} alt=""/>}
            <div className="hero__scrim"></div>
            <div className="genscr__cap">
              <div className="overline" style={{color:"rgba(255,255,255,.78)"}}>{place.latin}</div>
              <h2>{place.name}</h2>
            </div>
          </div>
          <window.StoryGenerating
            steps={writing ? window.GEN_STEPS_B : window.GEN_STEPS_A}
            title={writing ? "正在寫下《"+(chosen?chosen.t:place.name)+"》" : "正在挖掘「"+place.name+"」的故事"}
            sub={writing ? "Lorescape 正把史料寫成一段可以聽的敘事" : "從地方志、老照片與檔案中找出可講的線索"}/>
        </div>
      );
    }

    const heroStyle = place.glyph
      ? { background:"linear-gradient(160deg, var(--cat-"+c.cls+"-ink), var(--ink-bg))" } : {};

    return (
      <div className="screen fade-enter" style={{background:"var(--paper)"}}>
        <StatusBar light time="8:07"/>
        <button className="iconbtn on-photo" onClick={back} aria-label="返回"
                style={{position:"absolute",top:"calc(var(--safe-top) + 6px)",left:14,zIndex:40}}>
          <Icon name="chevron-left" size={26}/></button>
        <div className="screen__scroll" style={{paddingTop:0}}>
          <div className="hero" style={{height:420, ...heroStyle}}>
            {!place.glyph && <img src={place.img} alt=""/>}
            {place.glyph && <div className="glyph-thumb" style={{color:"rgba(255,255,255,.5)"}}><Icon name={c.glyph} size={120} stroke={1.1}/></div>}
            <div className="hero__scrim"/>
            <div className="hero__place-latin overline" style={{bottom:96,color:"rgba(255,255,255,.78)"}}>{place.latin}</div>
            <div className="hero__cap">
              <h2 style={{marginBottom:10}}>{place.name}</h2>
              <CategoryTag cat={place.cat} onPhoto/>
            </div>
          </div>

          {phase==="loading" && (
            <window.StoryGenerating place={place.name}/>
          )}

          {phase==="options" && (
            <div className="story-opts">
              <h3>想聽哪段故事?</h3>
              <div className="story-opts__note">為「{place.name}」找到 3 條故事線,選一條繼續生成完整故事。</div>
              {opts.map((o,i)=>(
                <div className="opt" key={i}
                     onClick={()=>{ setChosen(o); setPhase("writing"); }}>
                  <div className="opt__no">{String(i+1).padStart(2,"0")}</div>
                  <div className="opt__b">
                    <div className="opt__t">{o.t}</div>
                    <div className="opt__d">{o.d}</div>
                  </div>
                  <div className="opt__chev"><Icon name="chevron-right" size={20}/></div>
                </div>
              ))}
            </div>
          )}

          {phase==="empty" && (
            <div className="gen-state">
              <div className="empty-card">
                <h3><Icon name="book-open" size={22} style={{color:"var(--clay)"}}/>這裡還沒有故事可講</h3>
                <p>我們暫時找不到這個景點的歷史人物或事件記錄。換個附近的地標,也許會有意想不到的發現。</p>
                <div style={{marginTop:18}}>
                  <button className="btn btn--ghost" onClick={back}>探索其他地點</button>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    );
  }

  Object.assign(window, { ReaderView, ReaderScreen, PlaceScreen });
})();
