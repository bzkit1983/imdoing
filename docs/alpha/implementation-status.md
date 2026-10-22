# Alpha → v1 實作對照（設計已落地項）

- 對照日：2026-10-22（含 PR #3–#40 相關玩法：掉貨瞄準、丟掉上架、丟掉砸小偷、Pages、docs align）
- 用途：把近期工程變更連回長線／Alpha 設計檔，方便查「文件寫在哪、程式改哪」
- 版控：`docs/versioning.md` · 技術债清單：`docs/alpha/tech-review-v0.1.md`（§6 已全部勾完） · 缺口：`docs/systemdesign-gaps.md` · 執行期優化：`docs/alpha/runtime-perf-audit.md`

| 變更 | 長線／Alpha 文件 | 工程 |
| --- | --- | --- |
| 凍結 Demo／Alpha，單一活線 | `docs/versioning.md`、`godot/README.md`、各目錄 `FROZEN.md` | 只維護 `godot/game`；tag `alpha-v0.1` |
| 存檔 `user://save.json` + `version` | **`docs/systemdesign/savesystem.md`**；`storepreparationphase.md`、`storeoperationphase.md` | `game_state.gd` 序列化；關店／準備結束寫入 |
| InputMap（移動／互動／取消／技能） | **`docs/systemdesign/control.md`**（檔首 action 表）；`cashiersystem.md`、`replenishmentsystem.md` 方向用語 | Autoload `Controls`；player／prep／demo |
| PlatformServices Autoload | **`docs/systemdesign/savesystem.md`**（平台節）；tech-review §4 | `platform_services.gd`＋Desktop backend；存檔 I/O、UI profile、掛起信號 |
| HUD／客人標籤髒刷新 | tech-review §3／§6 | `hud.gd` cache；`player._emit_stats_if_changed`；`customer._sync_labels` |
| 貨架 SKU 索引 | tech-review §3／§6 | `demo._shelves_by_sku`＋`shelf.stock_sku_changed`；`find_shelf` 走索引 |
| NotoSansTC 子集 | **`docs/alpha/fonts-subset.md`** | `NotoSansTC-Game.otf`＋`charset_game.txt`；`tools/fonts/subset_notosans_tc.py` |
| 執行期效能審計（剩餘熱路徑） | tech-review §3；**`docs/alpha/runtime-perf-audit.md`** | 對齊 `main` @ v1.0 tip；P1：interactable／HUD 計算／`thieves()`／尋路／地板／box_stack |
| 暫停選單＋掛起／恢復 | **`docs/systemdesign/pausemenu.md`** | `pause_menu.tscn`；`PlatformServices` 信號；營運日 Esc／Start |
| Win／Linux 匯出（Steam 候選） | **`docs/alpha/export-presets.md`** | `export_presets.cfg`；輸出 `build/windows`／`build/linux`；feature `steam_candidate` |
| 字串表 i18n | **`docs/alpha/i18n.md`** | `locale/strings.csv`；Autoload `Loc`；準備／暫停／HUD 已遷 |
| 主機商務評估（帳號／W4／埠接） | **`docs/alpha/console-business.md`** | 文件結論：帳號可早開；W4 自埠預設；買工具前過釘版閘門 |
| Godot ↔ middleware 釘版 | **`docs/alpha/godot-middleware-pin.md`** | 桌面維持 4.7；主機衝刺對齊 W4 表（2026-10-21 最高 4.6）；禁止專案複本 |
| Alpha v1.0 Web → Pages | `docs/versioning.md`；`docs/play/README.md` | `godot/game` Web 匯出到 `docs/play/`；試玩 https://bzkit1983.github.io/imdoing/play/ |
| 角色四向動作動畫 | **`docs/alpha/animation-v1.0.md`**；待辦 **`docs/alpha/animation-pending.md`** | `tools/voxel_character_anims.py`；`Vox.animated`／`play_anim`；player／customer／clerk |
| 掉貨瞄準／放手掉出／5 身位／青軌道 | **`docs/systemdesign/playeraction.md`**、`control.md` | `player.gd` cancel hold；`Tuning.DROP_*`；`drop_flight.gd` |
| 方向丟掉 → 同款貨架直接補架（剩貨掉地） | **`docs/systemdesign/replenishmentsystem.md`**、`playeraction.md` | `demo._resolve_toss_landing`／`_shelf_for_toss`；`Tuning.DROP_SHELF_HIT_RADIUS` |
| 方向丟掉砸中小偷 → Screen KO；贓物原地掉落 | **`docs/systemdesign/thiefsystem.md`**、`playeraction.md` | `demo._thief_for_toss`；`player.apply_toss_ko`；`customer.ko_box_hit_and_flee`；`spawn_loot_inplace` |
| 小偷打擊 KO／連打晃動／近遠散落 | **`docs/systemdesign/thiefsystem.md`**、`playermovement.md` | `player.gd` fight／KO；`demo.spawn_loot_scatter`；`Tuning.LOOT_SCATTER_*`／`FIGHT_*` |
| 離店途中仍可抓／砸／撞；出口才計被偷＋橫幅 | **`docs/systemdesign/thiefsystem.md`**、`storeoperationphase.md` | `is_active_thief` 含 LEAVE；`_finish_thief_exit`；`show_stolen_banner`／`demo.stolen_banner` |
| 客人離店不卡門 | **`docs/systemdesign/customer.md`** | leave `collision_mask=0`；`exit_pos` 在 pathfinder 內；門檻／逾時 despawn |
| 技術審查與跟進清單 | `docs/alpha/tech-review-v0.1.md` | 非玩法規格；§6 項目已全部勾完 |

仍缺（非 §6）：設定音量、教學、技能演出鎖輸入、Steamworks 等——見 `docs/alpha/design.md`。prep UI 已拆為 `scenes/prep_menu.tscn` + `scripts/prep/`。
