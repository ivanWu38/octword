# Session Handoff（最後更新：2026-07-09）

## 目前進度
本次 session 大幅打磨 Explore 分頁（Categories / Challenges）與遊戲畫面。以下全部已完成、已 build 成功（BUILD SUCCEEDED）並裝到模擬器：

- **固定標題／不亂滑**：Explore、Categories、Challenges、CategoryDetail、Journey(StatsView) 都把 masthead 抽到 ScrollView 外固定，內容才捲動。
- **Challenge 圖卡**：沒最佳成績時隱藏「—」；愛心改單一 icon＋數字（HUD 命數已 clamp `max(0,…)` 不顯示負數）。
- **Coffee 流程**：移除「No pressure」中間頁（`SupportConfirmSheet` 已刪），SupporterView 與 DailyView 卡片點「Buy me a coffee」直接跳廣告。
- **廣告修復**：把 categories 獎勵廣告獨立成新單元 `ca-app-pub-5654617376526903/3122234771`（`Constants.categoryRewardedAdUnitId` + `RewardedAdManager.category`）；修好 present 競態（`stablePresenter()` 等 sheet 完全 dismiss、presenter 需 `presentedViewController == nil`），解決「一直轉圈」與「already presenting」不跳廣告。DEBUG 仍用 Google 測試 ID。
- **鎖定 pack 新彈窗**：`LockedPackSheet.swift`（新檔，已加進 pbxproj）——金色「Watch a short ad」主鈕＋Premium 次鈕；訂閱一律叫 **Premium**。
- **移除 Free Today**：`CategoryService.dailyFreeCategoryId` 與列表金色標籤都拿掉。
- **新解鎖流程＋永久保留**：看廣告→進 pack 關卡列表、最前面未破關解鎖；pack 內每關各自需廣告。`adUnlockedPuzzles` 與 `enteredPacks` 都存 UserDefaults（重開 app 仍解鎖）；已進入的 pack 列表 icon 變 chevron。CategoryDetailView 有 per-level 鎖定（solved／ready／playable／locked 四態）。
- **Challenge 模式重做（各 5 檔、全免費）**：Timed＝「限時完成 N 局」（`ChallengeType.gameTarget`、`ChallengeSession.didCompleteGoal`）；Run＝命數存活、每局 10 猜（`GameState.maxGuessesOverride`）。名稱報紙主題：Timed＝Flash/Bulletin/Column/Feature/Front Page；Run＝Stop Press/Print Run/Daily Grind/Circulation/The Long Read。
- **Run 每盤結果卡**（`RunRoundCard`）：看答案＋鼓勵語＋剩餘命＋Continue；完美盤 confetti＋Flawless。結算頁有 rounds/flawless 統計。
- **Review 畫面**（`ChallengeReviewView`，editorial 風）：底線分頁 Boards/Answers＋箭頭切局；session 存每盤 `BoardData` 快照（上限 40）。
- **格子放大**：所有 8 盤模式（daily/unlimited/challenge/theme）tile 改由寬度決定（`GameView` 8-board 分支 `tileSize = tileWidth`），盤面上下捲動。
- **How to Play**：Explore 三模式遊戲畫面 `<` 右邊加 `?`（`questionmark.circle`），跳出**模式專屬、數字動態帶入**的說明卡（`HowToPlayContent` / `HowToPlayCard` 在 GameView.swift 末端）。不重講基本規則，只講各模式特別之處。

## 進行中
（無）—— 最後一項 How to Play 剛實作＋裝好，等使用者實測。

## 下一步
- 使用者實測 How to Play 卡（進 theme 關卡或 challenge 遊戲點左上 `?`）。
- **待辦（使用者說「等一下再做」）**：為 special/Explore 模式新增 achievements / badges（例：連續 N 盤全破、單場破 X 字、完成 Front Page…）。可參考 `puzzle-game-kit` skill。
- 可考慮：Run 的成績目前記「破字數」，但使用者敘述偏「撐幾盤」，未來或可調整成績指標／成就。

## 重要脈絡 / 決定
- 廣告不跳的根因有二：(1) 從 `.sheet` dismiss 後太快 present → present 在正在消失的 VC 上會靜默失敗且 delegate 不回呼 → 永久轉圈；(2) presenter 還掛著要消失的 sheet → 「already presenting」。修法都在 `RewardedAdManager.stablePresenter()`。
- 決策：解鎖永久保留（非 session-only，這是後來使用者更正的）；1-life「Stop Press」保留（釐清 life＝漏一個字才扣，不是猜錯就扣，可玩）；Run 每局收到 10 猜讓命真的會扣。
- 說明卡要「動態」：實機讀當下 preset/category 的實際數字，不可每模式寫死同一份。
- 使用者很在意品質與 app 的報紙(editorial)風格：襯線標題＋上下細線＋rust(#AE4124)/gold(#D89C28) 點綴，不要 iOS 圓角膠囊。改 UI 前習慣先出 HTML 給他看、確認才寫 code。
- 用繁體中文溝通、精簡直接。

## 相關檔案
- Explore：`Octordle/Views/Explore/`（CategoriesView / CategoryDetailView / ChallengesView / ExploreView / ChallengeGameView / LockedPackSheet）
- 服務／模型：`Octordle/Services/CategoryService.swift`、`ChallengeSession.swift`；`Octordle/Models/ChallengeType.swift`、`GameState.swift`、`BoardData.swift`
- 遊戲：`Octordle/ViewModels/GameViewModel.swift`、`Octordle/Views/Game/GameView.swift`（tiles＋HowToPlay）、`BoardView.swift`
- 廣告：`Octordle/Ads/RewardedAdManager.swift`、`Octordle/Utils/Constants.swift`
- 其他：`Octordle/Views/Stats/StatsView.swift`、`Support/SupportView.swift`、`Daily/DailyView.swift`
- HTML 設計稿（scratchpad）：locked_pack_sheet.html、challenge_screens.html、review_board.html、howtoplay.html
