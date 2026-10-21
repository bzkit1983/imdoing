# Alpha V0.1　Voxel 初模

這是美術的第一刀，也是能玩的一版。玩法跟 Demo v0.6 一樣：準備、擺店、開店、收銀、清潔、小偷。畫面換成 Voxel。

> **凍結：** `godot/alpha_v0_1` 不再接受新功能。v1 美術與玩法請改 **`godot/game`**（見 `docs/versioning.md`、`godot/README.md`）。以下步驟保留作 Alpha 歷史說明；烘焙腳本預設已指向 `godot/game`。

Demo v0.6 那個專案沒有改。要重播 Alpha，用 Godot 4.7 打開 `godot/alpha_v0_1`，直接按播放。手機可開 https://bzkit1983.github.io/imdoing/play-alpha-v01/ 。操作和 Demo 相同。

`docs/alpha/plan.md` 寫的是系統做完才把 Voxel 渲成精靈。V0.1 先做模型本身，那份計劃的玩法數字這裡不用。

# 設計師怎樣改

1. 用 MagicaVoxel 打開 `godot/alpha_v0_1/art/src/` 裡的 `.vox`。一個物件一個檔，檔名就是 id。
2. 在原來的外框裡加細節、改形狀、改顏色。腳底保持貼著 z = 0，角色繼續面向 +Y。
3. 不要改檔名。遊戲和預覽都靠檔名找模型。
4. 改完跑 `python3 tools/voxel_sprites.py`。它只更新遊戲裡的圖，不改 `.vox`。
5. 再開 `godot/alpha_v0_1` 按播放看店裡的大小。模型總覽仍是 `scenes/preview.tscn`。
6. 不要再跑 `tools/voxel_blockout.py`。那個腳本會把 `art/src` 蓋回這套初模。

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

# 怎麼玩

主場景是 `scenes/demo.tscn`。專案一打開就是店舖。

人物和會轉向的傢俬有四個方向。走路還沒有動畫，轉向時換那一面的圖。貨架上有貨時，會再顯示該貨品的小模型。

模型總覽仍可開 `scenes/preview.tscn`。左鍵拖動旋轉，滾輪拉近。

# 這版不做

- 走路動畫、被打飛的另一套模型
- 改成 3D 鏡頭遊玩。店仍是俯瞰，Voxel 畫在原來的位置上
- 吸貨、金幣、時停那些特效
- 同一種貨架做成四個長度
- 水漬的透明
