# 中期美術（v1.5.0）

- 狀態：測試期可讀、可整套換皮。這一版不是最終美術定案。
- 工程活線：`godot/game`。高解析度合約見 `docs/alpha/voxel-hires-scale-plan.md`。貨品圖示契約見 `ops-sku-icon-ui.md`。
- 產品字串：`v1.5.0`。**發佈當時**存檔格式不升（`SAVE_VERSION` 維持 4）。Git tag `v1.5.0` 已打在 `main`；功能分支本身不打 tag。其後存檔已升至 **`SAVE_VERSION` 9**（與本中期美術錨點分開；見 [`savesystem.md`](savesystem.md)、[`versioning.md`](../versioning.md)）。

## 範圍

重做非玩家模型、補貨架高度、貨品與技能小圖示、準備回合每一頁的排版與配色，以及地板、牆、三種污物。

保持不動：

- 玩家四套造型（`player`、`player_alt1`、`player_alt2`、`player_alt3`）。`player_alt3`（玩家·學生）是密度與剪影基準。
- `GameState.CELL = 64`、傢俬佔格、角色碰撞 26×26、店員碰撞 22×22。
- 技能數值、距離、COST、施放路徑。
- 店門（`door`）。

## 體素

- 軸向：Magica X 右、Y 前、Z 上。腳在 z=0。角色臉朝 +Y。
- 非玩家角色對齊 `player_alt3` 的 Q 版：頭約佔身高四成、身子短、雙手平伸。玩家四套造型不改。
- 角色包絡 **90×40×130**。走路仍用 `tools/voxel_character_anims.py` 的肢體分區（由 12×10×20 按 `sx/12`、`sz/20` 放大）。手、腳必須落在分區裡。
- 烘圖：`PX=1`，再 `DISPLAY_SCALE=0.5`，outline_only（墨線、無 RGB 階調）。角色螢幕寬維持約 45px。
- 調色盤用 `godot/game/art/catalog.json`。客人、小偷、收銀員、補貨員靠服裝剪影分開。
- `customer_hurry`、`customer_slow` 沿用客人網格，只換衣色。
- 貨架包絡維持 **256×128×144**。容量 4／8／12／24 共用同一座模型。
- 補貨架包絡 **256×96×144**。Z 與貨架同為 144。X 與貨架同寬，讓 `Vox.fit` 進 2×2 格時縮放約為 1，畫面上的高度才不會高過貨架。佔格與碰撞仍是 2×2。乾貨、凍飲、冰品只差箱色。
- 地板一格 **128×128×8**。淨色加磚縫，不加棋盤或磨損點；鋪滿後仍是一格 `CELL`。
- 牆段 **128×16×128**。踢腳線與分縫可讀；佔格與門洞邏輯不變。
- 污物：垃圾 **112×96×48**、水漬 **128×112×8**、嘔吐物 **112×96×16**。清潔淡出幀跟同一座模型縮減，不再用 10³ 小塊。

生成腳本：`tools/voxel_interim_v15.py`（寫入 `godot/game/art/src/`，不跑會覆寫全庫的 `voxel_blockout.py`）。

## 圖示

- 九種貨的世界模型、UI 小圖、貨架正面圖是同一正面剪影。UI 圖由該貨的體素正面最近鄰縮成 `godot/game/art/ui/sku/<id>.png`（64×64）。貨架正面與清單走 `SkuIcons.texture`。架上的貨是同一座模型縮小，不是色塊。
- 邏輯顯示仍約 28–32px。缺檔才退回程式剪影。高亮用外框，不用 `modulate` 改圖本色。
- 九種貨必須在 28px、去色後兩兩可分。零食是軟袋鋸齒封口，牛奶是屋脊紙盒加倒出口。
- 技能臨時圖：`godot/game/art/ui/skill/<id>.png`。圓形選單、觸控鍵、右下 HUD、準備回合技能列共用。
- 營運右下技能 HUD：每列「技能圖｜技能名稱」（不顯示就緒／CD 秒數）。主動可放時圖亮、CD 中變暗並以 360° 掃回原色；有效期間外圍閃金框並隨剩餘時間變短。被動恆亮並閃金框表示常駐發動中。
- 準備主畫面圖塊：`godot/game/art/ui/prep/<id>.png`。
- 圖內不寫字。檔名用 id。

## 準備回合

殼層仍是 `prep_menu.tscn`。頁面 id、流程、教學鎖、手掣與鍵盤操作不變。

版心：頂列標題、其下說明（右側留給返回）、中段內容、底部動作。間距 8px。列表、說明、數量、店舖設計的尺寸列與地圖各佔一塊，不相交。720 高度內不裁切。

**目標配色**跟全遊戲 Cozy 母本 [`imdoing-pause-ui-chrome.md`](../../agents/skills/pause-ui-chrome/imdoing-pause-ui-chrome.md)（奶油／羊皮／沙邊／暖金 Focus）；現行 `prep_widgets.gd` 深底＋金屬過渡佔位，遷移時唔再開新色票。卡片、焦點環、列表選取收在 `prep_widgets.gd`。

## 美術放置驗收清單

工程只驗契約、不摆店。放置／換皮由美術成員完成後，用本清單對過再合併。

### 檔名與目錄

- [ ] 體素源檔在 `godot/game/art/src/`，id 對齊 [`art/catalog.json`](../../godot/game/art/catalog.json)
- [ ] SKU UI：`godot/game/art/ui/sku/<id>.png`（64×64）；技能：`art/ui/skill/<id>.png`；準備圖塊：`art/ui/prep/<id>.png`
- [ ] 圖內不寫字；檔名用 id（不用中文檔名）
- [ ] 生成用 `tools/voxel_interim_v15.py`；**勿**跑會覆寫全庫的 `voxel_blockout.py`

### 匯入與顯示

- [ ] 貼圖 Filter＝**Nearest**（硬邊；勿開模糊過濾）
- [ ] 角色腳底對準節點原點；臉朝 +Y（Magica 軸向：X 右、Y 前、Z 上）
- [ ] 烘圖：`PX=1` + `DISPLAY_SCALE=0.5`，outline_only；角色螢幕寬約 45px
- [ ] 缺檔時遊戲可退回程式剪影；有檔則世界／UI／貨架正面為同一剪影

### 包絡（不可破）

- [ ] 非玩家角色包絡 **90×40×130**（對齊 `player_alt3` Q 版密度）
- [ ] 貨架 **256×128×144**；補貨架 **256×96×144**（Z 與貨架同高）
- [ ] 地板格 **128×128×8**；牆段 **128×16×128**
- [ ] 污物：垃圾 **112×96×48**、水漬 **128×112×8**、嘔吐物 **112×96×16**

### 禁止改動（玩法凍結）

- [ ] 玩家四套 Look（`player`／`player_alt1`／`player_alt2`／`player_alt3`）不改
- [ ] `GameState.CELL = 64`、傢俬佔格、角色碰撞 26×26、店員 22×22 不改
- [ ] 技能數值、距離、COST、施放路徑不改
- [ ] 店門（`door`）不改

### 預覽

- [ ] 用 `scenes/preview.tscn` 或 `art/preview/` 對過大小與腳底
- [ ] 九種貨在約 28px、去色後兩兩可分
- [ ] 客人／小偷／收銀員／補貨員靠服裝剪影可分（不只靠改色）
