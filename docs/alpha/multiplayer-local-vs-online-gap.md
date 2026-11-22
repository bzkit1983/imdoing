# 本機多人 vs 網上連線：全面對照報告

- **性質：** 工程對照審計（設計契約 × 活線程式）；**非**玩法規格、**非**本輪修 bug PR
- **對照日：** 2026-11-22（初稿）；**修復跟進：** 2026-11-22（§7 項 1／2／3／5 已落地；項 4 COMBO HUD 暫緩）
- **權威規格：** [`docs/systemdesign/multiplayer.md`](../systemdesign/multiplayer.md)
- **活線入口：** `godot/game/scripts/session/session_service.gd`、`seat_table.gd`、`net_transport.gd`、`demo.gd`
- **相關：** [`multiplayer-smoke-checklist.md`](multiplayer-smoke-checklist.md)、[`implementation-status.md`](implementation-status.md)、[`../systemdesign-gaps.md`](../systemdesign-gaps.md)

## 結論

Seat≠Peer listen-server 骨架（M1～M3）已落地。審計時網上路徑有數處違反 §8 Host 權威的 Client 本地模擬；**項 1／2／3／5 已修**（時鐘、庫存／L 鎖、Intent aim／toss／restock、`guest_stats`＝local_index 1）。**COMBO HUD（項 4）另行再設計，不直出介面。** 仍開：§8.4／§12.10／§13.6 驗收、M4 `web_ws`、雙 peer CI。

| 計量 | 數量 |
| --- | --- |
| P0 已修 | 時鐘／庫存／InteractLock／Intent（4） |
| P1 已修 | guest_stats 解耦；COMBO HUD 暫緩 |
| 規格驗收未勾 | §8.4／§12.10／§13.6 |
| CODE 未支援 | M4 `web_ws` |

---

## 1. 高層契約（應該怎樣）

| 層 | 契約 |
| --- | --- |
| 產品 | 同 Session 支援純本機 2、純線上 4、本機 2＋線上補位；`room_max_seats=4` |
| 權威 | Host 擁有世界時鐘、AI、庫存、L 鎖、技能世界效果、營收／XP／結算（§8.1） |
| Client | 只送 Intent；表現可樂觀，絕對 RPC 覆蓋（§8.2／§8.4） |
| 閘門 | 玩法走 `is_networked()`；`is_lan()` 只給 IP UX |
| 里程碑狀態 | M1 local／M2 LAN M2.0–M2.9／M3 Steam §13.4＝已交；§8.4／§12.10／§13.6＝驗收勾未打；M4 `web_ws`＝未做 |

```text
Client peer ──Intent 30Hz (seat_id)──► Host Sim (clock / AI / inventory / locks / settle)
Host peer    ─────────────────────────► SeatTable + NetTransport (local | lan_enet | steam)
Host Sim     ──pose / chrome / settle──► Client NetPresentation
```

---

## 2. 刻意差異（不是 bug）

這些是規格寫明的本機／網上行為差，不應當「對不上」修掉：

| 主題 | 本機 `local` | 網上 LAN／Steam |
| --- | --- | --- |
| Transport | 無 peer；`is_server()` 恒 true | ENet 或 SteamMultiplayerPeer |
| 鏡頭 | 跟兩可控角色中點 | 跟**本機擁有** seat 中點；遠端世界標記（[`control.md`](../systemdesign/control.md)） |
| 暫停／結業 | 任 seat 可開暫停；本機亦可結束日 | 任機開全房暫停；**僅 Host** 結束本日（暫停選單路徑） |
| 掛起 | 本機暫停／checkpoint | Client 掛起＝斷線（開日後凍座）；Host 掛起＝全房暫停 |
| 資金 | 本機 P2 訪客槽**不寫**店資金 | 遠端 peer **主存檔** `money += revenue`；claim2 訪客槽仍不寫資金 |
| 結算後 | 本機 ≥2 seat 留房；純單人回 Prep home | 同 §12.10 留房；Steam 保留 lobby |
| Web | 強制每機 1 seat；無 LAN／Steam 入口 | M4 才做 `web_ws` |

---

## 3. 文件已標、實作半完成的驗收缺口

