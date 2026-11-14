# 任務系統設定

- 此檔案定義營運／事件／劇情三種任務的共用條件語意、狀態、掛載、存檔與內容接口
- 內容組合流水號見：`taskcontent-ops-test.md`、`taskcontent-event-stub.md`、`taskcontent-story-stub.md`
- 評價條件語意見 `ratingsystem.md`；生態系統進度欄見 `ecosystem.md`
- 事件規則修飾器屬事件系統（`eventsystem.md` 待建）；本檔只消費任務條件列
- 工程活線尚未實作；掛點見文末

# 三種任務

| 種類 | `kind` | 來源 | 生命週期 | 失敗後果 |
| --- | --- | --- | --- | --- |
| 營運任務 | `ops` | 設計師按商店／進度編排；測試可用生成器 | 當日或跨日累計；每營運回合 0～不設限條 | 不擋劇情 |
| 事件任務 | `event` | 事件觸發（進度／條件／可控隨機） | 隨事件清單；可疊加或替換當日條件 | 不擋劇情（與劇情分開） |
| 劇情任務 | `story` | 主線綁定 | 做完一次即完結並推進劇情 | **失敗擋劇情推進** |

營運任務根據範圍在同一個或跨營運回合達成；以玩家完成為準（seat 規則見下）。

# 與成就

- 任務與成就是**兩套系統**（成就尚未設計）
- 成就可复用本檔的 `condition`／metric 語意；達成時**另計**成就進度，不與任務 bag 共用
- 同一行為可同時推進任務與成就

# 範圍（scope）

| `scope.type` | 語意 |
| --- | --- |
| `day` | 當日（一個營運回合） |
| `accumulate` | 跨回合累計；可帶 `max_days`（缺省＝無限回合） |

- 跨回合進行中的任務在**準備回合**顯示
- 跨日／N 日內窗口依持久 `day_index`（見存檔）

# 狀態與顯示

| 狀態 | UI |
| --- | --- |
| 進行中 | 進度 `current/target` |
| 已達成 | TICK＋已達成 |
| 已失敗（數學上不可能，如上限型超標） | **即時** X＋已失敗 |
| 提早關店／正常關店時下限型未達標 | 失敗（X）；當日下限型不結轉 |
| 跨回合進行中 | 準備回合任務列表 |

# Seat 計數規則（誰算進度）

| 來源 | 是否計入 |
| --- | --- |
| 主機可控 seat | 是 |
| 訪客 seat | 是 |
| 店員／NPC | 否 |
| 影分身 | 否（除非任務 `filters` 明示須用該技能／影分身達成） |

- 訪客與主機**每人一份**任務進度（per-seat bag）
- 進度相同時可**共同推進／共同解決**同一條件（coop 協力）
- 訪客進度落後 Host 時，**不以 Host 完成逕行判定訪客已完成**
- Host／訪客對齊與「共同解決」的精確規則：**劇情設計補完**

# 營業日 `day_index`

- 商店持久欄；每次營運日結束（含**提早關店**）`day_index += 1`
- 跨日任務的起始日／截止日依此計算

# 失敗時機（已拍板）

1. 上限型（`op` 為 `<`／`<=`）等「已不可能達成」→ **即時**標失敗
2. 關店（含提早）時，當日或到期窗口內下限型未達標 → **失敗**（不是未完成可續）

# 報酬

- 正式版允許任務發放：XP、`shop_rating` 加減、技能學習、貨品開發解鎖、外觀解鎖等
- 細節與發放時機 → **Beta**（見 `docs/beta/design.md`）；本檔只留 `rewards[]` 占位
- 測試版可只追蹤 TICK／X、不發獎

# 店鋪進度解鎖

- 任務**可以**作為店鋪功能／進度解鎖條件（不再僅角色等級）
- 詳細解鎖機制 → **Beta**（改 `shopprogress.md`）；本檔只聲明任務可為解鎖來源

# 完美交付與 COMBO（任務語意）

- **完美交付**：一次把該客**購物清單交清**（不要求舊版 ≥3 件門檻）
- **COMBO**：每成功交付客人一次 +1；**交付失誤時個人 RESET**（全隊不因個人失誤清零）
- 活線已對齊：見 `fetchcombo.md`；完美交付另觸發客人不滿 −40／營收 ×1.2 與評級 P5

# 內容接口（可序列化 dict／JSON）

