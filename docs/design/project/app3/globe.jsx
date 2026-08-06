// globe.jsx — illustrated orthographic globe (d3 + world-atlas), draggable, animated focus
(function(){
  const { useRef, useEffect } = React;
  const WORLD = 'https://cdn.jsdelivr.net/npm/world-atlas@2.0.2/countries-110m.json';
  let _world = null;
  function loadWorld(){
    if(!_world) _world = fetch(WORLD).then(r=>r.json()).then(t=>topojson.feature(t, t.objects.countries));
    return _world;
  }
  const GRAT = d3.geoGraticule10();

  // pins: [{id, coord:[lat,lng], label}] ; activeId gets the big pin + chip
  function GlobeView({ pins, activeId, size=344 }){
    const cvRef=useRef(null), pinRef=useRef(null), chipRef=useRef(null);
    const S = useRef({ rot:null, land:null, raf:0, drag:null }).current;
    const active = pins.find(p=>p.id===activeId) || pins[0];
    const activeRef = useRef(active); activeRef.current = active;

    function draw(){
      const cv=cvRef.current; if(!cv || !S.rot) return;
      const dpr=Math.min(2, window.devicePixelRatio||1);
      if(cv.width!==size*dpr){ cv.width=size*dpr; cv.height=size*dpr; }
      const ctx=cv.getContext('2d');
      ctx.setTransform(dpr,0,0,dpr,0,0);
      ctx.clearRect(0,0,size,size);
      const R=size/2-3;
      const proj=d3.geoOrthographic().translate([size/2,size/2]).scale(R).rotate(S.rot).clipAngle(90);
      const path=d3.geoPath(proj,ctx);
      ctx.beginPath(); path({type:"Sphere"}); ctx.fillStyle="#FCF8ED"; ctx.fill();
      ctx.beginPath(); path(GRAT); ctx.strokeStyle="rgba(111,124,86,.17)"; ctx.lineWidth=.7; ctx.stroke();
      if(S.land){
        ctx.beginPath(); path(S.land);
        ctx.fillStyle="#CBD8A9"; ctx.fill();
        ctx.strokeStyle="rgba(101,116,74,.42)"; ctx.lineWidth=.7; ctx.stroke();
      }
      let g=ctx.createRadialGradient(size*.36,size*.30,R*.12, size/2,size/2,R);
      g.addColorStop(0,"rgba(255,255,255,.5)"); g.addColorStop(.55,"rgba(255,255,255,0)"); g.addColorStop(1,"rgba(120,106,70,.22)");
      ctx.beginPath(); ctx.arc(size/2,size/2,R,0,7); ctx.fillStyle=g; ctx.fill();
      ctx.beginPath(); ctx.arc(size/2,size/2,R,0,7); ctx.strokeStyle="rgba(120,106,70,.3)"; ctx.lineWidth=1; ctx.stroke();

      const act = activeRef.current;
      const center=[-S.rot[0],-S.rot[1]];
      ctx.font='600 11px "Noto Sans TC",sans-serif';
      pins.forEach(p=>{
        if(p.id===act.id) return;
        const lp=[p.coord[1],p.coord[0]];
        if(d3.geoDistance(lp,center)>1.4) return;
        const xy=proj(lp); if(!xy) return;
        ctx.beginPath(); ctx.arc(xy[0],xy[1],4.5,0,7);
        ctx.fillStyle="#5F7148"; ctx.fill();
        ctx.lineWidth=2; ctx.strokeStyle="#FCF8ED"; ctx.stroke();
        const flip = xy[0] > size*.62;
        ctx.fillStyle="#6E6350"; ctx.textAlign= flip ? "right" : "left";
        ctx.fillText(p.label, xy[0]+(flip?-10:10), xy[1]+4);
      });
      const alp=[act.coord[1],act.coord[0]];
      const vis = d3.geoDistance(alp,center) < 1.32;
      const xy = proj(alp);
      if(pinRef.current && chipRef.current){
        pinRef.current.style.opacity = vis?1:0;
        chipRef.current.style.opacity = vis?1:0;
        if(vis && xy){
          pinRef.current.style.transform = `translate(${xy[0]}px,${xy[1]}px)`;
          chipRef.current.style.transform = `translate(${xy[0]}px,${xy[1]}px)`;
        }
      }
    }

    useEffect(()=>{
      let ok=true;
      loadWorld().then(l=>{ if(ok){ S.land=l; draw(); } }).catch(()=>{});
      return ()=>{ ok=false; };
    },[]);

    // rotate to the active pin
    useEffect(()=>{
      const target=[-active.coord[1], -(active.coord[0]-8)];
      if(!S.rot){ S.rot=target; draw(); return; }
      cancelAnimationFrame(S.raf);
      const from=S.rot.slice();
      let d0=target[0]-from[0]; d0=((d0%360)+540)%360-180;
      const d1=target[1]-from[1];
      const t0=performance.now(), dur=950, ease=t=>1-Math.pow(1-t,3);
      const step=(now)=>{
        const k=Math.min(1,(now-t0)/dur), e=ease(k);
        S.rot=[from[0]+d0*e, from[1]+d1*e];
        draw();
        if(k<1) S.raf=requestAnimationFrame(step);
      };
      S.raf=requestAnimationFrame(step);
      return ()=>cancelAnimationFrame(S.raf);
    },[activeId]);

    function onDown(e){
      cancelAnimationFrame(S.raf);
      S.drag={x:e.clientX, y:e.clientY, rot:S.rot.slice()};
      e.currentTarget.setPointerCapture(e.pointerId);
    }
    function onMove(e){
      if(!S.drag) return;
      const k=.32;
      S.rot=[ S.drag.rot[0]+(e.clientX-S.drag.x)*k,
              Math.max(-78, Math.min(78, S.drag.rot[1]-(e.clientY-S.drag.y)*k)) ];
      draw();
    }
    function onUp(){ S.drag=null; }

    return (
      <div className="globe-box" style={{width:size,height:size}}>
        <canvas ref={cvRef} style={{width:size,height:size,touchAction:"none",cursor:"grab",display:"block",position:"relative"}}
                onPointerDown={onDown} onPointerMove={onMove} onPointerUp={onUp} onPointerCancel={onUp}/>
        <div className="gpin" ref={pinRef}><div className="map-pin map-pin--g"><i></i></div></div>
        <div className="gchip" ref={chipRef}><div className="gchip__in"><i></i><span>{active.label}</span></div></div>
      </div>
    );
  }
  window.GlobeView = GlobeView;
})();
