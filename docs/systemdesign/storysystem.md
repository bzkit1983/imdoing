# 劇情模式框架

- 此檔案定義**劇情模式框架**（進程槽、主題選章、解鎖權威、與任務／成長系統的關係）
- **不含**劇本對話、角色設定、具體任務文案；各章／主題細節見 [`story/`](story/)
- **閘門：** 本檔與 `story/` 的**十章選章／`story_slot` 狀態機／分店 runtime**仍為設計先行，活線未做。Steam EA 已拍板範圍仍是純日循環、不做完整章節 runtime（見 [`docs/versioning.md`](../versioning.md)）。惟活線已有可玩片段：劇本 **8** 序章內容閘與經濟、劇本 **6** 頭目戰測試。**序章是否計入 EA 交負責人決定，本檔不預先拍板。** 貢獻者勿把完整章節 runtime／`StoryDirector` 當成已核准的 EA 工單，除非 milestone 改範圍或開 Beta 旗標。
- 概念沙盒（已被本選章框架取代方向）：[`docs/concepts/ten-chapter-growth-blueprint.md`](../concepts/ten-chapter-growth-blueprint.md)
- 任務條件語意：[`tasksystem.md`](tasksystem.md)；劇情 pack stub：[`taskcontent-story-stub.md`](taskcontent-story-stub.md)
- 事件修飾器表：[`eventsystem.md`](eventsystem.md)（占位；**不**排活線）
- 精英店員（主題主導 NPC）：[`eliteclerk.md`](eliteclerk.md)

# 狀態

| 項目 | 狀態 |
|------|------|
| 框架結構（本章） | **產品規格開檔（設計）** — 選章＋破局 |
| 各章／主題內容／事件／劇本 | 開檔 stub，詳情後補 |
| 期望 EXP／資金／技能／開發規模等數字 | 產品建議見 `story/growth-*.md`；實作前可再調 |
| 活線實作 | **部分已接：** 劇本 8 序章內容閘／經濟（`SAVE_VERSION` ≥7；`ST-PROLOGUE-MONEY`）、劇本 6 頭目戰測試。**未做：** 十章選章、`story_slot` 狀態機、分店 runtime。序章是否計入 EA **尚未決定**（見 `docs/beta/design.md`、`docs/versioning.md`） |

# 進程模型（slot × theme）

主線**不是**固定世界線性 2→8。改為兩層：

| 層 | 含義 |
|----|------|
| `story_slot` | 進程深度：`prologue` → `chapter_01` → `chapter_02` → `chapter_03`…`chapter_08` → `finale` → `afterstory` |
| `theme_id` | 內容包：破局固定主題＋**六個可選主題**；第 3–8 槽執行時綁定一個 theme |
| 解鎖持久 | 主題內解鎖的技能／貨／奧義／外觀／精英店員等 **跨槽可帶**（穿越／多元宇宙敘事）；**店舖本體**破局後按主題快照（見 [`branchstore.md`](branchstore.md)），非單店穿越 |

```text
序章 → 第1章 → 第2章（theme_break 破局）
              ↓
        選未完成主題 ⇄ 填滿 story_slot 3…8（各跑一主題）
              ↓（可回訪已完成主題補任務／事件；不開新槽）
        六主題全清 → 終章 → 後日談
```

| 序 | `story_slot` | 檔案 | 角色（框架層） |
|----|--------------|------|----------------|
| 0 | `prologue` | [`story/prologue.md`](story/prologue.md) | 新手教學＋首段營運達標 |
| 1 | `chapter_01` | [`story/chapter-01.md`](story/chapter-01.md) | 一般營運實踐／擴店／麻煩客人登場 |
| 2 | `chapter_02` | [`story/chapter-02.md`](story/chapter-02.md) | **固定破局**：`theme_break`；章末大事件打開多元宇宙／選主題 |
| 3–8 | `chapter_03`…`chapter_08` | [`story/chapter-03.md`](story/chapter-03.md) … | **進程槽**：玩家選一未完成主題填入；內容讀 `active_theme_id` |
| 9 | `finale` | [`story/finale.md`](story/finale.md) | 閘：`themes_cleared.count == 6`；集合大成＋最終頭目 |
| — | `afterstory` | [`story/afterstory.md`](story/afterstory.md) | 終章後持續營運／回訪主題／重玩性 |

