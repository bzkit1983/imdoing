# Alpha v1.0 角色動作與動畫

- 活線：`godot/game`
- 待辦精修／未做項：[`animation-pending.md`](animation-pending.md)
- 需求來源：`docs/alpha/plan.md` 動畫插座；`voxel-v0.1.md`（四向靜態已有、走路動畫未有）

## 管線

1. **靜態物件**（貨架、貨品、污物）：`python3 tools/voxel_sprites.py` ← 讀 `art/src/*.vox`
2. **角色動作**：`python3 tools/voxel_character_anims.py`（不覆寫 `art/src`），寫入  
   `art/sprites/{id}_{anim}_{facing}_{frame}.png` + `anim_manifest.json`  
   - 有 `art/src/{id}.vox` → 以設計師模型為底，再套共用肢體區偏移  
   - 無設計師檔 → 程序 12×10×20 模板（高解析人物包絡見 [`voxel-hires-scale-plan.md`](voxel-hires-scale-plan.md)：基準 **90×40×130**；刀 1 接線前仍用現行低解析）  
   - 可選完整幀覆寫：`art/src/anim/{id}_{anim}_{facing}_{frame}.vox`（見該目錄 README）
3. **貨架填滿／污物清潔／特效**：`python3 tools/voxel_alpha_props.py` ← Alpha 表現用；寫入  
   `shelf_*_fill_*`、`*_clean_*`、`fx_*` + `props_manifest.json`
4. 執行期：`scripts/voxel_sprite.gd` → `AnimatedSprite2D`（`Vox.animated` / `Vox.play_anim`）；特效 `scripts/fx_burst.gd`

遊玩仍是俯瞰 2D；真 3D 店／Skeleton3D 見 [`voxel-3d-play-deferred.md`](voxel-3d-play-deferred.md)。

**角色 Facing（十六向）：** `0` 南 … `15` 南偏西（22.5°；偶數 = 舊八向）。轉身交叉淡入已關；面向滯後見 [`animation-facing-8way.md`](animation-facing-8way.md)。貨架／傢俬仍四向。

## 本輪已接狀態

| 角色 | 狀態 → 動畫 |
| --- | --- |
| player | idle／walk／walk_carry／run／dash／clean／fight／checkout／restock／slip／down／cast／deliver |
| customer | idle／walk／angry／leave（含 hurry／slow 三模型） |
| thief | idle／walk／fight／leave／fly |
| clerk_cashier | idle／walk／walk_carry／checkout |
| clerk_restock | idle／walk／walk_carry／restock |

| 物件／特效 | 接線 |
| --- | --- |
| shelf_* | `fill_0`…`fill_3` 依庫存比例換身（SKU 小圖仍疊加） |
| trash／puddle／vomit | 清潔中切 `*_clean_0..2`＋透明度 |
| fx | suck（執貨）／spray（上架）／coin（收銀）／combo／timestop（奧義）／clean_spark／skid |

技能選單仍用 tint＋UI；持箱仍用 `box_stack` 疊圖（店員持箱另播 `walk_carry`）。設計師之後用 MagicaVoxel 覆寫同名 PNG 即可，不必改腳本。
