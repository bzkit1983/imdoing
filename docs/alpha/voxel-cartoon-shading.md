# Voxel Cartoon Shading（活線＝烘焙端）

- **狀態：** 預設已改為 **outline_only**（墨線、不做 RGB 階調）；`cartoon`／`classic` 仍可診斷對照；執行期 Canvas 描邊預設關
- **活線：** `godot/game`
- **對照：** [`voxel-v0.1.md`](voxel-v0.1.md)、[`voxel-hires-scale-plan.md`](voxel-hires-scale-plan.md)、[`voxel-3d-play-deferred.md`](voxel-3d-play-deferred.md)、[`animation-v1.0.md`](animation-v1.0.md)

## 產品邊界（勿誤解）

| 要 | 不要 |
| --- | --- |
| 更卡通的 **2D voxel 精靈**（硬邊明暗 + bake 墨線） | 執行期 3D Cel／Toon 材質進店舖 |
| 改 [`tools/voxel_sprites.py`](../../tools/voxel_sprites.py) 的 `render()` 後重烘 PNG | 為卡通改 Forward+／開第二份專案 |
| 設計師仍改 MagicaVoxel `.vox` → 跑 bake | 把「上 3D 模型」當成已可上店內 toon |

店內執行期仍是 `AnimatedSprite2D`（[`voxel_sprite.gd`](../../godot/game/scripts/voxel_sprite.gd)）+ **GL Compatibility**。真 3D mesh 僅 preview QA，見 [`voxel-3d-play-deferred.md`](voxel-3d-play-deferred.md)。

## 管線

```text
art/src/*.vox
  → voxel_sprites.render()（classic｜cartoon｜outline_only）
  → art/sprites/*.png
  → Vox.sprite / Vox.animated / Vox.play_anim
```

[`voxel_character_anims.py`](../../tools/voxel_character_anims.py)／[`voxel_alpha_props.py`](../../tools/voxel_alpha_props.py) 已呼叫 `voxel_sprites.render`，與靜態 bake **共用同一套 shading**。

## 風格參數（簽樣後鎖進代碼）

環境變數：`VOXEL_SHADING=classic|cartoon|outline_only`（**預設 outline_only**）。

| 參數 | classic | cartoon（舊預設） | outline_only（現預設） |
| --- | --- | --- | --- |
| 頂／前／側面倍率 | 1.08／0.78／0.62 | 1.15／0.72／0.52 | 1.08／0.78／0.62 |
| RGB 階調 | 無 | 每通道 4 階（0–255 → 4 buckets） | 無（保留膚色／色盤） |
| 墨線 | 無 | 不透明外輪廓 1px，色約 `#1a1a1a` | 同左 |
| 像素 | 低解 4px／voxel；高解 PX=1 後 nearest `DISPLAY_SCALE=0.5` | 同左；outline／posterize 在 downscale **前**做 | 同左 |

**為何改預設：** `cartoon` 的 4 階 `posterize` 會把膚色量化成髒色；墨線本身不傷色盤。`outline_only` = classic 明暗 + 1px 墨線。

**樣張簽核（全庫 bake 前必過）：** `player`／`player_alt3`（至少一面向靜態）+ `shelf_dry`。標準：可讀、膚色不髒、墨線不吞小臉。

## 設計師怎麼配合

1. 照常在 `art/src/` 改 `.vox`（檔名／外框／腳底 z=0／臉朝 +Y 不變）。
2. 色盤可維持自然膚色；不再需要為 4 階量化刻意拉高對比。
3. 跑既有 bake（預設即 outline_only）：
   - `python3 tools/voxel_sprites.py`
   - 角色幀：`python3 tools/voxel_character_anims.py`
   - 道具／FX：`python3 tools/voxel_alpha_props.py`
4. 對照：
   - `VOXEL_SHADING=classic python3 tools/voxel_sprites.py`
   - `VOXEL_SHADING=cartoon python3 tools/voxel_sprites.py`（僅診斷，不當預設發行）
5. Godot 重開或 `--import` 後看店內 nearest 縮放。

不要重跑 `voxel_blockout.py`（會蓋掉 `art/src` 初模）。

## 分刀（實作順序）

| 刀 | 內容 |
| --- | --- |
| **0** | 本文件＋與 3D-deferred 交叉連結 — **已交** |
| **1** | `render()` prototype＋`player`／`shelf_dry` 簽樣 — **已交** |
| **2** | 全庫 sprites／anims／props 重烘＋合約／`--import` — **已交** |
| **3** | 預設**關閉**的 Canvas 描邊（bake 墨線為主；執行期加粗可選）— **已交** |
| **4** | 預設改 **outline_only**、全庫重烘 — **已交** |

## 執行期 Canvas 描邊（刀 3，預設關）

Bake 1px 墨線已是發行觀感。若要 QA／加粗，可掛 [`shaders/sprite_outline.gdshader`](../../godot/game/shaders/sprite_outline.gdshader)：

```gdscript
Vox.set_canvas_outline_enabled(true)   # 之後 Vox.sprite / Vox.animated 會掛 material
Vox.apply_canvas_outline(existing_spr) # 已在場上的精靈
```

或啟動前設環境變數 `VOXEL_CANVAS_OUTLINE=1`。皮膚 `modulate` tint 仍作用於本體；描邊維持近墨色。Web／GL Compatibility 可用。預設**不要**開。

### 樣張／對照

對照 PNG（facing 0）仍留於 `godot/game/art/preview/cartoon_compare_*`（classic vs 舊 cartoon）。預覽三變體可用：

```bash
python3 tools/preview_shading_compare.py
```

全庫重烘：

```bash
python3 tools/voxel_sprites.py
python3 tools/voxel_character_anims.py
python3 tools/voxel_alpha_props.py
# Godot: --path godot/game --headless --import --quit
# 回歸: python3 tools/test_character_anims.py
```

診斷舊 cartoon／classic：

```bash
VOXEL_SHADING=cartoon VOXEL_BAKE_IDS=player,shelf_dry python3 tools/voxel_sprites.py
VOXEL_SHADING=classic VOXEL_BAKE_IDS=player,shelf_dry python3 tools/voxel_sprites.py
```

## 明確禁止

- 把 Cartoon 需求解讀成「立刻上店內 3D Toon／Skeleton3D」
- 為卡通單獨開 `godot/game_cartoon` 複本
- 拿掉 `classic`／`cartoon` 對照開關（須可還原診斷）
