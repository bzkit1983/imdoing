# 版本控制策略（Alpha v0.1 → v1.0+）

- **目的：** 保留可玩的 Alpha v0.1，之後所有 issue／功能只在一條主線上推進，不再整包複製 Godot 專案。
- **對照：** 技術評估見 `docs/alpha/tech-review-v0.3.md`（現行）；前一輪 `docs/alpha/tech-review-v0.2.md`；v0.1 歷史清單見 `docs/alpha/tech-review-v0.1.md`。
- **巨石合併紀律（L4）：** 改 `demo.gd`／`player.gd`／`skill_caster.gd` 且淨增時，見 [`docs/alpha/monolith-merge-gate.md`](alpha/monolith-merge-gate.md)。
- **拍板日：** 2026-10-21

## 一句話

**目錄裡的 Alpha 凍結當文物；Git tag 當發布錨點；程式只養一個活專案 `godot/game`（自 v1.0 起）。**

## Early Access／現行產品範圍（2026-11-27 更新）

- **2026-11-27 決議（Jackson）：** EA 劇情進程＝**序章 → 第1章 → 第2章（破局）→ 自選一章（EA 期間只有安桃山可選）**。此決議**取代** 2026-11-18 H3「EA＝純日循環、不做章節 runtime」。
- **同日決議（Jackson）：** 遊戲**先以付費 Steam Early Access 上市**（劇情範圍同上）。另定義**免費 Demo**，範圍是付費 EA 的子集＝**序章 + 第1章**（第1章通關後停下，不進破局／選章／安桃山）。**暫不含多人**（專用多人體驗另議）。**Demo 存檔不轉入付費 EA**（須獨立路徑／槽或標記，避免 EA 誤讀）。結束畫面引導願望單或直接購買。詳見 [`steam-productization.md`](alpha/steam-productization.md)。
- **同日再決（Jackson，設計問題 1–10）：**
  - **正式／EA／Demo 組建沒有劇本選擇。** 現有全部劇本（含 5–10 等）皆為**測試內容／沙盒**。開始遊戲直接進入正式劇情模式，並以**邊玩邊學的體驗式教學**織入進程。先前「Demo 含教學（劇本 5）」**改為**：Demo 含上述**劇情內體驗式教學**，**不是**劇本 5（特此標註更正）。
  - 選章畫面**會顯示其他主題**，但 EA **只能選安桃山**（其餘可見但鎖定）。**六主題劇情都會寫**；其餘五主題正文仍不排 EA 活線（寫作時程未另決）。
  - 打完安桃山後，EA **繼續進入日循環**（營運、儲錢、累積經驗）；**可能設進度上限**，以免正式版更新時進度超前（上限數字 **TBD**）。
  - 打完安桃山後 **可開分店**（不再把分店整體暫緩）。
  - 第1、2章 **需要事件系統**。
  - 資金門檻暫時採用成長分析建議值，最終再調。劇本 6 頭目**純測試**，**不要原樣复用作正章頭目**；各章頭目 TBD。
  - **失敗（同日放寬 2026-11-18 H3「不做失敗／過關敘事層」）：** 失敗可令事件或劇情任務無法達成，變相擋劇情推進，但**不阻擋營運日結算**。原因：正式劇情需要可用失敗擋關，但不能中斷日循環結算。
- **範圍內（付費 EA）：** 可連線的動作經營**日循環**（準備 → 補貨 → 營運 → 結算）、技能、評價、中期美術、Steam／LAN／本機多人（至 M3）；上列 EA 劇情進程（對照見 [`storysystem.md`](systemdesign/storysystem.md)）；**劇情內體驗式教學**；第1／2章所需**事件系統**；打完安桃山後的**分店**：
  - 序章＝`prologue`（正式開局走進劇情模式，無劇本選擇。活線劇本 **8** `SCENARIO_PROLOGUE` 的內容閘／經濟可作測試參考，本身是測試入口，對白後補）
  - 第1章＝`chapter_01`（概念開檔，內容 **TBD**；資金門檻暫用分析值；需要事件系統）
  - 第2章（破局）＝`chapter_02`＋固定主題 `theme_break`（概念開檔，內容 **TBD**；需要事件系統）
  - 自選一章＝可選主題 `theme_historic`（安桃山；玩法／id 已定稿，劇本／頭目細則後補）。依現有選章模型，破局後綁入下一空槽（預期 `chapter_03`）。選章畫面顯示六主題，僅安桃山可選、其餘可見鎖定。劇本 **9／10** 與其他現有劇本皆為**測試沙盒**，不是正式入口。
- **免費 Demo：** 僅序章＋第1章（與付費 EA 共用同一套內容至第1章結束），並含**劇情內體驗式教學**（**不是**劇本 5）；暫不含多人。正式 Demo **無劇本選擇**。商店頁／結束畫面導流、獨立 App ID／匯出、**分離存檔**與 Steam Next Fest 注意事項見 [`steam-productization.md`](alpha/steam-productization.md)；實作見 issue。
- **範圍外（EA 與 Demo 都不做；留 Beta／之後）：** 其餘五個可選主題的活線正文、終章／後日談、完整十章選章、完整事件表（第1／2章所需事件 runtime 已列入 EA）、技能解鎖表、長線流量定稿。可重玩當日與資金保留仍依現有結算規則。進度上限數字尚未定。
- **劇情閘門（N1）：** EA 所需的 `story_slot` 狀態機、顯示六主題但僅安桃山可選的選章畫面、第1／2章內容（含事件系統）、打完安桃山後的分店與續日循環、官方組建無劇本選擇與體驗式教學，現為**已核准的 EA 範圍**（實作另開 issue）。Demo 另需第1章結束後的內容閘（不進第2章）。完整十章與其餘五主題活線、終章仍設計先行。勿把其餘主題正文／終章當成已核准工單。
- 對照：[`docs/alpha/design.md`](alpha/design.md)、[`docs/alpha/tech-review-v0.3.md`](alpha/tech-review-v0.3.md)（H3 原文見 [`tech-review-v0.2.md`](alpha/tech-review-v0.2.md)；已被本決議取代）、[`docs/beta/design.md`](beta/design.md)。

