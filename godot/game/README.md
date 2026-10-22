# imdoing（活線）

v1.0 起唯一維護的 Godot 專案。從凍結的 `godot/alpha_v0_1` 複製一次而來。

- **產品版：** `1.1.0`（`config/version` · `scripts/product_version.gd` · repo `VERSION` · tag `v1.1.0`）
- 用 Godot **4.7** 打開本目錄的 `project.godot`（主機 middleware 對齊政策見 `docs/alpha/godot-middleware-pin.md`）
- 版控：`docs/versioning.md`
- 技術债清單：`docs/alpha/tech-review-v0.1.md`
- 匯出預設：`export_presets.cfg` — Web → `docs/play/`；Windows／Linux（Steam 候選）→ repo `build/`（說明：`docs/alpha/export-presets.md`）
- **字串表：** `locale/strings.csv`＋Autoload `Loc`（`docs/alpha/i18n.md`）
- **存檔：** `user://save.json`（`game_state.SAVE_VERSION`）。關店結算後、準備回合按「開始營業」時各寫一次；啟動時自動讀取。準備選單可「清除存檔並重選劇本」。
- **輸入：** Autoload `Controls` 註冊 InputMap（`move_*`／`interact`／`cancel`／`dash`／`skill`／`ult`／`rotate`…）。預設仍是 WASD + J/K/L/U 與 Xbox 手把；可在專案設定改鍵。

**活線試玩：** https://bzkit1983.github.io/imdoing/play/  
Alpha v0.1 試玩（不動）：https://bzkit1983.github.io/imdoing/play-alpha-v01/

**角色動畫：** `python3 tools/voxel_character_anims.py` → `art/sprites/*_{anim}_{facing}_{frame}.png`（說明：`docs/alpha/animation-v1.0.md`；待辦：`docs/alpha/animation-pending.md`）
