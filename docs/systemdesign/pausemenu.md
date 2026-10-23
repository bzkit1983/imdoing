# 暫停選單與掛起／恢復

- 活線：`godot/game`
- 工程：`scenes/pause_menu.tscn`、`scripts/pause_menu.gd`；掛起信號來自 Autoload `PlatformServices`
- 文案：`Loc`（`pause.*` keys；見 `docs/alpha/i18n.md`）
- 營運回合交叉：`storeoperationphase.md`
- 音效開關：`SfxBus`（設定寫入 `user://settings.cfg` → `[audio] sfx_muted`）

## 何時可開

- 僅營運日 `restock`／`open`
- 提早關店對話開著時不可開（避免雙層對話搶輸入）

## 操作

| 操作 | 預設（InputMap／鍵） | 觸控／Web |
| --- | --- | --- |
| 開關暫停 | Esc／手把 Start | HUD 右上「暫停」按鈕（`hud.pause`） |
| 選擇 | `move_up`／`move_down`（預設 W／S、方向鍵、D-Pad） | 點選按鈕 |
| 確定 | `interact`（預設 J／Enter／A） | 點選按鈕 |
| 返回（繼續） | `cancel`（預設 ;／Backspace／B） | 「繼續遊戲」 |

選項：

1. **繼續遊戲** — 解除 `get_tree().paused`，回到店舖  
2. **音效：開／關** — 切換事件 SFX（不含 BGM；狀態跨局保留）  
3. **結束本日並結算** — 等同 HUD「馬上完成營運」（`skip_operate`）

> 手機 Web 沒有 Esc／Start：用右上「暫停」。系統掛起（切 App／鎖屏）仍會經 `PlatformServices` 自動開暫停選單。

## 掛起／恢復

1. `NOTIFICATION_APPLICATION_PAUSED` → `PlatformServices.checkpoint()` → `suspended` → `pause_menu_requested`  
2. 暫停選單以 `from_suspend` 開啟，樹暫停，文案提示系統掛起  
3. `NOTIFICATION_APPLICATION_RESUMED` → `resumed`；**不自動繼續**，玩家按「繼續遊戲」  
4. Desktop 失焦只 checkpoint，不強制開暫停 UI  
5. 關閉視窗前 checkpoint  

營運中途仍不另寫玩法存檔（見 `savesystem.md`）；checkpoint 保證既有 `user://save.json` I/O 刷完，避免掛起損檔。
