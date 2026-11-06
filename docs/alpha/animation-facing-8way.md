# 角色八向面向＋轉身短淡入

- **狀態：** 活線試行（`godot/game`）
- **對照：** [`animation-v1.0.md`](animation-v1.0.md)、[`animation-pending.md`](animation-pending.md)、[`voxel-3d-play-deferred.md`](voxel-3d-play-deferred.md)

## 決議

| 項目 | 決定 |
| --- | --- |
| 角色面向 | **八向**（南、東南、東、東北、北、西北、西、西南） |
| 轉身表現 | 八向帶滯後避免搖桿邊界閃向；**交叉淡入已關**（實測換向時殘影造成消失／錯向） |
| 貨架／傢俬 | 維持 **四向**（放置旋轉仍是 90°） |
| 十六向 | 本輪不做；八向驗證後再評估 |
| 真 3D 店／連續水平角 | 仍見延後文件；不與本輪綁死 |

## 面向合約

| 指數 | 方向 | 舊四向對應 |
| --- | --- | --- |
| 0 | 南 | 0 |
| 1 | 東南 | （新建，斜向） |
| 2 | 東 | 1 |
| 3 | 東北 | （新建） |
| 4 | 北 | 2 |
| 5 | 西北 | （新建） |
| 6 | 西 | 3 |
| 7 | 西南 | （新建） |

檔名仍為 `{id}_{anim}_{facing}_{frame}.png`。`anim_manifest.json`：`version` ≥ 3，`facings: 8`，`facing: ["s","se","e","ne","n","nw","w","sw"]`。

執行期：`Vox.k_from_facing(v)` 預設八分位；傢俬傳 `k_from_facing(v, 4)`。

## 烘焙

```bash
python3 tools/voxel_sprites.py          # 角色靜態八向；傢俬仍四向（合併寫入 anchors，不整檔覆寫）
python3 tools/voxel_character_anims.py  # 動作 × 八向
python3 tools/voxel_alpha_props.py      # 貨架 fill／污物／fx 錨點；須在靜態 bake 之後跑，或保留既有 keys
```

斜向由同一 `.vox`／姿勢網格做 45° 水平旋轉後渲成 PNG（非手繪）。

### MagicaVoxel 覆寫（`art/src/anim/`）

1. **完整八向：** `{id}_{anim}_{0..7}_{frame}.vox` 齊 → 原樣烘焙  
2. **舊四向包：** 僅 `0..3`（南東西北）齊 → 對應輸出偶數向；奇數斜向由上一正東方再轉 45°  
3. 缺檔則退回設計師靜態 `.vox`＋肢體偏移（或程序模板）再八向旋轉

## 實測坑（升十六向必讀）

八向上線後曾出現「角色移動時消失／面向像反了」。根因與修法如下；**十六向加檔後用同一檢查清單**，避免只在半圈方向空白。

| 現象 | 原因 | 解法／防再發 |
| --- | --- | --- |
| 往北／西／對角走時精靈空白，往南／東正常 | PNG 與 `.import` 已有，但 `.godot/imported/*.ctex` 未生成；`ResourceLoader.exists` 仍為 true，`load()` 回 null，`SpriteFrames` 仍 `add_frame` → 播該向時整隻消失 | 新增面向／重 bake 後跑 Godot 匯入（編輯器開專案或 `--headless --import`）。`voxel_sprite.gd` 已拒收 null texture，並退回靜態／近正東向 |
| 店員／顧客面向卡住或與速度不一致 | 外層用 **raw** `k_from_facing` 閘 `_shown_anim`，內層 `play_anim` 用 **stable** 滯後 → 閘值超前，之後跳過更新 | 閘與播放必須用同一套 `k_from_facing_stable`（player／clerk／customer／shadow 皆然） |
| 換向殘影蓋住本體、短暫消失 | 轉身交叉淡入（舊幀 Sprite2D）在快速八向切換時疊層／透明度異常 | **交叉淡入維持關閉**；十六向若再試淡入，先單角色壓測高速轉圈 |
| 貨架 fill／污物錨點整批消失 | `voxel_sprites.py` 整檔覆寫 `anchors.json`，洗掉 `voxel_alpha_props` 的 key | 靜態 bake **合併**寫入 anchors；alpha props 在靜態之後跑，或保留既有 keys |
| （已否決）走路 L/R 再鏡射面向 | 試圖用 `(8-k)%8` 修「錯向」，實測把西播成東 | **禁止**對 locomotion 做水平面向 remap；合約指數與 `atan2(x,y)` 對齊即可 |

### 十六向檢查清單

1. Bake 出 `{id}_{anim}_{0..15}_{frame}.png` 後，確認每個新 facing 的 `.ctex` 存在（或開一次編輯器完成 import）。  
2. `anim_manifest.json` 的 `facings`／`facing` 名稱與檔名指數一致後再跑遊戲。  
3. 用 debug／目視繞一圈：每一向 `get_frame_texture` 非 null、寬高 > 0。  
4. 所有角色視覺閘（含 NPC）與 `Vox.play_anim` 共用同一 facing 函式，勿 raw／stable 混用。  
5. 勿重新打開面向交叉淡入，除非有獨立壓測證明無殘影。  
6. 重跑 `voxel_sprites.py` 後抽查 `anchors.json` 仍含貨架 fill／dirt／fx keys。

## 不做

- 不把 Skeleton3D 嵌進 2D 主循環  
- 不為動畫再開 Godot 專案複本  
- 不把本輪做成「必須上立體相機」  
