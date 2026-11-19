# Steam 產品化衝刺（H1–H3）

- 對照日：2026-11-18
- 活線：`godot/game`
- tech-review：[`tech-review-v0.2.md`](tech-review-v0.2.md) §7 H1–H3
- GodotSteam 接入：[`godotsteam-setup.md`](godotsteam-setup.md)
- EA 範圍：[`docs/versioning.md`](../versioning.md)「Early Access／現行產品範圍」

## 狀態總覽

| 項 | 狀態 | 說明 |
| --- | --- | --- |
| **H3** EA 範圍聲明 | **Done** | 純日循環；不做失敗／過關／提早關店敘事；敘事／事件留 Beta |
| **H1** Cloud／成就 API | **接線已落地** | `steam_platform.gd`：本機寫入後 `fileWrite`；冷啟可 `fileRead`；`setAchievement`＋`storeStats` |
| **H1** 正式 App ID | **Open** | 現仍測試 **480**；需 Steam Direct 正式 ID 後改下列檔 |
| **H2** 完整設定頁 | **Done** | 暫停「設定」子選單＋準備「系統工具→設定」；寫入既有 `user://settings.cfg` |
| **H2** 第一日引導打磨 | **Done** | 新檔劇本頁先問開始／跳過教學；模態可跳過整條；進度寫存檔；暫停可重溫 |

## H1 — 正式 App ID 切換清單（取得 ID 後）

1. 改 [`godot/game/steam_appid.txt`](../../godot/game/steam_appid.txt)
2. 改 `project.godot` 的 `steam/initialization/app_data/app_id`
3. 確認 Partner 已開 **Steam Cloud**（配額／路徑與 `save.json`／`guest_slots.json` 一致）
4. 在 Partner 登記成就 API 名稱，與 `PlatformServices.unlock_achievement(id)` 呼叫一致
5. 重跑 [`tools/m3_steam_smoke.sh`](../../tools/m3_steam_smoke.sh)＋手動 Cloud／成就煙測
6. **勿**把成就／Cloud 邏輯寫死只認 480

## H1 — Cloud／成就行為（現行）

- 權威仍是本機 `user://`；Cloud 為同步／還原層
- `write_save`／`write_guest_slots`／`checkpoint` → 成功寫盤後嘗試 Cloud `fileWrite`
- 本機無檔時 `read_*`／`has_*` 可從 Cloud 拉回
- `unlock_achievement` → `setAchievement`＋`storeStats`；Steam 未開或 id 未登記則 log，不崩

## H2 — 完整設定頁（驗收）

收束現有碎片為單一「設定」入口（暫停或準備皆可進）：

- [x] BGM 開／關與音量
- [x] 事件 SFX 開／關與音量
- [x] 語言（四語）
- [x] 鏡頭視野
- [x] 虛擬搖桿（觸控 profile）
- [x] 寫入既有 `user://settings.cfg`（不另開設定存檔格式）

實作：暫停主列 →「設定」子頁；準備「系統工具」→「設定」頁（`prep_pages._settings`）。

## H2 — 第一日引導打磨（驗收）

- [x] 非「測試工具→劇本 5」的**預設新檔**也會進入最小教學鏈（或明確一次詢問）— 劇本頁「開始教學／跳過教學」
- [x] 可跳過；進度寫入存檔（`tutorial_skipped`＋各課 `done`；模態「跳過教學」）
- [x] 暫停可重看已完成課（既有）

產品教學仍走 scenario 5 經濟（$3000／簡易／空白技能組）；測試工具清單可另列劇本 5。

## H3 — EA 範圍（已拍板）

見 [`docs/versioning.md`](../versioning.md) 與 [`docs/alpha/design.md`](design.md)。

**範圍內：** 日循環、技能、評價、教學框架、中期美術、多人至 M3。  
**範圍外：** 失敗／過關敘事、完整事件／劇情、技能解鎖表、長線流量定稿。
