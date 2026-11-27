# Alpha → v1 實作對照（設計已落地項）

- 對照日：2026-11-27（`origin/main` @ `c8c778e`；含 PR #3–#146 等；多人 **M1～M2.9 已落地**；**§13 M3 Steam 已驗收**；產品 **v1.5.0** 中期美術；`SAVE_VERSION` **9**；收銀取消 Circle／INT 技能重做；11-20 之後見下表新增列）
- 用途：把近期工程變更連回長線／Alpha 設計檔，方便查「文件寫在哪、程式改哪」
- 版控：`docs/versioning.md` · 技術評估：`docs/alpha/tech-review-v0.3.md`（現行；v0.2 §7 多數已勾見 [`tech-review-v0.2.md`](tech-review-v0.2.md)；v0.1 §6 見 [`tech-review-v0.1.md`](tech-review-v0.1.md)） · 缺口：`docs/systemdesign-gaps.md` · 執行期優化：`docs/alpha/runtime-perf-audit.md`
- **美術：** v1.5.0 中期規格見 [`art-interim-v1.5.md`](../systemdesign/art-interim-v1.5.md)；**放置／換皮暫交美術成員**（工程維持插座與契約，不改玩法距離／COST／碰撞）
- **EA 範圍（2026-11-27，Jackson；取代 H3「純日循環」）：** 付費 Steam EA＝序章 → 第1章 → 第2章（破局）→ 自選一章（只有安桃山可選；選章顯示其他主題但鎖定）。**免費 Demo**＝序章 + 第1章＋**劇情內體驗式教學**（**不是**劇本 5），第1章通關後停下；暫不含多人；存檔不轉入 EA。正式組建無劇本選擇。第1／2章要事件系統；打完安桃山後可開分店並續日循環（上限 TBD）。失敗可擋事件／劇情任務、不擋日結算。見 `versioning.md`／`storysystem.md`／`steam-productization.md`。活線已有測試入口：序章內容閘（劇本 8）與頭目測試（劇本 6）；第1／2章、選章 runtime、事件／分店與 Demo 組建尚未做

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
| BGM（準備／營運／麻煩客人）＋音量 | **`docs/systemdesign/bgm.md`**；`pausemenu.md` | `BgmBus`；Music bus；暫停＋準備系統工具 mute／volume |
| 音效需求表＋SfxBus＋測試頁 map | **`docs/systemdesign/soundeffects.md`** | `sfx_bus.gd`／`sfx_catalog.gd`；`sfx_test.tscn` 標註觸發 |
| 準備選單測試資金 $1000 | **`docs/systemdesign/storepreparationphase.md`** | `ProductVersion.TEST_TOOLS`；prep home 按鈕 |
| 測試版難度（簡易／普通） | **`docs/systemdesign/storepreparationphase.md`**；`customer.md`、`cleaningsystem.md`、`thiefsystem.md` | prep 主畫面；`Tuning` 簡易係數；`demo` 在開始營運後套用 |
| Win／Linux／macOS 匯出（Steam 候選） | **`docs/alpha/export-presets.md`** | `export_presets.cfg`；輸出 `build/windows`／`build/linux`／`build/macos`；feature `desktop,steam_candidate,net_steam` |
| 字串表 i18n | **`docs/alpha/i18n.md`**；[`AGENTS.md`](../../AGENTS.md)／[`agents/skills/i18n-content`](../../agents/skills/i18n-content/SKILL.md) | `strings.csv`+`data.csv`；技能／SKU／傢俬＋log／mood／prep／驗證／場上標籤／HUD 觸控已遷；SFX 註解除外 |
| 主機商務評估（帳號／W4／埠接） | **`docs/alpha/console-business.md`** | 文件結論：帳號可早開；W4 自埠預設；買工具前過釘版閘門 |
| Godot ↔ middleware 釘版 | **`docs/alpha/godot-middleware-pin.md`** | 桌面維持 4.7；主機衝刺對齊 W4 表（2026-10-21 最高 4.6）；禁止專案複本 |
| Alpha／v1 Web → Pages | `docs/versioning.md`；`docs/play/README.md` | `godot/game` Web 匯出到 `docs/play/`；試玩 https://bzkit1983.github.io/imdoing/play/ |
| 角色四向動作動畫＋pending enrichment | **`docs/alpha/animation-v1.0.md`**；**`docs/alpha/animation-pending.md`** | `voxel_character_anims.py`／`voxel_alpha_props.py`；`Vox.animated`／`play_anim`；`fx_burst`；shelf／dirt／客人 pace |
| Voxel 高解析升模（人物包絡 90×40×130；標準 `player_alt3`） | **`docs/alpha/voxel-hires-scale-plan.md`**；`voxel-v0.1.md` | Look 皮膚＋CHAR_WAY；bake 雙路徑 PX=4／PX=1+scale0.5；升採樣占位＋rebake |
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
| 技術審查與跟進清單 | `docs/alpha/tech-review-v0.1.md`；v0.2；**現行** [`tech-review-v0.3.md`](tech-review-v0.3.md) | 非玩法規格；v0.1 §6 已勾完；v0.2 F–J 多數已勾；**v0.3 L1–L4 已勾**（巨石再抽／skill 分族／UI 瘦身／[`monolith-merge-gate.md`](monolith-merge-gate.md)）；H1／K1 仍開 |
| Runtime P1＋P2 熱路徑優化 | **`docs/alpha/runtime-perf-audit.md`**（文末 P1／P2 DONE） | `player`/`customer`/`demo`/`pathfinder`/`inventory`/`box_stack`/`floor_tiles`／`cashier`／`clerk`／`hud`／`drop_flight`；A* 預算、髒 HUD、地板單節點、佇列索引、dirt 網格 |
| 客人貨品交付（v1.2.0） | **`docs/systemdesign/customerdelivery.md`** | **已實作**。貨架短按 1 件、長按親手交付（近的先、每件 −15）、方向＋短按丟一件、整箱改每件 −15、主動技衝刺交付（COST 1、5 秒） |
| 自訂技能組合 | **`docs/systemdesign/customizedskillset.md`**、`playersetup.md` | **已實作**。五組預存、準備時可改未選用組、改完立刻寫檔、營運中鎖定。自訂名稱只准 10 個英文字母。角色整備入口「裝備技能」不顯示 COST；各組列表仍顯示 |
| 營運回合可互動發光 | **`docs/systemdesign/playeraction.md`**、`storeoperationphase.md` | **已實作**。對準且行動鍵現在會作用的對象暖色光暈（貼近目標）；準備回合與不能真的互動時不亮 |
| 技能選單先開再放 | **`docs/systemdesign/playerskills.md`**、`control.md` | **已實作**。短按／長按技能鍵都先開選單；選單開著時方向不走路 |
| 狙擊手（貨架／客人／小偷） | **`docs/systemdesign/playeractiveskills.md`**、`playeraction.md`、`replenishmentsystem.md`、`customerdelivery.md`、`thiefsystem.md` | **已實作**。各 COST 2、維持 30 秒、表列 CD 10。有方向投出改飛技能目標；腳邊丟掉不受影響。同時生效優先序：**小偷 → 客人 → 貨架** |
| Dark Side | **`docs/systemdesign/darkside.md`**、`playeractiveskills.md` | **已實作**。COST 2、表列 CD 30（吃 INT）。準備頁選 LV1／2／3（預設 LV3），抽 1／2／3 名客人當臨時收銀或補貨 30 現實秒。不佔雇員、不扣日薪、仍算在店客人 |
| 多重影分身 | **`docs/systemdesign/shadowclone.md`**、`playeractiveskills.md` 及營運／備戰／店員／丟掉／奧義等活線檔 | **已實作**。COST 3、表列 CD 30（吃 INT）。準備頁選 LV1／2／3（預設 LV3），身旁生 1／2／3 個半透明玩家分身當收銀／補貨 30 現實秒。能力用施放當下 STR／AGI／INT＋被動。再放先讓舊分身消失 |
| 技能測試劇本 | **`docs/systemdesign/storepreparationphase.md`** | **已實作**。劇本4：LV10、三圍 20、$99999、規模 LV3 18×10、已放好可開工店面 |
| Design Gap 拍板（v1.1.0） | **`docs/systemdesign-gaps.md`**；各 systemdesign 檔 | 衝刺撞客人／擁擠／凌波微步／丟掉砸客人／多台選隊／重置費用／衝刺算抓住等；見 gaps「已處理」 |
| 麻煩客人 EliteCustomer | **`docs/systemdesign/elitecustomer.md`**、`customer.md`、`ecosystem.md` | `customer.become_elite`／詞綴；`demo` 1–5% spawn＋橫幅／ZOOM；收銀雙倍＋`XP_ELITE_SERVE`；活線暫只解鎖 LV1 |

