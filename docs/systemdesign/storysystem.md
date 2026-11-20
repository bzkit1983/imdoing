# 劇情模式框架

- 此檔案定義**劇情模式框架**（章節結構、解鎖權威、與任務／成長系統的關係）
- **不含**劇本對話、角色設定、具體任務文案；各章細節見 [`story/`](story/)
- 概念沙盒對照（非產品、可推翻）：[`docs/concepts/ten-chapter-growth-blueprint.md`](../concepts/ten-chapter-growth-blueprint.md)
- 任務條件語意：[`tasksystem.md`](tasksystem.md)；劇情 pack stub：[`taskcontent-story-stub.md`](taskcontent-story-stub.md)
- 事件修飾器表：待 [`eventsystem.md`](eventsystem.md)（尚未開檔）

# 狀態

| 項目 | 狀態 |
|------|------|
| 框架結構（本章） | **產品規格開檔** |
| 各章內容／事件／劇本 | 開檔 stub，詳情後補 |
| 期望 EXP／資金／技能／開發規模等數字 | 產品建議見 `story/growth-*.md`；實作前可再調 |
| 活線實作 | 未做（見 `docs/beta/design.md`、`docs/versioning.md`） |

# 章節結構

主線共 **10 個章節**，完結後進入後日談：

| 序 | id | 檔案 | 角色（框架層） |
|----|-----|------|----------------|
| 0 | `prologue` | [`story/prologue.md`](story/prologue.md) | 新手教學＋首段營運達標 |
| 1 | `chapter_01` | [`story/chapter-01.md`](story/chapter-01.md) | 擴店／增收／開始出現麻煩客人 |
| 2–8 | `chapter_02`…`chapter_08` | [`story/chapter-02.md`](story/chapter-02.md) … [`chapter-08.md`](story/chapter-08.md) | 每章新主題＋新玩法／貨種／壓力 |
| 9 | `finale` | [`story/finale.md`](story/finale.md) | 集合大成；大事任務後最終頭目 |
| — | `afterstory` | [`story/afterstory.md`](story/afterstory.md) | 終章後持續營運／回訪舊章／重玩性 |

- 流水編號慣例：劇情任務 pack `ST-<章節>-###`（章節縮寫見各章檔；例：`ST-PROLOGUE-001`）
- 章節推進：完成該章**主線劇情任務鏈**（及章末頭目條件）→ `advance_story` 進入下一章
- 失敗擋推進：見 `tasksystem.md`（`on_fail.block_story_advance`）。UX 已拍：**日常＝軟擋（A）**；**頭目＝失敗演出後回準備再挑戰（D→C）**。詳見 [`story/progression-crossref.md`](story/progression-crossref.md) §6.1

# 每章會掛上的元素（框架槽位）

每一章設計時應填下列槽位（數字與具體表另分析後補；本框架只定**有哪些槽**）：

| 槽位 | 說明 | 詳細補完位置 |
|------|------|--------------|
| 主題方向 | 該章玩法／壓力主題（抽象即可） | 各章 stub |
| 新貨品種類／SKU | 外觀＋**通用性狀**（可被章／事件修飾器覆寫）；特性表章內補 | 各章＋[`story/growth-economy.md`](story/growth-economy.md) |
| 新事件任務 | ① 關聯劇情的一次性任務（含解鎖）② 與劇情無關、可重覆的期間限定 | 各章＋`taskcontent-event-*` |
| 新技能 | **劇情／事件任務獎勵**學會（等級不解鎖）；每章有能力推進任務 | 各章＋[`story/growth-skills.md`](story/growth-skills.md) |
| 客人特別行為 | 套用到**該章一般客人族群**（非麻煩客個體），例：購物完成率↑、移速↑、易怒 | 各章 |
| 客人流量／不滿度 | 章級調參（不寫死） | 各章＋成長分析 |
| 麻煩客人 | 可解鎖的最高等級／前綴池擴張；分析起點＝**每章升一級至 LV6**（序章未解鎖） | 各章＋`elitecustomer.md`；粗表見 [`story/progression-crossref.md`](story/progression-crossref.md) §6 |
| 店舖／收銀／店員 | 擴店、收銀機、雇員等主線任務鉤子 | 各章 |
| 章末頭目 | 大型特定營運回合／多階段壓力 | 各章 |
| 期望成長帶 | 目標等級帶、資金帶、可用技能帶、開發規模 | [`story/growth-character.md`](story/growth-character.md) 等三份分析 |

# 解鎖權威（任務解鎖）

拍板：**等級從不直接解鎖**；解鎖一律由**劇情任務或事件任務**發放。

| 權威 | 角色 | 備註 |
|------|------|------|
| **劇情任務** | 可推進章節，**也可觸發解鎖**（貨種、技能、規模資格、麻煩上限、道具、外觀等） | 失敗擋推進見 §失敗 UX |
| **事件任務** | 可觸發解鎖；含一次性劇情向與可重覆期間限定 | 失敗不擋劇情 |
| **角色等級** | 只成長能力點／XP；**可作任務條件**（例 `player_level >= N`） | **不是**解鎖表 |
| **資金** | 有解鎖資格後的購買／擴店／開發／雇員經濟門檻 | 不解鎖資格本身 |

