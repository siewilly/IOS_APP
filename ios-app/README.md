# Live2DChatApp (iOS 原生 + 低功耗 WebEngine 混合架構)

專為愛蜜莉雅（Emilia）打造的 iOS 伴侶應用程式，採用 **SwiftUI 原生聊天介面與音訊網路管線 ＋ 本地端 WKWebView 專責低功耗 Live2D 渲染** 的極致防發燙混合架構。

---

## 🌟 架構亮點與防發燙省電設計

1. **零 Web Audio 負載**：
   - 瀏覽器端 Web Audio API 頻譜分析是手機發燙的主因。本專案將 TTS 語音解碼與音訊播放交由 iOS 原生 `AVAudioPlayer` 處理。
   - 原生 Swift 透過 `CADisplayLink`（限制在 20 FPS）讀取硬體音訊振幅，換算嘴型開合程度後，透過 JS Bridge 直接注入 Live2D 的 `ParamMouthOpenY`。
2. **動態幀率降溫機制**：
   - **待機狀態**：`PIXI.ticker.maxFPS` 鎖定在 **12 FPS**（維持細膩呼吸與微動，極低 GPU 負擔）。
   - **說話 / 動作喚醒**：收到語音或動作時動態提升至 **30 FPS**，結束後 2 秒自動降回 12 FPS。
3. **強制鎖定解析度倍率**：
   - 強制 `resolution: 1`、`autoDensity: false`、`powerPreference: 'low-power'`，避免 iPhone 3x Retina 螢幕產生 9 倍像素運算壓力。
4. **背景自動凍結**：
   - 監聽 SwiftUI `scenePhase`，進入後台或螢幕關閉時立即暫停 `app.ticker` 與音訊管線。
5. **雲端穿透動態設定**：
   - App 內建原生設定頁面，可隨時填寫並切換 Cloudflare Tunnel 網址（如 `https://xxxx.trycloudflare.com`）或區域網路 IP，無須重新編譯。

---

## 📁 專案檔案結構

```
ios-app/
├── project.yml                               # XcodeGen 專案生成配置 (iOS 16.0+)
├── README.md                                 # 本文件
└── Live2DChatApp/
    ├── Info.plist                            # ATS 任意連線許可與麥克風權限
    ├── App/
    │   └── Live2DChatAppApp.swift            # SwiftUI App 進入點
    ├── Models/
    │   └── ChatModels.swift                  # 訊息與伺服器 Payload 資料結構
    ├── Services/
    │   ├── ServerConfigManager.swift         # 伺服器網址記憶與 WebSocket URL 解析
    │   ├── ChatNetworkService.swift          # 原生 URLSession WebSocket 通訊
    │   └── NativeAudioLipSyncManager.swift   # 原生 AVAudioPlayer + CADisplayLink 低功耗嘴型同步
    ├── Views/
    │   ├── ContentView.swift                 # 主介面（Live2D 底層 + 半透明聊天層）
    │   ├── Live2DWebView.swift               # WKWebView 容器與 JS Bridge 控制器
    │   ├── ChatMessageBubble.swift           # 水晶紫質感的氣泡對話框
    │   └── SettingsView.swift                # 伺服器網址與純文字省電模式設定
    └── Resources/
        └── WebEngine/                        # 本地資料夾參照 (Folder Reference)
            ├── index.html                    # 極簡透明畫布
            ├── renderer.js                   # 12/30 FPS 動態幀率渲染引擎
            ├── libs/                         # PixiJS 6 + Cubism 4 Core
            └── model/                        # 愛蜜莉雅 Live2D 模型、貼圖、動作與表情
```

---

## 🚀 雲端自動打包（GitHub Actions）

本專案已在 `.github/workflows/build-ios-ipa.yml` 配置完整的 GitHub Actions 工作流程：

1. **觸發條件**：
   - Push 或 Pull Request 包含 `ios-app/**` 資料夾。
   - 或在 GitHub 倉庫的 **Actions** 分頁中手動點擊 **Run workflow**。
2. **自動建置流程**：
   - 在 `macos-latest` 虛擬機自動安裝 `xcodegen`。
   - 執行 `xcodegen generate` 生成 `Live2DChatApp.xcodeproj`。
   - 透過 `xcodebuild` 以 `Release` 與略過簽名（`CODE_SIGNING_ALLOWED=NO`）編譯 `.app`。
   - 打包為 `Payload/` 並壓縮成 `Live2DChatApp-unsigned.ipa`。
   - 上傳為 GitHub Artifacts，供直接下載回電腦進行側載安裝。

---

## 📲 側載安裝說明（Sideloading）

下載打包出的 `Live2DChatApp-unsigned.ipa` 後，可透過以下工具直接安裝至 iPhone：
- **TrollStore**（巨魔商店，支援系統免重簽永久安裝）
- **AltStore / SideStore**（使用個人免費 Apple ID 進行 7 天自簽安裝）
- **Sideloadly**（Windows / Mac / Linux 下的 IPA 簽名側載工具）
- **LiveContainer** / **Scarlet** / **Esign**

---

## 💻 本地 macOS 開發（若後續需要 Xcode）

在 macOS 終端機中執行：
```bash
brew install xcodegen
cd ios-app
xcodegen generate
open Live2DChatApp.xcodeproj
```
即可直接在 Xcode 中進行模擬器或實機除錯。
