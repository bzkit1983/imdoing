# Alpha → v1 實作對照（設計已落地項）

- 對照日：2026-10-30（含 PR #3–#117：掉貨／丟掉上架砸小偷、Design Gap、Runtime P1＋P2、SFX、客人交付 v1.2、自訂技能組、互動發光、三招狙擊手＋優先序、Pages、Dark Side、多重影分身設計）
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
| NotoSansTC 子集（TTF／iOS） | **`docs/alpha/fonts-subset.md`** | `NotoSansTC-Game.ttf`＋`charset_game.txt`；`tools/fonts/subset_notosans_tc.py`（含 soundeffects 字集） |
| 執行期效能審計＋P1／P2 優化 | tech-review §3；**`docs/alpha/runtime-perf-audit.md`** | 審計＋實作已合入；見 audit 文末 P1／P2 DONE |
| 暫停選單＋掛起／恢復＋SFX 音量 | **`docs/systemdesign/pausemenu.md`** | `pause_menu.tscn`；`SfxBus` mute／volume；手機 Web「暫停」鈕 |
| 音效需求表＋SfxBus＋測試頁 map | **`docs/systemdesign/soundeffects.md`** | `sfx_bus.gd`／`sfx_catalog.gd`；`sfx_test.tscn` 標註觸發 |
| 準備選單測試資金 $1000 | **`docs/systemdesign/storepreparationphase.md`** | `ProductVersion.TEST_TOOLS`；prep home 按鈕 |
| 測試版難度（簡易／普通） | **`docs/systemdesign/storepreparationphase.md`**；`customer.md`、`cleaningsystem.md`、`thiefsystem.md` | prep 主畫面；`Tuning` 簡易係數；`demo` 在開始營運後套用 |
| Win／Linux 匯出（Steam 候選） | **`docs/alpha/export-presets.md`** | `export_presets.cfg`；輸出 `build/windows`／`build/linux`；feature `steam_candidate` |
| 字串表 i18n | **`docs/alpha/i18n.md`** | `locale/strings.csv`；Autoload `Loc`；準備／暫停／HUD 已遷 |
| 主機商務評估（帳號／W4／埠接） | **`docs/alpha/console-business.md`** | 文件結論：帳號可早開；W4 自埠預設；買工具前過釘版閘門 |
| Godot ↔ middleware 釘版 | **`docs/alpha/godot-middleware-pin.md`** | 桌面維持 4.7；主機衝刺對齊 W4 表（2026-10-21 最高 4.6）；禁止專案複本 |
| Alpha／v1 Web → Pages | `docs/versioning.md`；`docs/play/README.md` | `godot/game` Web 匯出到 `docs/play/`；試玩 https://bzkit1983.github.io/imdoing/play/ |
| 角色四向動作動畫＋pending enrichment | **`docs/alpha/animation-v1.0.md`**；**`docs/alpha/animation-pending.md`** | `voxel_character_anims.py`／`voxel_alpha_props.py`；`Vox.animated`／`play_anim`；`fx_burst`；shelf／dirt／客人 pace |
| Loading Circle 最上層 | **`docs/systemdesign/playeraction.md`**、`replenishmentsystem.md` | `loading_circle.gd` viewport CanvasLayer |
| 清潔：只顯示藍計，隱藏黃 Circle | **`docs/systemdesign/cleaningsystem.md`**、`playeraction.md` | `player._cleaning` 抑制黃圈；`dirt.StickHint` 抬高 |
| 掉貨瞄準／放手掉出／5 身位／青軌道 | **`docs/systemdesign/playeraction.md`**、`control.md` | `player.gd` cancel hold；`Tuning.DROP_*`；`drop_flight.gd` |
| 方向丟掉 → 同款貨架直接補架（剩貨掉地） | **`docs/systemdesign/replenishmentsystem.md`**、`playeraction.md` | `demo._resolve_toss_landing`／`_shelf_for_toss`；`Tuning.DROP_SHELF_HIT_RADIUS` |
| 方向丟掉砸中小偷 → Screen KO；贓物原地掉落 | **`docs/systemdesign/thiefsystem.md`**、`playeraction.md` | `demo._thief_for_toss`；`player.apply_toss_ko`；`customer.ko_box_hit_and_flee`；`spawn_loot_inplace` |
| 丟掉交齊清單 → 立刻去收銀 | **`docs/systemdesign/playeraction.md`**、`customer.md`、`cashiersystem.md` | `customer.accept_toss_box` → `_begin_checkout` |
| 衝刺撞客：清單不重抽、從頭再買 | **`docs/systemdesign/playermovement.md`**、`customer.md` | `customer.dash_knock_guest` 重建 shopping＝cart＋剩餘 |
| 補貨店員：計劃中每幀跟隨 | **`docs/systemdesign/clerksystem.md`** | `clerk.gd`：`_job_search_cd` 只節流閒置掃描 |
| 小偷打擊 KO／連打晃動／近遠散落 | **`docs/systemdesign/thiefsystem.md`**、`playermovement.md` | `player.gd` fight／KO；`demo.spawn_loot_scatter`；`Tuning.LOOT_SCATTER_*`／`FIGHT_*` |
| 離店途中仍可抓／砸／撞；出口才計被偷＋橫幅 | **`docs/systemdesign/thiefsystem.md`**、`storeoperationphase.md` | `is_active_thief` 含 LEAVE；`_finish_thief_exit`；`show_stolen_banner`／`demo.stolen_banner` |
| 客人離店不卡門 | **`docs/systemdesign/customer.md`** | leave `collision_mask=0`；`exit_pos` 在 pathfinder 內；門檻／逾時 despawn |
| 技術審查與跟進清單 | `docs/alpha/tech-review-v0.1.md` | 非玩法規格；§6 項目已全部勾完 |
| Runtime P1＋P2 熱路徑優化 | **`docs/alpha/runtime-perf-audit.md`**（文末 P1／P2 DONE） | `player`/`customer`/`demo`/`pathfinder`/`inventory`/`box_stack`/`floor_tiles`／`cashier`／`clerk`／`hud`／`drop_flight`；A* 預算、髒 HUD、地板單節點、佇列索引、dirt 網格 |
| 客人貨品交付（v1.2.0） | **`docs/systemdesign/customerdelivery.md`** | **已實作**。貨架短按 1 件、長按親手交付（近的先、每件 −15）、方向＋短按丟一件、整箱改每件 −15、主動技衝刺交付（COST 2、5 秒） |
| 自訂技能組合 | **`docs/systemdesign/customizedskillset.md`**、`playersetup.md` | **已實作**。五組預存、準備時可改未選用組、改完立刻寫檔、營運中鎖定。自訂名稱只准 10 個英文字母。角色整備入口「裝備技能」不顯示 COST；各組列表仍顯示 |
| 營運回合可互動發光 | **`docs/systemdesign/playeraction.md`**、`storeoperationphase.md` | **已實作**。對準且行動鍵現在會作用的對象暖色光暈（貼近目標）；準備回合與不能真的互動時不亮 |
| 技能選單先開再放 | **`docs/systemdesign/playerskills.md`**、`control.md` | **已實作**。短按／長按技能鍵都先開選單；選單開著時方向不走路 |
| 狙擊手（貨架／客人／小偷） | **`docs/systemdesign/playeractiveskills.md`**、`playeraction.md`、`replenishmentsystem.md`、`customerdelivery.md`、`thiefsystem.md` | **已實作**。各 COST 2、維持 30 秒、表列 CD 10。有方向投出改飛技能目標；腳邊丟掉不受影響。同時生效優先序：**小偷 → 客人 → 貨架** |
| Dark Side | **`docs/systemdesign/darkside.md`**、`playeractiveskills.md` | **已實作**。COST 2、表列 CD 30（吃 INT）。準備頁選 LV1／2／3（預設 LV3），抽 1／2／3 名客人當臨時收銀或補貨 30 現實秒。不佔雇員、不扣日薪、仍算在店客人 |
| 多重影分身 | **`docs/systemdesign/shadowclone.md`**、`playeractiveskills.md` 及營運／備戰／店員／丟掉／奧義等活線檔 | **已拍板，未實作**。COST 3、表列 CD 30（吃 INT）。準備頁選 LV1／2／3（預設 LV3），身旁生 1／2／3 個半透明玩家分身當收銀／補貨 30 現實秒。能力用施放當下 STR／AGI／INT＋被動。再放先讓舊分身消失。活線文件已對齊；程式尚未做 |
| 技能測試劇本 | **`docs/systemdesign/storepreparationphase.md`** | **已實作**。劇本4：LV10、三圍 20、$99999、規模 LV3 18×10、已放好可開工店面 |
| Design Gap 拍板（v1.1.0） | **`docs/systemdesign-gaps.md`**；各 systemdesign 檔 | 衝刺撞客人／擁擠／凌波微步／丟掉砸客人／多台選隊／重置費用／衝刺算抓住等；見 gaps「已處理」 |
| 麻煩客人 EliteCustomer | **`docs/systemdesign/elitecustomer.md`**、`customer.md`、`ecosystem.md` | `customer.become_elite`／詞綴；`demo` 1–5% spawn＋橫幅／ZOOM；收銀雙倍＋`XP_ELITE_SERVE`；活線暫只解鎖 LV1 |

仍缺（非 §6）：BGM／完整設定頁、教學、技能演出鎖輸入、Steamworks 等——見 `docs/alpha/design.md`。事件 SFX 音量已在暫停選單。prep UI 已拆為 `scenes/prep_menu.tscn` + `scripts/prep/`。
