# Godot 工程目錄

版控規則見 [`docs/versioning.md`](../docs/versioning.md)。

| 路徑 | 狀態 | 說明 |
| --- | --- | --- |
| **`game/`** | **唯一活線（v1.0 開發）** | 所有新功能、bugfix、美術迭代改這裡 |
| `alpha_v0_1/` | 凍結 | Alpha v0.1 可玩快照；Pages：`docs/play-alpha-v01/` |
| `demo_v0_*/` | 凍結 | 歷史 Demo；僅供對照，不開新功能 |

## 開發者請開哪個專案？

用 Godot 4.7 打開 **`godot/game/project.godot`**。

不要在 `alpha_v0_1` 或 `demo_v0_*` 上做 v1 功能。那些目錄裡的 `FROZEN.md` 有同樣提醒。

匯出：Web → `docs/play/`；Windows／Linux（Steam 候選）→ repo `build/`。見 [`docs/alpha/export-presets.md`](../docs/alpha/export-presets.md)。

## 美術烘焙

活線圖素：

```bash
python3 tools/voxel_sprites.py
```

預設讀寫 `godot/game/art/`。凍結的 Alpha 來源仍留在 `godot/alpha_v0_1/art/` 不改。
