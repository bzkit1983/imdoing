# 熟食系統（`cooked`）

- 主題：[`story/themes/theme-historic.md`](story/themes/theme-historic.md)
- 交叉：[`stocksystem.md`](stocksystem.md)、[`shopitem.md`](shopitem.md)、[`replenishmentsystem.md`](replenishmentsystem.md)、[`customer.md`](customer.md)、[`procurement.md`](procurement.md)、[`storeoperationphase.md`](storeoperationphase.md)
- **狀態：** 產品合約定稿；加工須**先投原料入檔**（不直接扣倉）、客人排隊／WAITING_CRAFT／完工交付、魚缸取魚已落地

# 1. 貨類 `cooked`

- 新貨類 id：`cooked`（熟食）
- **不可**經準備回合「採購」購入倉庫件數
- 客人可把已開發且 `for_sale` 的熟食 SKU 抽進購物清單（同既有 `sellable()` 規則）
- 取得唯一路徑：營運中（或開日前預製，見 §4）在 **`cooked_stall`** 依食譜消耗原料加工

對既有冰櫃 SKU **`rice`（叮叮飯）無影響**。本主題乾貨「米」為 **`grain`**。

# 2. 可售熟食 SKU

| `sku_id` | 顯示 | 食譜（各 1 件產出） |
|----------|------|---------------------|
| `onigiri` | 飯團 | `grain`＋`grain` |
| `yakimochi` | 烤年糕 | `grain`＋`soy_sauce` |
| `nigiri` | 手握壽司 | `grain`＋**任一** `fish_id`（`saba`／`tai`／`sanma`／`aji`／`ayu`） |

規則：

- 米＋不同魚 → 一律產出 **`nigiri`**（暫不按魚種分 SKU）
- 客人購物清單只會出現 `nigiri`，**不會**要求特定魚種
- 加工時玩家自選消耗哪一種魚（有庫存者）；缺魚不可做壽司
- 原料來源（兩段式；**加工不直接扣倉**）：
  1. 玩家自乾貨補貨點取 `grain`／`soy_sauce`，自魚缸取魚（見 [`fishingtaro.md`](fishingtaro.md)）
  2. **短按熟食檔**把持有原料投入檔內 `pantry`；製作只扣 `pantry`

建議性狀（草案）：

| trait | 用途 |
|-------|------|
| `craft_only` | 禁採購 UI／禁 `buy_stock` |
| `spoil_unshelved`（可選偏短） | 熟食離檔後較易壞（實測再釘秒數） |

售價／開發費帶：見 [`story/growth-economy.md`](story/growth-economy.md) §4.2。

# 3. 商店物品 `cooked_stall`（熟食檔攤）

## 3.1 Catalog

- id：`cooked_stall`
- 系列定位：**類似貨架**——面向客人取貨／點餐；不是乾／凍／冰補貨架
- 佔格建議：`2×1`（與 `shelf_dry_*` 同級；實作可調）
- 價格／解鎖：主題任務發資格後購入（建議價帶 $800–1,200；落地改 shopitem）
- 開店：至少放置 1 座 `cooked_stall` **才允許**把熟食列入當日 `for_sale`／進 `sellable`（無檔則熟食自動不可售，避免幽靈清單）
- **不**要求 `restock_cooked`（無此傢俬）；原料走乾貨倉＋魚缸

## 3.2 檔面庫存（可預補多 SKU）

與現行「一架單 SKU」不同，熟食檔支援**多 SKU 並列槽**：

```text
CookedStallFace {
  slots: Array[{ sku_id: String, count: int }]  # 僅 cooked 類
  capacity_total: int   # 建議預設 8；後可出更大款
}
```

- 準備回合／補貨時段：玩家可對檔攤「預補」——從既有熟食倉庫件（若有隔日退倉）或**當場加工**填入 slots
- 同一 `sku_id` 可合併計數；總件數 ≤ `capacity_total`
- 視覺：檔面顯示多個熟食圖示／數量

