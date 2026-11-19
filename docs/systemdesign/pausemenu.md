# 暫停選單與掛起／恢復

- 活線：`godot/game`
- 工程：`scenes/pause_menu.tscn`、`scripts/pause_menu.gd`；掛起信號來自 Autoload `PlatformServices`
- 文案：`Loc`（`pause.*` keys；見 `docs/alpha/i18n.md`）
- 營運回合交叉：`storeoperationphase.md`
- 音效設定：`SfxBus`（`user://settings.cfg` → `[audio] sfx_muted`、`sfx_volume`）
- 背景音樂：`BgmBus`（同檔 `[audio] bgm_muted`、`bgm_volume`；規則見 `bgm.md`）
- UI 偏好：`PlatformServices`（同檔 `[ui] virtual_stick`、`camera_view`、`locale`）
- **完整設定頁（H2 Done）：** 暫停「設定」子選單＋準備「系統工具→設定」；驗收見 [`docs/alpha/steam-productization.md`](../alpha/steam-productization.md)

## 何時可開

- 僅營運日 `restock`／`open`
- 提早關店對話開著時不可開（避免雙層對話搶輸入）

## 操作

| 操作 | 預設（InputMap／鍵） | 觸控／Web |
| --- | --- | --- |
| 開關暫停 | Esc／手把 Start（**本機雙人：任一 seat** 的 Esc／Start 皆可；見 `multiplayer.md` §11.5）。**線上（M2+）：Host 或 client 任一機**均可開／關**全房**暫停（§12.6） | HUD 右上「暫停」按鈕（`hud.pause`；線上各機有效） |
| 選擇 | `move_up`／`move_down`（預設 W／S、方向鍵、D-Pad）；左／右搖桿（暫停時輪詢，含右類比） | 點選按鈕 |
| 調音量 | 音量列上 `move_left`／`move_right`（A／D、←／→、D-Pad）；左／右搖桿左右 | 「−」「＋」 |
| 確定 | `interact`（預設 J／Enter／A） | 點選按鈕 |
| 返回（繼續） | `cancel`（預設 ;／Backspace／B） | 「繼續遊戲」 |

主畫面說明文（`pause.body`／`pause.body_suspend`）與提示小字（`pause.hint`／`pause.hint_touch`）僅在 **顯示開發用資訊**（`PlatformServices.is_show_dev_hud()`）開啟時顯示。語言／任務詳情子頁仍可顯示其自身說明。

選項（主列，H2 起）：

1. **繼續遊戲** — 解除 `get_tree().paused`，回到店舖  
2. **任務詳情** — 子畫面列出本座進行中任務（名稱【】＋描述＋進度／狀態）；返回回到暫停主列。資料來自當日 `task_hud_lines`  
3. **教學** — 子畫面列出已完成的教學單元，可重溫講解分頁（不強制練習）。契約見 `tutorial.md`  
4. **設定** — 子畫面收束下列控制（寫入既有 `user://settings.cfg`；與準備「系統工具→設定」同一套 API）：
   - **音效：開／關** — 靜音事件 SFX（不含 BGM；跨局保留）  
   - **音效聲量：N%** — 0–100%、每檔 10%；−／＋ 或 A／D；J／點中間可試聽  
   - **背景音樂：開／關** — 靜音 BGM（跨局保留）  
   - **背景音樂聲量：N%** — 0–100%、每檔 10%；−／＋ 或 A／D；J／點中間可試聽（見 `bgm.md`）  
   - **虛擬搖桿：開／關** — `[ui] virtual_stick`（預設關）。開後只在觸控活躍時顯示；手掣／鍵盤自動隱藏（見 `inputmodes-vj.md`）  
   - **鏡頭：正常／稍遠／全地圖** — 循環三種視野（見 `control.md`）。`[ui] camera_view`（`normal`｜`far`｜`overview`）。營運中亦可用 Xbox 視圖鍵／鍵盤 `V` 循環  
   - **返回** — 回暫停主列  
5. **語言** — 再開「選擇語言」子畫面；`Loc.locales()`；`[ui] locale`（預設 `zh_TW`）。見 `docs/alpha/i18n.md`  
6. **結束本日並結算** — 等同 HUD「馬上完成營運」（`skip_operate`）。**線上：僅 Host 機**可觸發；client 無此項或按下無效（`multiplayer.md` §12.6）。若有強制教學步驟未完成則擋住（見 `tutorial.md`）

工程：`scenes/pause_menu.tscn` 用 `CardBg`（NinePatch）＋ Button `StyleBoxTexture`；執行期 `_style_btn` **唔再**用 Flat 蓋皮，選中改用 focus 皮。字色／字級／間距見 [`uitypography.md`](uitypography.md)（標題 heading-sm 43＋Cocoa；說明 body／caption＋Taupe；掣 body-sm 22）；面板色見 `agents/skills/pause-ui-chrome/`。

> 手機 Web 沒有 Esc／Start：用右上「暫停」。系統掛起（切 App／鎖屏）仍會經 `PlatformServices` 自動開暫停選單。

## 線上（M2 LAN，見 `multiplayer.md` §12.6）

- **任機**開／關暫停（含「繼續遊戲」resume）→ 請求送 Host，廣播全房 `paused`；競態以 Host 最後狀態為準。
- 各機顯示暫停選單（可繼續、改音效／鏡頭／語言等本機設定）。
- Client **不可**「結束本日並結算」（選單隱藏或禁用）；HUD `skip_operate` 在 client 無效。
- Host「結束本日」→ 全房走結算；client 等日結 RPC 寫檔（角色 only，見 `savesystem.md`）。
- 結算確認後**留房回大廳**（§12.10），不因日結解散；局間「離開／關閉房間」才 `SessionService.close()`。

## 掛起／恢復

1. `NOTIFICATION_APPLICATION_PAUSED` → `PlatformServices.checkpoint()` → `suspended` → `pause_menu_requested`  
2. 暫停選單以 `from_suspend` 開啟，樹暫停，文案提示系統掛起  
3. `NOTIFICATION_APPLICATION_RESUMED` → `resumed`；**不自動繼續**，玩家按「繼續遊戲」  
4. Desktop 失焦只 checkpoint，不強制開暫停 UI  
5. 關閉視窗前 checkpoint  
6. **線上 Client** 系統掛起 → **斷線**；關視窗 → **斷線**（開日後該 seat 凍座；見 `multiplayer.md` §12.6／§12.7）。**線上 Host** 掛起 → 全房暫停（同上 Host 暫停路徑）

營運中途仍不另寫玩法存檔（見 `savesystem.md`）；checkpoint 保證既有 `user://save.json` I/O 刷完，避免掛起損檔。
