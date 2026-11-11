# 匯出預設（Web + Steam 候選桌面）

- 活線專案：`godot/game`
- 設定檔：`godot/game/export_presets.cfg`（可進版控）
- 機密：`.godot/export_credentials.cfg`（勿提交；已在 `.godot/` ignore）
- Steam 多人規格：[`docs/systemdesign/multiplayer.md`](../systemdesign/multiplayer.md) §13；GodotSteam：[`godotsteam-setup.md`](godotsteam-setup.md)

## 預設一覽

| 名稱 | 平台 | 自訂 feature | 輸出 |
| --- | --- | --- | --- |
| **Web** | Web | （無） | `docs/play/index.html` |
| **Windows Desktop** | Windows Desktop | `desktop`, `steam_candidate`, `net_steam` | `build/windows/imdoing.exe` |
| **Linux** | Linux | `desktop`, `steam_candidate`, `net_steam` | `build/linux/imdoing.x86_64` |
| **macOS** | macOS | `desktop`, `steam_candidate`, `net_steam` | `build/macos/imdoing.app` |

- 架構：Win／Linux **x86_64**；macOS **universal**（arm64 + x86_64）  
- `embed_pck=false`：可執行檔與 `.pck` 分開，方便 Steam depot 分層更新  
- 排除：`fonts/source/*`（完整 Noto 重建用，不進包）  
- 渲染：專案已釘 **GL Compatibility**（見 `project.godot`），與桌面／Deck／主機友善路徑一致  

腳本可用 `OS.has_feature("steam_candidate")`／`"net_steam"`／`"desktop"` 分辨桌面 Steam 候選包（見 §13）。

## 本機匯出

1. 安裝 Godot **4.7**，並下載對應 **Export Templates**（Editor → Manage Export Templates）。  
2. 打開 `godot/game/project.godot`。  
3. Project → Export → 選預設 → Export Project。  

或命令列（在 repo 根，`godot` 指 4.7 可執行檔）：

```bash
mkdir -p build/windows build/linux build/macos
godot --path godot/game --headless --export-release "Windows Desktop" ../../build/windows/imdoing.exe
godot --path godot/game --headless --export-release "Linux" ../../build/linux/imdoing.x86_64
godot --path godot/game --headless --export-release "macOS" ../../build/macos/imdoing.app
godot --path godot/game --headless --export-release "Web" ../../docs/play/index.html
```

`build/` 底下的二進位已 gitignore；只留 `build/README.md`。

## Steam 候選（Win／Linux／macOS depot）

目前預設解決「能打出三桌面包」。接 Steamworks 時：

1. 依 [`godotsteam-setup.md`](godotsteam-setup.md) 安裝 GodotSteam（含 **macOS universal**）  
2. 開發期 `steam_appid.txt` = **480**；上架改正式 App ID  
3. 雲存檔包同一 `user://save.json` JSON（見 `docs/systemdesign/savesystem.md`）  
4. Partner depot：**Windows／Linux／macOS 各一**；可把 `.pck` 與可執行檔分 depot  
5. Steam Deck：先以 Linux x86_64 + GL Compatibility 包驗證；Verified 再補 Steam Input  
6. macOS 簽名／公證：Steam 不強制，建議在文件記錄是否公證（減少 Gatekeeper 客訴）  

**不要**為 Steam 另開 `godot/game_steam` 複本（見 `docs/versioning.md`）。