## 主題目錄（草稿 id；名稱可後改）

詳見 [`story/themes/`](story/themes/)：

| `theme_id` | 角色 | 草稿方向 |
|------------|------|----------|
| `theme_break` | **第2章固定** | 破局：打開多元宇宙／穿越時空 |
| `theme_historic` | 可選 | 歷史城下町 |
| `theme_ritual` | 可選 | 遠古儀式／禁忌貨 |
| `theme_fantasy` | 可選 | 劍與魔法 |
| `theme_tech` | 可選 | 高密度科技 |
| `theme_climate` | 可選 | 極端氣候／災難營運 |
| `theme_mirror` | 可選 | 鏡子宇宙／規則變異 |

（原概念「多元交匯」併入破局敘事，不佔可選六席。）

## 選章／回訪／終章閘

- **選章：** 第2章通關後，自六可選主題中選一未完成者 → 綁定下一空槽（`chapter_03`…`chapter_08`）→ 跑該主題主線＋頭目 → 標記 `themes_cleared`
- **回訪：** 主線進行中可進入**已完成**主題，補未完成事件／任務或重玩；**不**另開進程槽；**不**重複發「首次主題通關」解鎖（重玩報酬另表後補）
- **終章閘：** 可選六主題皆在 `themes_cleared` 才開 `finale`
- **推進：** 完成該槽／主題**主線劇情任務鏈**（及頭目）→ `advance_story`（選章態或下一槽）
- **失敗擋推進：** 見 `tasksystem.md`。UX：**日常＝軟擋（A）**；**頭目＝失敗演出後回準備再挑戰（D→C）**。詳見 [`story/progression-crossref.md`](story/progression-crossref.md) §6.1

## 任務 pack 慣例

- 進程槽固定段：`ST-PROLOGUE-###`、`ST-CH01-###`、`ST-CH02-###`、`ST-FINALE-###`、`ST-AFTER-###`
- 主題內容：`ST-<THEME>-###`（例：`ST-HISTORIC-001`；THEME 縮寫見各主題檔）
- 第 3–8 槽本身不擁有獨立世界 pack；掛載的是當前 `active_theme_id` 的 `ST-<THEME>-*`

# 每主題／每槽會掛上的元素（框架槽位）

主題設計時應填下列槽位（數字與具體表另分析後補）：

| 槽位 | 說明 | 詳細補完位置 |
|------|------|--------------|
| 主題方向 | 玩法／壓力／世界方向 | [`story/themes/`](story/themes/) |
| 新貨品種類／SKU | 外觀＋**通用性狀**（可被主題／事件修飾器覆寫） | 主題＋[`story/growth-economy.md`](story/growth-economy.md) |
| 商店物品 | 主題向家具／設備等 | 主題＋`shopitem.md` |
| 新事件任務 | ① 劇情一次性（含解鎖）② 可重覆期間限定 | 主題＋`taskcontent-event-*` |
| 新技能 | **劇情／事件任務獎勵**學會（等級不解鎖） | 主題＋[`story/growth-skills.md`](story/growth-skills.md) |
| 奧義 | 主題頭目**首次**通關解鎖為主 | [`story/growth-skills.md`](story/growth-skills.md) |
| 精英店員 | 該主題**主導 NPC 店員**（名稱／背景／可升級）；通關獲得為主 | [`eliteclerk.md`](eliteclerk.md) |
| 小遊戲 | 主題向小遊戲（可發非劇情精英店員等） | 主題 stub；詳後補 |
| 主角外觀 | 主題解鎖 skin／tint 等 | 主題＋外觀目錄 |
| 客人特別行為 | 套用到**該主題一般客人族群** | 主題 |
| 客人流量／不滿度 | 主題／槽級調參 | 主題＋成長分析 |
| 麻煩客人 | 最高解鎖 LV 跟 **story_slot 深度**（非 theme 順序） | `elitecustomer.md`；粗表見 crossref |
| 店舖／收銀／店員 | 擴店、收銀機、一般雇員鉤子 | 槽節奏見 economy；雇員見 `clerksystem.md` |
| 章／主題末頭目 | 大型特定營運回合 | 主題／槽 |
| 期望成長帶 | 目標等級／資金／技能／規模跟 **story_slot** | [`story/growth-character.md`](story/growth-character.md) 等 |

