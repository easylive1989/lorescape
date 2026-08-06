// icons.jsx — Lorescape line-icon set. Exports window.Icon
(function(){
  const P = {
    'chevron-left':  <polyline points="15 18 9 12 15 6"/>,
    'chevron-right': <polyline points="9 18 15 12 9 6"/>,
    'chevron-down':  <polyline points="6 9 12 15 18 9"/>,
    'search':        <g><circle cx="11" cy="11" r="7"/><line x1="21" y1="21" x2="16.5" y2="16.5"/></g>,
    'sliders':       <g><line x1="4" y1="8" x2="20" y2="8"/><line x1="4" y1="16" x2="20" y2="16"/><circle cx="9" cy="8" r="2.4" fill="currentColor" stroke="none"/><circle cx="15" cy="16" r="2.4" fill="currentColor" stroke="none"/></g>,
    'refresh':       <g><path d="M21 12a9 9 0 1 1-2.64-6.36"/><polyline points="21 3 21 9 15 9"/></g>,
    'bookmark':      <path d="M6 4h12a1 1 0 0 1 1 1v15l-7-4-7 4V5a1 1 0 0 1 1-1z"/>,
    'bookmark-fill': <path d="M6 4h12a1 1 0 0 1 1 1v15l-7-4-7 4V5a1 1 0 0 1 1-1z" fill="currentColor"/>,
    'compass':       <g><circle cx="12" cy="12" r="9"/><polygon points="15.5 8.5 10.5 10.5 8.5 15.5 13.5 13.5" fill="currentColor" stroke="none"/></g>,
    'book-open':     <path d="M12 6.5C10.5 5 8 4.5 4 4.8V18c4-.3 6.5.2 8 1.7 1.5-1.5 4-2 8-1.7V4.8c-4-.3-6.5.2-8 1.7zM12 6.5V19.7"/>,
    'book':          <path d="M6 3h12a1 1 0 0 1 1 1v16l-7-3.5L5 20V4a1 1 0 0 1 1-1z"/>,
    'settings':      <g><circle cx="12" cy="12" r="3"/><path d="M19.4 13.5a1.6 1.6 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.6 1.6 0 0 0-2.7 1.1V20a2 2 0 0 1-4 0v-.1a1.6 1.6 0 0 0-2.7-1.1l-.1.1A2 2 0 1 1 2.5 16l.1-.1a1.6 1.6 0 0 0-1.1-2.7H1a2 2 0 0 1 0-4h.1a1.6 1.6 0 0 0 1.1-2.7l-.1-.1A2 2 0 1 1 5 3.6l.1.1a1.6 1.6 0 0 0 1.8.3 1.6 1.6 0 0 0 1-1.4V2a2 2 0 0 1 4 0v.1a1.6 1.6 0 0 0 2.7 1.1l.1-.1A2 2 0 1 1 21.5 6l-.1.1a1.6 1.6 0 0 0-.3 1.8 1.6 1.6 0 0 0 1.4 1H23a2 2 0 0 1 0 4h-.1a1.6 1.6 0 0 0-1.5 1z"/></g>,
    'share':         <g><circle cx="18" cy="5" r="2.6"/><circle cx="6" cy="12" r="2.6"/><circle cx="18" cy="19" r="2.6"/><line x1="8.3" y1="10.8" x2="15.7" y2="6.2"/><line x1="8.3" y1="13.2" x2="15.7" y2="17.8"/></g>,
    'trash':         <g><polyline points="4 6 20 6"/><path d="M8 6V4.5A1.5 1.5 0 0 1 9.5 3h5A1.5 1.5 0 0 1 16 4.5V6"/><path d="M6.5 6l1 13a1 1 0 0 0 1 1h7a1 1 0 0 0 1-1l1-13"/></g>,
    'plus':          <g><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></g>,
    'x':             <g><line x1="6" y1="6" x2="18" y2="18"/><line x1="18" y1="6" x2="6" y2="18"/></g>,
    'sparkle':       <path d="M12 3l1.8 5.4L19 10.2l-5.2 1.8L12 17.4l-1.8-5.4L5 10.2l5.2-1.8z" fill="currentColor" stroke="none"/>,
    'calendar':      <g><rect x="3.5" y="5" width="17" height="16" rx="2"/><line x1="3.5" y1="9.5" x2="20.5" y2="9.5"/><line x1="8" y1="3" x2="8" y2="6"/><line x1="16" y1="3" x2="16" y2="6"/></g>,
    'pencil':        <path d="M16.5 3.5l4 4L8 20l-4.5.5L4 16z"/>,
    'play':          <polygon points="7 4 20 12 7 20" fill="currentColor" stroke="none"/>,
    'pause':         <g><rect x="6" y="5" width="4" height="14" rx="1" fill="currentColor" stroke="none"/><rect x="14" y="5" width="4" height="14" rx="1" fill="currentColor" stroke="none"/></g>,
    'skip-back':     <g><polygon points="19 5 9 12 19 19" fill="currentColor" stroke="none"/><rect x="5" y="5" width="2.4" height="14" rx="1" fill="currentColor" stroke="none"/></g>,
    'skip-fwd':      <g><polygon points="5 5 15 12 5 19" fill="currentColor" stroke="none"/><rect x="16.6" y="5" width="2.4" height="14" rx="1" fill="currentColor" stroke="none"/></g>,
    'globe':         <g><circle cx="12" cy="12" r="9"/><line x1="3" y1="12" x2="21" y2="12"/><path d="M12 3c2.5 2.5 3.8 5.7 3.8 9s-1.3 6.5-3.8 9c-2.5-2.5-3.8-5.7-3.8-9S9.5 5.5 12 3z"/></g>,
    'user':          <g><circle cx="12" cy="8" r="4"/><path d="M5 21c0-3.9 3.1-7 7-7s7 3.1 7 7"/></g>,
    'cloud-sync':    <g><path d="M7 18a4 4 0 0 1-.5-7.97A6 6 0 0 1 18 9.5a3.5 3.5 0 0 1-.5 8.5"/><polyline points="10 14 12 16 10 18"/><polyline points="14 18 12 16 14 14"/></g>,
    'bar-chart':     <g><line x1="6" y1="20" x2="6" y2="12"/><line x1="12" y1="20" x2="12" y2="6"/><line x1="18" y1="20" x2="18" y2="14"/></g>,
    'lock':          <g><rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></g>,
    'check':         <polyline points="5 12.5 10 17.5 19 7"/>,
    'location':      <g><path d="M12 21s7-6.2 7-11a7 7 0 1 0-14 0c0 4.8 7 11 7 11z"/><circle cx="12" cy="10" r="2.5"/></g>,
    'mountain':      <path d="M3 19h18L14 7l-3 5-2-2z"/>,
    'columns':       <g><path d="M4 9l8-5 8 5"/><line x1="5" y1="9" x2="5" y2="19"/><line x1="9.5" y1="9" x2="9.5" y2="19"/><line x1="14.5" y1="9" x2="14.5" y2="19"/><line x1="19" y1="9" x2="19" y2="19"/><line x1="3" y1="20" x2="21" y2="20"/></g>,
    'building':      <g><rect x="5" y="3" width="14" height="18" rx="1"/><line x1="9" y1="7" x2="9" y2="7.01"/><line x1="15" y1="7" x2="15" y2="7.01"/><line x1="9" y1="11" x2="9" y2="11.01"/><line x1="15" y1="11" x2="15" y2="11.01"/><path d="M10 21v-4h4v4"/></g>,
    'waves':         <g><path d="M2 8c2 0 2 2 4 2s2-2 4-2 2 2 4 2 2-2 4-2 2 2 4 2"/><path d="M2 14c2 0 2 2 4 2s2-2 4-2 2 2 4 2 2-2 4-2 2 2 4 2"/></g>,
    'gem':           <g><path d="M6 3h12l4 6-10 12L2 9z"/><path d="M2 9h20M9 3 7 9l5 12M15 3l2 6-5 12"/></g>,
    'book-marker':   <g><path d="M5 4h11a1 1 0 0 1 1 1v15l-6-3.2L6 20"/><path d="M19 4v8l2.2-1.3L23.4 12V5z" transform="translate(-4 0)"/></g>,
    'globe-pin':     <g><circle cx="12" cy="12" r="9"/><line x1="3" y1="12" x2="21" y2="12"/></g>,
    'image-off':     <g><rect x="3.5" y="4.5" width="17" height="15" rx="2"/><line x1="4" y1="20" x2="20" y2="4"/></g>,
  };
  function Icon({ name, size=22, stroke=1.7, className, style }){
    const p = P[name];
    if(!p) return null;
    return (
      <svg className={className} style={style} width={size} height={size} viewBox="0 0 24 24"
           fill="none" stroke="currentColor" strokeWidth={stroke}
           strokeLinecap="round" strokeLinejoin="round">{p}</svg>
    );
  }
  window.Icon = Icon;
})();
