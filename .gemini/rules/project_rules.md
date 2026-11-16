---
description: "版本更新規範：每次版本更新皆需執行 Git Commit 紀錄與 README.md 更新"
globs: ["**/*"]
alwaysApply: true
---

# 專案版本更新硬性規範

> [!IMPORTANT]
> 依使用者嚴格指示：**從此之後，每次專案有任何功能調整、修正、重構或版本更新時，均必須同步完成以下兩項操作**：

1. **Git 版本控制紀錄**：
   - 所有相關修改的子專案與主目錄必須進行完整 `git add` 與 `git commit`。
   - Commit 訊息格式須清晰說明本次更動的模組與功能（如 `feat(ui): ...`、`fix(backend): ...`）。
2. **README.md 規範與更新**：
   - 根目錄 [README.md](/home/siewilly/Live2D_pet/README.md) 必須同步更新版本紀錄（Version History / Changelog）。
   - 記錄更新日期、版本號碼、新增/修改之功能與驗證狀態。
3. **介面純粹性原則**：
   - 桌面寵物與網頁版一律預設為**純淨桌寵聊天框模式（Live2D 角色 ＋ 懸浮 InputSubtitle 卡片 ＋ 頂部 HUD 工具列）**。
   - 絕不可預設載入包含側邊欄、全螢幕大儀表板、鏡頭/螢幕分頁等非桌寵的完整 Repo 管理介面。