# 解鎖權威（任務解鎖）

拍板：**等級從不直接解鎖**；解鎖一律由**劇情任務或事件任務**發放。內容解鎖表掛 **`theme_id`（或序／1／終 slot）**；經濟節奏（規模檔、期望 LV）跟 **`story_slot` 深度**。

| 權威 | 角色 | 備註 |
|------|------|------|
| **劇情任務** | 可推進槽／主題，**也可觸發解鎖** | 失敗擋推進見 §失敗 UX |
| **事件任務** | 可觸發解鎖；含一次性劇情向與可重覆期間限定 | 失敗不擋劇情 |
| **角色等級** | 只成長能力點／XP；**可作任務條件** | **不是**解鎖表 |
| **資金** | 有解鎖資格後的購買／擴店／開發／雇員／精英店員投資 | 不解鎖資格本身 |

現行 `shopprogress.md` 等級表＝**測試版／過渡**，以任務解鎖表取代。見 [`story/progression-crossref.md`](story/progression-crossref.md)、三份成長分析。

產品建議數字見：

1. [`story/growth-character.md`](story/growth-character.md)  
2. [`story/growth-economy.md`](story/growth-economy.md)  
3. [`story/growth-skills.md`](story/growth-skills.md)  

已拍板方向：

- **劇情／事件 XP：** 允許；由**個別任務報酬**決定
- **貨品性狀：** 通用性狀為主；主題／事件修飾器可覆寫（事件＞主題＞SKU 預設）
- **頭目日：** 普通結算＋任務另發大額 XP／資金＋**解鎖奧義**（首次通關）
- **店舖規模：** **S1–S6**；跟進 **story_slot** 深度（約每 1–2 槽一檔）；任務解鎖資格＋資金付款
- **教學 vs 序章：** 系統分開，元件可重用
- **跨主題攜帶：** 已解鎖元素（技能／貨開發權／奧義／外觀／精英店員等）在後續槽／回訪可用（敘事＝穿越）
- **店舖實體（破局後）：** 六可選主題各一間**獨立店快照**；回訪該主題＝本店，其餘可進**分店**背景營運；**共用資金**；見 [`branchstore.md`](branchstore.md)。序章＋第1章＋破局＝起源本店（單一路徑）；分店系統於清完第一個可選主題後解鎖

# 等級錨點（框架層）

| 錨點 | 值 | 說明 |
|------|-----|------|
| 角色等級上限 | **99** | 與 `playerlevel.md` 一致 |
| 序章→終章目標等級 | **約 60** | 曲線見 [`story/growth-character.md`](story/growth-character.md)；帶跟 slot 深度 |
| 後日談 | **61–99** | 再練、回訪、重玩性空間 |

# 與三層循環的關係

```text
劇情／事件發生  →  店鋪準備  →  店鋪經營
       ↑________________（關店結算後回到）
```

- 劇情進度決定：當日掛哪些 `story` 任務、是否進入頭目日、主題客人修飾器、已解鎖內容、選章／回訪入口
- 事件可疊加 `event` 任務與規則修飾器；**失敗不擋劇情**
- 教學系統（`tutorial.md`）與序章**不合併**，但 Lesson／步驟／條件等**可重用**；見 [`story/prologue.md`](story/prologue.md)

# 存檔欄位（框架形狀）

生態系統已列「劇情進度」（`ecosystem.md`）。正式欄位名落地時至少需要：

