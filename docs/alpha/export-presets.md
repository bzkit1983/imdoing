# 匯出預設（Web + Steam 候選桌面）

- 活線專案：`godot/game`
- 設定檔：`godot/game/export_presets.cfg`（可進版控）
- 機密：`.godot/export_credentials.cfg`（勿提交；已在 `.godot/` ignore）

## 預設一覽

| 名稱 | 平台 | 自訂 feature | 輸出 |
| --- | --- | --- | --- |
| **Web** | Web | （無） | `docs/play/index.html` |
| **Windows Desktop** | Windows Desktop | `desktop`, `steam_candidate` | `build/windows/imdoing.exe` |
| **Linux** | Linux | `desktop`, `steam_candidate` | `build/linux/imdoing.x86_64` |

- 架構：x86_64  
- `embed_pck=false`：exe／binary 與 `.pck` 分開，方便之後 Steam depot 分層更新  
- 排除：`fonts/source/*`（完整 Noto 重建用，不進包）  
- 渲染：專案已釘 **GL Compatibility**（見 `project.godot`），與桌面／Deck／主機友善路徑一致  

腳本可用 `OS.has_feature("steam_candidate")`／`"desktop"` 分辨桌面候選包（尚未接 GodotSteam）。

## 本機匯出

1. 安裝 Godot **4.7**，並下載對應 **Export Templates**（Editor → Manage Export Templates）。  
2. 打開 `godot/game/project.godot`。  
3. Project → Export → 選預設 → Export Project。  

或命令列（在 repo 根，`godot` 指 4.7 可執行檔）：

```bash
mkdir -p build/windows build/linux
godot --path godot/game --headless --export-release "Windows Desktop" ../../build/windows/imdoing.exe
godot --path godot/game --headless --export-release "Linux" ../../build/linux/imdoing.x86_64
godot --path godot/game --headless --export-release "Web" ../../docs/play/index.html
```

`build/` 底下的二進位已 gitignore；只留 `build/README.md`。

## Steam 候選（尚未接 Steamworks）

目前預設只解決「能打出 Windows／Linux 包」。之後接 Steam 時建議：

1. 用 GodotSteam（或官方方案）做 **Steam** backend，掛在既有 `PlatformServices` 後  
2. 雲存檔包同一 `user://save.json` JSON（見 `docs/systemdesign/savesystem.md`）  
3. Depot 建議：Windows／Linux 各一；可把 `.pck` 與可執行檔分 depot  
4. Steam Deck：先以本 Linux x86_64 + GL Compatibility 包驗證；Verified 再補 Steam Input／暫停（暫停已接 `pausemenu.md`）  

**不要**為 Steam 另開 `godot/game_steam` 複本（見 `docs/versioning.md`）。
