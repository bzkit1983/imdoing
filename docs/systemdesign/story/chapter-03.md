# 第3章｜進程槽（開檔）

- 章 id／`story_slot`：`chapter_03`
- **內容：** 執行時綁定 `active_theme_id`（六可選主題之一）；**不是**固定世界
- 劇情 pack：主題側 `ST-<THEME>-###`（見 [`themes/`](themes/)）；本槽無獨立世界 pack
- 框架總則：[`../storysystem.md`](../storysystem.md)
- **狀態：** 進程槽模板；主題詳情見主題檔

# 概念（框架）

本檔＝主線第 **3** 個主題進程槽（選章順序中的第 1 個可選主題）。

- 進入：選章 UI 選一**尚未**在 `themes_cleared` 的可選主題 → 設 `active_theme_id` → 跑該主題主線
- 完成：主題頭目通關 → 主題 id 記入 `themes_cleared` → 若未滿 6 則回選章；滿 6 開終章閘
- **回訪：** 之後可再進已完成主題補任務／事件；不佔新槽、不重發首次通關解鎖
- 解鎖持久：本槽獲得的內容跨後續槽可用

# 主線推進條件（形狀）

| 方向 | 說明 |
|------|------|
| 主題主線 | 依 `active_theme_id` 的 `ST-<THEME>-*` |
| 主題頭目 | 首次通關＝本槽完成＋主題記入 cleared |
| 資金／評價等 | 閾值跟**本槽深度**節奏（growth-character／economy） |

# 本槽元素槽位

全部讀主題檔；本槽只提供節奏錨點。

| 槽位 | 開檔內容 | 待補 |
|------|----------|------|
| `active_theme_id` | 玩家選擇 | 選章 UX |
| 期望成長帶 | 第3槽深度；見 [growth-character.md](growth-character.md) §5 | 細則 |
| 麻煩最高 LV | 跟 slot 深度（crossref §6） | 解鎖任務 |

# 劇情／事件內容

- 由當前主題檔提供；本槽不寫死劇本
