# 小遊戲：釣魚太郎（`fishing_taro`）

- 主題：[`story/themes/theme-historic.md`](story/themes/theme-historic.md)
- 交叉：[`cookedfoodsystem.md`](cookedfoodsystem.md)、[`shopitem.md`](shopitem.md)、[`storepreparationphase.md`](storepreparationphase.md)
- Prep 入口慣例：對齊既有 hub minigames（`prep_pages`／`prep_menu`）
- **狀態：** 產品合約定稿；ACNH 釣魚＋魚缸取魚＋**欣賞頁游動魚**已落地

# 1. 定位

8-bit 風釣魚小遊戲。玩家控制角色到河邊釣魚；手感對齊**動物森友會式**釣魚（見影→拋竿→咬鉤節奏→收竿），不是戰鬥釣魚。

釣獲五種魚寫入商店 **`fish_stock`**；魚缸傢俬解鎖後可於營運當乾貨式「魚倉」提取，供熟食檔做 `nigiri`。

# 2. 魚種（鎖定）

| 顯示 | `fish_id` | 建議權重（可調） |
|------|-----------|------------------|
| 鯖魚 | `saba` | 28% |
| 鯛魚 | `tai` | 12% |
| 秋刀魚 | `sanma` | 22% |
| 竹筴魚 | `aji` | 22% |
| 香魚 | `ayu` | 16% |

- 全部進 `fish_stock[fish_id] += 1`（或單次多條規則後補）
- **不是**可售 SKU；不進 `Tuning.SELLABLE_SKUS`／客人清單
- Locale：`fish.saba` 等（`data.csv`）；與 `sku.*` 分開命名空間

# 3. 流程與操作（v1）

## 3.1 場景

- Prep 子場景（建議 `fishing_taro.tscn`）：橫向／俯視河邊＋角色＋水面
- 畫風：低彩度像素／8-bit UI 框；仍可用全遊戲 Cozy 字級母本包一層外框
- 結束：`signal exited` → 回 Prep 小遊戲 hub（同 bun／dasher）

## 3.2 一輪釣魚（ACNH 感）

1. **移動**：左右沿岸（或有限平台）；不可下水
2. **見影**：水面隨機出現魚影；走近可拋竿
3. **拋竿**：行動鍵拋出；浮標落在影區才有機會
4. **等待**：浮標輕晃；魚影靠近
5. **咬鉤**：明顯咬鉤演出＋短窗（建議 0.45–0.7s）按行動鍵收竿
6. **成功**：出示魚種卡片＋收入 `fish_stock`；可立即再釣
7. **失敗**：早收／晚收／空竿 → 短挫敗演出，魚影消失重抽

單次 Prep 造訪建議軟上限（例 20 次拋竿或 5 分鐘）防刷；主題任務可要求「累計釣到 N 條」。

## 3.3 解鎖與存檔

| 旗標／欄位 | 說明 |
|------------|------|
| `fishing_taro_unlocked` | 主題任務 H3 後 hub 顯示 |
| `fishing_taro_played` | 曾進入並正常退出至少一次 |
| `fish_stock` | 五魚件數字典；跨日持久 |
| `owned["fish_tank"]` | **`fishing_taro_played` 首次成立時自動 +1 授予**（零資金；購入列不賣） |

回訪小遊戲可繼續累積魚；**不**重複授予第二座魚缸（`owned` 上限 1，除非日後出更大款）。

# 4. 商店物品 `fish_tank`（魚缸）

## 4.1 Catalog

- id：`fish_tank`
- 取得：**事件／遊玩授予**，不可資金購入（對齊 `portal` 先例）
- 佔格建議：`2×2`
- 放置：店舖設計圖；未放置時魚仍存在 `fish_stock`，但營運**不能**從缸提取（須放置才當魚倉口）
- 開店：非必要物；不進一般 `open_blockers`

## 4.2 營運＝魚補貨口

- 行為對齊補貨架輕放取件：對準魚缸 → 輕放取 **1** 條目前選中 `fish_id`（`fish_stock` −1；佔負重 1）
- 長按：清單改選魚種（層級同 restock SKU 清單）
- 取出的魚為**持有原料**（視覺可用專用魚箱面貼或 SKU 風格圖示）；可帶去 `cooked_stall` 作 `nigiri`
- **不可**上架到乾／凍／冰貨架；`shelf.can_accept` 拒絕所有 `fish_id`
- 關店：手上未用魚退回 `fish_stock`（同倉庫退倉精神）

無「魚貨架」系列；魚不零售。

## 4.3 Prep：魚缸欣賞頁 `fish_tank_gallery`

- 入口：Prep（擁有魚缸後）；可由傢俬列或小遊戲 hub 旁進入
- 內容：
  - 五魚數量表
  - 簡易魚缸展示區：依擁有／數量生成游動魚 sprite（8-bit）
  - 只讀欣賞＋可選「前往釣魚太郎」按鈕
- 不在此頁消耗／販賣魚

# 5. Locale 鍵（鎖定）

| key | 用途 |
|-----|------|
| `fish.saba`／`tai`／`sanma`／`aji`／`ayu` | 魚名 |
| `furniture.fish_tank` | 魚缸 |
| `prep.fishing_taro.title`／`.hint`／`.reward_tank` | hub／首次解鎖提示 |
| `prep.fish_tank_gallery.*` | 欣賞頁 |

# 6. 實作掛點（給後日程式；本檔不實作）

- `scripts/prep/fishing_taro.gd`（＋可選 `fishing_taro_art.gd`）
- `prep_menu`／`prep_pages` hub 列
- `GameState.fish_stock`／`unlock_fish_tank_from_fishing()`
- `fish_tank` 執行時節點（restock 變體或獨立 `fish_tank.gd`）
- 音效／BGM 鍵後補 `soundeffects.md`／`bgm.md`