| 多人 M1 本機雙人 | **`docs/systemdesign/multiplayer.md`** §11 | **已實作**。`SeatTable`／`InteractLock`／`SessionService`（`transport=local`）；prep 1｜2；訪客槽；日結 XP 平分＋`support_rating` |
| 多人 M2 LAN／ENet | **`docs/systemdesign/multiplayer.md`** §12 | **首刀～M2.9 已交**：含 **收銀指令 UI**（`checkout_seq` `agent_state`；`prompt_state` RPC；`apply_net_checkout_prompt`；client 禁雙重 randi） |
| 多人 M3 Steam | **`docs/systemdesign/multiplayer.md`** §13 | **§13.4 已驗收**（2026-11-11）。GodotSteam 4.24；`host_with_lobby`／`connect_to_lobby`；雙帳邀請進混合房＋開日／日結。正式 App ID／Cloud／成就可後補 |
| 本機 vs 網上缺口審計 | **[`multiplayer-local-vs-online-gap.md`](multiplayer-local-vs-online-gap.md)** | **文件已交**（2026-11-22）。 |
| 網上權威修復（1／2／3／5） | 同上 §7；`session_service`／`demo`／`player`／`seat_table`／`interact_lock` | **已修**：Host 時鐘＋early-close 閘；Client 禁庫存／交付突變；Intent aim／toss／restock；`guest_stats`＝local_index 1。COMBO HUD 暫緩另設計 |
| 中期美術 v1.5.0 | **`docs/systemdesign/art-interim-v1.5.md`**；`voxel-hires-scale-plan.md`；`ops-sku-icon-ui.md` | 非玩家體素、補貨架高度、SKU／技能／prep 圖示、地板牆污物；玩家四套 Look／CELL／碰撞／技能數值凍結。**放置／換皮暫交美術**；工程驗收見 art-interim「美術放置驗收清單」 |
| 收銀取消 Circle＋INT／技能重做（2026-11-18） | **`cashiersystem.md`**、`playerstats.md`、`playeractiveskills.md`、`playerpassiveskills.md`；日誌 [`Bzho_log/20261118_….md`](../Bzho_log/20261118_收銀取消Circle與INT技能重做.md) | 指令完成即入帳（無 Loading Circle）；INT 減次數＋親收加錢；`checkout_rush`／`checkout_speed`／`senior_cashier` 重做；店員／影分身／Dark Side 就緒即收 |
| EA 範圍聲明 | **`docs/versioning.md`**；`docs/alpha/design.md`；`storysystem.md`；`steam-productization.md` | **2026-11-27 已拍板（Jackson）：** 先以**付費 Steam EA** 上市，進程＝序章 → 第1章 → 第2章（破局）→ 自選一章（只有安桃山；選章顯示其他主題但鎖定）。**免費 Demo**＝序章 + 第1章＋劇情內體驗式教學（不是劇本 5）；暫不含多人；**存檔不轉入 EA**。正式組建無劇本選擇。第1／2章要事件；打完安桃山可開分店並續日循環。失敗可擋事件／劇情任務、不擋日結算（放寬 H3）。其餘五主題／終章／完整事件表留 Beta。Demo 組建尚未做 |
| 劇情模式框架 | **`docs/systemdesign/storysystem.md`**；`story/`；`docs/beta/design.md` | **設計：** 十章選章＋成長三分析＋失敗擋 UX（2026-11-27：可擋事件／劇情任務、不擋日結算）。**EA 要做：** 官方開局（無劇本選擇＋體驗式教學）＋序章（活線劇本 8 閘／經濟為測試入口）＋第1章＋第2章破局（含事件）＋顯示六主題但僅安桃山可選＋`story_slot` 狀態機＋打完安桃山後分店與續日循環。**仍未做（屬 EA）。仍暫緩：** 其餘五主題活線正文、終章 |
| 事件系統占位（N2） | **`docs/systemdesign/eventsystem.md`** | **2026-11-27 已決：第1／2章需要事件系統**（改列入 EA）。完整事件表仍後補。活線未做 |
| CJK 字型子集（M2） | **`docs/alpha/fonts-subset.md`** | 2026-11-21 重跑 Regular／Bold／Black（西客炮／源頭減廢／有糧出…） |
| 效能基線 J1（O1） | **`docs/alpha/perf-baseline-j1.md`** | 空店＋桌面 `--load` 滿店 15／分身 3；Deck 待測 |
| CI 靜態（G1）＋本地閘門 | **`.github/workflows/ci.yml`** 僅 `static-tests`（`python3 tools/run_ci_static.py`）；[`ci-local.md`](ci-local.md) | `tools/run_godot_checks.py` 可本地跑（shelf_sniper／interact_glow／difficulty），**尚未**成為 workflow job（Q1 的 `godot-checks` 因 `workflow` scope 未推入）。2026-11-27 已加 pre-push hook |
| Steam Cloud／成就接線（H1 半程） | **`docs/alpha/steam-productization.md`**；`godotsteam-setup.md` | `steam_platform.gd`：`fileWrite`／`fileRead`／`setAchievement`＋`storeStats`；正式 App ID 仍 Open（480） |
| 完整設定頁＋首日引導（H2） | **`docs/alpha/steam-productization.md`**；`pausemenu.md`；`tutorial.md` | 暫停「設定」子選單＋準備「系統工具→設定」；新檔開始／跳過教學；`tutorial_skipped`＋模態跳過；暫停可重溫 |
| 傳送門 | **`docs/systemdesign/shopitem.md`**、`shopsetup.md` | **已實作**（2026-11-24）。成對 `portal`＋`pair_id`；光束傳送；測試 VOX 圖與 Prep 圖示。測試版可授予最多 4 端；序章／教學不加 |
| 自助收銀修理（劇本 7） | **`docs/systemdesign/cashiersystem.md`**、`shopitem.md`、`storepreparationphase.md` | **已實作**（2026-11-24）。傢俬 `self_cashier` 耐久／修理迴圈；劇本 7 藍本＝劇本 4，門口一台自助機、無收銀店員 |
| 頭目戰測試（劇本 6） | **`docs/systemdesign/bossbattle.md`**、`bosses/alien_tycoon.md` | **已實作**（2026-11-21）。選劇本 6 後「開始營運」進入頭目日，測外星大土豪 |
| 序章內容閘／經濟（劇本 8） | **`docs/systemdesign/story/prologue.md`**、`taskcontent-story-stub.md`、`storysystem.md` | **已實作**（2026-11-25）。`GameState.SCENARIO_PROLOGUE = 8`：LV1、$2500、空店、內容閘（`unlocked_*`／`prologue_boss_unlocked`，`SAVE_VERSION` ≥7）；任務 pack `ST-PROLOGUE-MONEY`。**2026-11-27 起列入 EA 起點**；通關後進第1章的 runtime 仍未做 |
| 安桃山熟食檔＋釣魚（劇本 9） | **`docs/systemdesign/cookedfoodsystem.md`**、`fishingtaro.md`、`storepreparationphase.md` | **已實作**（2026-11-25）。`theme_historic` 熟食檔與釣魚太郎；劇本 9 藍本同劇本 4；`SAVE_VERSION` ≥8（`fish_stock`／`fishing_taro_played`） |
| 精英店員（劇本 10） | **`docs/systemdesign/eliteclerk.md`**、`storepreparationphase.md`、`savesystem.md` | **已實作**（2026-11-26，#146）。Prep UI＋多崗位；`SAVE_VERSION` 9（`elite_clerks`）。劇本 10＝安桃山布局營運日測試，目錄全員 debug 滿級 |
| 分店系統（垂直切片） | **`docs/systemdesign/branchstore.md`**；`savesystem.md` | **`SAVE_VERSION` 10**＋劇本 11：主題店快照、Prep 分店、背景結算、日結分店欄。起源店可作分店背景營運。正式選章 runtime 仍未做 |
| Ambient Peek 操作層 | **`docs/systemdesign/player-context-ui.md`**、`control.md` | **已實作**（2026-11-23）。背包菱形、持物條、技能環；#144／#145 |
| 其他 11-20～11-27 同期落地 | 各技能／小遊戲／多人檔 | 商品 XP 曲線 LV99 與店規模 S1–S6（#140）；培養預覽；收銀對決／Dasher／快吞包對決／Metal Rush 等小遊戲；網上 Host 權威修復（#143）；本地 vs 網上缺口文件（#142）；手掣／鍵盤短按徑向重綁 |

