# 主題：安桃山／日本戰國（`theme_historic`）

- `theme_id`：`theme_historic`
- 劇情 pack 前綴：`ST-HISTORIC-###`
- 角色：可選主題（填入 story_slot 3–8）
- 框架總則：[`../../storysystem.md`](../../storysystem.md)
- 專檔：[`../../cookedfoodsystem.md`](../../cookedfoodsystem.md)、[`../../fishingtaro.md`](../../fishingtaro.md)
- 經濟／貨束：[`../growth-economy.md`](../growth-economy.md) §4.2／§7
- **狀態：** 玩法＋id 合約定稿；劇本對話／頭目細則後補

# 概念

此宇宙把店搬回**日本戰國～安土桃山**氛圍（文檔簡稱「安桃山」）。城下町攤販、米醬、鮮魚與熟食檔成為本主題核心營運壓力；財閥影子仍以「官許專賣／特許狀」呈現（敘事腦暴見 `docs/concepts/story-world-narrative-brainstorm.md` V1-C，**本檔產品合約優先**）。

- 進入：選章綁定；首次通關記入 `themes_cleared`
- 解鎖持久：本主題學會／獲得的技能、貨種、傢俬資格、外觀、精英店員等可**跨槽攜帶**
- 首次通關：標記完成；**不**因回訪重發首次解鎖
- 進行中外觀覆寫：一般客人隨機武士／平民／商人造型；小偷用戰國皮；店舖牆／地板改戰國模式（見 §外觀）

# 主線推進條件（形狀）

| 方向 | 說明 |
|------|------|
| 主題主線任務鏈 | `ST-HISTORIC-*` 一次性劇情推進 |
| 新貨種／商店物品導入 | 乾貨 `grain`／`soy_sauce`；熟食三款；`cooked_stall`；釣魚→`fish_tank` |
| 能力推進事件 | 解鎖本主題技能（既定：`shelf_sniper` `must_deliver` `magneto`） |
| 精英店員 | 通關或主線節點獲得（`yayoi`／彌生；詳 [`../../eliteclerk.md`](../../eliteclerk.md)／`elite_clerk_catalog.gd`） |
| 資金／評價等達標 | 閾值跟當前 story_slot 節奏（growth-economy） |
| 主題末頭目 | 首次通關解鎖奧義 `fundraise` |

# 鎖定 id 總表

## 貨類

| 顯示 | `category` id | 備註 |
|------|---------------|------|
| 乾貨 | `dry` | 既有；本主題加 `grain`／`soy_sauce` |
| 凍櫃 | `frozen` | 既有 |
| 冰櫃 | `ice` | 既有；**`rice`＝叮叮飯，不變** |
| 熟食 | `cooked` | **本主題新類**；不可採購直入倉，只經熟食檔加工產出 |

## 可售 SKU

| 顯示名 | `sku_id` | 貨類 | 入手 |
|--------|----------|------|------|
| 米 | `grain` | `dry` | 開發後採購入乾貨倉（**勿**與冰櫃 `rice` 叮叮飯混淆） |
| 醬油 | `soy_sauce` | `dry` | 同上 |
| 飯團 | `onigiri` | `cooked` | 僅熟食檔配方產出 |
| 烤年糕 | `yakimochi` | `cooked` | 同上 |
| 手握壽司 | `nigiri` | `cooked` | 同上；魚種不拆分客人需求 |

## 魚材（不可售；非 `sellable`）

| 顯示名 | `fish_id` | 來源 |
|--------|-----------|------|
| 鯖魚 | `saba` | 小遊戲「釣魚太郎」 |
| 鯛魚 | `tai` | 同上 |
| 秋刀魚 | `sanma` | 同上 |
| 竹筴魚 | `aji` | 同上 |
| 香魚 | `ayu` | 同上 |

存檔鍵建議：`fish_stock: Dictionary`（`fish_id` → 件數）。**不**進客人購物清單池。

## 商店物品

| 顯示名 | `furniture` id | 取得 |
|--------|----------------|------|
| 熟食檔攤 | `cooked_stall` | 主題任務發購入資格後付資金（見 shopitem） |
| 魚缸 | `fish_tank` | 遊玩過釣魚太郎後**自動授予** `owned`（零資金；類似事件授予） |

