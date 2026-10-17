# Alpha V0.1　Voxel 初模

這是美術的第一刀。把現有 2D 色塊的人物和物件做成 3D Voxel，給之後的設計在同一套尺寸上加細節。

不改玩法，也不接進 Demo v0.6 的經營回合。Demo 仍是俯瞰 2D。

`docs/alpha/plan.md` 寫的是系統做完才把 Voxel 渲成精靈。V0.1 先做模型本身，那份計劃的玩法數字這裡不用。

# 設計師怎樣改

1. 用 MagicaVoxel 打開 `godot/alpha_v0_1/art/src/` 裡的 `.vox`。一個物件一個檔，檔名就是 id。
2. 在原來的外框裡加細節、改形狀、改顏色。腳底保持貼著 z = 0，角色繼續面向 +Y。
3. 不要改檔名。遊戲和預覽都靠檔名找模型。
4. 改完直接開 Godot 專案 `godot/alpha_v0_1` 看整套。預覽讀的是 `.vox`，不用先輸出圖。
5. 不要再跑 `tools/voxel_blockout.py`。那個腳本會把 `art/src` 蓋回這套初模。

新物件先在 `art/catalog.json` 加一筆，再加同名 `.vox`。不要改已經在用的 id。

# 座標和尺寸

MagicaVoxel 裡：X 向右，Y 向前，Z 向上。

- 角色都是 12 × 10 × 20。腳在 z = 0，臉朝 +Y。五個人用同一副骨架，方便之後做走路。
- 1 格店面 = 16 voxel。貨架佔 2 × 1 格，所以是 32 × 16。
- 預覽裡 1 voxel = 0.1。角色大約 2 單位高。
- Godot 把 Z 上轉成 Y 上。面向 +Y 的模型，在預覽裡朝向鏡頭的前方。

4、8、12、24 件是容量，不是四個長度。這版每種貨架只有一個外框。

# 這版有什麼

清單和每件的備註在 `godot/alpha_v0_1/art/catalog.json`。一張總覽在 `godot/alpha_v0_1/art/preview/sheet.png`。

| 組 | id |
| --- | --- |
| 人物 | `player` 玩家、`customer` 客人、`thief` 小偷、`clerk_cashier` 收銀店員、`clerk_restock` 補貨店員 |
| 店內物件 | `register` 收銀機、`restock_dry`／`restock_frozen`／`restock_ice` 三種補貨架、`shelf_dry`／`shelf_frozen`／`shelf_ice` 三種貨架 |
| 貨品 | `box` 貨箱，以及罐頭、零食、杯麵、支裝凍飲、牛奶、汽水、雪糕、凍肉、叮叮飯 |
| 地面與污物 | `floor_tile` 地磚、`wall` 牆、`door` 店門、`trash` 垃圾、`puddle` 水漬、`vomit` 嘔吐物 |

色盤在 catalog 的 `palette`。初模用這些 index 上色。改某一格的顏色可以，先不要把 index 拿去表示別的東西。

小偷靠兜帽和面罩跟客人分開。收銀店員有白牌，補貨店員沒有。乾貨架是開架，凍櫃前面有玻璃框，冰櫃有頂蓋。

# 預覽

用 Godot 4.7 打開 `godot/alpha_v0_1`，播放 `scenes/preview.tscn`。

左鍵拖動畫旋轉，滾輪拉近。中文名用系統的蘋方。

# 這版不做

- 走路、四個方向、被打飛
- 把模型接進 Demo 經營回合，或改成 3D 遊玩
- 吸貨、金幣、時停那些特效
- 同一種貨架做成四個長度
- 水漬的透明
