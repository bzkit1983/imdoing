# 版本控制策略（Alpha v0.1 → v1.0+）

- **目的：** 保留可玩的 Alpha v0.1，之後所有 issue／功能只在一條主線上推進，不再整包複製 Godot 專案。
- **對照：** 技術债與平台清單見 `docs/alpha/tech-review-v0.1.md`。
- **拍板日：** 2026-10-21

## 一句話

**目錄裡的 Alpha 凍結當文物；Git tag 當發布錨點；程式只養一個活專案 `godot/game`（自 v1.0 起）。**

## 現在的產品版

| | |
| --- | --- |
| **現行產品 SemVer** | **`v1.0.0`**（Git tag；權威；2026-10-22 重錨後 `main` 續合丟掉上架／丟掉砸小偷／Pages，約 PR #21–#39） |
| 對齊字串 | repo 根目錄 [`VERSION`](../VERSION)；`godot/game/project.godot` `config/version`；`scripts/product_version.gd`；Windows 匯出 `export_presets.cfg` |
| 存檔格式版 | `game_state.SAVE_VERSION`（整數，與 SemVer **分開**） |
| 查詢 | `git tag -l 'v*'` · `git describe --tags --exact-match`（恰在 tag 上時） · `git rev-parse v1.0.0^{}` |

誰改號：負責人依下方 SemVer 規則決定後，在 `main` **打／推 tag**，並同步改 `VERSION` 與上表字串（同一 PR 或發佈當下）。合併功能 PR **不會**自動升版。

---

## 1. 三層「版本」不要混用

| 層 | 記在哪 | 用途 |
| --- | --- | --- |
| **產品版本** | Git tag / GitHub Release（`v1.0.0`） | 給玩家、商店、Pages 連結看的號 |
| **活工程** | 單一目錄 `godot/game` | 唯一持續改的 Godot 專案 |
| **歷史快照** | 凍結目錄 + tag | 可重播舊體驗，但**不再開新功能** |

過去的 `godot/demo_v0_*`、`godot/alpha_v0_1` 屬於歷史快照。  
v1.0 起**禁止**再新增 `godot/v1_0`、`godot/v1_1` 這類整包複本。

---

## 2. 從 Alpha 接到 v1.0 的一次動作

做一次分叉即可，之後只往前推：

```text
godot/alpha_v0_1/   ← 永遠凍結（可玩、可對照、可開 Pages）
        │
        │  複製一次（僅此一次）
        ▼
godot/game/         ← v1.0 起唯一活線；所有 issue 改這裡
```

建議步驟：

1. **Git tag 凍結 Alpha**（在現在 `main` 上打）  
   - 標籤名：`alpha-v0.1`  
   - GitHub Release 說明：對應 Pages `play-alpha-v01/`，目錄 `godot/alpha_v0_1`
2. **複製** `godot/alpha_v0_1` → `godot/game`（或 `git mv` 若團隊同意只留一份活線；若要「目錄仍看得到 alpha」就用複製）
3. 改 `godot/game/project.godot` 的 `config/name` 為產品名／`imdoing v1`（開發中可用 `imdoing`）
4. 之後 **所有 PR 只動 `godot/game`**（外加 `docs/`、`tools/`）；碰 `alpha_v0_1` / `demo_v0_*` 僅限修 Pages 連結或明顯壞掉的靜態展示

> 若暫時不想改路徑：也可短期繼續改 `alpha_v0_1`，但必須先打 `alpha-v0.1` tag，並約定「tag 之後的 commit 都算 v1 開發」。目錄改名只是比較不容易誤改文物。

---

## 3. Git 分支怎麼用

| 分支 | 用途 |
| --- | --- |
| `main` | 唯一主線；隨時可匯出試玩；**不要**長期分 `main-alpha` / `main-v1` |
| `cursor/…` 或 `feat/…` | 單一 issue／小功能；短命，合併後刪 |
| `release/x.y` | **可選**；只有要同時熱修舊版（例如商店已上 `1.0` 又在做 `1.1`）才開 |

原則：

- 功能用 **feature branch → PR → main**，不用「新開整個專案目錄」當分支。  
- 平台差異（Steam／Switch／Xbox）用 **匯出預設 + `PlatformServices` + feature flag**，不用 `godot/game_switch` 複本。

---

## 4. Tag 與號號（建議 SemVer）

格式：`vMAJOR.MINOR.PATCH`

| 變哪個 | 何時 |
| --- | --- |
| **MAJOR** | 存檔不相容、大幅砍循環、或商店認定的世代（例如 1→2） |
| **MINOR** | 新系統／可玩內容（COMBO、事件、店員擴充…）；存檔仍能升 |
| **PATCH** | bugfix、數值小調、不改存檔形狀 |

命名約定：

