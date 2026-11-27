# 精英店員設定

- 此檔案定義**精英店員**（店鋪 NPC 店員的特殊類型）
- **狀態：** 系統定稿（v1）；個別角色數值／技能細節以目錄表為準，可再擴充
- 一般雇員：[`clerksystem.md`](clerksystem.md)
- 劇情框架／主題通關來源：[`storysystem.md`](storysystem.md)、[`story/themes/`](story/themes/)
- 工程活線：`godot/game`（目錄 `scripts/session/elite_clerk_catalog.gd`；狀態／存檔 `game_state.gd`；Prep UI `prep/prep_pages.gd`；營運 AI `clerk.gd`）

# 與一般雇員的差異

| 項目 | 一般雇員（`clerksystem`） | 精英店員 |
|------|---------------------------|----------|
| 身份 | 可雇 NPC；無固定劇情名 | **有名稱**（不可改）、有劇情背景 |
| 取得 | 規模內雇用（日薪） | 劇情／特別事件／小遊戲；**不可招聘** |
| 欄位 | 佔 `HIRE_CAP`＋普通收銀機上限 | **另占精英欄**；**不佔**一般 `HIRE_CAP`／收銀機人數上限 |
| 日薪 | 每人開工扣 `$100` | **不扣日薪**（金錢成本＝升級投資） |
| 等級 | 無獨立投資等級 | **可支付金錢升級**；成長線預設，能力不可自由分配 |
| 能力 | 崗位固定行為；補貨／清潔用固定 AGI 10 | 依角色預設成長線隨等級提升 STR／AGI／INT |
| 技能 | 無 | **一個固有技能**（玩家技能池或 NPC 專用） |
| 崗位 | 一人一崗：`restock`／`cashier`／`security`／`cleaner` | 可同回合**多崗位**；數量上限視個別店員 `max_posts`／`allowed_roles` |
| 名字 | 無 | 固定顯示名（locale）；不可修改 |

# 獲得方法

1. **劇情發展解鎖**（主題通關為主；個別例外後補）
2. **完成特別事件**
3. **小遊戲獎勵**
4. **不可**透過一般招聘／`hire` 獲得

解鎖 API：`GameState.unlock_elite_clerk(elite_clerk_id, source)`。  
已擁有則幂等（不重設等級）。來源字串寫入進度供統計／任務（`theme_clear`／`event`／`minigame`／`debug` 等）。

# 欄位與出勤（拍板）

- 精英店員與一般雇員**並行**：兩邊可同時出勤
- 精英**不佔**一般雇員欄、**不扣**日薪
- 準備期決定是否**出勤**（`on_duty`）與本回合**崗位集合**（`roles[]`）
- 收銀崗位仍需店內已放置普通 `cashier`；多位精英／雇員綁同一機時行為與現況一致（就緒即入帳）
- 頭目戰日：含 `cashier` 的精英與一般收銀雇員同樣**不派出收銀職責**（其餘已派崗位照常）；配置留在準備／存檔
- **分店派駐（設計；見 [`branchstore.md`](branchstore.md)）：** 精英為全域解鎖池；可派任分店店長／四崗位（`assignment{theme_id, post}`）。**互斥：** `on_duty`（本店出勤）與任一分店 `assignment` 不可同時成立；同一員只能佔一個分店崗位

# 管理 UI（準備期）

員工管理（Prep hub `staff`）下設分頁：

1. **一般店員** — 既有召募／切崗／改派機／解僱
2. **精英店員** — 已擁有列表；選中後詳情：
   - 背景資料
   - 現有等級／等級上限
   - 當前能力值（STR／AGI／INT；只讀）
   - 固有技能名稱與簡述
   - 可分配崗位（僅該員 `allowed_roles` 內；可多選至 `max_posts`）
   - 出勤開關
   - **升級**（支付金錢；顯示下一級費用與能力預覽）

# 升級機制