- 設計、loader、生成器、存檔快照**同一形狀**
- 測試版可用 GDScript const 填同形（不當第二套欄位模型）；穩定後落到 `res://data/tasks/*.json`
- 玩家可見文案一律 `Loc` key（`quest.*`），不進數據正文
- 成就日後复用同一 condition 欄位

## Pack 形狀

```json
{
  "pack_id": "OP-TUT-001",
  "kind": "ops",
  "tasks": []
}
```

| 欄位 | 說明 |
| --- | --- |
| `pack_id` | 組合流水編號 |
| `kind` | `ops`｜`event`｜`story` |
| `tasks` | 任務列（可空） |

## Task 形狀

```json
{
  "id": "OP-TUT-001-A",
  "metric": "shelve_count",
  "op": ">=",
  "target": 12,
  "scope": { "type": "day" },
  "filters": { "sku": "canned" },
  "loc_key": "quest.op_tut_001_a",
  "rewards": []
}
```

| 欄位 | 說明 |
| --- | --- |
| `id` | 任務流水號 |
| `metric` | 見下方 metric 表 |
| `op` | `>=`｜`>`｜`<=`｜`<`｜`==` |
| `target` | 數值目標（級別類可用字串級別名，見評價類） |
| `scope` | `{ "type": "day" }` 或 `{ "type": "accumulate", "max_days": 3 }`（省略 `max_days`＝無限） |
| `filters` | 可空；SKU／類別／技能 id／趕賊方式等 |
| `loc_key` | `quest.*` |
| `rewards` | 可空陣列；Beta 填具體型別 |

累計任務開始時可在 runtime 狀態寫入 `started_day`（存檔用，不必進內容定義）。

## Metric 表（現階段；可再加）

### 金額類

| metric | 說明 | filters 例 |
| --- | --- | --- |
| `shop_money` | 商店資金總額 | — |
| `sales_revenue` | 總銷售額 | — |
| `sales_revenue_category` | 指定同類貨品銷售額 | `category` |
| `sales_revenue_sku` | 指定同款貨品銷售額 | `sku` |

### 數量類

| metric | 說明 | filters 例 |
| --- | --- | --- |
| `sold_count` | 總賣出貨品量 | — |
| `sold_count_category` | 同類賣出量 | `category` |
| `sold_count_sku` | 同款賣出量 | `sku` |
| `shelve_count` | 上貨架總數量 | — |
| `shelve_count_sku` | 指定貨品上架量 | `sku` |

### 清潔類

| metric | 說明 |
| --- | --- |
| `clean_count` | 完成清潔次數 |
| `dirt_affect_count` | 當日被污物影響次數（上限型常用） |

### 客人類

| metric | 說明 | filters 例 |
| --- | --- | --- |
| `deliver_count` | 總交付次數（成功交付客人次數） | — |
| `angry_leave` | 客人不滿離開數 | — |
| `wrong_deliver` | 交付錯誤數 | — |
| `hand_deliver_count` | 親手交付數量 | — |
| `toss_deliver_count` | 投擲交付數量 | — |
| `dash_knock_guest` | 衝刺撞倒客人數 | — |
| `perfect_deliver_count` | 完美交付（清單一次交清） | — |
| `deliver_combo` | 交付 Combo 數（任務新定義） | — |
| `deliver_sku` | 交付指定 SKU 件／次 | `sku`；可加 `mode`: `hand`｜`toss`｜`any` |

### 收銀類

| metric | 說明 |
| --- | --- |
| `checkout_count` | 完成收銀次數 |
| `checkout_perfect` | 完美收銀次數 |

### 小偷類

| metric | 說明 | filters 例 |
| --- | --- | --- |
| `thief_caught` | 成功趕走小偷次數 | — |
| `thief_caught_melee` | 近身趕走 | — |
| `thief_caught_dash` | 衝刺趕走 | — |

### 技能類

| metric | 說明 | filters 例 |
| --- | --- | --- |
| `skill_cast` | 使用指定技能次數 | `skill_id` |
| `ult_cast` | 使用指定奧義次數 | `skill_id` |

### 評價類

| metric | 說明 | filters／target 例 |
| --- | --- | --- |
| `ops_rating` | 營運點達標 | — |
| `shop_rating` | 商店評價達標 | — |
| `day_grade` | 當日評級達某級 | `target` 為 −3…+3 |
| `grade_streak` | 連續 N 日評級達某級 | `target` 級別；`filters.min_grade`；`filters.days` |

