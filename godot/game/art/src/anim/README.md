# MagicaVoxel 動作幀覆寫

把完整動作幀放到這裡即可覆寫程序姿／設計師靜態偏移烘焙。

## 檔名合約

```
{id}_{anim}_{facing}_{frame}.vox
```

- `id`：與 `art/src/{id}.vox` 相同（如 `player`、`customer`）
- `anim`：與執行期一致（`idle`、`walk`、`run`、`dash`、`clean`、`fight`…）
- `facing`（十六向）：`0` 南 … `15` 南偏西（22.5°）  
  - **完整十六向：** `0..15` × 每幀都齊 → `full16` 原樣烘焙  
  - **舊八向包：** 僅 `0..7` 齊 → `legacy8`；偶數向對應，奇數半扇自動轉 22.5°  
  - **舊四向包：** 僅 `0..3`（南／東／北／西）齊 → `legacy4`；輸出 0/4/8/12，中間角自動 yaw  
- `frame`：從 `0` 起，張數須與 `tools/voxel_character_anims.py` 裡該 anim 的 frames 數相同

缺檔則該 anim 退回設計師靜態 `.vox`＋肢體偏移（或程序模板），再做十六向旋轉。詳見 `docs/alpha/animation-facing-8way.md`。

## 烘焙

```bash
python3 tools/voxel_sprites.py          # 角色靜態十六向；傢俬四向（anchors 合併）
python3 tools/voxel_character_anims.py  # 動作幀（讀 src + 本目錄）
python3 tools/voxel_alpha_props.py      # 貨架 fill／污物／fx
Godot --headless --path godot/game --import   # 新增面向後必跑，否則半圈空白
```

不覆寫 `art/src/*.vox`。遊玩相機仍是 2D；真 3D 店面見 `docs/alpha/voxel-3d-play-deferred.md`。
