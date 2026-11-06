# 角色十六向面向

- **狀態：** 活線試行（`godot/game`）
- **對照：** [`animation-v1.0.md`](animation-v1.0.md)、[`animation-pending.md`](animation-pending.md)、[`voxel-3d-play-deferred.md`](voxel-3d-play-deferred.md)

## 決議

| 項目 | 決定 |
| --- | --- |
| 角色面向 | **十六向**（22.5°：南 → 南偏西） |
| 轉身表現 | 面向滯後避免搖桿邊界閃向；**交叉淡入已關**（實測換向時殘影造成消失／錯向） |
| 貨架／傢俬 | 維持 **四向**（放置旋轉仍是 90°） |
| 八向 | 已由十六向取代（舊偶數指數 = 原八向） |
| 真 3D 店／連續水平角 | 仍見延後文件；不與本輪綁死 |

## 面向合約

| 指數 | 名稱 | 舊八向 |
| --- | --- | --- |
| 0 | 南 `s` | 0 |
| 1 | 南偏東 `sse` | （新建） |
| 2 | 東南 `se` | 1 |
| 3 | 東偏南 `ese` | （新建） |
| 4 | 東 `e` | 2 |
| 5 | 東偏北 `ene` | （新建） |
| 6 | 東北 `ne` | 3 |
| 7 | 北偏東 `nne` | （新建） |
| 8 | 北 `n` | 4 |
| 9 | 北偏西 `nnw` | （新建） |
| 10 | 西北 `nw` | 5 |
| 11 | 西偏北 `wnw` | （新建） |
| 12 | 西 `w` | 6 |
| 13 | 西偏南 `wsw` | （新建） |
| 14 | 西南 `sw` | 7 |
| 15 | 南偏西 `ssw` | （新建） |

檔名仍為 `{id}_{anim}_{facing}_{frame}.png`。`anim_manifest.json`：`version` ≥ 4，`facings: 16`，`facing: ["s","sse","se","ese","e","ene","ne","nne","n","nnw","nw","wnw","w","wsw","sw","ssw"]`。

執行期：`Vox.k_from_facing(v)` 讀 manifest 八／十六分位；傢俬傳 `k_from_facing(v, 4)`。Cardinal fallback stride = `facing_count()/4`（十六向 → 4）。

## 烘焙

```bash
python3 tools/voxel_sprites.py          # 角色靜態十六向；傢俬仍四向（合併寫入 anchors，不整檔覆寫）
python3 tools/voxel_character_anims.py  # 動作 × 十六向
python3 tools/voxel_alpha_props.py      # 貨架 fill／污物／fx 錨點；須在靜態 bake 之後跑，或保留既有 keys
# 新增面向後必跑，否則半圈方向空白（缺 .ctex）：
Godot --headless --path godot/game --import
```

斜向由同一 `.vox`／姿勢網格做 22.5° 水平旋轉後渲成 PNG（非手繪）。

### MagicaVoxel 覆寫（`art/src/anim/`）

1. **完整十六向：** `{id}_{anim}_{0..15}_{frame}.vox` 齊 → `full16` 原樣烘焙  
2. **舊八向包：** 僅 `0..7` 齊 → `legacy8`：偶數向對應；奇數半扇由上一向再轉 22.5°  
3. **舊四向包：** 僅 `0..3`（南東西北）齊 → `legacy4`：輸出 0/4/8/12，中間角自動 yaw  
4. 缺檔則退回設計師靜態 `.vox`＋肢體偏移（或程序模板）再十六向旋轉

## 實測坑（升面向數必讀）

八向上線後曾出現「角色移動時消失／面向像反了」。根因與修法如下；**再加面向（或重 bake）用同一檢查清單**，避免只在半圈方向空白。

| 現象 | 原因 | 解法／防再發 |
| --- | --- | --- |
| 往北／西／對角走時精靈空白，往南／東正常 | PNG 與 `.import` 已有，但 `.godot/imported/*.ctex` 未生成；`ResourceLoader.exists` 仍為 true，`load()` 回 null，`SpriteFrames` 仍 `add_frame` → 播該向時整隻消失 | 新增面向／重 bake 後跑 Godot 匯入（編輯器開專案或 `--headless --import`）。`voxel_sprite.gd` 已拒收 null texture，並退回靜態／近正東向 |
| 店員／顧客面向卡住或與速度不一致 | 外層用 **raw** `k_from_facing` 閘 `_shown_anim`，內層 `play_anim` 用 **stable** 滯後 → 閘值超前，之後跳過更新 | 閘與播放必須用同一套 `k_from_facing_stable`（player／clerk／customer／shadow 皆然） |
| 換向殘影蓋住本體、短暫消失 | 轉身交叉淡入（舊幀 Sprite2D）在快速切換時疊層／透明度異常 | **交叉淡入維持關閉**；若再試淡入，先單角色壓測高速轉圈 |
| 貨架 fill／污物錨點整批消失 | `voxel_sprites.py` 整檔覆寫 `anchors.json`，洗掉 `voxel_alpha_props` 的 key | 靜態 bake **合併**寫入 anchors；alpha props 在靜態之後跑，或保留既有 keys |
| （已否決）走路 L/R 再鏡射面向 | 試圖用 `(n-k)%n` 修「錯向」，實測把西播成東 | **禁止**對 locomotion 做水平面向 remap；合約指數與 `atan2(x,y)` 對齊即可 |

### 檢查清單

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