| ID | 規格 | 現況 |
| --- | --- | --- |
| A | §8.4 Client 手感 | `NetPresentation`＋30Hz tick 已寫；三項驗收 `[ ]` 未勾；雙帳手感仍靠手動 |
| B | §12.10 日結留房 | 程式有 `keeps_room_after_settle()`／`return_to_lobby_after_settle()`；規格驗收與 smoke checklist step 5 仍 `[ ]` |
| C | §13.6 Overlay 免打 Lobby ID | `NetTransport` 已有 invite hooks／`+connect_lobby`／`invite_overlay`；§13.6 驗收仍 `[ ]`（§13.4 手動 ID 路徑已過） |
| D | M4 `web_ws` | `is_networked()` 已保留字串；**無** WebSocket peer 工廠 |
| E | 教學聯機 | [`tutorial.md`](../systemdesign/tutorial.md)：「先單機／Host 本地；聯機同步另開」——Client 仍會跑 director／freeze |
| F | 難度聯機細節 | [`difficulty.md`](../systemdesign/difficulty.md)「未定」：房用 Host 難度已口述，表未補 |
| G | Feature flags | 設計 `net_local`／`net_enet`／`multiplayer_session` 幾乎未用；實作靠 `transport_id`＋匯出 `net_steam` |

---

## 4. 程式層問題（本機可過、網上會衝突／對不上）

### P0 — 違反 Host 權威，會造成房內狀態分裂

**P0-1 Client 自跑世界時鐘，可觸發結業／提早關店 UI**

- `demo.gd` `_process`：所有 peer（含 Client）`real_time += …` → `DayPhase.advance` → `finished` 時呼叫 `_finish_day()`；`open` 時 `_consider_early_close()`。
- `_finish_day()` 對 Client 會等 Host settle RPC（好），但**提早關店確認** `_confirm_early_close()` **沒有** `is_server()`／`request_end_day()` 閘——Client 可自己進「等結算」而 Host 仍在營運。
- 對比：暫停選單結束本日正確走 `request_end_day()`（Host-only）。
- 規格衝突：§8.1「世界時鐘」屬 Host。

**P0-2 Client 樂觀改庫存／貨架／客人交付**

- `player.gd` `_try_pickup`／上架／`_hand_deliver`、`restock_point.gd` `take_pieces` → `state.consume_stock`：Client **無** early-return。
- 規格 §8.2：**禁止** client 宣告「我撿了 N 件」；§8.4 要求庫存 Host 權威。
- 絕對 `stock_state`／`carry_state` 可覆蓋，但失敗鎖／短暫錯 chrome／提早關店條件（看本機 stock）會抖。

**P0-3 InteractLock 只在本進程有效**

- `session/interact_lock.gd` 用 `Object.get_instance_id()`；Host／Client ID 不同，**無**鎖廣播。
- 本機雙人＝同表，正確；網上＝Client「以為拿到 L 鎖」與 Host 真實鎖無關（§11.6）。

**P0-4 兩段瞄準技能／丟掉方向不在 Intent**

- Intent 實際欄位（`demo._net_client_send_intents`）：`mx/my`＋holds＋`hotkey`／`bag_slot`／`ult_cast`。
- **缺：** aim confirm／目標列表、toss 方向／蓄力、補貨選 SKU 索引。
- `player/skill_range_caster.gd`（使命必達／磁力等）Client 本地進出 aim；Host 遠端座只見 hold——RTT／位置差 → 不同目標。
- `player/toss_controller.gd` 方向在模擬端用 facing／move——Client 預測與 Host 落點可錯。

### P1 — 明顯產品／規格落差

**P1-1 COMBO HUD 與網上複製**

- 規格／[`fetchcombo.md`](../systemdesign/fetchcombo.md)：個人＋TEAM HUD；locale 有 `hud.combo`／`hud.combo_coop`。
- `hud.gd`：**零** combo 引用；狀態在 `ComboState`／`demo.combo_*` 有算。
- `combo_note_*` **無** Client gate，且 **不在** `_broadcast_day_hud_state`（只同步 ops／revenue／stolen／served…）→ 網上任務 `deliver_combo`／HUD 可漂。

**P1-2 開日 `seed` 未套用**

- Prep snapshot 帶 `"seed": Time.get_ticks_msec()`；`_rpc_start_day` 未 seed RNG。
- Host 單點 `randi` 仍一致；Client 若本地再 roll（少數殘路）會偏。規格 §12.4 意圖未閉環。

**P1-3 `guest_stats` 硬綁 `seat_id == 1`**

- `session/seat_table.gd` `sheet_of`／`set_sheet`：seat 1 ↔ `guest_stats`。
- 本機 claim2：seat1＝訪客槽，正確。
- 網上：Host 只佔 seat0 時，**遠端第一座常是 seat1**——命名／sheet 刷新路徑（prep `sheet_of(1)`）易與「本機 P2 訪客槽」語意撞車。屬契約漂移風險。

