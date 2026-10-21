# Alpha v1.0 角色動作與動畫

- 活線：`godot/game`
- 待辦精修／未做項：[`animation-pending.md`](animation-pending.md)
- 需求來源：`docs/alpha/plan.md` 動畫插座；`voxel-v0.1.md`（四向靜態已有、走路動畫未有）

## 管線

1. **靜態物件**（貨架、貨品、污物）：`python3 tools/voxel_sprites.py` ← 讀 `art/src/*.vox`
2. **角色動作**：`python3 tools/voxel_character_anims.py` ← 程序姿勢（不覆寫 `art/src`），寫入  
   `art/sprites/{id}_{anim}_{facing}_{frame}.png` + `anim_manifest.json`
3. 執行期：`scripts/voxel_sprite.gd` → `AnimatedSprite2D`（`Vox.animated` / `Vox.play_anim`）

Facing：`0` 南 · `1` 東 · `2` 北 · `3` 西（與舊 `{id}_{k}.png` 一致）。

## 本輪已接狀態

| 角色 | 狀態 → 動畫 |
| --- | --- |
| player | idle／walk／run／dash／clean／fight／checkout／restock／slip／down |
| customer | idle／walk／angry／leave |
| thief | idle／walk／fight／leave／fly |
| clerk_cashier | idle／walk／checkout |
| clerk_restock | idle／walk／restock |

技能選單／奧義仍用 tint＋UI；持箱仍用 `box_stack` 疊圖。
