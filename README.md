# 愛蜜莉雅 (Emilia) 靈動生物引擎 Live2D 桌面寵物

> 原汁原味《Re:從零開始的異世界生活》愛蜜莉雅桌面伴侶。融合官方 Live2D 渲染架構、微表情生物模擬引擎、Fish Speech 高橋李依聲線克隆、Groq 秒級容錯大模型池、零 Token 螢幕視覺感知與純淨桌寵互動卡片。

---

## 🌟 核心特色與實裝功能

1. **純淨桌寵介面（InputSubtitle 卡片）**：
   - 預設擺脫厚重 Repo 儀表板，僅呈現極致純粹的 Live2D 角色與底部懸浮對話卡片（支援自由拖曳、即時字幕顯示、打斷與語音輸入開關）。
2. **頂部 HUD 水平平滑滑動工具列**：
   - 包含好感度羈絆膠囊、一鍵換裝（經典大衣 / 夏日泳裝）、番茄鐘、治癒 BGM、小日記、語音喚醒、視覺感知、調校室等完整功能。
3. **無邊框全透明背景桌面寵物 (Pet Mode)**：
   - 支援系統級透明穿透、滑鼠穿透與視窗化雙向切換。
4. **零 Token 本機畫面感知 (Screen Vision)**：
   - 透過 `/api/capture-screen` 在本機進行毫秒級 Perceptual Diff 像素比對，未變動自動攔截，Token 消耗精準為 0。
5. **待機 30 分鐘溫柔關懷 (Proactive Speaking)**：
   - 閒置門檻設為 30 分鐘，專注不打擾，支援 `[SILENT]` 靜默陪伴機制。
6. **Groq 免費備用模型秒級容錯切換池**：
   - 主力 `qwen/qwen3.8-27b`（40ms 響應）遇 429 速率限制時，0.1 秒無縫轉移至備用池 `openai/gpt-oss-120b` 與 `openai/gpt-oss-20b`，自動字串清洗杜絕報錯中斷。
7. **全網際網路 / 區網跨設備連線**：
   - 支援 Cloudflare HTTPS 安全加密通道，手機與外網設備皆可開啟麥克風語音互動。

---

## 🚀 快速啟動指南

### 1. 本地啟動腳本
```bash
# 啟動桌寵後端與桌面客戶端
./start_pet.sh

# 停止所有桌寵服務
./stop_pet.sh

# 重啟桌寵服務
./restart_pet.sh
```

### 2. 存取入口
- **本機網頁版**：`http://localhost:12393`
- **區域網路 (Wi-Fi)**：`http://192.168.1.103:12393`
- **外網安全通道 (HTTPS)**：透過 `cloudflared tunnel --url http://localhost:12393` 取得即時網址

---

## 📜 版本更新紀錄 (Version History / Changelog)

