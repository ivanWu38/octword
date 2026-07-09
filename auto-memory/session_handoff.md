# Session Handoff（最後更新：2026-07-09）

## 背景
打敗競品 8Words/Octordly（策略見 memory/competitor-8words-strategy.md）。

## 目前進度

### 第一批（commit fea3c92 已提交）
評分機制改造、4-tab 導航、Categories（16 類 306 題）、Challenges（Timed/Run）。

### 第二批（未 commit，等用戶模擬器實測）— 依用戶 feedback
1. **統一報頭 EditorialMasthead**（Views/Components/EditorialMasthead.swift）：固定高度、上下 hairline、標題單行自動縮放；帶狀區左右放按鈕。所有頁面統一套用。
2. **齒輪**改 SF gearshape、放 root 頁報頭右側；移除 MainTabView 浮動齒輪。
3. **返回鈕** ‹ 放子頁報頭左側（onBack: dismiss）。
4. **Challenge 計時器**：隱藏 GameView 從 0 起跳的計時器（只留 HUD 倒數/命數）。
5. **咖啡機制（本輪 session 完成並 build 驗證通過）**：從 Quordle 移植、改成 Octordle editorial 風。本質是 rewarded ad 包裝成「請開發者喝咖啡」，非真 IAP。
   - 新檔 `Octordle/Services/SupportService.swift`：`@MainActor` singleton。`octordle_coffeeCount` 存咖啡數；`octordle_supportCardDismissedDay` 存當天已 dismiss（用 `DailyPuzzleService.shared.todayString`）。`buyCoffee()` → `RewardedAdManager.support.showAd()`，成功才 +1。`shouldShowCard(isPremium:totalGamesPlayed:)`：premium / 玩不到 3 場 / 當天已 dismiss → 不顯示。
   - 新檔 `Octordle/Views/Support/SupportView.swift`：`SupportCard`（完成頁內嵌卡）、`SupportConfirmSheet`（看廣告前確認）、`SupporterView`（全螢幕咖啡頁，EditorialMasthead 當頂，0 杯 / 1+ 杯兩狀態）、`CoffeeThanksOverlay`（感謝動畫 2.6s 自動關）。serif 標題 + hairline + `Color.quordleCoffee` + `ScaleButtonStyle`。
   - 4 個 root 頁（Daily/Explore/Unlimited/Stats）報頭左側加 ☕ pill（非 premium 才顯示，透過 `showCoffee/coffeeCount/onCoffee` param）→ 開 `SupporterView`。`StatsView` 原本沒 subscriptionService，已補 `@EnvironmentObject`。
   - `DailyView.completedView` 的 countdownFooter 上方加 `SupportCard` → `SupportConfirmSheet` → rewarded ad → `CoffeeThanksOverlay`。
   - pbxproj 已手動註冊兩新檔（PBXBuildFile/FileReference/Sources phase；SupportService 掛 Services group，新建 Support PBXGroup 掛 Views 底下）。
   - 廣告 unit：`Constants.AdMob.supportRewardedAdUnitId`（prod = ca-app-pub-5654617376526903/5535012213，DEBUG 用測試單元）；`RewardedAdManager.support`。

## 進行中
- （無）咖啡機制已完成、build 已 SUCCEEDED。

## 下一步
- 用戶在模擬器實測第二批全部項目，滿意後 → commit（/chinese-commit）。整批目前都未 commit。
- 咖啡待測：pill 開贊助頁、Today 完成邀請卡、看廣告流程（DEBUG 測試廣告）、感謝動畫。
- 其他待測：報頭一致性（小螢幕不換行）、齒輪開設定、子頁 ‹ 返回、Challenge 只剩倒數/命數。
- 後續：鍵盤音效、Game Center 排行榜、App Store 文案更新。

## 重要脈絡 / 決定
- 咖啡機制不可改的既有資產（已幫我準備好、直接沿用）：`Constants.AdMob.supportRewardedAdUnitId`、`RewardedAdManager.support`、`Color.quordleCoffee`、EditorialMasthead 的 coffee pill 參數。
- 明確禁改清單：EditorialMasthead / ReviewManager / CategoryService / ChallengeSession / MainTabView / Constants / RewardedAdManager / Extensions / GameView / GameViewModel。
- pbxproj 是 classic 格式，新檔一定要手動註冊；ID 用 `secrets.token_hex(12)` 產生並 grep 確認不重複。
- DailyView 用獨立 state（showSupportConfirm / isBuyingCoffee / showCoffeeThanks）驅動內嵌卡片流程，跟 masthead pill 開的 SupporterView 分開。
- 咖啡數只存本機 UserDefaults，未跨裝置同步。

## 相關檔案
- `Octordle/Services/SupportService.swift`
- `Octordle/Views/Support/SupportView.swift`
- `Octordle/Views/Daily/DailyView.swift`、`Views/Explore/ExploreView.swift`、`Views/Unlimited/UnlimitedView.swift`、`Views/Stats/StatsView.swift`
- `Octordle/Views/Components/EditorialMasthead.swift`
- `Octordle.xcodeproj/project.pbxproj`
- 設計稿：scratchpad/masthead_design.html
- Quordle 參考：`/Users/wuyuping/Desktop/ios_apps/Quordle_3/Quordle/Services/SupportService.swift`、`.../Views/Support/SupportView.swift`
