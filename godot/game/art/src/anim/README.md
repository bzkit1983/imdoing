# MagicaVoxel 動作幀覆寫

把完整動作幀放到這裡即可覆寫程序姿／設計師靜態偏移烘焙。

## 檔名合約

```
{id}_{anim}_{facing}_{frame}.vox
```

- `id`：與 `art/src/{id}.vox` 相同（如 `player`、`customer`）
- `anim`：與執行期一致（`idle`、`walk`、`run`、`dash`、`clean`、`fight`…）
- `facing`（八向）：`0` 南 · `1` 東南 · `2` 東 · `3` 東北 · `4` 北 · `5` 西北 · `6` 西 · `7` 西南  
  - **完整八向：** `0..7` × 每幀都齊 → 原樣烘焙  
  - **舊四向包：** 僅 `0..3`（南／東／北／西）齊亦可；對應輸出偶數向，斜向由烘焙自動轉 45°  
- `frame`：從 `0` 起，張數須與 `tools/voxel_character_anims.py` 裡該 anim 的 frames 數相同

缺檔則該 anim 退回設計師靜態 `.vox`＋肢體偏移（或程序模板），再做八向旋轉。詳見 `docs/alpha/animation-facing-8way.md`。

## 烘焙

```bash
python3 tools/voxel_sprites.py          # 角色靜態八向；傢俬四向
python3 tools/voxel_character_anims.py  # 動作幀（讀 src + 本目錄）
```

不覆寫 `art/src/*.vox`。遊玩相機仍是 2D；真 3D 店面見 `docs/alpha/voxel-3d-play-deferred.md`。
