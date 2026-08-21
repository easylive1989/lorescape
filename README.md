# Lorescape — 你的 AI 口袋歷史學家

[![CI/CD Pipeline](https://github.com/easylive1989/instant_explore/actions/workflows/ci.yml/badge.svg)](https://github.com/easylive1989/instant_explore/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/easylive1989/instant_explore/graph/badge.svg)](https://codecov.io/gh/easylive1989/instant_explore)

別只是看風景，要讀懂風景。Lorescape 為你眼前的每個景點，生成一段以史實為本的真實小故事，再以純淨人聲為你娓娓道來。

## 詳細說明

🌍 當你站在宏偉的古蹟前，你看見的是一堆冰冷的石頭，還是千年前的輝煌與脈絡？

親愛的旅人，我們知道你不滿足於走馬看花。 你渴望了解這座城市的靈魂，你想要看穿表象，閱讀磚瓦背後的故事。

歡迎使用 Lorescape — 專為深度知性旅人打造的 AI 故事導覽。在這裡，旅行不再只是拍照打卡，而是一場深度的閱讀體驗。我們不堆砌冷冰冰的條目式資訊，而是為每個景點寫成一篇有溫度、有脈絡，且**以維基百科等可信來源為事實依據**的真實小故事，再用自然的語音念給你聽。

把手機放口袋，戴上耳機，讓風景開口說故事。

✨ 為什麼 Lorescape 是你的最佳旅伴？

📖 **真實，而非杜撰的小故事** 每段內容都由 AI 以維基百科內容為事實根據撰寫，並標註資料來源（grounding），讓你聽得安心。我們把生硬的歷史資料，轉化成三段式、引人入勝的敘事，而不是制式的百科條目。

🎭 **你來挑選故事的切角** 同一個景點，可以有很多種說法。Lorescape 會先給你 2～3 個故事角度的預告（例如「一場大火的祕辛」、「建築背後的權力角力」），你挑選最感興趣的那個，我們才為你展開完整故事。

🎙️ **純淨人聲，邊聽邊看** 故事以語音逐句朗讀，畫面同步高亮正在念到的段落。我們希望你抬起頭欣賞實景，必要時再低頭看一眼文字。

📔 **你的旅程，自動成冊** 每聽完一段故事，就自動留下一篇手記，依旅程歸檔、沿時間軸重溫，走過的每個角落隨時翻得回來。

📍 **自由探索，隨遇而安** 打開 App，看看身邊有哪些隱藏的歷史寶藏，想去哪就點哪，享受真正的自由行樂趣。

準備好閱讀這個世界了嗎？ 現在就下載 Lorescape，讓每一次的駐足，都充滿意義。

## ✨ 核心功能
- 📖 **AI 景點故事生成** - 以維基百科等可信來源為依據，為每個景點生成三段式的真實小故事，並標註資料出處。
- 🎭 **故事角度選擇** - 先給你 2～3 個故事切角預告，挑一個感興趣的再展開成完整故事。
- 🎙️ **語音口述導覽** - 純淨人聲逐句朗讀，畫面同步高亮正在念到的內容。
- 📔 **旅程手記** - 聽完的故事自動成篇，依旅程歸檔，沿時間軸重溫走過的地方。
- 📍 **地圖探索** - 定位當前位置，發現身邊的景點並一鍵生成故事。
- 🔐 **安全登入** - 支援 Google、Apple 帳號登入，雲端同步資料安全有保障。

## 💡 使用場景

- 🌍 **深度知性旅行** - 適合不滿足於走馬看花，渴望了解城市靈魂的深度知性旅人。
- 📚 **歷史文化學習** - 透過以史實為本的故事敘事，深入了解景點背後的脈絡。
- 🧭 **自由行探索** - 擺脫傳統導覽路線束縛，隨心所欲探索周邊景點。

> **設計理念**：以史實為本、敘事為形、語音為媒，讓閱讀世界成為習慣而非負擔。

## 🛠️ 技術棧

- **前端:** Flutter (iOS / Android / Web)
- **後端服務:** Python (FastAPI) — 負責故事生成、每日故事排程與社群發佈
- **資料/帳號:** Supabase (Authentication, Database, Storage)
- **AI 服務:** Gemini (LLM 故事生成)
- **事實來源:** Wikidata / Wikipedia (grounding，確保故事以史實為本)
- **語音合成:** flutter_tts (TTS 逐句朗讀與進度同步)
- **地圖服務:** Google Maps API
- **訂閱管理:** RevenueCat
- **架構:** Feature-First 模組化設計
- **狀態管理:** Riverpod
- **設計理念:** 行動優先 (Mobile-First)

## 🚀 快速開始

```bash
# 複製專案
git clone https://github.com/easylive1989/instant_explore.git
cd instant_explore/frontend

# 安裝依賴
fvm flutter pub get

# 執行應用程式 (開發環境，需透過 --dart-define 傳入環境變數)
fvm flutter run \
  --dart-define=GOOGLE_MAPS_API_KEY=your_key \
  --dart-define=SUPABASE_URL=your_url \
  --dart-define=SUPABASE_ANON_KEY=your_key \
  --dart-define=GEMINI_API_KEY=your_key
```

### 環境變數設定

透過 `--dart-define` 傳入以下變數:

| 變數名稱 | 說明 |
|---------|------|
| `GOOGLE_MAPS_API_KEY` | Google Maps API 金鑰 |
| `SUPABASE_URL` | Supabase 專案 URL |
| `SUPABASE_ANON_KEY` | Supabase Anon Key |
| `GEMINI_API_KEY` | Google Gemini API 金鑰 |
| `GOOGLE_WEB_CLIENT_ID` | Google OAuth Web Client ID |
| `GOOGLE_IOS_CLIENT_ID` | Google OAuth iOS Client ID |
| `REVENUECAT_API_KEY_ANDROID` | RevenueCat Android API 金鑰 |
| `REVENUECAT_API_KEY_IOS` | RevenueCat iOS API 金鑰 |

> 詳細設定請參考 `frontend/.env.example`

### 🔧 CI/CD 狀態
- **程式碼檢查**: 每次 push 自動執行格式檢查與靜態分析
- **單元測試**: 自動執行單元測試
- **資料庫同步**: master 分支自動推送 Supabase DB Schema
- **自動部署**:
  - Android: 自動建置 AAB 並部署至 Google Play Internal Testing
  - iOS: 自動建置 IPA 並上傳至 TestFlight

## 📚 專案架構

### 目錄結構

```
instant_explore/
├── frontend/                 # Flutter 應用程式
│   ├── lib/
│   │   ├── main.dart         # 應用程式入口
│   │   ├── app.dart          # App 設定 (路由、主題)
│   │   ├── app/              # App 層級設定 (路由、主題、環境設定)
│   │   ├── core/             # 框架無關的基礎設施 (錯誤、服務、工具)
│   │   ├── shared/           # 跨功能共用的 UI 元件與擴充
│   │   └── features/         # 功能模組
│   │       ├── explore/      # 地圖探索附近景點
│   │       ├── narration/    # AI 故事生成 + TTS 語音朗讀 (核心)
│   │       ├── journey/      # 文化足跡日誌
│   │       ├── trip/         # 旅程分組
│   │       ├── auth/         # 登入與認證
│   │       ├── subscription/ # 訂閱管理
│   │       ├── settings/     # 設定頁面
│   │       └── ...           # 其他模組 (sync / usage / ads / analytics 等)
│   ├── test/                 # 測試檔案
│   └── assets/               # 靜態資源
├── backend/                  # Python (FastAPI) 後端：故事生成、每日故事排程、社群發佈
├── supabase/                 # Supabase 設定與 Schema
├── landing/                  # 行銷官網 (Next.js)
└── docs/                     # 專案文件與設計文件
```

## 🧪 測試

```bash
cd frontend
# 執行單元測試
fvm flutter test
```

## 📝 授權

本專案採用 Apache 2.0 授權條款 - 詳見 [LICENSE](LICENSE) 檔案

---

**Lorescape** - 讓每一次的駐足，都充滿意義 📖✨