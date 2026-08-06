// icons3.jsx — extra icons for v3, wraps app2 icon set
(function(){
  const Base = window.Icon;
  const P3 = {
    'locate': <g><circle cx="12" cy="12" r="6.5"/><circle cx="12" cy="12" r="2" fill="currentColor" stroke="none"/><line x1="12" y1="2.5" x2="12" y2="5.5"/><line x1="12" y1="18.5" x2="12" y2="21.5"/><line x1="2.5" y1="12" x2="5.5" y2="12"/><line x1="18.5" y1="12" x2="21.5" y2="12"/></g>,
    'map': <g><path d="M9 4.5 3.5 6.5v13L9 17.5l6 2 5.5-2v-13l-5.5 2z"/><line x1="9" y1="4.5" x2="9" y2="17.5"/><line x1="15" y1="6.5" x2="15" y2="19.5"/></g>,
    'info': <g><circle cx="12" cy="12" r="9"/><line x1="12" y1="11" x2="12" y2="16.5"/><circle cx="12" cy="7.6" r="1.2" fill="currentColor" stroke="none"/></g>,
  };
  function Icon(props){
    const p = P3[props.name];
    if(!p) return <Base {...props}/>;
    const { size=22, stroke=1.7, className, style } = props;
    return (
      <svg className={className} style={style} width={size} height={size} viewBox="0 0 24 24"
           fill="none" stroke="currentColor" strokeWidth={stroke}
           strokeLinecap="round" strokeLinejoin="round">{p}</svg>
    );
  }
  window.Icon = Icon;
})();