| 欄位（暫名） | 用途 |
|--------------|------|
| `story_slot` / `story_chapter_id` | 當前進程槽（`prologue`…`finale`／`afterstory`） |
| `active_theme_id` | 第 3–8 槽或回訪時當前主題；第2章固定 `theme_break` |
| `themes_cleared` | 已通關可選主題 id 列表（終章閘用） |
| `theme_run_flags` | 各主題節點／支線／事件完成旗標 |
| `story_flags` | 全局已完成節點／解鎖旗標 |
| `story_blocked` | 是否因劇情任務失敗擋推進 |
| `completed_story_packs` | 已完結的 `ST-*` pack id |
| `theme_stores`／`origin_store` | 可選主題店／起源店完整快照；見 [`branchstore.md`](branchstore.md) |
| `money`（頂層共用） | 本店與分店共用資金；分店不另設資金欄 |

十章選章欄位的精確 schema 與再升 `SAVE_VERSION`：待 `story_slot` runtime 實作時改 `savesystem.md`。序章內容閘欄位（`unlocked_skus`／`unlocked_furniture`／`prologue_boss_unlocked`）已在 `SAVE_VERSION` 7。分店欄位細節見 `branchstore.md`。

# 頭目（框架定義）

- **頭目**＝槽／主題主線終點的**特殊營運日**（可多階段），不是另開戰鬥場景
- **回合規則／HUD／世界覆寫／演出契約：** 見 [`bossbattle.md`](bossbattle.md)；各頭目詳設見 [`bosses/`](bosses/)
- 通過條件由該主題劇情任務／評價／存活指標等組合定義
- 終章頭目為最終頭目；後日談可另設可選週期挑戰頭目（非擋主線）
- **通關報酬：** 當日**普通結算**照算；**任務獎勵另給**大額 EXP、大額資金、**解鎖奧義**（首次通關；D→C 重試不重複發解鎖／大額）。量級見成長分析
- **失敗：** 先走敘事失敗態 → 回準備回合調整 → 再進入同一頭目節點（D→C）。通過前 `story_blocked`，不 `advance_story`
- **日常劇情失敗：** 軟擋（A）——可繼續日循環，只擋推進

# 後日談（框架層）

終章完結後進入 `afterstory`：

- 可繼續營運、升級、賺錢（LV61–99）
- 可回訪已通關**主題**完成未清任務／挑戰（與主線回訪規則對齊，長尾開放）
- 可加入重玩性設計（輪換規則、隱藏解鎖等——後日談檔開槽，內容後補）

# 相關文件

| 文件 | 角色 |
|------|------|
| [`story/themes/`](story/themes/) | 破局＋六可選主題 stub |
| [`story/progression-crossref.md`](story/progression-crossref.md) | 現有設計對照＋決策／開放問題 |
| [`story/growth-character.md`](story/growth-character.md) | 角色成長（XP／等級帶 ↔ slot） |
| [`story/growth-economy.md`](story/growth-economy.md) | 貨品／資金／規模（SKU ↔ theme；規模 ↔ slot） |
| [`story/growth-skills.md`](story/growth-skills.md) | 技能／奧義（學會 ↔ theme） |
| [`eliteclerk.md`](eliteclerk.md) | 精英店員 |
| [`branchstore.md`](branchstore.md) | 分店／主題店快照／背景營運 |
| [`tasksystem.md`](tasksystem.md) | 任務 kind／失敗擋推進 |
| [`playerlevel.md`](playerlevel.md) | 等級上限／EXP 來源 |
| [`shopprogress.md`](shopprogress.md) | 現行等級解鎖表（過渡／作廢中） |
| [`elitecustomer.md`](elitecustomer.md) | 麻煩客人等級 |
| [`clerksystem.md`](clerksystem.md) | 一般雇員；精英店員見 `eliteclerk.md` |
| [`bossbattle.md`](bossbattle.md) | 頭目戰回合框架 |
| [`bosses/`](bosses/) | 各頭目專檔 |
| [`tutorial.md`](tutorial.md) | 教學 Lesson；與序章分開可重用 |
| [`docs/beta/design.md`](../beta/design.md) | 報酬落地細節仍可標 Beta |
