# 分店系統

- 此檔定義**分店系統**（主題店快照、本店／分店切換、分店設置、背景營運結算、日結分頁）
- **狀態：** 設計先行（產品規格開檔）。**活線未做**；依賴劇情 `story_slot` × `theme_id` runtime（見 [`storysystem.md`](storysystem.md)；EA 不做章節 runtime）
- 交叉：[`ecosystem.md`](ecosystem.md)、[`savesystem.md`](savesystem.md)、[`ratingsystem.md`](ratingsystem.md)、[`clerksystem.md`](clerksystem.md)、[`eliteclerk.md`](eliteclerk.md)、[`storepreparationphase.md`](storepreparationphase.md)、[`storeoperationphase.md`](storeoperationphase.md)、[`procurement.md`](procurement.md)、[`story/progression-crossref.md`](story/progression-crossref.md)

# 分店定義

- 玩家當下操作的店＝**本店**（完整即時世界營運）
- **起源線：** 序章 → 第1章 → 第2章破局（`theme_break`）＝**同一間起源本店**；破局**之前**沒有分店模型
- **破局後**進入分店模型：每到一個**可選主題**（六主題）都**重新開店**，與已完本／已遊玩的主題店**獨立**
- 玩家穿越回訪某主題時，該主題店成為**本店**；其他已開的可選主題店成為**分店**
- **只有六個可選主題店**進入分店池；起源店見下文「起源店」

```text
序章＋第1章＋破局 ＝ 起源本店（單一路徑）
         ↓ 破局後選可選主題 → 新開該主題店（完整快照）
清完第一個可選主題 → 解鎖分店系統
         ↓
回訪／切主題：當前主題＝本店；其餘已開可選主題店＝分店（可背景營運）
```

# 解鎖

| 條件 | 說明 |
|------|------|
| 閘門 | **清完第一個可選主題**（`themes_cleared` 至少 1）之後解鎖分店系統 UI 與背景結算 |
| 前置 | 自然含「已過破局」；破局當下仍無分店可管 |
| 旗標（暫名） | `branch_system_unlocked`（亦可由 `themes_cleared.size() >= 1` 推導，不另存） |

解鎖前：可選主題店仍各自快照與切換本店，但**不**跑背景營運、Prep 不顯示分店入口。

# 本店／分店運作

| 角色 | 行為 |
|------|------|
| **本店** | 玩家準備＋即時營運日（現行 `storeoperationphase`）；日結改**該店**評價與共用資金 |
| **分店** | 玩家不操作；可設店長／店員／方針／售賣／採購；本店每回合營運時，合格分店在背後**同步抽象結算** |
| **資金** | **全域共用**一份 `money`；分店**不**設獨立資金欄。分店賺到的營業額直接 `money +=` |
| **評價** | 每間主題店各自 `shop_rating`／`rating_history`；分店背景結果**只改該分店** |

## 起源店

- 破局前：與現行單店一致（頂層店舖欄＝起源店）
- 破局後玩家進入第一個可選主題：**新開**該主題空店為本店；起源店寫入獨立快照槽（暫名 `origin_store` 或 `theme_id = origin`）
- 起源店**可回訪**做即時本店營運（敘事／補任務），但**不進入分店背景營運池**（避免與「清第一可選主題才解鎖分店」打架，也避免起源與主題池規則分叉）
- 起源店回訪時：當前可選主題店若已解鎖分店且有店長 → 照常背景結算

## 切換本店

1. 選章或回訪選定 `theme_id`（或回訪起源）
2. 將現行本店完整狀態**寫回**對應快照
3. 載入目標快照為可互動本店（`active_theme_id`／起源旗標）
4. 其餘已開**可選**主題店＝分店候選

# 分店設置（Prep）

解鎖後，準備回合新增入口「**分店**」（建議 home 獨立圖塊；亦可掛 `hub_shop` 下）。選一間非本店的已開主題店後，簡易設定：

## 在店貨品（採購）

- 對該分店倉庫採購已開發且該店開售的 SKU
- **扣共用** `money`；規則對齊 [`procurement.md`](procurement.md)（件數／箱價）
- 亦可只靠每日自動補貨（見下）

## 商品售賣設定

- 開關該分店各已開發 SKU 的售賣狀態（語意同本店 `for_sale`）
- 至少保留一項可售（與本店相同約束）；不可售者不進自動補貨目標、不進背景銷售池

## 營運方針 `policy`

| id | 名稱 | 效果傾向 |
|----|------|----------|
| `high_pressure` | 高壓銷售 | 資金結果較易高、評價較易低 |
| `balanced` | 平均營運 | 資金與評價平衡（預設） |
| `customer_first` | 顧客至上 | 資金結果較易低、評價較易高 |

## 崗位