| 標籤 | 意義 |
| --- | --- |
| `alpha-v0.1` | 凍結的 Alpha 文物（已存在之可玩狀態） |
| `v1.0.0` | 第一個「依 tech-review issue 清單收斂」的可玩里程碑 |
| `v1.1.0`、`v1.2.0`… | 之後內容／系統增量 |
| `v1.0.1` | 只修 `v1.0.0` 的缺陷 |

開發中未發布可用：

- 專案內顯示：`1.0.0-dev`  
- 或 GitHub Pre-release：`v1.0.0-rc.1`

**存檔 JSON 必含 `version` 欄**（整數或 semver 字串），與產品 tag 分開演進；升級時寫 migration，不要靠複製舊專案躲相容問題。

---

## 5. GitHub 上怎麼跟 issue

| 工具 | 用法 |
| --- | --- |
| **Milestone** | `v1.0`、`v1.1`… 對應產品小版本；tech-review checklist 先全部掛 `v1.0` 再拆出延後項 |
| **Label** | `platform` / `perf` / `tech-debt` / `gameplay` / `docs` |
| **Issue** | 一張一件事；PR 用 `Fixes #n` 連回去 |
| **Project（可選）** | 看板：Todo / Doing / Done |

v1.0 Milestone 建議直接收錄 `docs/alpha/tech-review-v0.1.md` §6 跟進清單，完成即具備「可連續開發的產品骨架」，不必等 Steam／主機真的送審。

---

## 6. 文件與 Pages 怎麼跟版本走

| 內容 | 策略 |
| --- | --- |
| `docs/alpha/*` | Alpha 時代文件；可補「已凍結」一句，之後少改 |
| `docs/systemdesign/*` | **長線真相**；v1+ 規則變更寫回這裡 |
| `docs/versioning.md` | 本檔；版控規則 |
| 發行說明 | 每個 GitHub Release 寫「相對上一 tag 玩家可見變更」 |
| Pages | `play-alpha-v01/` **凍結**；活線 v1 試玩為 `docs/play/`（由 `godot/game` Web 匯出） |

不要為每個 minor 複製一份 `docs/` 樹；要用「設計檔持續更新 + Release notes 記歷史」。

---

## 7. 明確不要做的事

1. 不要再 `cp -r godot/game godot/v1_1` 開新版。  
2. 不要用長期分支代替版本（例如永遠不合併的 `v1-branch`）。  
3. 不要讓 Web、Steam、Switch 各養一份玩法腳本。  
4. 不要改 `godot/alpha_v0_1` 來做 v1 功能（除非只修展示壞掉）。  
5. 不要把「Demo 數字」和「長線 systemdesign」混成兩套都在改的真相。

---

## 8. 建議的近期操作順序

1. ~~在 `main` 打 tag `alpha-v0.1`~~ **已做**（凍結 Alpha 可玩狀態）。  
2. ~~建立 `godot/game`（自 `alpha_v0_1` 複製一次）~~ **已做**；`demo_v0_*`／`alpha_v0_1` 已放 `FROZEN.md`，見 `godot/README.md`。  
3. 把 tech-review §6 checklist 建成 Issues，全掛 Milestone `v1.0`。  
4. ~~存檔~~ **已做**；~~InputMap~~ **已做**（Autoload `Controls`）；~~`PlatformServices` stub~~ **已做**；~~暫停選單＋掛起鉤子~~ **已做**；~~Win／Linux 匯出預設~~ **已做**（`docs/alpha/export-presets.md`）；~~字串表 i18n~~ **已做**（`docs/alpha/i18n.md`）；~~主機商務評估~~ **已做**（`docs/alpha/console-business.md`）；~~Godot／middleware 釘版~~ **已做**（`docs/alpha/godot-middleware-pin.md`：桌面 4.7，主機對齊 W4 表）。接著：Steamworks／內容與 v1.0 里程碑收尾等。  
5. ~~Web 匯出到 Pages `docs/play/`~~ **已做**。~~打 `v1.0.0`~~ **已做**（2026-10-22 將 tag **重錨**到含掉貨瞄準、小偷 KO／散落、離店可抓、得手橫幅、客人離店不卡門與對應 Pages 的 `main`；其後合入方向丟掉上架、丟掉砸小偷 KO、Pages 再匯出，約 PR #21–#39）。之後內容／系統進 `v1.1` Milestone；熱修打 `v1.0.x`。

長線設計對應：存檔 → `savesystem.md`；操作 → `control.md`；準備／營運回合已交叉連到上述檔。

---

## 9. 目錄目標長相（穩定後）

```text
godot/
  demo_v0_*/          # 凍結文物（可選：日後移到 archive/）
  alpha_v0_1/         # 凍結文物 + Pages play-alpha-v01
  game/               # 唯一活線（v1.0+）
docs/
  alpha/              # Alpha 計劃／審查（歷史）
  systemdesign/       # 長線規則（持續更新）
  versioning.md       # 本策略
```

團隊查「現在該改哪裡？」→ **永遠是 `godot/game`。**  
查「Alpha 當初長怎樣？」→ **目錄 `alpha_v0_1` + tag `alpha-v0.1`。**
