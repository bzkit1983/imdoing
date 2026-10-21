# Alpha → v1 實作對照（設計已落地項）

- 對照日：2026-10-21
- 用途：把近期工程變更連回長線／Alpha 設計檔，方便查「文件寫在哪、程式改哪」
- 版控：`docs/versioning.md` · 技術债清單：`docs/alpha/tech-review-v0.1.md`

| 變更 | 長線／Alpha 文件 | 工程 |
| --- | --- | --- |
| 凍結 Demo／Alpha，單一活線 | `docs/versioning.md`、`godot/README.md`、各目錄 `FROZEN.md` | 只維護 `godot/game`；tag `alpha-v0.1` |
| 存檔 `user://save.json` + `version` | **`docs/systemdesign/savesystem.md`**；`storepreparationphase.md`、`storeoperationphase.md` | `game_state.gd` 序列化；關店／準備結束寫入 |
| InputMap（移動／互動／取消／技能） | **`docs/systemdesign/control.md`**（檔首 action 表）；`cashiersystem.md`、`replenishmentsystem.md` 方向用語 | Autoload `Controls`；player／prep／demo |
| PlatformServices Autoload | **`docs/systemdesign/savesystem.md`**（平台節）；tech-review §4 | `platform_services.gd`＋Desktop backend；存檔 I/O、UI profile、掛起信號 |
| 技術審查與跟進清單 | `docs/alpha/tech-review-v0.1.md` | 非玩法規格；issue 掛 Milestone `v1.0` |

仍缺（文件與程式都未完成）：暫停選單、設定音量、教學、技能演出鎖輸入等——見 tech-review §6 未勾項與 `docs/alpha/design.md`。prep UI 已拆為 `scenes/prep_menu.tscn` + `scripts/prep/`。