**P1-4 收銀樂觀雙驅動**

- M2.9 已修 Client 禁雙重 `randi` 抽 seq（好）。
- Client `_try_command` 仍本地推 `seq_index`；Host 用 `remote_move`＋`prompt_state` 覆蓋——漏按／閃爍仍可能。

**P1-5 教學在 Client 仍可 freeze**

- `_begin_day` 對 Client 跳過部分 seed，但 tutorial director／`tutorial_freezes_play()` 仍可凍**單機**時鐘；與 Host 不同步（設計亦承認另開）。

**P1-6 §8.5 Intent 頻率限制未做**

- 有 `seq` 丟舊包、stale → `remote_move=0`；**無**顯式 rate-limit（規格寫對齊網 tick）。

### P2 — 工程／平台／覆蓋面

| 項 | 說明 |
| --- | --- |
| 無雙 peer 整合測 | 僅靜態 [`tools/test_multiplayer_smoke_contract.py`](../../tools/test_multiplayer_smoke_contract.py)＋手動 checklist＋[`m3_steam_smoke.sh`](../../tools/m3_steam_smoke.sh) |
| Net 浸入 monolith | `@rpc` 全在 `session_service.gd`；tick／settle／chrome 仍大量在 `demo.gd`（tech-review 已點） |
| Steam 產品化 | App ID 仍 480；Cloud／成就半程（非玩法同步，但是網上發行缺口） |
| 成就／部分 Platform stub | 與連線無直接 RPC 衝突，但 Steam 包完整度不足 |
| BGM／VFX 本地 RNG | 僅表現，可接受 |

---

## 5. 已對齊、相對健康的路徑（對照用）

- Seat claim／ready／freeze／Host 斷解散／`open_day_seat_n` XP 分母
- Pause RPC：任機暫停、Host-only 結束日（暫停列）
- Agent spawn／pose、stock／carry／prompt／skill_cd 絕對 RPC（M2.4–M2.9）
- 炮台／影分身等世界部署 Host gate（`host/skill_*.gd`、`_net_client_predicting`）
- 環境生成 Host-only（`host/world_spawn.gd`）
- 鏡頭本機中點、遠端不做分屏
- 玩法不直接 `ENetMultiplayerPeer.new()`（經 `NetTransport`）

---

## 6. 嚴重度總表

| Pri | 問題 | 本機 | 網上 | 類型 |
| --- | --- | --- | --- | --- |
| P0 | Client 時鐘＋提早關店 | 無 peer，OK | 結業／UI 分裂 | 權威缺失 |
| P0 | Client 改 stock／交付 | 同模擬 | 短暫／條件錯亂 | 權威缺失 |
| P0 | InteractLock 進程本地 | OK | L 鎖失效 | 不支援網上 |
| P0 | Aim／toss 不在 Intent | OK | 技能／丟掉目標錯 | 協定不足 |
| P1 | COMBO HUD／未 replicate | HUD 缺顯示 | 任務／顯示漂 | 設計≠碼 |
| P1 | seed 未用 | 無感 | 殘餘 RNG 風險 | 契約未閉 |
| P1 | seat1＝guest_stats | OK | sheet／語意風險 | 模型耦合 |
| P1 | 教學不同步 | Host 本地 | Client freeze | 規格延期 |
| Doc | §8.4／§12.10／§13.6 | — | 驗收未簽 | 未完成 |
| — | M4 web_ws | — | 未實作 | CODE 不支援 |
| — | 雙 peer CI | — | 回歸靠手 | 工程風險 |

---

## 7. 建議修復順序

1. **Host 權威時鐘：** ~~Client 停跑 DayPhase／提早關店；Host 廣播 clock~~ **已修**（2026-11-22）。
2. **L 互動＋庫存：** ~~Host-only 突變＋穩定 lock key~~ **已修**（2026-11-22）。
3. **擴 Intent：** ~~aim-confirm、toss dir／charge、restock~~ **已修**（2026-11-22）。
4. **COMBO HUD：** 另行再設計；**不**直出介面（暫緩）。
5. **解耦 guest_stats ↔ seat 1**（local_index 1）**已修**（2026-11-22）。
6. **補驗收／測試：** §8.4／§12.10／§13.6 真機勾完；至少一條雙實例 headless／半自動 smoke。