- 每個 `elite_clerk_id` 有預設成長線：每級對應固定 STR／AGI／INT（**不能**自由配點）
- 玩家支付 `upgrade_cost(level → level+1)`（僅金錢；無素材）升級
- 費用與能力表寫在目錄；資金不足不可升級
- 等級範圍：目錄 `level_min`（預設 1）～`level_max`（v1 預設 10）

# 能力值

- 每名角色有固定發展方向（偏 STR／AGI／INT 或平均），數值已先行定義於成長線
- 營運中：
  - 補貨 Circle → `Tuning.restock_seconds(agi)`（可再乘固有技能 `restock_pct`）
  - 清潔 Circle → `Tuning.clean_seconds(agi)`
  - 移動等可吃 `move_pct` 類被動
  - 一般雇員維持既有固定 AGI 10／即時收銀規則不變

# 技能

- 每名精英**恰好一個**固有技能（`skill_id`）
- 可為：
  - 現有玩家技能池 id（主動／被動）
  - NPC 專用 id（`npc_*`，定義於精英目錄或 skills 擴充）
- v1 行為：
  - **被動／數值標籤**：套用至該精英的營運工作（如 `restock_pct`、`move_pct`）
  - **主動**：目錄可標 `auto_cast`；有實作路徑者於 CD 到時自動觸發；未接線者仍顯示於 UI，效果後補
- 精英技能**不佔**玩家 COST／裝備格；與玩家 loadout 獨立

# 名字

- 顯示名走 locale（`elite_clerk.<id>.name`）；**不可**在遊戲內修改
- 背景短述：`elite_clerk.<id>.bio`

# 多崗位

- 「同回合多崗位」＝同一營業日可被指派多個崗位，單一身體以**需求優先切換**執行（非多分身）
- 暫不設全域崗位數量上限；以各員 `max_posts` 與 `allowed_roles` 為準
- v1 切換優先（由高到低；僅在已指派集合內）：
  1. `security`：偵測範圍內有可抓小偷 → 追擊／撞飛（可中斷巡邏／閒置／清潔接近；持箱則先放下再開追）
  2. `cleaner`：有可清污物且未被玩家佔用 → 前往清潔
  3. `cashier`：綁定機有就緒客人（非頭目須玩家結帳）→ 即時入帳
  4. `restock`：有補貨工作 → 取貨上架
- 單崗位精英與一般雇員相同：只跑該崗 AI
- 範例：同時指派補貨＋收銀 → 有客先收、空檔去補；捉賊＋清潔 → 有賊先捉、否則清污

# 資料形狀

## 目錄（靜態）

| 欄位 | 說明 |
|------|------|
| `id` | 穩定 `elite_clerk_id` |
| `theme_id` | 主題主導則填；非劇情可空 |
| `source_hint` | 設計用主要來源：`theme_clear`／`minigame`／`event` |
| `name_key`／`bio_key` | locale |
| `model_id` | 世界模型（暫可複用 `clerk_*`） |
| `allowed_roles` | 可指派崗位子集 |
| `max_posts` | 同時最多幾個崗位 |
| `default_roles` | 首次解鎖預設指派 |
| `skill_id` | 固有技能 |
| `level_max` | 等級上限 |
| `growth` | 陣列：index 0＝Lv1 的 `{str,agi,int}` |
| `upgrade_costs` | 陣列：升到 Lv2、Lv3… 的費用（長度 `level_max-1`） |

## 存檔（進度）

`elite_clerks`: 陣列，每項：

```json
{
  "id": "yayoi",
  "level": 1,
  "on_duty": true,
  "roles": ["cashier", "security"],
  "register": 0,
  "source": "theme_clear",
  "assignment": null
}
```

- `SAVE_VERSION` ≥ 9
- 未擁有者不在列表中
- 清除存檔／重選劇本時一併清空（與一般 `clerks` 相同）
- **設計擴欄 `assignment`：** `{ "theme_id": "theme_historic", "post": "manager" }` 或 `null`；與 `on_duty` 互斥（見 [`branchstore.md`](branchstore.md)）

# 與其他系統

