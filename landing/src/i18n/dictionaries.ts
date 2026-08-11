import type { Locale } from "./config";

export interface Dict {
  nav: {
    links: { label: string; anchor: string }[];
    downloadApp: string;
    switchTo: string; // 切換鈕顯示文字（指向另一語言）
  };
  storeButtons: { ios: string; android: string };
  hero: {
    pill: string;
    headlineTop: string;
    headlineClay: string;
    lede: string;
    scroll: string;
    nowTouring: string;
    plateTitle: string;
    plateImageAlt: string;
    plateOrigin: string;
  };
  manifesto: { line1: string; line2Lead: string; line2Quote: string; cite: string };
  localStories: {
    no: string;
    h2Top: string;
    h2Bottom: string;
    lede: string;
    card1Title: string;
    card1Body: string;
    card2Title: string;
    card2Body: string;
    mediaCap: string;
    mediaOrigin: string;
    mediaAlt: string;
  };
  manyAngles: {
    no: string;
    over: string;
    h2Top: string;
    h2Bottom: string;
    lede: string;
    modes: { num: string; title: string; body: string }[];
    nowPlaying: string;
    phoneTitleTop: string;
    phoneTitleBottom: string;
    phoneSubtitle: string;
    phoneImageAlt: string;
  };
  exploreNearby: {
    over: string;
    h2: string;
    body: string;
    checks: string[];
    chips: string[]; // 對應 [自然,人文,信仰,城市] 四項
    imageAlt: string;
  };
  // 目前不 render：App 的書架（旅程手記）功能自 2026-08-11 起隱藏
  // （frontend 的 kBookshelfEnabled = false）。文案與 JourneyJournal 元件
  // 都保留，功能一恢復就把 page.tsx 的 <JourneyJournal /> 與 nav 的
  // 「旅程手記」/「Journey Journal」項目加回去即可。
  journeyJournal: {
    no: string;
    h2: string;
    lede: string;
    stats: { num: string; lab: string; caption: string; body: string }[];
  };
  videoDemo: {
    caption: string;
    ariaLabel: string;
  };
  trust: {
    no: string;
    h2: string;
    lede: string;
    proof: string;
  };
  pricing: {
    no: string;
    h2: string;
    lede: string;
    trialBadge: string;
    recommendedBadge: string;
    plans: {
      name: string;
      price: string;
      period: string;
      desc: string;
      trial: boolean;
      recommended: boolean;
    }[];
    note: string;
  };
  finalCTA: {
    over: string;
    h2Top: string;
    h2Bottom: string;
    body: string;
    imageAlt: string;
  };
  footer: {
    tag: string;
    colProduct: string;
    colCompany: string;
    contact: string;
    colLegal: string;
    privacy: string;
    terms: string;
    credits: string;
    copyright: string;
    version: string;
  };
  metadata: {
    title: string;
    description: string;
    keywords: string[];
    ogTitle: string;
    ogDescription: string;
  };
  story: {
    eyebrow: string;
    continueCta: string;
    notFoundTitle: string;
    notFoundBody: string;
  };
}

