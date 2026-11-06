# 真 3D 遊玩相機／Skeleton3D — 延後里程碑

- **狀態：** 產品未拍板前 **不做**
- **活線：** `godot/game`
- **對照：** [`voxel-v0.1.md`](voxel-v0.1.md)、[`animation-v1.0.md`](animation-v1.0.md)、[`tech-review-v0.1.md`](tech-review-v0.1.md)

## 決議

| 項目 | 決定 |
| --- | --- |
| 遊玩相機 | 維持俯瞰 **Camera2D** + `CharacterBody2D` |
| 美術源 | MagicaVoxel `.vox` → 烘焙 PNG／幀序列 |
| 執行期角色 | `AnimatedSprite2D`（`voxel_sprite.gd`） |
| 真 3D mesh | 僅 [`preview.tscn`](../../godot/game/scenes/preview.tscn) + `vox_mesh.gd` 作 QA |
| Skeleton3D／AnimationPlayer 骨骼 | **不**嵌入現行 2D loop |
| 與動作升級關係 | **解綁** — 幀動作／設計師 `.vox` 對齊可獨立交付 |

Alpha V0.1 已寫明「不做 3D 鏡頭遊玩」。本文件把該凍結升成活線產品邊界，避免美術「上 3D 模型」被誤解成要換店內相機與物理。

## 現行正確升級路徑（已開）

1. 精修 `art/src/*.vox`
2. `python3 tools/voxel_sprites.py`（靜態）
3. `python3 tools/voxel_character_anims.py`（讀設計師源＋肢體偏移；可選 `art/src/anim/` MagicaVoxel 完整幀）
4. 執行期合約不變：`{id}_{anim}_{facing}_{frame}.png`

## 若日後產品拍板「立體店」

獨立里程碑（勿與幀動作 PR 綁在一起）：

1. 新場景：正交 `Camera3D`（或固定等距）
2. 離線 bake `.vox` → `ArrayMesh`；道具優先 MultiMesh
3. 角色動畫優先 **幀 mesh 切換／morph**，Skeleton3D 列最後手段
4. 優先試「2D 模擬 + 3D 外觀」，再考慮整店 3D 物理

## 明確禁止（在拍板前）

- 執行期每隻角色 `vox_mesh.load_mesh`
- 把 Skeleton3D 嵌進現有 `demo`／`player` 2D loop
- 為 3D 動畫再開一份 Godot 專案複本