### 事件／設置類（條件例）

| metric | 說明 | filters 例 |
| --- | --- | --- |
| `shelf_setup` | 營運中須同時設置某類補貨架數量 | `furniture`／`category`；`target`＝架數 |

未接線的 metric 在測試版應標「未接線」，避免靜默當 0 造成假失敗。

# 測試版掛載與測試

## 入口

準備選單 **「測試任務」**，可選：

1. `pack_tutorial_prologue` — 固定教學組合（`OP-TUT-001`）
2. `pack_manual_<id>` — 指定流水號組合
3. `gen_random_ops` — 隨機營運任務生成器

## 時機

| 時機 | 行為 |
| --- | --- |
| 準備「測試任務」／開業前 | 預覽當日＋跨日任務 |
| 營運日開始（`_begin_day`） | 為每 seat 掛 `TaskBag`；重設當日 metric |
| 營運中 | 合法 seat 動作增量 → 即時 TICK／X |
| 關店（含提早） | 下限未達 → 失敗；寫存檔；`day_index += 1` |
| 回準備 | 顯示跨日任務 |

## 檢查表

- 當日下限達標 → TICK；關店未達 → 失敗
- 上限超標 → 即時 X
- 跨日：準備回合仍顯示；窗口內達標 → TICK；逾期 → X
- 提早關店：`day_index` +1；當日下限未達 → 失敗
- 店員／影分身預設不計；訪客與 Host 分袋
- 缺 metric →「未接線」

# 隨機營運任務生成器（測試用）

- 入口：準備選單「測試任務」→ 隨機
- 正式關卡改設計師固定流水號；生成器保留 QA／測試

## 輸入

| 欄位 | 說明 |
| --- | --- |
| `day_index` | 當前營業日 |
| `player_level` | 過濾技能／評價類 |
| `unlocked_skus`／家具 | 過濾 SKU／貨架類 |
| `seed` | 可重現 |
| `slot_count` | 建議 2–4 |

## 步驟

1. 依等級／解鎖過濾 template pool（金額／數量／清潔／客人／收銀／小偷／技能／評價）
2. 每槽抽 1 template；同 `metric`（＋主要 filter）不重複；至多 1 個上限型
3. 標度：`target = clamp(round(base * difficulty_mult * rand(0.85, 1.15)), min, max)`；上限型基線放寬
4. 範圍權重（測試）：70% `day`、20% `accumulate` `max_days=3`、10% `accumulate` 無限
5. 輸出與 Pack 同形，並帶 `seed`：

```json
{
  "pack_id": "OP-RAND",
  "kind": "ops",
  "seed": 12345,
  "tasks": []
}
```

# 存檔（設計欄）

店檔至少：

| 欄位 | 說明 |
| --- | --- |
| `day_index` | 已結束的營業日數（關店後遞增） |
| `active_tasks_by_seat` | seat → 進行中任務狀態（含 task 快照同形 dict、`current`、`status`、`started_day`） |
| `completed_task_ids`／失敗紀錄 | 依種類分表可再細分 |
| 劇情／事件進度 | 與 `ecosystem.md` 對齊；劇情失敗擋推進 |

存檔 `SAVE_VERSION` 4+（`day_index`／`active_tasks_by_seat`／測試選擇）。

# 活線摘要（已接）

- `scripts/session/task_catalog.gd`／`task_tracker.gd`
- `demo.gd`：`_begin_day` 掛測試包／隨機；metric note；`_finish_day` 結算任務後 `day_index++`
- Prep：任務頁＋系統工具「測試任務」；HUD 左欄清單；結算任務行
- COMBO 活線與本檔對齊（`fetchcombo.md`）
- 事件／劇情 pack 接口可載入；修飾器／擋推進未做
- 報酬發放未做（Beta）

# 待其他設計補完

- Host／訪客「共同解決」劇情向细则
- 報酬表與發放時機（Beta）
- 店鋪進度任務解鎖機制（Beta，`shopprogress.md`）
- 成就系統（獨立檔）
- 完整事件表（`eventsystem.md`）與劇情任務內容

# 相關檔

- 內容：`taskcontent-ops-test.md`、`taskcontent-event-stub.md`、`taskcontent-story-stub.md`
- `gameconcept.md`、`ecosystem.md`、`ratingsystem.md`、`shopprogress.md`、`fetchcombo.md`
- `docs/beta/design.md`、`docs/systemdesign-gaps.md`