const zh: Dict = {
  nav: {
    links: [
      { label: "在地故事", anchor: "#stories" },
      { label: "多種角度", anchor: "#angles" },
      { label: "探索附近", anchor: "#explore" },
    ],
    downloadApp: "下載 App",
    switchTo: "EN",
  },
  storeButtons: { ios: "即刻取得", android: "立即下載" },
  hero: {
    pill: "AI 隨行的旅行說書人",
    headlineTop: "體驗歷史",
    headlineClay: "而不只是風景",
    lede: "你的隨身 AI 旅行說書人。走到哪，就把那裡的來歷、傳說與歷史，說給你聽。",
    scroll: "向下捲動",
    nowTouring: "正在導覽",
    plateTitle: "摧毀與重生的百年豪賭",
    plateImageAlt: "聖伯多祿大殿",
    plateOrigin: "St. Peter's Basilica · Vatican",
  },
  manifesto: {
    line1: "別再低頭盯著螢幕。",
    line2Lead: "抬起眼睛，",
    line2Quote: "世界本身就是展品。",
    cite: "Lorescape · 旅行說書人",
  },
  localStories: {
    no: "功能 01",
    h2Top: "為眼前的風景，",
    h2Bottom: "即時寫一篇故事",
    lede: "不是條列式的百科資料。Lorescape 為你經過的每座地標、古蹟與山林，當場編寫一篇有人物、有轉折、值得細讀的故事。",
    card1Title: "值得細讀的歷史長文",
    card1Body: "有起承轉合、有人物與懸念的敘事，而不是冰冷的年份與條目。",
    card2Title: "一鍵化為語音",
    card2Body: "把手機收進口袋，邊走邊聽它把這裡的來歷娓娓道來。",
    mediaCap: "台中朝聖宮",
    mediaOrigin: "Chaosheng Temple · Taichung",
    mediaAlt: "台中朝聖宮",
  },
  manyAngles: {
    no: "功能 02",
    over: "Many Angles, One Place",
    h2Top: "同一座地標，",
    h2Bottom: "不只一個故事",
    lede: "權謀、傳說、建築祕辛——AI 在每個地點為你備好幾種切入角度。挑一個最吸引你的，開始聆聽。",
    modes: [
      {
        num: "01",
        title: "摧毀與重生的百年豪賭",
        body: "儒略二世決定拆毀君士坦丁大帝的千年古教堂，這場瘋狂重建竟耗時百餘年。",
      },
      {
        num: "02",
        title: "祭壇之下的神聖祕密",
        body: "世界上最大的教堂並非教宗的主教座堂，因為它底下埋藏著更神聖的祕密。",
      },
      {
        num: "03",
        title: "文藝復興巨匠的接力賽",
        body: "米開朗基羅與拉斐爾輪番上陣，在同一座教堂留下各自的瘋狂印記。",
      },
    ],
    nowPlaying: "正在播放",
    phoneTitleTop: "摧毀與重生的",
    phoneTitleBottom: "百年豪賭",
    phoneSubtitle: "St. Peter's Basilica",
    phoneImageAlt: "聖伯多祿大殿導覽",
  },
  exploreNearby: {
    over: "功能 03 · Explore Nearby",
    h2: "探索身邊的風景",
    body: "翻開地圖之前，先看看方圓之內。Lorescape 依距離與主題，為你列出附近值得停留的每一個角落——每一種風景，都有屬於它的故事。",
    checks: [
      "依距離篩選，只看走得到的地方",
      "多種主題分類，各有專屬故事",
      "收藏想去的地點，隨時回來",
    ],
    chips: ["自然景觀", "人文古蹟", "信仰聖地", "城市地標"],
    imageAlt: "公園步道",
  },
  journeyJournal: {
    no: "功能 04",
    h2: "你的旅程，自動成冊",
    lede: "每一次駐足，都被悄悄寫進一本屬於你的旅行手記。",
    stats: [
      { num: "I", lab: "Auto Journal", caption: "自動成篇", body: "每聽完一段故事，就自動留下一篇可回味的手記。" },
      { num: "II", lab: "Trips", caption: "依旅程歸檔", body: "把沿途的記錄整理成一趟趟旅程，井然有序。" },
      { num: "III", lab: "Timeline", caption: "沿時間軸重溫", body: "順著時間軸回看，隨時重返走過的任何一個角落。" },
    ],
  },
  videoDemo: {
    caption: "看看 Lorescape 如何把眼前的風景，變成一段值得細聽的故事。",
    ariaLabel: "Lorescape App 示範影片",
  },
  trust: {
    no: "以史實為本",
    h2: "AI 說的，是真的嗎？",
    lede:
      "每一則故事都以 Wikipedia 為事實依據，並附上出處連結——不是 AI 憑空杜撰。你聽到的每一段脈絡，都能回溯到可查證的來源。",
    proof: "每則故事，皆附 Wikipedia 出處",
  },
  pricing: {
    no: "方案",
    h2: "先免費試用 7 天，喜歡再訂閱",
    lede: "付費方案皆含 7 天免費試用，隨時可取消。",
    trialBadge: "7 天免費試用",
    recommendedBadge: "推薦",
    plans: [
      {
        name: "免費",
        price: "NT$0",
        period: "",
        desc: "每日精選故事",
        trial: false,
        recommended: false,
      },
      {
        name: "週訂",
        price: "NT$33",
        period: "/ 週",
        desc: "無限 AI 導覽",
        trial: false,
        recommended: false,
      },
      {
        name: "月訂",
        price: "NT$150",
        period: "/ 月",
        desc: "無限 AI 導覽",
        trial: true,
        recommended: false,
      },
      {
        name: "年訂",
        price: "NT$660",
        period: "/ 年",
        desc: "最超值，約 4.4 個月月費",
        trial: true,
        recommended: true,
      },
    ],
    note: "價格依地區與商店而異；訂閱可隨時於 App Store / Google Play 取消。",
  },
  finalCTA: {
    over: "開始你的第一段故事",
    h2Top: "城市是一本書。",
    h2Bottom: "開始閱讀吧。",
    body: "一路聽，一路讀，讓每一次駐足都留下故事。",
    imageAlt: "阿格拉紅堡",
  },
  footer: {
    tag: "溫潤紙感 × 文學宋體 × 陶土點綴——為旅途中的每一段故事而設計。",
    colProduct: "產品",
    colCompany: "公司",
    contact: "聯絡我們",
    colLegal: "法律",
    privacy: "隱私政策",
    terms: "使用條款",
    credits: "圖片來源",
    copyright: "© 2026 Lorescape. 版權所有。",
    version: "旅行說書人 · v1.0",
  },
  metadata: {
    title: "Lorescape 讀景 — AI 語音導覽 App，讓每一處風景開口說故事",
    description: "走到哪聽到哪的景點語音導覽 App。Lorescape 讀景是你 AI 隨行的旅行說書人，把眼前景點的來歷、傳說與歷史即時編寫成值得細讀的故事，還能化作語音邊走邊聽。",
    keywords: ["語音導覽 app", "景點導覽 app", "AI 導覽", "旅遊導覽", "景點故事", "在地故事", "文化旅遊", "旅行說書人", "Lorescape", "讀景"],
    ogTitle: "Lorescape — 讓每一處風景，開口說它的故事",
    ogDescription: "AI 隨行的旅行說書人，為每一處風景備好屬於它的故事。",
  },
  story: {
    eyebrow: "來自 Lorescape 的每日故事",
    continueCta: "想聽完整故事？下載 App，每天還有一則新的。",
    notFoundTitle: "這則故事還在路上",
    notFoundBody:
      "我們找不到這一則故事，但每天都有一則新的在等你。下載 Lorescape，" +
      "走到哪，就聽那裡的歷史故事。",
  },
};

