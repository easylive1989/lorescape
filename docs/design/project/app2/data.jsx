// data.jsx — Lorescape content. Exports window.LS_DATA
(function(){
  const CAT = {
    nature:   { label:"自然景觀", glyph:"mountain",  cls:"nature"  },
    heritage: { label:"人文古蹟", glyph:"columns",   cls:"heritage"},
    urban:    { label:"城市地標", glyph:"building",   cls:"urban"   },
    coast:    { label:"海岸水域", glyph:"waves",      cls:"coast"   },
    sacred:   { label:"信仰聖地", glyph:"book-marker", cls:"sacred" },
  };

  const PLACES = [
    { id:"stpeters", name:"聖伯多祿大殿", cat:"urban", img:"assets/img/stpeters.jpg", coord:[41.9022,12.4533],
      latin:"ST. PETER'S BASILICA · VATICAN", state:"options" },
    { id:"temple", name:"台中朝聖宮", cat:"heritage", img:"assets/img/temple.jpg", coord:[24.1489,120.6839],
      latin:"CHAOSHENG TEMPLE · TAICHUNG", state:"empty", saved:true },
    { id:"macaron", name:"馬卡龍公園", cat:"nature", img:"assets/img/park.jpg", coord:[24.1755,120.6250],
      latin:"MACARON PARK · TAICHUNG", state:"loading" },
    { id:"pinglin", name:"坪林森林公園", cat:"nature", glyph:true, coord:[24.1339,120.7145],
      latin:"PINGLIN FOREST PARK", state:"loading" },
    { id:"langzi", name:"廊子公園", cat:"nature", glyph:true, coord:[24.1620,120.6470],
      latin:"LANGZI PARK", state:"loading" },
    { id:"guanyin", name:"南觀音山", cat:"nature", glyph:true, coord:[24.0730,120.5600],
      latin:"NAN GUANYIN MOUNTAIN", state:"loading" },
  ];

  const STORY_OPTIONS = [
    { t:"摧毀與重生的百年豪賭", d:"儒略二世決定拆毀君士坦丁大帝的千年古教堂,這場瘋狂重建竟耗時百餘年……" },
    { t:"祭壇之下的神聖祕密", d:"世界上最大的教堂並非教宗的主教座堂,因為它底下埋藏著更神聖的祕密……" },
    { t:"文藝復興巨匠的接力賽", d:"米開朗基羅與拉斐爾等巨匠輪番上陣,如何在一座教堂上留下各自的瘋狂印記?" },
  ];

  // Full editorial stories (故事 feed + reader)
  const STORIES = [
    {
      id:"ahwar", place:"伊拉克南部阿瓦爾", img:"assets/img/ahwar.jpg",
      date:"2026年5月29日", chapter:"Anno · I",
      latin:"AHWAR OF SOUTHERN IRAQ · IRAQ",
      title:"尋找塵世的伊甸園", sub:"「阿瓦爾」沼澤與蘇美古城的文明啟示",
      dropcap:"聖",
      body:[
        "經學者們為了尋找傳說中的「伊甸園」,將目光投向底格里斯河與幼發拉底河交匯的伊拉克南部阿瓦爾。他們渴望在這片由河流滋養的土地上,證實人類文明與生命搖籃的起點。",
        "沼澤與古城的交織帶來了巨大挑戰。學者們必須在胡韋扎等四片濕地,以及烏魯克、吾珥與埃利都三座蘇美古城遺址之間,拼湊出自然生態與人類最早城市文明共生的歷史軌跡。",
        "阿瓦爾最終被證實為伊甸園的塵世遺存。這片融合了四處沼澤與三座古城的奇蹟之地,如今榮登世界遺產名錄,成為展現美索不達米亞文明起點與生物多樣性避難所的永恆見證。",
      ],
      quote:{ q:"「伊甸園」", by:"—— 聖經學者" },
      footer:"伊拉克 · IRAQ",
    },
    {
      id:"agra", place:"阿格拉紅堡", img:"assets/img/agra.jpg",
      date:"2026年5月28日", chapter:"Anno · II",
      latin:"AGRA FORT · INDIA",
      title:"帝王的紅砂岩王座", sub:"蒙兀兒王朝權力與愛恨的見證",
      dropcap:"阿",
      body:[
        "克巴皇帝在一五六五年凝視著阿格拉的舊要塞。自父親胡馬雍在此加冕後,這座古堡已顯破敗;於是他決心徹底重建,以紅砂岩砌出一座配得上帝國的雄偉王座。",
        "歷時八年,逾四千名工匠在亞穆納河畔築起這座周長兩公里半的城塞。它既是軍事堡壘,也是宮廷;其後的沙賈汗更在牆內添入白色大理石的優雅,讓剛硬的紅砂岩多了一分柔情。",
        "然而紅堡最動人的,是它最後的故事。沙賈汗晚年遭兒子奧朗則布囚禁於此,只能隔著河水,遙望他為亡妻所建、波光中的泰姬瑪哈陵,直到生命終了。",
      ],
      quote:{ q:"他只能隔著亞穆納河,遠望那座為愛而生的白色陵墓。", by:"—— 阿格拉紅堡" },
      footer:"印度 · INDIA",
    },
    {
      id:"stpeters-card", place:"聖伯多祿大殿", img:"assets/img/stpeters.jpg",
      date:"2026年5月27日", chapter:"Anno · III",
      latin:"ST. PETER'S BASILICA · VATICAN",
      title:"摧毀與重生的百年豪賭", sub:"儒略二世與一座教堂的瘋狂重生",
      dropcap:"一",
      body:[
        "五〇六年四月,教宗儒略二世站在君士坦丁大帝所建、如今已顯破舊的老聖伯多祿大殿前,做出了一個驚世駭俗的決定。",
        "拆毀千年古堂,在原址重建一座前所未見的雄偉聖殿。這場豪賭橫跨百餘年,歷經二十位教宗與數代巨匠之手。",
        "米開朗基羅、拉斐爾、貝尼尼輪番上陣,每一位都在這座教堂留下自己的印記,最終成就了世界上最大的教堂。",
      ],
      quote:{ q:"拆毀,是為了一場橫跨百年的重生。", by:"—— 聖伯多祿大殿" },
      footer:"梵蒂岡 · VATICAN",
    },
    {
      id:"temple", place:"彰化泰京山莊四面佛寺", img:"assets/img/temple.jpg",
      date:"2026年5月26日", chapter:"Anno · IV",
      latin:"SI MIAN FO TEMPLE · CHANGHUA",
      title:"一碗麵線換來的神明", sub:"蚵仔麵線小販與一座泰式佛寺的緣起",
      dropcap:"民",
      body:[
        "國七十四年左右,賣蚵仔麵線的林逢永先生跟團遠赴泰國,走進了曼谷香火鼎盛的四面佛壇前,許下一個關於家業的願。",
        "願望應驗之後,他決定把這份謝意帶回彰化。從募資、迎請神像到監造工匠,一座泰式佛寺在台灣中部的丘陵間慢慢立起。",
        "如今寺前香煙不斷,信眾多半不知道這裡最初的起點,只是一位小販與一碗麵線之間的約定。",
      ],
      quote:{ q:"一個許願,換來一座跨海而來的佛寺。", by:"—— 泰京山莊四面佛寺" },
      footer:"台灣 · TAIWAN",
    },
    {
      id:"park", place:"廊子公園", img:"assets/img/park.jpg",
      date:"2026年5月25日", chapter:"Anno · V",
      latin:"LANGZI PARK · CHANGHUA",
      title:"老榕樹底下的舊河道", sub:"公園綠地與一條消失的水路",
      dropcap:"漫",
      body:[
        "步廊子公園,目光總會被幾株雄偉的老榕樹吸引。枝繁葉茂,氣根盤結,像一位位歷經滄桑的長者靜默守護這片土地。",
        "然而這些榕樹的排列並非偶然。它們沿著一條早已被填平的灌溉水路生長,樹根記得那條水線的走向。",
        "公園的步道今日仍沿著同一道弧線延伸,人們在不知情中,重複著百年前挑水人走過的路徑。",
      ],
      quote:{ q:"樹根記得那條已經消失的水線。", by:"—— 廊子公園" },
      footer:"台灣 · TAIWAN",
    },
  ];

  // St Peter's reader (from a chosen story option) — has audio
  const STPETERS_STORY = {
    id:"stpeters-story", place:"聖伯多祿大殿", img:"assets/img/stpeters.jpg",
    date:"2026年5月30日", chapter:"Anno · I",
    latin:"ST. PETER'S BASILICA · VATICAN",
    title:"摧毀與重生的百年豪賭", sub:"儒略二世與一座教堂的瘋狂重生",
    dropcap:"一",
    body:[
      "五〇六年四月,羅馬的春風吹拂著梵蒂岡山丘。教宗儒略二世站在那座由君士坦丁大帝於四世紀建造、如今已顯得破舊不堪的老聖伯多祿大殿前。",
      "對儒略二世而言,這座古老的教堂不僅僅是一座建築,更是天主教會最神聖的象徵,因為天主教會聖傳記載著,耶穌十二宗徒之長、同時也是首任羅馬主教的聖伯多祿,其遺骨就安葬於這片土地之下。",
      "為了守護這份神聖的遺產,並展現天主教會的權威與榮光,儒略二世做出了一個驚世駭俗的決定——拆毀這座千年古堂,在原址上重建一座前所未見的雄偉聖殿。",
    ],
    quote:{ q:"拆毀,是為了一場橫跨百年的重生。", by:"—— 聖伯多祿大殿" },
    footer:"梵蒂岡 · VATICAN",
    audio:true,
  };

  const TIMELINE = [
    { date:"5月 17", time:"08:51", title:"廊子公園",
      text:"漫步廊子公園,目光總會被眼前這幾株雄偉的老榕樹吸引。它們枝繁葉茂,氣根盤結,彷彿一位位歷經滄桑的長者,靜默地守護著這片土地。然而,這些老榕樹並……" },
    { date:"5月 16", time:"09:50", title:"彰化泰京山莊四面佛寺", img:"assets/img/temple.jpg",
      text:"彰化泰京山莊四面佛寺的故事,要從一位平凡的蚵仔麵線小販說起。那是在民國七十四年(1985年)左右,林逢永先生跟團遠赴泰國旅遊,走進了曼谷香火鼎盛的……" },
    { date:"5月 12", time:"17:24", title:"南觀音山",
      text:"南觀音山的稜線在暮色中起伏,像一道凝固的浪。早年採石的痕跡仍鐫刻在山腹,如今卻被綠意慢慢縫合,成為城市邊緣一處被重新看見的野地……" },
  ];

  const TRIPS = [
    { id:"uncat", name:"所有景點", count:"4 筆記錄", style:"plain" },
    { id:"oc2026", name:"2026奧捷", range:"2026/4/1 – 2026/4/9", count:"18 筆記錄", style:"clay",
      dateLabel:"2026年4月1日 – 2026年4月9日",
      items:[
        { date:"4月 9", time:"10:09", title:"克拉姆-葛拉斯宮",
          addr:"Husova 158/20, Staré Město, 110 00 Praha-Praha 1, 捷克",
          text:"各位貴賓,現在我們正站在克拉姆-葛拉斯宮前,這座氣勢恢宏的建築,不僅是布拉格巴洛克建築的瑰寶,更是一段段引人入勝的人類故事的載體。它的歷史遠不止……" },
        { date:"4月 8", time:"09:13", title:"Fountain and statue of Saint George, Prague Castle",
          addr:"Třetí nádvoří Pražského hradu, 119 00 Praha 1-Hradčany, 捷克",
          text:"漫步在這布拉格城堡的第三庭院,您眼前這座聖喬治噴泉與雕像,不僅僅是石與水的結合,更是布拉格千年歷史與信仰的縮影。它的存在,訴說著一段又一段關於……" },
      ] },
  ];

  const PLANS = [
    { id:"week",  name:"每週方案", price:"$30.00",  per:"/ 週" },
    { id:"month", name:"每月方案", price:"$150.00", per:"/ 月" },
    { id:"year",  name:"每年方案", price:"$690.00", per:"/ 年", badge:"最划算",
      feats:["無限次數使用導覽","無廣告體驗","路線規劃功能"], fine:"每年自動續訂,可隨時取消" },
  ];

  const OPT_TPL = {
    nature: [
      { t:"被留下來的那片樹林", d:"開發圖上曾該被抹除的綿意，如何在居民的連署下變成今天的樹冠……" },
      { t:"河道改道之前的此地", d:"水系整治把一座農地推成公園，舊圖上的彎道還留在步道的弧形裡……" },
      { t:"黃昏時的鳥與人", d:"黃昏後一小時，這裡會换上另一批居民——以及一群守護它們的人……" },
    ],
    heritage: [
      { t:"建康對面的那場火", d:"一場夜火決定了這區街廮的尺寸，也決定了今天你走的這條路……" },
      { t:"匠師留在檑上的名字", d:"重修時工人在檑柶上發現一行墨字，那是一位不在後例上的匠師……" },
      { t:"一年一次的遷徒", d:"陣頭、鐘鼓、燈火：這場已經走了一百年的運動到底在搝住什麽？" },
    ],
    urban: [
      { t:"拆除與重建的豪賭", d:"一份被否決十年的圖面，最後如何把這康街口改寫成今天的樣子……" },
      { t:"站前那席不存在的場", d:"舊照片裡的市集已經消失，它的作息卻還留在這區的作息上……" },
      { t:"樓高限制的那場爭執", d:"一條看不見的線，決定了你現在抬頭看到的天空有多大……" },
    ],
  };
  function genOptions(p){
    if(p.id==="stpeters") return STORY_OPTIONS;
    return (OPT_TPL[p.cat] || OPT_TPL.urban);
  }

  function genStory(p){
    return {
      id:"gen-"+p.id, place:p.name, img:p.img, glyph:p.glyph, cat:p.cat,
      date:"2026年5月30日", chapter:"Anno · I", latin:p.latin,
      title:"城市邊緣的綠色記憶", sub:p.name, dropcap:"沿",
      body:[
        "著步道緩緩深入,"+p.name+"在喧囂的城市邊緣闢出一方靜土。陽光穿過層層枝葉,在地面灑落斑駁的光影,空氣裡滿是草木與濕潤泥土的氣息。",
        "這片綠地的故事,往往藏在不起眼的角落——一株被刻意保留的老樹、一道整治過的河岸,或一座承載了幾代人童年的遊具。它們默默見證著,土地如何在開發與守護之間,慢慢尋得平衡。",
        "如今的"+p.name+",是居民散步、孩童嬉戲、旅人駐足的所在。它溫柔地提醒著我們:最動人的風景,有時就在離家不遠的地方。",
      ],
      quote:{ q:"最動人的風景,有時就在離家不遠的地方。", by:"—— "+p.name },
      footer:(p.latin||"").split(" · ")[0] || p.name,
    };
  }

  window.LS_DATA = { CAT, PLACES, STORY_OPTIONS, STORIES, STPETERS_STORY, TIMELINE, TRIPS, PLANS, genStory, genOptions };
})();