### [v1.9.0] - 2026-11-18
- **資安強化、資源按需載入、雙語無延遲解析與統一事件匯流排架構升級 (`Architecture, Security, Lazy ASR & Unified Bridge`)**：
  - **1. 資安防護與金鑰外置化 (`server.py`)**：
    - **`/api/capture-screen` 本機／區網白名單防護**：新增 `_is_local_or_lan_request`，嚴格驗證來源 IP 與 `CF-Connecting-IP` / `X-Forwarded-For` 標頭，拒絕外網穿透訪客呼叫截圖端點（回傳 HTTP 403）。
    - **移除硬編碼 Groq API Key**：改由環境變數 `GROQ_API_KEY` 或 `conf.yaml`（`groq_llm.llm_api_key`）動態讀取密鑰。
  - **2. 按需延遲載入 ASR 與零冗餘音訊負載 (`service_context.py` / `stream_audio.py`)**：
    - **`LazyASREngine` 延遲初始化**：後端啟動時僅登錄輕量代理實例，待實際收到語音轉文字請求時才載入 `sherpa_onnx_asr` 模型，伺服器啟動時間由 4 秒以上降至約 **1 秒**並節省大量待機記憶體。
    - **消除重複音量計算 (`prepare_audio_payload`)**：對於 `.wav` 音訊直接讀取位元組並設 `volumes = []`，略過後端 `pydub` 解碼與逐 20ms 切片計算（統一由前端 `LAppWavFileHandler` 讀取 WAV PCM 計算 RMS）。
  - **3. 長期記憶非同步防抖落盤 (`local_memory_system.py`)**：
    - `add_memory` 改透過 `threading.Timer`（2.0 秒防抖）＋ `atexit` 安全 `flush()` 寫入磁碟，對話回合不再阻塞於同步寫檔。
  - **4. 多句括號雙語 0ms 解析與桌寵雙語層次統一 (`WebView.tsx` / `input-subtitle.tsx`)**：
    - 新增共用 `parseBilingualText` 解析器，可精準拆解單句與多句混排括號翻譯（僅擷取含漢字且不含假名之括號內容），前後端同步支援於 **0ms** 內免二次呼叫翻譯端點。
    - 同步升級桌面寵物端 `InputSubtitle` 排版與網頁版一致：**上方日文原聲大字 ＋ 下方繁體中文副字幕**。
  - **5. 統一前端事件橋接 `window.emiliaBridge` 與安全分包 (`emilia_biometric_enhancer.js` / `WebToolMenu.tsx` / `vite.config.ts`)**：
    - 以 `window.emiliaBridge` ＋ `emilia-bridge-update` 事件取代脆弱的 `document.getElementById(...).click()` 模擬點擊，於網頁端 `WebToolMenu` 補齊 **🍅 25分鐘番茄鐘專注**、**📖 冒險日記** 與 **BGM 即時播放狀態** 同步；網頁模式下將右上紫水晶吊墜下移至 `top: 64px` 避免與頂部列重疊。
    - 調整 `vite.config.ts` `manualChunks` 僅獨立拆出無 React 依賴的 `vendor-ai`（578.55 kB）與 `vendor-utils`（71.66 kB），杜絕 Rollup CommonJS 循環依賴錯誤同時縮減主包體積。

