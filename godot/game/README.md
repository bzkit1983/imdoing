# imdoing（活線）

v1.0 起唯一維護的 Godot 專案。從凍結的 `godot/alpha_v0_1` 複製一次而來。

- 用 Godot **4.7** 打開本目錄的 `project.godot`
- 版控：`docs/versioning.md`
- 技術债清單：`docs/alpha/tech-review-v0.1.md`
- 匯出預設：`export_presets.cfg` — Web → `docs/play/`；Windows／Linux（Steam 候選）→ repo `build/`（說明：`docs/alpha/export-presets.md`）
- **存檔：** `user://save.json`（`game_state.SAVE_VERSION`）。關店結算後、準備回合按「開始營業」時各寫一次；啟動時自動讀取。準備選單可「清除存檔並重選劇本」。

Alpha 試玩（不動）：https://bzkit1983.github.io/imdoing/play-alpha-v01/
