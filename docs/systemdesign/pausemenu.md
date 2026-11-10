# 暫停選單與掛起／恢復

- 活線：`godot/game`
- 工程：`scenes/pause_menu.tscn`、`scripts/pause_menu.gd`；掛起信號來自 Autoload `PlatformServices`
- 文案：`Loc`（`pause.*` keys；見 `docs/alpha/i18n.md`）
- 營運回合交叉：`storeoperationphase.md`
- 音效設定：`SfxBus`（`user://settings.cfg` → `[audio] sfx_muted`、`sfx_volume`）
- UI 偏好：`PlatformServices`（同檔 `[ui] virtual_stick`、`camera_view`、`locale`）

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

選項：

1. **繼續遊戲** — 解除 `get_tree().paused`，回到店舖  
2. **音效：開／關** — 靜音事件 SFX（不含 BGM；跨局保留）  
3. **音效聲量：N%** — 0–100%、每檔 10%；−／＋ 或 A／D；J／點中間可試聽  
4. **虛擬搖桿：開／關** — 與準備「系統工具」共用 `[ui] virtual_stick`（預設關）。開後只在觸控活躍時顯示；手掣／鍵盤自動隱藏（見 `inputmodes-vj.md`）。Desktop 編輯器亦顯示此列方便預覽  
5. **鏡頭：正常／稍遠／全地圖** — 循環三種視野（見 `control.md`）。寫入 `user://settings.cfg` → `[ui] camera_view`（`normal`｜`far`｜`overview`，預設 `normal`）。改完繼續即套用，之後營運日沿用。營運中亦可用 Xbox 視圖鍵／鍵盤 `V` 循環（暫停開著時改由本列操作）  
6. **語言** — 先開「選擇語言」子畫面，再從 `Loc.locales()`／CSV 欄支援列表（`zh_TW`／`en`／`zh_CN`／`ja`）選一項；寫入 `[ui] locale`（預設 `zh_TW`）。主列文案為「語言：%s」，語系名用各語 **endonym**（繁體中文／English／简体中文／日本語，不隨 UI 語系翻譯）。取消／返回不改語系。與準備「系統工具」共用；選定後當頁文案即刷。見 `docs/alpha/i18n.md`  
7. **結束本日並結算** — 等同 HUD「馬上完成營運」（`skip_operate`）。**線上：僅 Host 機**可觸發；client 無此項或按下無效（`multiplayer.md` §12.6）

> 手機 Web 沒有 Esc／Start：用右上「暫停」。系統掛起（切 App／鎖屏）仍會經 `PlatformServices` 自動開暫停選單。

## 線上（M2 LAN，見 `multiplayer.md` §12.6）

- **任機**開／關暫停（含「繼續遊戲」resume）→ 請求送 Host，廣播全房 `paused`；競態以 Host 最後狀態為準。
- 各機顯示暫停選單（可繼續、改音效／鏡頭／語言等本機設定）。
- Client **不可**「結束本日並結算」（選單隱藏或禁用）；HUD `skip_operate` 在 client 無效。
- Host「結束本日」→ 全房走結算；client 等日結 RPC 寫檔（角色 only，見 `savesystem.md`）。

## 掛起／恢復

1. `NOTIFICATION_APPLICATION_PAUSED` → `PlatformServices.checkpoint()` → `suspended` → `pause_menu_requested`  
2. 暫停選單以 `from_suspend` 開啟，樹暫停，文案提示系統掛起  
3. `NOTIFICATION_APPLICATION_RESUMED` → `resumed`；**不自動繼續**，玩家按「繼續遊戲」  
4. Desktop 失焦只 checkpoint，不強制開暫停 UI  
5. 關閉視窗前 checkpoint  
6. **線上 Client** 系統掛起 → **斷線**；關視窗 → **斷線**（開日後該 seat 凍座；見 `multiplayer.md` §12.6／§12.7）。**線上 Host** 掛起 → 全房暫停（同上 Host 暫停路徑）

營運中途仍不另寫玩法存檔（見 `savesystem.md`）；checkpoint 保證既有 `user://save.json` I/O 刷完，避免掛起損檔。