| 崗位 | 必填 | 說明 | 背景結算加成軸 |
|------|------|------|----------------|
| **店長** `manager` | **是**（無店長＝當日停業） | 店員總合力加資金與評價的**主因** | 店長綜合能力（見公式） |
| 收銀 `cashier` | 可空 | 店員 | **INT** → 資金加成 |
| 補貨 `restock` | 可空 | 店員 | **STR** → 資金加成 |
| 清潔 `cleaner` | 可空 | 店員 | **AGI** → 評價加成 |
| 保安 `security` | 可空 | 店員 | **STR** → 評價加成 |

- 店長與四崗位可為**一般雇員**或**精英店員**
- 同一人**不可**同時：本店出勤（`on_duty`／本店 `clerks` 當班）**又**佔任一分店崗位（全宇宙互斥）
- **一般雇員：** 每店 `clerks[]` **各自招聘**（日薪、HIRE_CAP 跟**該店**規模／普通收銀機數）
- **精英店員：** 全域解鎖池（`elite_clerks`）；派駐分店時寫 `assignment`（見存檔）；與本店 `on_duty` 互斥。分店崗位上的精英**不**另扣日薪（與精英現行規則一致）
- 分店店長若為一般雇員：仍算該店雇員欄與日薪（開工時一併從共用資金扣，或併入該分店當日結算支出列）

# 自動補貨

於每間**合格分店**背景營運開始前執行：

1. 對象：該店 `for_sale == true` 的已開發 SKU
2. 目標庫存：`target_pieces(sku) = max(shelf_capacity_for_sku, DAILY_USAGE_PIECES)`  
   - `shelf_capacity_for_sku`：依該店已放置、可放該 SKU 類型的貨架空位合計（設計意圖；實作可簡化為類型架容量表）  
   - `DAILY_USAGE_PIECES`：**待平衡**常數（首版建議每開售 SKU **16** 件／日，可按規模檔微調）
3. 若倉庫件數 `< target`，採購差額；**扣共用** `money`
4. 資金不足：**能買多少買多少**（依採購單價從高優先或清單順序買；**不透支**）
5. 支出記入該分店當日報告的「自動補貨」列，並可計入虧損判斷的採購側（與本店 `day_procurement` 分開列示，或加總進當日全域採購統計——實作時二選一，預設**分店採購另列**、不併本店虧損旗）

**停業日（無店長）：** 不自動補貨、不營運、不改評價。

# 背景營運結算

時機：本店關店 `settle` **同一流程內**（本店入帳之後或並列，須在寫檔前完成），對每間合格分店跑一次**抽象結算**（**不**開 3 分鐘世界模擬、不 spawn 店員 AI）。

## 資格

```text
branch_system_unlocked
∧ theme_store 為可選主題店
∧ theme_id ≠ 當前本店
∧ 已配置店長（manager 非空）
```

否則：報告列「停業」或「未解鎖／非分店」，跳過。

## 能力讀取

| 來源 | STR／AGI／INT |
|------|----------------|
| 精英 | 該員當前等級成長線（[`eliteclerk.md`](eliteclerk.md)） |
| 一般雇員 | 固定基準 **STR 10／AGI 10／INT 10**（與活線雇員行為基準對齊；**待平衡**可改） |
| 空崗 | 該軸加成＝0 |

**店長綜合分（待平衡）：**

```text
manager_score = (STR + AGI + INT) / 3
```

## 方針係數（待平衡）

| policy | `fund_mult` | `rating_mult` |
|--------|-------------|-----------------|
| `high_pressure` | 1.25 | 0.75 |
| `balanced` | 1.00 | 1.00 |
| `customer_first` | 0.75 | 1.25 |

## 資金結果（待平衡）

```text
base_revenue = BRANCH_BASE_REVENUE
             × (1 + manager_score / MANAGER_FUND_DIV)
             × stock_factor
             × scale_factor

staff_fund_bonus = INT_cashier × K_INT_FUND
                 + STR_restock × K_STR_FUND

revenue = max(0, round( (base_revenue + staff_fund_bonus) × fund_mult ))
```

| 常數（首版建議） | 值 | 說明 |
|------------------|-----|------|
| `BRANCH_BASE_REVENUE` | 400 | 日基礎營業額 |
| `MANAGER_FUND_DIV` | 50 | 店長綜合分除數 |
| `K_INT_FUND` | 8 | 收銀 INT→資金 |
| `K_STR_FUND` | 6 | 補貨 STR→資金 |
| `stock_factor` | `clamp(開售且倉庫>0 的 SKU 數 / max(開售 SKU 數, 1), 0.2, 1.0)` | 貨不夠則打折 |
| `scale_factor` | S1–S6 → 0.7／0.85／1.0／1.1／1.2／1.3 | 跟該店 `shop_scale` |