const en: Dict = {
  nav: {
    links: [
      { label: "Local Stories", anchor: "#stories" },
      { label: "Many Angles", anchor: "#angles" },
      { label: "Explore Nearby", anchor: "#explore" },
    ],
    downloadApp: "Download App",
    switchTo: "中文",
  },
  storeButtons: { ios: "Download on the", android: "GET IT ON" },
  hero: {
    pill: "Your AI travel storyteller",
    headlineTop: "Experience history,",
    headlineClay: "not just the view",
    lede: "Your pocket AI storyteller. Wherever you go, it tells you the origins, legends, and history of the place around you.",
    scroll: "Scroll down",
    nowTouring: "Now touring",
    plateTitle: "A century-long gamble of ruin and rebirth",
    plateImageAlt: "St. Peter's Basilica",
    plateOrigin: "St. Peter's Basilica · Vatican",
  },
  manifesto: {
    line1: "Stop staring down at your screen.",
    line2Lead: "Look up — ",
    line2Quote: "the world itself is the exhibit.",
    cite: "Lorescape · Field Notes",
  },
  localStories: {
    no: "Feature 01",
    h2Top: "A story for the view in front of you,",
    h2Bottom: "written on the spot",
    lede: "Not a bullet-point encyclopedia entry. For every landmark, monument, and mountain you pass, Lorescape composes a story with characters, twists, and depth worth reading.",
    card1Title: "Long-form history worth reading",
    card1Body: "Narrative with arc, characters, and suspense — not cold dates and entries.",
    card2Title: "Turn it into audio with one tap",
    card2Body: "Slip your phone into your pocket and listen as it recounts the story while you walk.",
    mediaCap: "Chaosheng Temple, Taichung",
    mediaOrigin: "Chaosheng Temple · Taichung",
    mediaAlt: "Chaosheng Temple",
  },
  manyAngles: {
    no: "Feature 02",
    over: "Many Angles, One Place",
    h2Top: "One landmark,",
    h2Bottom: "more than one story",
    lede: "Politics, legends, architectural secrets — AI prepares several angles for every place. Pick the one that draws you in and start listening.",
    modes: [
      {
        num: "01",
        title: "A century-long gamble of ruin and rebirth",
        body: "Pope Julius II tore down Constantine's thousand-year-old basilica — and the audacious rebuild took over a century.",
      },
      {
        num: "02",
        title: "The sacred secret beneath the altar",
        body: "The world's largest church isn't the pope's cathedral — because something far holier lies buried beneath it.",
      },
      {
        num: "03",
        title: "A relay race of Renaissance masters",
        body: "Michelangelo and Raphael took turns, each leaving their own audacious mark on the same church.",
      },
    ],
    nowPlaying: "Now playing",
    phoneTitleTop: "A century-long gamble",
    phoneTitleBottom: "of ruin and rebirth",
    phoneSubtitle: "St. Peter's Basilica",
    phoneImageAlt: "St. Peter's Basilica tour",
  },
  exploreNearby: {
    over: "Feature 03 · Explore Nearby",
    h2: "Explore what's around you",
    body: "Before you open the map, look at what's within reach. By distance and theme, Lorescape lists every nearby corner worth a stop — and every one has a story of its own.",
    checks: [
      "Filter by distance — see only places you can walk to",
      "Multiple themes, each with its own stories",
      "Save the places you want to visit and return anytime",
    ],
    chips: ["Nature", "Heritage", "Sacred Sites", "City Landmarks"],
    imageAlt: "Park trail",
  },
  journeyJournal: {
    no: "Feature 04",
    h2: "Your journey, bound into a journal automatically",
    lede: "Every stop is quietly written into a travel journal that's yours.",
    stats: [
      { num: "I", lab: "Auto Journal", caption: "Auto-written", body: "Finish a story and a memorable entry is saved for you automatically." },
      { num: "II", lab: "Trips", caption: "Filed by trip", body: "Your records along the way are organized into neat, separate trips." },
      { num: "III", lab: "Timeline", caption: "Along a timeline", body: "Look back along a timeline and revisit any corner you've walked, anytime." },
    ],
  },
  videoDemo: {
    caption: "See how Lorescape turns the view in front of you into a story worth hearing.",
    ariaLabel: "Lorescape app demo video",
  },
  trust: {
    no: "Grounded in fact",
    h2: "Is what the AI says true?",
    lede:
      "Every story is grounded in Wikipedia and comes with source links — not invented by AI. Every detail you hear traces back to a source you can check.",
    proof: "Every story cites its Wikipedia source",
  },
  pricing: {
    no: "Plans",
    h2: "Try 7 days free, subscribe if you love it",
    lede: "Every paid plan includes a 7-day free trial. Cancel anytime.",
    trialBadge: "7-day free trial",
    recommendedBadge: "Recommended",
    plans: [
      {
        name: "Free",
        price: "NT$0",
        period: "",
        desc: "A daily featured story",
        trial: false,
        recommended: false,
      },
      {
        name: "Weekly",
        price: "NT$33",
        period: "/ week",
        desc: "Unlimited AI tours",
        trial: false,
        recommended: false,
      },
      {
        name: "Monthly",
        price: "NT$150",
        period: "/ month",
        desc: "Unlimited AI tours",
        trial: true,
        recommended: false,
      },
      {
        name: "Yearly",
        price: "NT$660",
        period: "/ year",
        desc: "Best value — about 4.4 months of monthly",
        trial: true,
        recommended: true,
      },
    ],
    note: "Prices vary by region and store. Cancel anytime in the App Store or Google Play.",
  },
  finalCTA: {
    over: "Begin your first story",
    h2Top: "The city is a book.",
    h2Bottom: "Start reading.",
    body: "Listen as you walk. Every stop becomes a story worth keeping.",
    imageAlt: "Agra Fort",
  },
  footer: {
    tag: "Warm paper × literary serif × terracotta accents — designed for every story along the way.",
    colProduct: "Product",
    colCompany: "Company",
    contact: "Contact",
    colLegal: "Legal",
    privacy: "Privacy Policy",
    terms: "Terms of Use",
    credits: "Image Credits",
    copyright: "© 2026 Lorescape. All rights reserved.",
    version: "Field Notes · v1.0",
  },
  metadata: {
    title: "Lorescape — AI Audio Tour Guide App That Tells Every Place's Story",
    description: "An AI audio tour guide that follows you anywhere. Lorescape writes the origins, legends, and history of the place in front of you into a story worth reading — and reads it aloud as you walk.",
    keywords: ["audio tour guide app", "AI tour guide", "audio guide app", "travel storyteller", "self-guided tour", "local stories", "cultural travel", "Lorescape"],
    ogTitle: "Lorescape — Let every place tell its story",
    ogDescription: "Your AI travel storyteller, with a story ready for every place you visit.",
  },
  story: {
    eyebrow: "A daily story from Lorescape",
    continueCta: "Want the full story? Download the app — a new one every day.",
    notFoundTitle: "This story is still on its way",
    notFoundBody:
      "We couldn't find this one, but there's a new story every day. " +
      "Download Lorescape and hear the history of any place you visit.",
  },
};

export const dictionaries: Record<Locale, Dict> = { zh, en };

export function getDictionary(locale: Locale): Dict {
  return dictionaries[locale];
}
