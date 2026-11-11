# GodotSteam 接入（M3）

- 對齊：[`docs/systemdesign/multiplayer.md`](../systemdesign/multiplayer.md) §13
- 活線：`godot/game`（Godot **4.7**）
- 開發 App ID：**480**（Spacewar）— 見 `godot/game/steam_appid.txt`
- **已釘版：** GodotSteam GDExtension **4.24**（Steamworks 1.65）→ `godot/game/addons/godotsteam/`（見該目錄 `VERSION.txt`）

## 安裝（本機）

Repo **已含** GDExtension 外掛（Win／Linux／macOS universal／Android）。若需重裝：

1. 自 [Godot Asset Library #2445](https://godotengine.org/asset-library/asset/2445) 或 [GodotSteam releases](https://codeberg.org/godotsteam/godotsteam/releases) 取得 **4.24 GDExtension**（Godot 4.4+）。  
2. 解壓使路徑為 `godot/game/addons/godotsteam/`（含 `godotsteam.gdextension`）。  
3. Editor 外掛已在 `project.godot` `[editor_plugins]` 啟用（僅更新器；Steam class 由 GDExtension 載入，不必另加 Autoload）。  
4. 本機開啟 **Steam 客戶端並登入**；專案根有 `steam_appid.txt` = `480`。  
5. 跑煙測：`./tools/m3_steam_smoke.sh`  
   - 期望：`steam_available` OK、LAN host OK。  
   - 若無 Steam 客戶端：`host_steam` 會 **SKIP**（`steam_not_running`），屬正常。  
6. F5：Prep 確認頁有 **Steam 開房／加入**；Steam 已登入時開房應得到非 0 Lobby ID。

未安裝／未載入時：`host_steam`／`join_steam_lobby` 回傳 `steam_unavailable`；Steam 未開則 `steam_not_running`。LAN 路徑不受影響。

## 雙帳邀請驗收（§13.4 主路徑）

本機需 **Steam 已登入** + **第二 Steam 帳或第二裝置**：

1. **Host（帳 A）**：Prep → Steam 開房（本機 seat 1｜2）→ 記下 Lobby ID（或 Overlay 邀請好友）。  
2. **Join（帳 B）**：Prep → 加入 Steam → 輸入 Lobby ID → claim 1｜2（claim2 需訪客存檔）。  
3. 雙方 ready → Host 開日 → 打完一日：Intent／暫停／凍座／日結。  
4. 可選跨平台：Mac↔Win／Linux 匯出包（[`export-presets.md`](export-presets.md)）。

## 上架

- Steam Direct 取得正式 App ID 後，改 `steam_appid.txt`／匯出設定，**勿**把成就／Cloud 綁死在 480。  
- Depot：**Windows + Linux + macOS**（見 `docs/alpha/export-presets.md`）。

## 不要

- 不要為 Steam 複製 `godot/game_steam`（見 `docs/versioning.md`）。  
- 不要在 Web 包啟用 `net_steam`。