## 小遊戲／Prep

| 顯示 | id | 入口 |
|------|-----|------|
| 釣魚太郎 | `fishing_taro` | Prep → 小遊戲 hub；詳 [`../../fishingtaro.md`](../../fishingtaro.md) |
| 魚缸欣賞頁 | `fish_tank_gallery` | Prep（擁有 `fish_tank` 後）；顯示各魚數量＋缸內展示 |

## 外觀／場所覆寫（主題進行中）

| 用途 | id |
|------|-----|
| 一般客人（武士／平民／商人） | `customer_sengoku_samurai`／`customer_sengoku_civilian`／`customer_sengoku_merchant` |
| 小偷 | `thief_sengoku` |
| 地板／牆 | `floor_tile_sengoku`／`wall_sengoku` |
| 主角外觀（首次通關或節點獎） | `player_sengoku`（半纏／短袴；tint＝藩色） |

- 一般客人三外觀**隨機抽**；急／慢／常只改行速，**不**另 bake mesh。
- 缺 bake／anim 時 fallback：`customer`／`thief`／`floor_tile`／`wall`。
- 門沿用既有 `door`；SKU／傢俬造型不隨主題換。

# 主題元素槽位

| 槽位 | 定稿內容 | 參照 |
|------|----------|------|
| 主題方向 | 安桃山／戰國城下町便利店 | 本檔 |
| 新貨品／SKU | `grain` `soy_sauce` `onigiri` `yakimochi` `nigiri`＋五魚材 | growth-economy §4.2；cookedfoodsystem |
| 商店物品 | `cooked_stall` `fish_tank` | shopitem |
| 事件任務 | 劇情向＋可重覆期間限定（後補 pack 表） | taskcontent-story-stub |
| 新技能 | `shelf_sniper` `must_deliver` `magneto` | growth-skills |
| 奧義 | `fundraise` | growth-skills §4 |
| 精英店員 | 本主題主導（暫名彌生） | eliteclerk.md |
| 小遊戲 | `fishing_taro` | fishingtaro.md |
| 主角外觀 | `player_sengoku` | appearance.md |
| 客人特別行為 | 熟食檔排隊點餐；武士催促可作事件修飾（後補） | cookedfoodsystem |
| 客人流量／不滿 | 跟 slot 深度；熟食等待延長不滿曲線（專檔） | — |
| 麻煩客人 | 最高 LV 跟**當前 story_slot** | progression-crossref §6 |
| 店舖／收銀／店員 | 牆地板覆寫；熟食檔需玩家操作（雇員暫不代做） | — |
| 主題末頭目 | 巡查使／特許採購團（敘事）；通關條件後補 | — |
| 期望成長帶 | 跟填入的 story_slot 深度 | growth-character §5 |

# 解鎖節點（建議；任務文案後補）

| 順序 | 任務／節點（示意） | 發放 |
|------|-------------------|------|
| H1 | 進入主題／開場任務 | `grain` `soy_sauce` 可開發資格；乾線仍用既有 `restock_dry`／`shelf_dry_*` |
| H2 | 建檔教學 | `cooked_stall` 可購入；`onigiri`／`yakimochi`／`nigiri` 配方解鎖（`developed` 熟食＝「已學會可售／可加工」，**無採購列**） |
| H3 | 初訪河邊 | Prep 解鎖 `fishing_taro`；首次退出小遊戲後授予 `fish_tank`＋`fish_tank_gallery` |
| H4 | 賣出 N 件熟食／營收帶 | 事件獎技能之一 |
| H5 | 主題頭目 | 奧義 `fundraise`；可選 `player_sengoku` |

凍櫃 `spoil_unshelved` 正式痛仍可與本主題並行（growth-economy 既定）；本檔不綁定必須先開 spoil。

# 劇情／事件內容

- 劇本對話、角色名定稿、具體任務文案、頭目回合規則：**後補**（pack `ST-HISTORIC-###`）
- 玩法系統合約以 `cookedfoodsystem.md`／`fishingtaro.md` 為準
