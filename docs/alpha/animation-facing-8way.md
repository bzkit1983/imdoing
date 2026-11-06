# 角色八向面向＋轉身短淡入

- **狀態：** 活線試行（`godot/game`）
- **對照：** [`animation-v1.0.md`](animation-v1.0.md)、[`animation-pending.md`](animation-pending.md)、[`voxel-3d-play-deferred.md`](voxel-3d-play-deferred.md)

## 決議

| 項目 | 決定 |
| --- | --- |
| 角色面向 | **八向**（南、東南、東、東北、北、西北、西、西南） |
| 轉身表現 | 換向約 **90ms** 舊幀交叉淡出；面向差 ≥2 時再疊一幀中間向幽靈（約 120ms） |
| 貨架／傢俬 | 維持 **四向**（放置旋轉仍是 90°） |
| 特效 | `fx_burst` 世界座標生成；可傳 facing 做朝向＋短拖影 |
| 圖集 | 角色 `SpriteFrames` 載入時打成單張圖集（執行期打包） |
| 十六向 | 本輪不做；八向驗證後再評估 |
| 真 3D 店／連續水平角 | 仍見延後文件（含角色子視口後備）；不與本輪綁死 |

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
python3 tools/voxel_sprites.py          # 角色靜態八向；傢俬仍四向
python3 tools/voxel_character_anims.py  # 動作 × 八向
```

斜向由同一 `.vox`／姿勢網格做 45° 水平旋轉後渲成 PNG（非手繪）。

### MagicaVoxel 覆寫（`art/src/anim/`）

1. **完整八向：** `{id}_{anim}_{0..7}_{frame}.vox` 齊 → 原樣烘焙  
2. **舊四向包：** 僅 `0..3`（南東西北）齊 → 對應輸出偶數向；奇數斜向由上一正東方再轉 45°  
3. 缺檔則退回設計師靜態 `.vox`＋肢體偏移（或程序模板）再八向旋轉

## 不做

- 不把 Skeleton3D 嵌進 2D 主循環  
- 不為動畫再開 Godot 專案複本  
- 不把本輪做成「必須上立體相機」  