## 巨石行數（2026-11-27 重數，`godot/game/scripts/`）

| 檔 | 行數 | 備註 |
| --- | ---: | --- |
| `player.gd` | **2893** | #175 拆到 `player/*` 後；合併閘監視檔，勿再吞控制器 |
| `demo.gd` | **3986** | 預算 ≤ 4000（`monolith-merge-gate.md`／`test_demo_host_extract.py`） |
| `prep_menu.gd` | 3265 | |
| `game_state.gd` | 2748 | |
| `customer.gd` | 2737 | |
| `hud.gd` | 1469 | |
| `skill_caster.gd` | 407 | 編排器預算 ~400 |

仍缺（非 §6）：**第一日引導打磨**（教學框架與設定頁已落地）、技能演出鎖輸入、正式 App ID／Cloud／成就、M4 Web、把 `run_godot_checks.py` 真正加進 CI——見 `docs/alpha/design.md`、`multiplayer.md` §13／§15。本機／網上權威缺口見 [`multiplayer-local-vs-online-gap.md`](multiplayer-local-vs-online-gap.md)（修 bug 另 PR）。事件 SFX／BGM 音量已在暫停選單（BGM 亦在準備系統工具）。prep UI 已拆為 `scenes/prep_menu.tscn` + `scripts/prep/`。**教學框架**已落地（`docs/systemdesign/tutorial.md`）；劇本 5 開局鏈已有 prep 購入家具／採購罐頭／店鋪設計／角色能力配點／裝備技能／開發商品／採購新貨／擴充商店物品／擴充店鋪設計／第二台收銀機／招募店員（教學鏈終點）與 ops 上架／清潔／收銀／捉小偷／客人交付／完成一日／空貨架提示／第二日使用技能／第三日評價點數（OP-TUT-001 練習＋完美交付 tip）。
