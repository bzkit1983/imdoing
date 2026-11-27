# 序章（開檔）

- 章 id：`prologue`
- 劇情 pack 前綴：`ST-PROLOGUE-###`
- 框架總則：[`../storysystem.md`](../storysystem.md)
- **狀態：** 進程主線已定（不含劇情）；劇本／事件文案後補。**EA（2026-11-27）：** 序章是付費 EA 與免費 Demo 的進程起點。**活線：** 劇本 8 已接內容閘與經濟（`ST-PROLOGUE-MONEY`）。通關後進第 1 章的 `story_slot` runtime 仍未做
- 經濟／規模：[`growth-economy.md`](growth-economy.md)；交叉：[`progression-crossref.md`](progression-crossref.md)

# 概念（框架）

序章＝**新手教學向進程槽**＋順利營運入門（可含包裝式操作任務）。選章／破局在第2章通關後才開放（EA 僅安桃山可選）。

- 不計劇本內容時：以劇情任務帶玩家一步步完成基本商店設置與營運
- 另有**小型事件任務**解鎖基本類型的**初階技能**（具體技能 id 待技能分析）
- **教學系統分開：** [`../tutorial.md`](../tutorial.md) 與序章**不合併**；Lesson／步驟／條件等**可重用**到序章任務（或序章引用教學已完成標記）。見 [`progression-crossref.md`](progression-crossref.md) §6
- 進程：通關後進入 [`chapter-01.md`](chapter-01.md)（仍直線，無選章）
- **解鎖規則：** 等級從不直接解鎖；任務發**可開發／可購入資格**，仍付開發費／傢俬價。未解鎖 SKU／傢俬在 Prep **不顯示**

# 開局狀態

| 項目 | 內容 |
|------|------|
| 開局資金 | **$2,500**（活線劇本 **8**；理論下限 $2,290＝必要傢俬＋零食開發＋第二套乾架／補＋罐頭 4 件） |
| 已開發且可售 | 僅 `can`（罐頭） |
| 其他 SKU | 未解鎖 → Prep 開發／採購／上架選單**不列** |
| 可購入傢俬 | 僅 `cashier`、`restock_dry`、`shelf_dry_4` |
| 不開放（隱藏） | 乾／凍 8·12·24 件架、全部冰櫃架／補貨、`self_cashier`、`portal`；SKU：`cup`／`soda`／`icecream`／`meat`／`rice` |
| `owned` | 空；需自購必要三件 |
| 凍飲／牛奶 spoil | 序章**暫不啟用** `spoil_unshelved`（教學友好） |
| 打賊（劇本 8） | 出賊更疏（首賊 ×3、間隔 ×3）、同時最多 1 賊；近身 mash 時限 ×1.6、傷害 ×2（緩解 STR10） |

# 主線進程（不含劇情）

資金達標＝**持有資金**（任務條件 `shop_money`），非生涯累計。

| 節點 | 持有資金門檻 | 節奏意圖 |
|------|-------------:|----------|
| `money_goal_1` | **$3,500** | 須 **高於**開局資金；乾線第二套架後再儲 |
| `money_goal_2` | **$4,500** | 第一組凍櫃（drink）後 |
| `money_goal_3` | **$5,500** | 第二組凍櫃（milk）後；頭目前緩衝 |

實測可整表 ±500。門檻須保持 **> 開局資金**，避免首日 `shop_money` 任務即達標。頭目首次資金獎 **$2,000**（與達標分開；見 `growth-economy.md` §6.2）。

### 開局成本明細（理論下限 $2,290）

| 項目 | 價 |
|------|---:|
| `cashier` ×1 | 1000 |
| `restock_dry` ×2 | 1000 |
| `shelf_dry_4` ×2 | 80 |
| 開發 `snack` | 200 |
| 採購 `can` ×4 | 10 |
| **合計** | **2290** |

開局取整 **$2,500**（餘約 $210 作營運緩衝）。買齊後持有遠低於 `money_goal_1`，需營運回本。

| # | 步驟 | 完成條件 | 發放資格 |
|---|------|----------|----------|
| 0 | 開局 | — | 可購乾線必要傢俬；`can` 可售 |
| 1 | 購入必要商店貨品 | `owned`：`shelf_dry_4≥1`、`cashier≥1`、`restock_dry≥1`（可要求已放置） | — |
| 2 | 採購 | 倉庫／架上有 `can`（建議 ≥4 件＝1 箱） | — |
| 3 | 開發零食 | 先發資格；`developed_has(snack)`＋付開發費 | 發 `snack` 可開發 |
| 4 | 買新乾貨架 | `owned shelf_dry_4≥2` | — |
| 5 | 買新乾貨補貨架 | `owned restock_dry≥2` | — |
| 6 | 資金達標 1 | `shop_money ≥ 3500` | 發 `drink` 可開發＋`shelf_frozen_4`／`restock_frozen` 可購入 |
| 7 | 開發支裝凍飲 | `developed_has(drink)`＋付開發費 | — |
| 8 | 買凍櫃 | `owned shelf_frozen_4≥1` | — |
| 9 | 買凍櫃補貨架 | `owned restock_frozen≥1` | — |
| 10 | 資金達標 2 | `shop_money ≥ 4500` | 發 `milk` 可開發 |
| 11 | 開發牛奶 | `developed_has(milk)`＋付開發費 | — |
| 12 | 再買凍櫃 | `owned shelf_frozen_4≥2` | — |
| 13 | 再買凍櫃補貨架 | `owned restock_frozen≥2` | — |
| 14 | 資金達標 3 | `shop_money ≥ 5500` | 解鎖序章頭目日 |
| 15 | 頭目戰回合 | 頭目營運日通關（形狀：尖峰流量／達標服務；**不含劇情文案**） | 頭目獎 $2000；奧義節奏見 [`growth-skills.md`](growth-skills.md) |
| 16 | 序章完 | `advance` → `chapter_01` | — |

貨束：`can` → `snack` → `drink` → `milk`。杯麵／汽水／冰櫃線延至 [`chapter-01.md`](chapter-01.md) 或之後。

# 本章元素槽位

| 槽位 | 開檔內容 | 待補 |
|------|----------|------|
| 主題方向 | 入門營運／教學 | 劇本主題 |
| 新貨品 | `can`＋`snack`＋`drink`＋`milk`（凍櫃提前教學） | 售價微調／spoil 開啟時機 |
| 事件任務 | 解鎖初階技能的小型事件；可另有可重覆期間限定 | pack 表 |
| 新技能 | 初階主動／被動；頭目解鎖 `the_world` | [`growth-skills.md`](growth-skills.md) §3–4 |
| 客人特別行為 | 教學友好（壓力低） | 修飾器數值 |
| 客人流量／不滿 | 低壓 | 待流量分析 |
| 麻煩客人 | 原則上未登場或極少（正式登場見第1章） | 解鎖表 |
| 店舖／收銀／店員 | 必要三件 → 第二套乾架／補貨 → 兩套凍櫃 4 件；店員不登場（S1 雇員 0） | 與教學 Lesson 對齊 |
| 章末頭目 | 達標服務／生存式教學尖峰 | 階段與通關條件 |
| 期望成長帶 | LV1→6；見 [`growth-character.md`](growth-character.md) §5 | 技能／奧義見 [`growth-skills.md`](growth-skills.md) |

# 劇情／事件內容

- 劇本對話、角色、具體任務文案：**後補**
- 測試占位 pack 形狀見 [`../taskcontent-story-stub.md`](../taskcontent-story-stub.md)（`ST-PROLOGUE-001`）