結算：`money += revenue`（共用資金）。自動補貨已先扣款。

分店**不**發角色 XP（背景日不計玩家／雇員 XP）。

## 評價結果（待平衡）

不分模擬逐筆行為；直接估當日**營運點**，再走與本店相同的評級帶（[`ratingsystem.md`](ratingsystem.md) −3…+3）：

```text
ops_points = 50
           + manager_score × K_MGR_OPS
           + AGI_cleaner × K_AGI_OPS
           + STR_security × K_STR_OPS
ops_points = ops_points × rating_mult
```

| 常數（首版建議） | 值 |
|------------------|-----|
| `K_MGR_OPS` | 1.5 |
| `K_AGI_OPS` | 0.8 |
| `K_STR_OPS` | 0.8 |

- 評級帶與本店相同（依最終 `ops_points`）
- `shop_rating = max(0, shop_rating + grade)` **僅該分店**
- 寫入**該分店** `rating_history`（最多 30 筆）
- **不**觸發本店難度建議窗（難度建議只看**本店**歷史）

## 任務條件預設

| metric | 預設語意 |
|--------|----------|
| `shop_money` | 共用 `money` |
| `shop_rating` | **本店**商店評價 |
| 指定分店 | 將來可加 `theme_id` 限定；本規格不強制 |

# 日結分頁（UX）

本店關店 closeout 既有面板之外，**另設分頁／面板「分店」**：

每間分店一列（或可展開卡）至少含：

- 主題名／`theme_id`
- 狀態：營運／停業（無店長等原因）
- 方針
- 自動補貨支出
- 營業額（入共用資金）
- 估得營運點 → 評級文案
- 該店商店評價：結算前 → 後
- （可選）店長／崗位摘要

無分店或未解鎖：分頁隱藏或顯示鎖定說明。

# 存檔欄位（設計意圖）

落地時升 `SAVE_VERSION` 並在 [`savesystem.md`](savesystem.md) 補 migration。建議形狀：

## 頂層（共用）

| 欄 | 說明 |
|----|------|
| `money` | 共用資金（維持頂層） |
| `active_theme_id` | 當前本店主題；起源本店可用 `""`／`origin` |
| `themes_cleared` | 既有劇情欄 |
| `theme_stores` | `Dict[theme_id, ThemeStoreDict]` 可選主題店快照 |
| `origin_store` | 起源店完整快照（破局後寫入；破局前可空，頂層店欄即起源） |

破局前相容：頂層仍可直接持有現行單店欄；遷移後「現行本店」＝自 `theme_stores[active]` 或 `origin_store` hydrate。

## `ThemeStoreDict`（每店）

與現行單店店舖欄對齊，至少：

- `owned`／`placed`／`shop_scale`／`grid_w`／`grid_h`
- `stock`／`developed`／`for_sale`／（主題相關 `fish_stock` 等若該店需要）
- `clerks[]`（**該店**一般雇員）
- `shop_rating`／`rating_history`／`last_ops_rating`／`last_grade`
- 分店營運：`policy`（`high_pressure`｜`balanced`｜`customer_first`）
- 崗位：`branch_posts`：

```json
{
  "manager": { "kind": "elite"|"clerk", "id": "yayoi"|clerk_index },
  "cashier": null,
  "restock": { "kind": "clerk", "id": 0 },
  "cleaner": null,
  "security": null
}
```

## 精英派駐

`elite_clerks[]` 每項在既有欄外增加（互斥）：

```json
{
  "id": "yayoi",
  "level": 3,
  "on_duty": false,
  "roles": [],
  "register": -1,
  "source": "theme_clear",
  "assignment": {
    "theme_id": "theme_historic",
    "post": "manager"
  }
}
```

- `on_duty == true`（本店出勤）時 `assignment` 必須為 null／缺省
- `assignment` 非空時不可本店出勤
- 同一 `elite_clerk_id` 只能佔一個分店崗位

# 與其他系統

| 系統 | 關係 |
|------|------|
| 劇情選章／回訪 | 驅動本店切換與主題店建立；見 `storysystem.md` |
| 本店營運 | 不變；分店只在 settle 附加 |
| 評價 | 每店獨立；難度建議只看本店 |
| 一般雇員 | 每店各自；分店背景用抽象能力，不跑 `clerk.gd` |
| 精英店員 | 全域擁有＋互斥派駐 |
| 多人 | **本輪不做**分店 × 訪客互動 |
| 活線 EA | **不實作**；僅設計 |

# 明確不做（本規格版）

- 分店即時 3 分鐘世界模擬
- 分店獨立資金帳戶
- 起源店背景自動營運
- 多人／線上訪客與分店
- Godot 存檔版號與 Prep／settle 實作（另 milestone）