## 現在的產品版

| | |
| --- | --- |
| **現行產品 SemVer** | **`v1.5.0`**（中期美術：非玩家體素、補貨架高度對齊貨架、具象貨品圖、技能臨時圖、準備回合排版。不是最終美術定案。見 `systemdesign/art-interim-v1.5.md`）。上一錨點 **`v1.4.0`**（全單位改「件」）。字串與 `VERSION`、`project.godot`、`product_version.gd` 對齊。`SAVE_VERSION` **現行 9**（與 SemVer **分開**；見 `game_state.gd`／[`savesystem.md`](systemdesign/savesystem.md)）。`v1.5.0` 發佈時存檔格式為 4，其後同產品字串內升至 9（5 商品培養、6 創世問答、7 序章內容閘、8 魚缸／釣魚、9 精英店員）。Git tag `v1.5.0` 已打在 `main`；功能分支不打 tag。 |
| 對齊字串 | repo 根目錄 [`VERSION`](../VERSION)；`godot/game/project.godot` `config/version`；`scripts/product_version.gd`；Windows 匯出 `export_presets.cfg` |
| 存檔格式版 | `game_state.SAVE_VERSION`（整數，與 SemVer **分開**；**現行 9**，演進見 [`savesystem.md`](systemdesign/savesystem.md)） |
| 查詢 | `git tag -l 'v*'` · `git describe --tags --exact-match`（恰在 tag 上時） · `git rev-parse v1.1.0^{}` |

誰改號：負責人依下方 SemVer 規則決定後，在 `main` **打／推 tag**，並同步改 `VERSION` 與上表字串（同一 PR 或發佈當下）。合併功能 PR **不會**自動升版。

---

## 1. 三層「版本」不要混用

| 層 | 記在哪 | 用途 |
| --- | --- | --- |
| **產品版本** | Git tag / GitHub Release（現行為字串 `v1.5.0`；origin 已發佈的 `v*` tag 為 `v1.0.0`、`v1.1.0`、`v1.5.0`） | 給玩家、商店、Pages 連結看的號 |
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
4. ~~存檔~~ **已做**；~~InputMap~~ **已做**（Autoload `Controls`）；~~`PlatformServices` stub~~ **已做**；~~暫停選單＋掛起鉤子~~ **已做**；~~Win／Linux／macOS 匯出預設~~ **已做**（`docs/alpha/export-presets.md`）；~~字串表 i18n~~ **已做**（`docs/alpha/i18n.md`）；~~主機商務評估~~ **已做**（`docs/alpha/console-business.md`）；~~Godot／middleware 釘版~~ **已做**（`docs/alpha/godot-middleware-pin.md`：桌面 4.7，主機對齊 W4 表）；~~M3 Steam §13.4 驗收~~ **已做**（2026-11-11）。接著：正式 App ID／Cloud／內容與 v1.0 里程碑收尾等。
5. ~~Web 匯出到 Pages `docs/play/`~~ **已做**（持續以 Pages PR 刷新 `docs/play/`）。~~打 `v1.0.0`~~ **已做**（2026-10-22 重錨；其後約 PR #21–#39）。~~打 `v1.1.0`~~ **已做**（2026-10-22：錨在含 Runtime P1＋P2 熱路徑優化的 `main`／PR #42；版號字串同步本檔與 `VERSION`）。其後活線熱修仍掛在已發佈的 `v1.1.0` tag 之後。**v1.2.0**（2026-10-26 起）：產品字串改為 `1.2.0`；客人貨品交付（`customerdelivery.md`）已實作；其後同版字串內再加自訂技能組、互動發光、三招狙擊手（貨架／客人／小偷；同時生效優先序小偷 → 客人 → 貨架）。未另打 `v1.2.0` Git tag。~~升產品字串 `v1.3.0`~~ **已做**（2026-11-02：改「件」單位前的可玩錨點；origin **未見** `v1.3.0` Git tag）。~~升 `v1.4.0`~~ **已做**（全單位改「件」：倉庫／採購／執貨／負重／掉貨／退倉；當時 `SAVE_VERSION` 2；origin **未見** `v1.4.0` Git tag）。~~打 `v1.5.0`~~ **已做**（中期美術，見 `systemdesign/art-interim-v1.5.md`：非玩家 Q 版、地板牆污物、貨品同一剪影、技能臨時圖、準備回合排版。產品字串 `1.5.0`；**發佈當時** `SAVE_VERSION` 維持 4。tag 錨在 #134 合併後的 `main`）。其後產品字串仍為 `1.5.0`，存檔格式已升至 **`SAVE_VERSION` 9**（見 `savesystem.md`）。

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