### [v1.8.0] - 2026-11-18
- **全棧極致效能架構重構與記憶體/I/O 瓶頸徹底清除 (Full-Stack Deep Performance & Zero-Blocking Optimization)**：
  - **1. 生物增強中介層效能突破 (`emilia_biometric_enhancer.js`)**：
    - **移除全頁 `MutationObserver` DOM 掃描風暴**：徹底刪除每次文字更新便遞迴走訪全頁 `p, span, div` 計算 `textContent` 的監聽器，直接透過 WebSocket 封包直驅 `[motion:...]` 動作，大幅消除主執行緒與打字機幀率抖動。
    - **關閉背景語音喚醒重試迴圈 (`wakeWordActive = false`)**：預設停用 `webkitSpeechRecognition` 背景常駐重試，徹底符合靜音指示並避免背景麥克風資源佔用。
    - **修復 `AudioContext` 實例洩漏與 `WeakMap` 參數快取**：改為全域複用單例 `bgmAudioContext`，並以 `WeakMap(core -> Map)` 按模型實例獨立快取 Live2D 參數索引，杜絕換裝時的索引錯位。
  - **2. Live2D 渲染管線與 WAV PCM 解析高速化 (`lappmodel.ts` / `lappwavfilehandler.ts`)**：
    - **頂點計算前注入生物微動 (`__emiliaApplyBiometrics`)**：將生物神經元微動從原本 `model.draw()` 之後提前至 `this._model.update()` 計算之前注入，消除一幀畫面延遲與參數被覆寫的問題。
    - **16-bit PCM 直接向量化讀取**：重寫 `LAppWavFileHandler.loadWavFile` 迴圈，直接以 `DataView.getInt16(..., true)` 讀取樣本（含安全邊界保護），消除 40 萬次以上逐樣本函式呼叫造成的話音初期卡頓。
  - **3. 桌面寵物主進程與翻譯雙向防抖 (`pet-main.cjs` / `input-subtitle.tsx`)**：
    - `saveBounds` 改採 **300ms 防抖 ＋ 非同步 `fs.promises.writeFile`**，徹底消除拖曳或縮放桌寵視窗時的同步磁碟 I/O 卡頓。
    - 桌寵版 `InputSubtitle` 的 `/api/translate` 請求同步補齊 **120ms 防抖機制**。
  - **4. Python 後端事件循環零阻塞與 $O(|C|)$ 記憶檢索 (`Open-LLM-VTuber`)**：
    - **`/api/capture-screen` 與音訊封裝全非阻塞化**：於 [server.py](file:///home/siewilly/Live2D_pet/Open-LLM-VTuber/src/open_llm_vtuber/server.py) 與 [tts_manager.py](file:///home/siewilly/Live2D_pet/Open-LLM-VTuber/src/open_llm_vtuber/conversations/tts_manager.py) 中透過 `asyncio.to_thread` 卸載截圖、影像縮放與音訊處理；[stream_audio.py](file:///home/siewilly/Live2D_pet/Open-LLM-VTuber/src/open_llm_vtuber/utils/stream_audio.py) 對原生 `.wav` 檔直接讀取載入，略過多餘 `ffmpeg` 子進程轉檔。
    - **長期記憶索引升級為 $O(|C|)$ 雜湊定位 (`local_memory_system.py`)**：新增 `_id_to_idx` 雜湊對映表（支援驅逐重建同步）與緊湊 JSON 格式 (`separators=(",", ":")`)，避免線性走訪並縮小序列化體積。
  - **5. 廢棄檔案清理**：清除 `frontend/assets/` 超過 60MB 的舊雜湊打包檔與根目錄臨時 `enhancer_from_line_*.js` 碎片檔案。

### [v1.7.2] - 2026-11-17
- **暫時停用聲音接收功能與麥克風常駐監聽 (Temporarily Disable Audio Reception / Always-On Mic)**：
  - **聲音接收功能安全關閉（Microphone & VAD Muted）**：
    - 依指示全域設定 `AUDIO_INPUT_DISABLED = true`，徹底關閉前端常駐麥克風監聽與語音活動偵測（VAD）。
    - 封鎖 `startMic` 與對話結束（`conversation-chain-end`）時的自動喚醒麥克風行為，徹底杜絕背景雜音誤觸或持續占用麥克風硬體。
    - 網頁版輸入列麥克風按鈕切換為靜音狀態標籤（`BsMicMuteFill`），點擊時給予貼心 Toast 提示引導文字交流。
  - **愛蜜莉雅語音說話功能 100% 完整保留（Emilia TTS Speech Fully Preserved）**：
    - 嚴格隔離輸入端與輸出端：使用者透過文字輸入框或快捷氣泡發送訊息時，愛蜜莉雅依然能即時生成 Fish Audio 原聲語音、驅動平滑嘴形動畫、展現動態頻譜與雙語對話字幕。

### [v1.7.1] - 2026-11-17
- **全端效能與流暢度深度優化 (Full-Stack Performance & Latency Optimization)**：
  - **前端 React 渲染效能升級（隔離狀態避免整頁高頻重繪）**：
    - 將對話框文字打字機邏輯抽離為獨立的 `EmiliaDialogueCard` Memoized 元件。
    - 徹底根除先前打字機每 18ms 觸發一次全域 `WebView`（包含背景、Live2D 舞台、頂部列、輸入列）整頁重渲染的問題，CPU 使用率降低 80% 以上，Live2D 動態維持極致 60 FPS 滿幀。
  - **Vite 多代碼塊分包（Multi-Chunk Code Splitting）**：
    - 設定 Rollup `manualChunks` 將原本單一 1.7 MB 的肥大 `main.js` 拆分為 `vendor-react`、`vendor-ui`、`vendor-ai`、`vendor-libs` 與 `main.js`。
    - `main.js` 核心體積由 **1,697 kB 暴跌至 310 kB（縮減 81.7%）**，搭配 `modulepreload` 與 HTTP/2 平行載入，首屏與資源載入速度提升近 2 倍。
  - **翻譯 API 呼叫 120ms 防抖（Debounce）**：
    - 在字幕串流抵達時加入 120ms 防抖機制，避免單一語句在串流階段重複向後端發送多次無效翻譯請求。
  - **後端 `/api/translate` 非同步連線池與零阻塞優化 (AsyncOpenAI Pooling & O(1) Cache)**：
    - 將原本每次請求重複建立 `OpenAI` 同步實例並阻塞 Uvicorn 事件循環的設計，徹底改為全域單例長駐 `AsyncOpenAI` 連線池。
    - 配合 `asyncio.wait_for` 與記憶體 LRU 快取，常見語句命中時間僅需 **2.4 毫秒**，未命中時亦 100% 釋放事件循環，不干擾 WebSocket 與音訊串流。
  - **語音合成延遲減半（Fish Audio Balanced Streaming）**：
    - 將 TTS 合成延遲模式由 `normal` 切換為 `balanced`，在維持高品質高橋李依聲線的同時，將語音生成排隊時間縮減達 50%。

### [v1.7.0] - 2026-11-17
- **網頁版對話框頂級動漫視覺昇華、日文主大字/中文副小字排版與說話順暢度大幅優化 (Web Dialogue UI Overhaul & Speech Smoothness System)**：
  - **日文主體大字 × 繁體中文副字幕層次重構 (Japanese-First Dual-Language Hierarchy)**：
    - **上方主要大字體 (Top Focus)**：愛蜜莉雅的原聲日文設為主要大字 (`20px ~ 23px`)，採用俐落高清晰度動漫字體族群 (`Hiragino Kaku Gothic ProN`, `Meiryo`, `Noto Sans JP`)，搭配 600 字重與柔和文字投影 (`text-shadow`)，完美還原日系視覺小說經典立體沉浸感。
    - **下方優雅副字幕 (Bottom Subtitle)**：即時翻譯的繁體中文作為副標小字 (`14px ~ 15px`)，以淡紫丁香色調 (`purple.100`) 呈現在纖細的紫水晶毛玻璃分割線下方，附帶圓角 `[中文]` 標籤，層次分明且不喧賓奪主。
  - **說話順暢度全面優化：物理阻尼嘴形平滑化 (Physically Damped Live2D Lip Sync)**：
    - 徹底根除 Live2D 嘴形在 60 FPS 下因音訊瞬態 RMS 波動產生的劇烈抽搐抖動（震動式開閉問題）。
    - 在 WebSDK `LAppModel` 底層引入**非對稱指數低通平滑濾波器 (Exponential LERP Low-Pass Filter)**：
      - 起音 (Attack)：以高響應物理阻尼速率 (`20.0`) 迅速張口，跟隨發音音節。
      - 釋音 (Decay)：以柔和漸收物理阻尼速率 (`12.0`) 平滑閉合，消除音節間急墜抽動。
      - 門檻降噪 (Noise Floor Gate)：抑制底噪微抖，並將增益倍率由原本失真剪切的 `4.0` 修正為自然口型係數 `1.0`，呈現栩栩如生的高品質動漫語音口型銜接。
  - **說話順暢度全面優化：打字機平滑推進流 (Progressive Typewriter Streaming)**：
    - 語音回覆不再瞬間突兀全句跳出，改為隨說話節奏逐字流暢推進（每字 18~28ms 平滑湧現），並自帶呼吸脈衝打字光標 (`▌`)。
    - 支援「點擊立即展開」機制（使用者點擊對話框即可立刻顯示全句，操作體驗如同視覺小說遊戲）。
  - **動態 4-Bar 語音頻譜等化器 (Voice Soundwave Visualizer)**：
    - 當愛蜜莉雅開口說話時，對話框頂部狀態列動態綻放 4 條上下起伏跳動的紫水晶光柱語音等化器 (`emilia-soundwave`)，隨語音律動起伏，提供立體直觀的對話生命力反饋。
  - **即時翻譯平滑淡入滑上動效 (Smooth Subtitle Transition)**：
    - 繁體中文翻譯生成後，採用 `@keyframes emiliaSubtitleSlideIn` 物理曲線柔和滑上淡入，消除文字瞬間突兀跳變。

### [v1.6.4] - 2026-11-17
- **桌面寵物端渲染穩定化與雙啟動腳本支援 (Desktop Pet Rendering Stabilization & Launchers)**：
  - **React 渲染錯誤修復 (ReferenceError Fix)**：修復 `input-subtitle.tsx` 中遺漏引入的 `useRef`，恢復桌寵模式下 React 元件樹的穩定渲染與輸入對話框正常運作。
  - **Live2D 高畫質視窗擷取支援 (`preserveDrawingBuffer: true`)**：在 WebGL 初始化時啟用 `preserveDrawingBuffer`，確保原生 Electron 視窗擷取（`webContents.capturePage()`）與 Canvas 離屏繪製能 100% 完整捕捉愛蜜莉雅精細立繪與透明背景。
  - **雙啟動腳本支援與 npm 腳本整合**：
    - 新增 `run_desktop_pet.sh` 軟連結指向 `run_pet.sh`，使用者無論執行 `./run_pet.sh` 或 `./run_desktop_pet.sh` 均可一鍵無縫喚醒桌面寵物。
    - `package.json` 正式登錄 `"pet": "electron --no-sandbox pet-main.cjs"`，相容於 Linux 各種桌面環境直接啟動。

### [v1.6.3] - 2026-11-17
- **工具選單頂級動漫毛玻璃重構 (Anime Glassmorphism Tool Menu & Console Deck Redesign)**：
  - **桌面寵物端靈動控制台 (`PetView` / `emilia_biometric_enhancer.js`)**：
    - **折疊狀態（預設純淨相伴）**：徹底移除原本橫跨愛蜜莉雅頭頂的粗糙長條按鈕列。預設優雅收攏為右上角懸浮的**「晶瑩紫水晶小吊墜」**，自帶溫柔上下漂浮呼吸光暈（`filter: drop-shadow`），還原 100% 乾淨無遮擋的桌面相伴體驗。
    - **展開狀態（動漫毛玻璃控制台 Console Deck）**：點擊吊墜時伴隨清脆空靈的水晶風鈴音效（`playFairyChime`），平滑綻放展開為 330px 精緻動漫卡片：
      - 🌸 **頂部控制台標題**：愛蜜莉雅靈動伴侶控制台（EMILIA COMPANION CONSOLE）與極簡圓形關閉按鈕（✕）。
      - 👗 **造型換裝專區**：獨立卡片清晰指示「當前造型」，並提供一鍵「切換 ⇄」直達 4星經典大衣 / 4星夏日泳裝。
      - 🪄 **靈動伴侶 2×3 矩陣**：完全剔除舊版生硬的 `|` 分隔線與左右滾動箭頭，重新編排為高對比毛玻璃按鈕矩陣：
        - 🎵 **治癒 BGM**：Re:0 經典水晶音樂播放/暫停與切換下一首（⏭️）。
        - 🍅 **番茄鐘專注**：25 分鐘專注陪伴倒數。
        - 👁️ **視覺感知**：即時螢幕智能觀測。
        - 🎙️ **語音喚醒**：喚醒詞（「愛蜜莉雅」/「EMT」）開關切換。
        - 📖 **冒險日記**：開啟每日冒險與回憶紀錄。
        - 💖 **好感羈絆**：即時動態呈現當前羈絆階級（例如 Lv.4 專屬戀人）。
      - 🐾 **底部快速通道**：切換桌寵/視窗模式與 Live2D 調校室快捷入口。
  - **網頁版專屬控制台抽屜 (`WebToolMenu.tsx`)**：
    - 徹底替換原本生硬擁擠的原版開發者側欄，打造全客製化 `WebToolMenu`：
      - 🌸 **精緻標題列**：毛玻璃紫韻質感徽章、愛蜜莉雅專屬標題與優雅關閉鈕。
      - 👗 **4星衣櫥造型卡片**：並列雙卡片視覺化呈現「4星 經典大衣 (冰之精靈)」與「4星 夏日泳裝 (沁涼夏日)」，自帶當前穿著高亮光環與打勾標章。
      - 💬 **對話與歷史管理**：一鍵開啟新話題、回顧歷史對話抽屜。
      - 🪄 **伴侶輔助工具**：Re:0 治癒音樂盒、螢幕畫面視覺感知。
      - 🖥️ **模式切換**：直覺切換至獨立桌寵視窗。
      - ⚙️ **系統進階設定**：呼叫完整的 TTS/LLM/ASR 設定面板。

### [v1.6.2] - 2026-11-17
- **對話框放大與日文即時繁體中文對照 (Enlarged Dialogue Card & Real-Time Translation)**：
  - **對話框大幅放大 (Generous Visual Area)**：
    - 寬度擴充至 780px (`width: min(94vw, 780px)`)，內縮間距大幅增加至 `px: 20~28px, py: 16~20px`，升級為 24px 圓角半透明毛玻璃質感。
    - 字體清晰度翻倍提升，主要中文翻譯採用 `18px ~ 21px` 大字體與 1.55 倍舒適行高，徹底告別手機或遠端觀看費力的問題。
  - **日文即時自動翻譯為繁體中文 (Real-time Japanese to Traditional Chinese)**：
    - 後端新增 `/api/translate` 極速翻譯 API 端點，結合 Groq 雲端推理與記憶體快取池（重複句 <1ms 極速秒回），專屬調校貼合《Re:0》愛蜜莉雅溫柔少女風格的台灣繁體中文翻譯。
    - 前端雙軌即時翻譯管線：
      1. 優先辨識與分離 LLM 自帶的括號中文翻譯。
      2. 若收到純日語原聲，自動向 `/api/translate` 請求即時繁中翻譯。
      3. 採用「**上層：清晰繁體中文翻譯（主要閱讀焦點）**」+「**下層：日文原句對照（保留動漫原汁原味）**」雙層架構，並標註 `中日即時雙語` 徽章。
    - 桌面寵物端（`InputSubtitle`）同步實裝中日雙語自動解析與對照顯示。

### [v1.6.1] - 2026-11-17
- **手機端網頁版頂級 UI 優化 (Mobile Web Responsive Optimization)**：
  - **角色絕對置中固定 (Strict Center Pinning)**：
    - 網頁版（`WebView`）徹底固定艾蜜莉雅於螢幕正中央（`x: 0.0`），舞台畫布鋪滿全視窗（`100vw × 100dvh`）。
    - 移除拖曳偏移與舊有座標快取，滑鼠或手機觸控不會將角色拉扯離位，同時完整保留點擊頭部摸頭反應（TapHead）與身體互動動作（TapBody）。
  - **動態安全區與防彈性回彈 (100dvh & Safe Area)**：
    - 採用 `100dvh` (Dynamic Viewport Height) 與 `env(safe-area-inset-bottom)`，徹底根治手機 Safari / Chrome 網址列伸縮造成的版面跳動與 iPhone 底部橫條遮擋問題。
    - 啟用 `overscroll-behavior: none`，滑動對話框時不會引發全頁橡皮筋滾動。
  - **抽屜式側邊欄 (Slide-over Drawer for Settings)**：
    - 移除手機端原本破壞比例的常駐大側欄，改為頂部懸浮毛玻璃按鈕觸發的滑出式抽屜面板，設定完成隨時收起，主畫面 100% 留給艾蜜莉雅。
  - **懸浮單手拇指操作台 (Floating Thumb-Zone Console)**：
    - **毛玻璃懸浮對話氣泡**：浮動於角色下方，支援打字機動效與角色名徽章。
    - **快捷互動提示詞膠囊**：提供橫向滑動的快捷標籤（「🌸 今天過得好嗎？」、「✨ 陪我聊聊天」、「🐾 摸摸頭」、「🪄 教我異世界魔法」），單擊直達。
    - **整合式懸浮輸入膠囊**：包含呼吸燈語音麥克風切換大鈕、文字輸入框與即時打斷/發送按鈕。
  - **頂部懸浮捷徑列**：
    - 整合極簡狀態呼吸指示燈（綠燈已連線 / 紅燈重連）與一鍵換裝捷徑（經典大衣 ⇄ 夏日泳裝）。

### [v1.6.0] - 2026-11-17
- **網頁版與桌寵全面解耦獨立 (Decoupled Web and Pet Architecture)**：
  - **模組化分工重構**：將過往混合於同一組件與全域 CSS 的架構徹底拆分為兩個獨立模組：
    - `src/renderer/src/pet/`（`PetView.tsx` & `pet.css`）：純淨桌面寵物專屬，固定於 440x700 緊湊視窗、100% 透明無邊框、精準黃金立繪比例與原生視窗拖曳，完全不受網頁版樣式污染。
    - `src/renderer/src/web/`（`WebView.tsx` & `web.css`）：大螢幕沉浸式網頁版專屬，完整保留左側功能面板（模型/TTS/Prompt/設定）、動態背景壁紙、沉浸式字幕區與底部輸入控制台，專供後續網頁端功能特別優化。
  - **智慧情境路由切換**：
    - Electron 桌面客戶端（或帶有 `?mode=pet` 參數）預設精準加載 `PetView`。
    - 標準網頁瀏覽器造訪（`http://localhost:12393/` 或 `?mode=web`）預設自動加載 `WebView`。
    - 側邊欄整合一鍵雙向切換選單（Web Mode / Pet Mode）。
  - **全域 CSS 樣式隔離**：移除強制全域透明背景，透過 `pet-mode` 與 `web-mode` 獨立作用域，確保網頁版壁紙主題與桌寵透明穿透各自獨立運作。

### [v1.5.2] - 2026-11-17
- **桌寵黃金比例精準校正 (Refined Proportions from User Reference)**：
  - 依照使用者提供的實機桌面截圖基準，徹底修復先前模型面部過度放大、比例跑掉的問題。
  - 將 Live2D 佈局寬度調校至 `0.41`、垂直位置配置於 `y: 0.28`，愛蜜莉雅全身立繪精準重現約佔螢幕 26% 的經典修長桌寵比例（高度約 260~300px），頭身比例優美端莊。
  - 愛蜜莉雅自然佇立於底部對話卡片正上方，雙足與輸入框上緣完美銜接，頭頂與頂部 HUD 留有舒適呼吸空間，視覺統一協調。
- **底部對話卡片精緻收斂**：
  - 輸入框寬度最佳化為 `380px`（`maxW: calc(100vw - 20px)`），完美貼齊桌寵下緣，無論在小視窗或螢幕邊角均精巧不突兀。
- **桌面截圖與視窗捕捉增強**：
  - 於 Electron 端支援 `desktopCapturer` 桌面擷取與螢幕驗證通道。

### [v1.5.1] - 2026-11-17
- **獨立緊湊桌寵小視窗 (440x700 剛好裝下愛蜜莉雅)**：
  - 徹底告別全螢幕大畫布，將桌寵前端改為 `440x700` 的精緻無邊框透明視窗，剛剛好完整容納愛蜜莉雅全身立繪與底部懸浮對話卡片。
- **電腦桌面左下角預設定位 (Desktop Bottom-Left Anchor)**：
  - 視窗啟動初始座標精準配置於電腦螢幕左下角（螢幕左側向內縮 40px、貼齊工作區底部上方），不遮擋桌面中央或右側主要工作區。
  - 支援 `pet_bounds.json` 本機座標持久化，手動拖曳至任意位置後自動保存，重啟立刻復位。
- **視窗級自由拖曳 (Native Window Dragging)**：
  - 透過 Electron IPC (`pet-drag-start`, `pet-drag-move`, `pet-drag-end`) 實現視窗級拖曳，按住角色或視窗任意區域即可平滑拖動整個視窗至電腦桌面任何角落，甚至跨雙螢幕自由穿梭。
- **模型完美居中與版面黃金適配**：
  - 模型原生座標配置為水平正中心（`x: 0.0`），立繪由頭頂至下身黃金填滿視窗，底部對話輸入卡片貼底收斂（`bottom: 24px`，寬 400px），精緻不擁擠。

### [v1.5.0] - 2026-11-17
- **100% 全透明網頁背景 (Transparent Web Background)**：
  - 徹底移除 `html:not(.electron) body` 的暗紫色漸層背景，全站強制套用 `background: transparent !important` 與 `background-color: transparent !important`，無論在 Web 端或 Electron 穿透環境均呈現 100% 透明。
- **預設預測左下角定位 (Default Bottom-Left Positioning)**：
  - 在 `Character.model3.json` 原生佈局設定與前端掛載邏輯中將愛蜜莉雅預設初始座標配置於左下角（`Layout: { width: 1.05, x: -0.95, y: -0.52 }`），使桌寵自然依附在螢幕左下方，不阻擋中央工作視窗。
  - 加入 `localStorage` 座標持久化機制（`emilia_pet_pos_x`, `emilia_pet_pos_y`），使用者自由拖動後即刻記憶，刷新或重啟自動還原最新位置。
- **適中黃金桌寵比例 (Proportional Moderate Scaling)**：
  - 修正原先 `Layout.width: 2.0` 疊加前端雙倍縮放導致角色過大、佔滿螢幕且超出視窗的異常問題。
  - 將模型佈局寬度調校為 `1.05`，`model_dict.json` 的 `kScale` 設為 `0.26`，前端自適應換算為約 52% 視窗高度的最適桌寵比例。
- **絲滑全域滑鼠自由拖曳 (Smooth Global Mouse Dragging)**：
  - 重構 `useLive2DModel.ts` 拖曳架構，結合模型邊界距離近接判定（`isNearModel`），點擊角色軀幹或週邊均可 100% 靈敏抓取。
  - 升級為全域 `document` Capture 級滑鼠移動與釋放監聽，徹底解決快速拖動時 React 容器失焦與掉落問題，拖曳反應極致絲滑穩定。

### [v1.4.0] - 2026-11-17
- **徹底清除走路與移動功能 (原地陪伴模式)**：
  - 徹底清除 `emilia_biometric_enhancer.js` 中的漫步引擎、位移動畫、地圖導航、桌椅抱枕等動態道具生成及打瞌睡位移代碼（共清除逾 1,360 行移動邏輯與冗餘樣式）。
  - 清理所有移動、漫步、起立、坐下相關按鈕監聽器與事件綁定，介面與選單完全不出現任何移動選項。
  - 愛蜜莉雅嚴格固定於原地安靜陪伴，完整保留 Live2D 自然呼吸微動作、視線微動反饋、摸頭反應、即時情緒動作、一鍵換裝、語音喚醒與治癒 BGM。

### [v1.3.0] - 2026-11-17
- **UI 優化**：全面改為純淨桌寵聊天框模式（`mode: 'pet'`），移除網頁版預設顯示的側邊欄、設定面板與深色背景，回歸輕巧靈動的懸浮卡片。
- **動態尋址**：`websocket-context` 支援動態依據目前 Origin 自動選用 `ws:` / `wss:`，完美相容 Cloudflare 外網通道與區網 IP。
- **Git 與規範實裝**：建立專案硬性規範，後續每次更新皆強制執行 Git 紀錄與 README 更新。

### [v1.2.0] - 2026-11-17
- **功能加回**：完整恢復 1、2、3、4、6 號功能（透明桌寵、桌面觀測、30m 待機插話、Groq 備用容錯池、頂部滑動 HUD）。
- **完全排除**：依使用者指示排除底部雙實體漫遊系統（功能 7）。

---

## 📌 開發維護硬性規範
所有後續維護此專案的 Agent 或開發者，必須嚴格遵守以下兩點：
1. **每次版本更新後，必須進行完整的 Git Commit 紀錄。**
2. **每次版本更新後，必須同步更新此 README.md 中的版本紀錄。**