現行 `shopprogress.md` 等級表＝**測試版／過渡**，以任務解鎖表取代。見 [`story/progression-crossref.md`](story/progression-crossref.md)、三份成長分析。

產品建議數字見：

1. [`story/growth-character.md`](story/growth-character.md)  
2. [`story/growth-economy.md`](story/growth-economy.md)  
3. [`story/growth-skills.md`](story/growth-skills.md)  

已拍板方向：

- **劇情／事件 XP：** 允許；由**個別任務報酬**決定
- **貨品性狀：** 通用性狀為主；章／事件修飾器可覆寫（事件＞章＞SKU 預設）
- **頭目日：** 普通結算＋任務另發大額 XP／資金＋**解鎖奧義**（首次通關）
- **店舖規模：** **S4+**（目標至 S6）；約每 1–2 章一檔
- **教學 vs 序章：** 系統分開，元件可重用

# 等級錨點（框架層）

| 錨點 | 值 | 說明 |
|------|-----|------|
| 角色等級上限 | **99** | 與 `playerlevel.md` 一致 |
| 序章→終章目標等級 | **約 60** | 曲線見 [`story/growth-character.md`](story/growth-character.md) |
| 後日談 | **61–99** | 再練、回訪、重玩性空間 |

# 與三層循環的關係

```text
劇情／事件發生  →  店鋪準備  →  店鋪經營
       ↑________________（關店結算後回到）
```

- 劇情進度決定：當日掛哪些 `story` 任務、是否進入頭目日、章節客人修飾器、已解鎖內容
- 事件可疊加 `event` 任務與規則修飾器；**失敗不擋劇情**（與劇情分開）
- 教學系統（`tutorial.md`）與序章**不合併**，但 Lesson／步驟／條件等**可重用**；見 [`story/prologue.md`](story/prologue.md)

# 存檔欄位（框架形狀）

生態系統已列「劇情進度」（`ecosystem.md`）。正式欄位名落地時至少需要：

| 欄位（暫名） | 用途 |
|--------------|------|
| `story_chapter_id` | 當前章（`prologue`…`finale`／`afterstory`） |
| `story_flags` | 已完成節點／解鎖旗標 |
| `story_blocked` | 是否因劇情任務失敗擋推進 |
| `completed_story_packs` | 已完結的 `ST-*` pack id |

精確 schema 與 `SAVE_VERSION` 升級：待實作時改 `savesystem.md`。

# 頭目（框架定義）

- **頭目**＝章節主線終點的**特殊營運日**（可多階段），不是另開戰鬥場景
- 通過條件由該章劇情任務／評價／存活指標等組合定義（章內補）
- 終章頭目為最終頭目；後日談可另設可選週期挑戰頭目（非擋主線）
- **通關報酬：** 當日**普通結算**照算；**任務獎勵另給**大額 EXP、大額資金、**解鎖奧義**（首次通關；D→C 重試不重複發解鎖／大額）。量級見成長分析
- **失敗：** 先走敘事失敗態（演出；懲罰待表）→ 回準備回合調整 → 再進入同一頭目節點（D→C）。通過前 `story_blocked`，不 `advance_story`
- **日常劇情失敗：** 軟擋（A）——可繼續日循環，只擋推進

# 後日談（框架層）

終章完結後進入 `afterstory`：

- 可繼續營運、升級、賺錢（LV61–99）
- 可回訪舊章「世界」完成未清任務／挑戰（回訪規則待補）
- 可加入重玩性設計（輪換規則、隱藏解鎖等——後日談檔開槽，內容後補）

# 相關文件

| 文件 | 角色 |
|------|------|
| [`story/progression-crossref.md`](story/progression-crossref.md) | 現有設計對照＋決策／開放問題 |
| [`story/growth-character.md`](story/growth-character.md) | 角色成長分析（XP／等級帶） |
| [`story/growth-economy.md`](story/growth-economy.md) | 貨品／資金／規模／性狀分析 |
| [`story/growth-skills.md`](story/growth-skills.md) | 技能／奧義分章學會表 |
| [`tasksystem.md`](tasksystem.md) | 任務 kind／失敗擋推進 |
| [`playerlevel.md`](playerlevel.md) | 等級上限／EXP 來源 |
| [`shopprogress.md`](shopprogress.md) | 現行等級解鎖表（過渡／作廢中） |
| [`elitecustomer.md`](elitecustomer.md) | 麻煩客人等級 |
| [`tutorial.md`](tutorial.md) | 教學 Lesson；與序章分開可重用 |
| [`docs/beta/design.md`](../beta/design.md) | 報酬落地細節仍可標 Beta |