- 不取代麻煩客人（`elitecustomer.md`）
- Dark Side／影分身臨時人力**不是**精英店員
- 主題元素槽與通關來源見 `storysystem.md`／各 `story/themes/*`
- 破局主題是否發精英：見 `story/progression-crossref.md`；目錄已預留 `alan`（暫名）

# 測試劇本 10「精英店員營運日測試」

- **狀態：** 活線已掛（`GameState.SCENARIO_ELITE_CLERK = 10`；僅 `ProductVersion.TEST_TOOLS` 劇本選單可見）
- **藍本：** 安桃山 place shell；店鋪／商品 **bake 自 2026-11-26 活線存檔**
- **店面：** 18×13；魚缸、熟食檔、乾貨補貨×3（米／醬油／零食）＋乾貨架×3；凍櫃補貨×2（飲／奶）＋凍貨架 24×2；冰櫃補貨×1（雪糕）＋冰貨架 24×1；收銀×1；**傳送門一對**（右上 `(16,0)` ↔ 右下 `(16,12)`）
- **已開發／可售：** 米、醬油、零食、飲、奶、雪糕、熟食三品可售；`can` 已開發但不可售
- **庫存：** 可售乾／凍／冰線各約 50 箱等價；**各魚 id＝40**
- **差異：** `EliteClerkCatalog` **全員** debug 解鎖並 `level_max`（多數 LV10；`kiko`＝8）；一般雇員補貨／收銀各 1
- **目的：** 在安桃山＋擴充凍／冰線營運日一次驗收精英店員進度

## 開局後建議驗收（對照現況）

### Prep

1. 員工管理 → **精英店員**分頁：列表顯示全員（名稱／等級／出勤／崗位摘要）
2. 開詳情：背景、等級上限、三圍、固有技能名／簡述、`max_posts`、可切崗位、出勤開關、升級費用
3. 升級：扣款成功；滿級／資金不足有錯誤字串
4. 多崗位：在 `allowed_roles` 內切到 `max_posts`；少於 1 崗／超上限有阻擋
5. 出勤關：該員不應出現在下一日 `on_duty_elite_clerks()`

### 營運日

1. 開始營運：世界應生成一般雇員＋所有出勤精英（`world_build._spawn_elite_clerks`）
2. **多崗位優先**（僅已指派集合內）：有賊 → security；否則可清污 → cleaner；機有就緒客 → cashier；否則 restock
3. 清潔中途污物被清掉／`queue_free`：清潔員不應因 freed 目標型別錯誤當掉（`_clean_target_valid` 未型別參數）
4. 一般雇員 `setup`：`roles: Array[String]` 指派正常（不再用 untyped `[job]` 字面量）
5. NUL（`max_posts` 3）等複合崗：觀察是否在補貨／收銀／清潔間切換，而非卡住單一崗

### 工程備註（已修、劇本用來回歸）

| 問題 | 修法摘要 |
|------|----------|
| `elite_clerk_catalog` `const ENTRIES` 呼叫 helper → Parse error | 成長／費用改具名 `const` 表再引用 |
| Prep 詳情 `:=` 推論失敗（`load()`／`menu.state`） | `lv_max`／`skill`／`cost` 顯式型別 |
| `roles = [job]` → Array 對不上 `Array[String]` | `clear`＋`append` |
| `_clean_target_valid(d: Node2D)` 傳入已釋放物件 | 參數改未型別；先 `is_instance_valid` 再當 `Node2D` 用 |

# 相關文件

| 文件 | 角色 |
|------|------|
| [`clerksystem.md`](clerksystem.md) | 一般雇員 |
| [`storepreparationphase.md`](storepreparationphase.md) | Prep 員工管理分頁；劇本 10 列於測試版選單 |
| [`savesystem.md`](savesystem.md) | `elite_clerks` 存檔 |
| [`branchstore.md`](branchstore.md) | 分店派駐／互斥／背景結算 |
| [`storysystem.md`](storysystem.md) | 主題元素槽含精英店員 |
| [`story/themes/`](story/themes/) | 各主題主導角色 |
| [`story/growth-skills.md`](story/growth-skills.md) | 玩家技能；精英固有技能另見本檔／目錄 |
