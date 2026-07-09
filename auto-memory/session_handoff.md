# Session Handoff — 2026-07-09

## 背景
目標：打敗競品 8Words/Octordly（id6444903053，4.7★/1343）。競品弱點與策略見 memory/competitor-8words-strategy.md。

## 本次完成（全部 build 通過，**尚未 commit**，用戶尚未在模擬器實測）
1. **評分機制改造**：觸發擴充（成就除 firstWord、daily 5/15/40/80 里程碑、個人紀錄、3星完美勝）、拒絕 cap 2＋90 天冷卻、14 天間隔、StoreKit 2、365 天 3 次額度用滿改深連 write-review。檔案：ReviewManager.swift、GameViewModel.swift。
2. **導航重構**：4 tab = Today / Explore / Unlimited / Journey；右上浮動齒輪（MainTabView overlay）開 Settings sheet。
3. **Categories**：16 類 306 題（curated 詞庫，免費 6 類，每日輪換 1 付費類限免，Pro/rewarded ad 解鎖）。檔案：WordCategory.swift、CategoryService.swift、CategoriesView.swift、CategoryDetailView.swift、Resources/categories.json。生成管線：scratchpad/categories_curated.json（品質篩選版）→ assemble_categories.py。
4. **Challenges**：Timed（3/10/30 分）＋ Run（3/5/10 命）連續多局；ChallengeType.swift、ChallengeSession.swift、ChallengesView.swift、ChallengeGameView.swift；GameViewModel 加 challengeSession 分支（不記 stats）；我修了一個回合間隙倒數歸零的競態（endGame 延遲 reset 前檢查 remainingSeconds）。

## 下一步建議
- 用戶模擬器實測：Explore 全流程（Categories 解鎖/每日限免、Challenges 兩種模式、齒輪設定）
- 測過滿意後 commit（可用 /chinese-commit）
- 後續可做：Categories 完成一類的慶祝/徽章、Challenges 接 Game Center、App Store 文案更新（新功能 + ASO 關鍵字）、鍵盤音效（對手有 typewriter/piano/pop，我們還沒做）
