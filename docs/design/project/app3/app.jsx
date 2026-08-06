// app.jsx (v3) — shell without tabbar: globe home, detail map, pushed 歷程/設定
(function(){
  const { useState } = React;
  const Icon = window.Icon;
  const { PLACES } = window.LS_DATA;
  const {
    HomeScreen, MapScreen,
    FilterSheet, SavedSheet,
    PlaceScreen, ReaderScreen,
    HistoryScreen, TripDetailScreen, CreateTripScreen, DatePickerSheet, JourneyScreen, MoveSheet,
    SettingsScreen, PaywallScreen,
    useTweaks, TweaksPanel, TweakSection, TweakRadio,
  } = window;

  const ACCENTS = {
    terracotta:{ clay:"#BC5E3E", deep:"#97442A", soft:"#F1DDCE", tint:"#F7E8DD" },
    amber:     { clay:"#B7842B", deep:"#8A5F18", soft:"#F0E5C8", tint:"#F6EED8" },
    sage:      { clay:"#5F7148", deep:"#46542F", soft:"#E3E8D3", tint:"#EBEFE0" },
  };
  const READS = {
    paper:{ bg:"#F7F1E6", ink:"#221C14", dim:"#5E5341", line:"#E4DAC8" },
    sepia:{ bg:"#EFE2CB", ink:"#2A2013", dim:"#6A5A3E", line:"#DDCBA8" },
    night:{ bg:"#1B1611", ink:"#E9E1D2", dim:"#9A8E7B", line:"rgba(247,241,230,.14)" },
  };

  const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
    "accent": "terracotta",
    "reading": "paper",
    "headlineFont": "serif"
  }/*EDITMODE-END*/;

  function BackWrap({ back, children }){
    return (
      <div className="pushed-tab">
        {children}
        <button className="iconbtn pushed-back" onClick={back} aria-label="返回">
          <Icon name="chevron-left" size={24}/></button>
      </div>
    );
  }

  function App(){
    const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);
    const [stack, setStack] = useState([{ name:"home", params:{} }]);
    const [sheet, setSheet] = useState(null);
    const [saved, setSaved] = useState(PLACES.filter(p=>p.saved).map(p=>p.id));
    const [draft, setDraft] = useState({ name:"", start:"", end:"" });

    const top = stack[stack.length-1];
    const go = (name, params={}) => setStack(s=>[...s, { name, params }]);
    const back = () => setStack(s=> s.length>1 ? s.slice(0,-1) : s);
    const openSheet = (type, params={}) => setSheet({ type, params });
    const closeSheet = () => setSheet(null);
    const toggleSaved = (id) => setSaved(s=> s.includes(id) ? s.filter(x=>x!==id) : [...s,id]);

    const a = ACCENTS[t.accent]||ACCENTS.terracotta;
    const r = READS[t.reading]||READS.paper;
    const vars = {
      "--clay":a.clay, "--clay-deep":a.deep, "--clay-soft":a.soft, "--clay-tint":a.tint,
      "--read-bg":r.bg, "--read-ink":r.ink, "--read-dim":r.dim, "--read-line":r.line, "--read-cap":a.deep,
      "--serif": t.headlineFont==="sans" ? 'var(--sans)' : '"Noto Serif TC","Songti TC",serif',
    };

    const screenFor = (route) => {
      switch(route.name){
        case "home":      return <HomeScreen go={go}/>;
        case "map":       return <MapScreen params={route.params} back={back} go={go} openSheet={openSheet} saved={saved}/>;
        case "place":     return <PlaceScreen params={route.params} back={back}/>;
        case "reader":    return <ReaderScreen params={route.params} back={back} go={go}/>;
        case "history":   return <BackWrap back={back}><HistoryScreen go={go}/></BackWrap>;
        case "settings":  return <BackWrap back={back}><SettingsScreen go={go}/></BackWrap>;
        case "trip":      return <TripDetailScreen params={route.params} back={back} go={go} openSheet={openSheet}/>;
        case "journey":   return <JourneyScreen params={route.params} back={back}/>;
        case "createTrip":return <CreateTripScreen back={back} openSheet={openSheet} draft={draft}/>;
        case "paywall":   return <PaywallScreen back={back}/>;
        default: return null;
      }
    };

    const lightInd = ["paywall","journey"].includes(top.name);

    return (
      <div className="stage" style={vars}>
        <div className="phone">
          <div className="phone__notch"></div>
          <div key={stack.length+"-"+top.name}>{screenFor(top)}</div>

          {sheet && sheet.type==="filter" && <FilterSheet close={closeSheet}/>}
          {sheet && sheet.type==="saved"  && <SavedSheet close={closeSheet} saved={saved} go={go}/>}
          {sheet && sheet.type==="move"   && <MoveSheet close={closeSheet} note={sheet.params.note} tripId={sheet.params.tripId}/>}
          {sheet && sheet.type==="date"   && (
            <DatePickerSheet close={closeSheet}
              onPick={(d)=> setDraft(prev=>({ ...prev, [sheet.params.which]:d })) }/>
          )}

          <div className={"home-ind"+(lightInd?" is-light":"")}></div>
        </div>

        <TweaksPanel title="Lorescape Tweaks">
          <TweakSection label="品牌主色"/>
          <TweakRadio label="Accent" value={t.accent}
            options={["terracotta","amber","sage"]}
            onChange={v=>setTweak("accent",v)}/>
          <TweakSection label="閱讀介面"/>
          <TweakRadio label="Reading" value={t.reading}
            options={["paper","sepia","night"]}
            onChange={v=>setTweak("reading",v)}/>
          <TweakSection label="標題字體"/>
          <TweakRadio label="Headline" value={t.headlineFont}
            options={["serif","sans"]}
            onChange={v=>setTweak("headlineFont",v)}/>
        </TweaksPanel>
      </div>
    );
  }

  window.LorescapeAppV3 = App;
})();
