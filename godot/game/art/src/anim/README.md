# MagicaVoxel 動作幀覆寫

把完整動作幀放到這裡即可覆寫程序姿／設計師靜態偏移烘焙。

## 檔名合約

```
{id}_{anim}_{facing}_{frame}.vox
```

- `id`：與 `art/src/{id}.vox` 相同（如 `player`、`customer`）
- `anim`：與執行期一致（`idle`、`walk`、`run`、`dash`、`clean`、`fight`…）
- `facing`：`0` 南 · `1` 東 · `2` 北 · `3` 西
- `frame`：從 `0` 起，張數須與 `tools/voxel_character_anims.py` 裡該 anim 的 frames 數相同

某一角色某一 anim **四向×每幀** 檔都齊，烘焙才會走 MagicaVoxel 幀路徑；缺一幀則整段 anim 退回設計師靜態 `.vox`＋肢體偏移（或程序模板）。

## 烘焙

```bash
python3 tools/voxel_sprites.py          # 靜態物件／角色四向
python3 tools/voxel_character_anims.py  # 動作幀（讀 src + 本目錄）
```

不覆寫 `art/src/*.vox`。遊玩相機仍是 2D；真 3D 店面見 `docs/alpha/voxel-3d-play-deferred.md`。