## 3.3 客人行為（排隊點餐）

1. 清單頭為 `cooked` SKU → 尋找已放置的 `cooked_stall`（優先有該 SKU 檔面庫存者；否則最近檔）。**小偷不適用**（不抽熟食、不排檔）。
2. 到達後進入**檔攤隊列**（獨立於收銀 QUEUE）
3. 到隊首：
   - 若檔面該 SKU `count ≥ 1`：短逗留 → 取 1 件入購物車、清單移除頭項（同貨架自取）
   - 若無貨：進入 **WAITING_CRAFT**，頭頂**對話框**內顯示需求熟食 SKU（排隊中不顯示「排隊中」文字）；累積不滿（建議略慢於收銀排隊，實測調）
4. 玩家完成對應該需求的加工並交付後（§4），客人取得貨、離開檔隊，繼續清單下一项或去收銀

雇員／分身：**v1 不代操作熟食檔**（僅玩家）。

# 4. 玩家加工（營運核心）

## 4.1 互動

- **短按**（手上有 `grain`／`soy_sauce`／`fish_id`）：投入檔內 `pantry`（不經倉庫直扣）
- **長按** → 檔攤**頂部／頭頂錨點**彈出加工 UI（最高層；對齊補貨長按清單）
- UI 內容：
  - 目前隊首（或選定）客人需求 SKU（若有）
  - 可製作食譜列表（已解鎖）
  - 每道食譜顯示原料與**檔內 pantry** 存量；不足者不可按
  - 手握壽司：額外選已投入的 `fish_id`
- 確認後進入 **CRAFTING**：短 Loading Circle／等候（建議 **1.5–2.5s**；技能後可縮）
- 開始時扣 `pantry`；移動取消／受擊 → **退回 `pantry`**（不退回倉／手）

## 4.2 完成交付（合約）

完成後依優先序：

1. **有 WAITING_CRAFT 且需求＝本產物**：直接寫入該客人購物車（清單該項完成）。產品語意對齊設計口述「加到客人購物清單」＝**完成其點餐訂單／入購物車**，不是再塞回未取清單。
2. 否則若檔面尚有容量：產物 **+1** 到檔面該 SKU（預補／備貨）
3. 否則若熟食倉庫有鍵：入 `stock[sku]`（隔日可再預補）
4. 否則失敗提示滿檔（不應發生若 UI 預檢）

投擲／技能交付：若客人清單含該熟食，允許既有投擲／使命必達等對 **已存在於檔面或持有的熟食件** 生效；**不可**對「尚未做出的訂單」空投。

# 5. 準備回合

- 開發：`grain`／`soy_sauce` 走一般開發費；三款熟食開發＝解鎖配方＋可售開關（無採購價）
- 可售：熟食可 `for_sale` 開關；無 `cooked_stall` 放置時開店檢查警告或強制不可售
- 魚缸欣賞：見 fishingtaro（非本檔）
- 栽培（cultivate）**不**混用熟食食譜（兩套系統分開）

# 6. Locale 鍵（鎖定）

| key | 用途 |
|-----|------|
| `sku.grain`／`sku.soy_sauce`／`sku.onigiri`／`sku.yakimochi`／`sku.nigiri` | 貨名 |
| `furniture.cooked_stall` | 傢俬名 |
| `ui.cooked.craft_*` | 加工 UI（後補細鍵） |

# 7. 實作掛點（給後日程式；本檔不實作）

- `Tuning.CAT_COOKED`、`COOKED_SKUS`、食譜表 `COOKED_RECIPES`
- `GameState.fish_stock`；`buy_stock` 拒絕 `craft_only`
- `cooked_stall.gd`＋`world_build` 生成；客人狀態 `QUEUE_STALL`／`WAITING_CRAFT`
- 開店：`open_blockers` 可選檢查「有熟食可售 ⇒ 需檔攤」
