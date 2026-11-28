# 技術評估 v0.4（可持續／效能／遊戲設計／平台；現行）

- **範圍：** 活線 `godot/game`（Godot **4.7** · 產品 **`v1.5.0`**）；設計以 `docs/systemdesign/` 為準
- **對照 tip：** `origin/main` @ `cf016822`（2026-11-27 23:56 UTC；評估日 2026-11-28）
- **前一輪：** [`tech-review-v0.3.md`](tech-review-v0.3.md)（2026-11-20，`f301053f` · 當時 `SAVE_VERSION` 4）
- **並行證據：** [`implementation-status.md`](implementation-status.md) · [`monolith-merge-gate.md`](monolith-merge-gate.md) · [`runtime-perf-audit.md`](runtime-perf-audit.md) · [`steam-productization.md`](steam-productization.md) · [`ci-local.md`](ci-local.md) · [`branchstore.md`](../systemdesign/branchstore.md) · [`eventsystem.md`](../systemdesign/eventsystem.md) · [`versioning.md`](../versioning.md)
- **目標平台：** Steam（付費 Early Access 先上；免費 Demo＝序章＋第1章）· Nintendo Switch · Xbox（及現行 Web 試玩）
- **性質：** 工程＋產品可交付性評估；**非**玩法規格。玩法仍以 `docs/systemdesign/` 為準。
- **量測方式：** §1 數字皆在本 tip 以指令實測（`find`／`wc`／`grep`／`git rev-list`／`du`），並以 `git archive f301053f` 在同一方法下重量 v0.3 作對照；**未量測**的項目明寫「未量測」，不由推估補數字。本機 clone 為 shallow（總 commit 101），區間 `f301053f..HEAD` 可正確計數。

## 總評

v0.3 的 L1–L4（`demo`／`skill_caster`／UI 瘦身＋合併門禁）**已兌現並被守住**，且本週再把 `demo.gd` 壓到 **3608**、`player.gd` 壓到 **2897**（#148／#175）。**但整體 GDScript 量 +35%，且重量轉移到沒有門禁的檔：`game_state.gd` 1699→2939、`prep_menu.gd` 2983→3510、`prep_pages.gd` 1406→2036、`customer.gd` 2169→2737。** 六大檔合計 17,533→17,727 行（+194），所以「抽出」改善了誰擔責，沒有改善總體積。

產品方向本週大幅收斂（11/27 決議：付費 EA 先上，序章→第1章→第2章（破局）→選章只能選安桃山，再開分店並續日循環；Demo＝序章＋第1章；正式版無劇本選擇；失敗可擋事件／劇情、不擋日結算；多人延後重設計）。**最大風險由「巨石回脹」轉為「EA 關鍵路徑零實作＋回歸網偏薄」**：章節狀態機、事件系統、第1／2章內容、選章、Demo 組建、正式 App ID 都還是 open issue，而本週三次 Godot 解析／執行期錯誤都不是靜態 CI 抓到的。

| 面向 | v0.3 → v0.4 | 一句話 |
| --- | --- | --- |
| 可持續開發 | 🔴→🟡 | `demo`／`player` 達標；體積移到 `game_state`／`prep_*`／`customer`，無門禁 |
| 執行期效能 | 持平 | 本輪未重跑任何效能量測；Deck／Switch 實機列仍空；新增 6 個小遊戲場景與分店結算為新壓力源 |
| 平台／上架 | 持平 | 決議更清楚（EA／Demo／Next Fest），執行為零：**App ID 仍 480** |
| 遊戲設計標準 | 內容加厚，EA 路徑未落地 | 序章／頭目日／小遊戲／精英店員／分店切片進活線；難度倍率、事件系統、章節機未做 |
| 多人 | 略降 | 修了 Host 權威（#143）但已決議延後重設計（#167）；分店結算未對多人設守衛 |
| 工程信頼 | 略降→補 | 審查當日 CI 只有 `static-tests`；**Q1／#154 其後已加 `godot-checks`**；本週數次解析／型別錯誤曾靠實跑才發現 |

### 分數卡（業界獨立／中小型工作室標尺 · 10 分制）

| 維度 | v0.3 | **v0.4** | 依據摘要 |
| --- | --- | --- | --- |
| **A. 架構與可持續** | 5.0 | **5.5** | `demo` 5414→3608、`player` 3862→2897、`skill_caster` 已 <1000；但 `game_state` +73%、`prep_menu`／`prep_pages`／`customer` 續增；`call`／`has_method` 675→938 |
| **B. 效能與擴展** | 7.5 | **7.5** | 本輪**未量測**；J1 基線沿用；Deck／Switch 實機仍空；新壓力源未驗 |
| **C. 工程質素／測試** | 7.0 | **6.5** | 靜態 CI 仍在、測試數小增；但 `godot-checks` 未進 CI，本週多次 parse／typed 錯誤（見 §2）靠實跑才抓到；#149 回歸未做 |
| **D. 內容管線** | 7.5 | **7.5** | 安桃山歷史主題美術、客人皮膚、6 個小遊戲場景、字型子集重建；`art` 58→85MB、`fonts/ZenMaruGothic` 19MB 未見引用 |
| **E. 平台就緒** | 6.0 | **6.0** | App ID 仍 480（`steam_appid.txt`、`net_transport.gd`）；Demo／Next Fest 已調研入 `steam-productization.md`，#152／#166 未動 |
| **F. 多人／網路** | 7.5 | **7.0** | `@rpc` 22→23；#143 修 Host 權威；多人決議延後重設計（#167）；分店結算呼叫處無多人守衛 |
| **G. 遊戲設計完整度** | 7.0 | **7.5** | 序章／頭目日／分店垂直切片／精英店員／XP 至 LV99 進活線；EA 必要的章節機（#161）、事件系統（#172）、難度倍率（#151）仍缺 |
| **H. 文件／流程** | 8.5 | **8.5** | 11/27 多輪對齊（SAVE_VERSION、實作狀態、EA／Demo 範圍）、issue #161–#172 已拆；v0.3 多項結論被決議取代（見其勘誤） |
| **綜合（等權）** | ~7.0 | **~7.0** | **分數持平：架構止血（+0.5）被回歸網（−0.5）與多人（−0.5）抵銷，內容／設計（+0.5）補回。上架路徑清楚，但實作尚未開始** |

---

## 1. 相對 v0.3 的變化（證據）

自 `f301053f` → `cf016822` 共 **89** commits（2026-11-20 → 2026-11-27）。

| 指標 | v0.3（tip） | v0.4（本 tip） | 解讀 |
| --- | --- | --- | --- |
| 產品 SemVer | `v1.5.0` | **`v1.5.0`** | 未變 |
| `SAVE_VERSION` | 4 | **10** | 一週內 +6（分店切片＝10）；#165 將再升一次 |
| GDScript 行數（`godot/game`，不含 `addons`） | 41,261 | **55,940** | ≈ **1.36×**；161 個 `.gd` |
| ≥1000 行腳本 | 10 | **9** | 見下列 |
| `demo.gd` | 5414 | **3608** | 閘門 ≤3900 ✅（#148 目標 <3700 ✅） |
| `player.gd` | 3862 | **2897** | #175 目標 <3000 ✅ |
| `prep_menu.gd` | 2983 | **3510** | +527；**無門禁** |
| `game_state.gd` | 1699 | **2939** | +1240（+73%）；分店／主題店／精英指派／存檔欄 |
| `prep_pages.gd` | 1406 | **2036** | +630 |
| `customer.gd` | 2169 | **2737** | +568 |
| 其他 ≥1000 | `pause_menu` 1683、`hud` 1409、`skill_caster` 1227、`session_service` 1155 | `hud` **1480**、`pause_menu` **1422**、`session_service` **1173**；`skill_caster` <1000 | L2／L3 持續有效 |
| 六大檔合計 | 17,533 | **17,727** | +194：搬走的量被別的檔吃回 |
| `call`／`has_method`（`call(`＋`has_method(` 行數） | 675 | **938** | +39%；`demo` 230→**146**、`player` **78**、`customer` **54**（本輪量） |
| `@rpc` | 22 | **23** | 仍集中 `session_service` |
| Autoload | 9 | **9** | 未變 |
| 自動化測試 | 45× `test_*`（38 py＋7 cjs）＋18× `*_check.gd` | **46× `test_*`（39 py＋7 cjs）＋18× `*_check.gd`** | 測試數幾乎持平，而程式 +35% |
| CI | `static-tests` | **仍只有 `static-tests`** | `godot-checks` 從未進 `ci.yml`；另加本地 pre-push 閘門（`c8c778e`） |
| `.tscn`（專案場景，不含 addon） | 8 | **14** | +6：`bun_duel`、`cashier_duel`、`dasher_trial`、`hoop_ace_trial`、`metal_rush_trial`、`swiss_lung_trial` |
| 活線磁碟（`godot/game`） | ~180MB | **~235MB** | `art` 58→85、`audio` 24→32、`fonts` 3→22（`fonts/ZenMaruGothic` 19MB，`.gd`／`.tres`／`project.godot` 內未見引用；其他資源檔**未查**）、`addons` ~93 |
| Steam App ID | 480 | **480** | `steam_appid.txt`＝480；`net_transport.gd` `STEAM_TEST_APP_ID := 480` |
| 子目錄行數（`.gd`） | — | `host` 5445、`player` 4967、`prep` 6467、`session` 4811、`tutorial` 1874 | v0.3 同口徑**未量測** |

本週重要內容（來自 commit log）：

- **#173／#176** 分店垂直切片與結算跟進：`session/branch_state.gd`（209）、`branch_rules.gd`（136）、`host/branch_settle.gd`（326）；劇本 11。
- **#148** `host/day_begin.gd`、`early_close.gd` 自 `demo` 抽出；**#175／#177** `player/` 新增 `input_controller`、`work_ticker`、`interact_controller`、`checkout_controller`、`frame_ticker`、`player_view` 等控制器。
- **#178** `day_begin` 把 `[]` 指定給 typed `Array[int]` 造成執行期錯誤，已修。
- 序章／頭目日（劇本 6，測試用）、精英店員（#146）、安桃山歷史主題＋熟食檔＋釣魚、自助收銀、傳送門、Hoop Ace／Metal Rush／Dasher／Bun Duel／Cashier Duel／Swiss Lung 小遊戲、XP 曲線至 LV99、Ambient Peek 操作、Host 權威修正（#143）。

### 現況架構（簡圖）

```text
SessionService / SeatTable / InteractLock / NetTransport / TaskTracker
        │
        ▼
demo.gd（GameHost · 3608）──── 日循環 · 結算 · 相位
        │
        ├─ host/    world_build · net_world · day_settle · day_begin · early_close
        │           branch_settle · skill_* · ops_world · boss_world · cooked_world（~5.4k）
        ├─ player.gd（2897）── 調度／狀態
        │     └─ player/  input · work_ticker · interact · checkout · frame_ticker
        │                 player_view · fight · toss · skill_* 族（~5.0k）
        ├─ customer.gd（2737）── AI · 小偷 · Elite
        ├─ game_state.gd（2939）── 存檔 v10 · 主題店／分店 · 精英指派   ← 新熱點
        ├─ prep_menu（3510）+ prep/prep_pages（2036）+ 小遊戲場景        ← 新熱點
        ├─ pause_menu（1422）+ hud（1480）+ tutorial/*
        ├─ session/ branch_state · branch_rules · task_* · seat_table …
        └─ PlatformServices → desktop | steam（Cloud／成就已接；正式 ID 未換）
```

**值得保留：** v0.3 所列＋ **`monolith-merge-gate` 在 `demo`／`skill_caster` 上確實有效**、`player/` 控制器模式、`host/branch_settle` 的「結算抽出」做法、本地 pre-push CI 閘門、#161–#172 的 EA 拆票。

**主要風險：**

1. **EA 關鍵路徑零實作**：章節機（#161）、第1／2章內容（#162／#163）、選章（#164）、存檔欄（#165）、Demo 組建（#166）、移除劇本選擇（#169）、事件系統（#172，P0）都未開工；正式 App ID（#152）未換。
2. **重量轉移、門禁覆蓋面不足**：`monolith-merge-gate.md` 只監視 `demo`／`player`／`skill_caster`；`game_state`／`prep_menu`／`prep_pages`／`customer` 無預算，而 #165、#171、#172 都會再加碼到 `game_state`。
3. **回歸網偏薄**：靜態 CI 抓不到 GDScript parse／typed 錯誤；#149 營運回歸未做；多人仍靠手動煙霧。

---

## 2. 可持續發展（Maintainability / Continuity）

### 業界對照（獨立團隊常見門檻）

| 實踐 | 業界期望 | 本專案（v0.4） |
| --- | --- | --- |
| 單一產品線 | 禁止分叉整專案 | ✅ `godot/game` + `versioning.md` |
| 系統邊界 | 子系統可獨立改／測 | ⚠️ `demo`／`player` 已拆；**`game_state`／`prep_*`／`customer` 成新匯流點** |
| 資料驅動 | 數值／字串／內容表 | ✅ tuning · locale · task catalog；分店規則進 `branch_rules`；技能表仍腳本為主 |
| 回歸網 | CI + 煙霧 | ⚠️ PR 靜態 CI；**無頭 Godot 未進 CI**；RPC 整合仍缺 |
| 型別紀律 | 跨模組呼叫有型別 API | ⚠️ `call`／`has_method` 938；`branch_state.gd` 仍呼叫 `game_state` 私有方法 |
| 文件即契約 | 設計可驗收 | ✅ 強；本週 EA／Demo 範圍已回寫 |

### 嚴重度表（本輪）

| 嚴重度 | 問題 | 證據 | 建議 |
| --- | --- | --- | --- |
| **高** | 重量轉移到無門禁檔 | `game_state` 1699→2939、`prep_menu` 3510、`prep_pages` 2036、`customer` 2737；六大檔合計 +194 | 把 `game_state`／`prep_menu`／`prep_pages`／`customer` 納入 `monolith-merge-gate`（先定水位，再定預算）；#165／#171／#172 動工前先排抽出 |
| **高** | 回歸網抓不到 parse／typed 錯誤 | 本週 `ec32b3a`（分店 Prep typed vars）、`27fd742`（`day_begin`／`checkout_controller` typed vars）、`ac64c24`（精英店員 parse）、**#178 執行期崩潰**；`godot-checks` 未進 `ci.yml` | #154：把 `run_godot_checks.py` 變成正式 CI job（需 `workflow` scope 推 yml）；同時做 #149 |
| **中** | 分店模組耦合私有 API | `session/branch_state.gd` 第 55、76、182 行呼叫 `state._elite_index`／`state._ensure_one_for_sale`（untyped `state`）；PR #176 審閱點，**仍未修** | 改為 `game_state` 公開方法＋型別參數 |
| **中** | 分店結算未對多人設守衛 | `demo.gd` 約第 2871 行 `BranchSettle.settle_all(state)` 於日結流程直接呼叫，該處未見 `is_networked()` 判斷；PR #176 審閱點 | 決定「多人跳過」或「同步給 client」，並在 #167 一併定案 |
| **中** | 淨額顯示 `$-120`、`world_build` 精英指派檢查重複 | PR #176 審閱點；`branch_settle.gd` 第 182 行把原始數字傳入 `settle.branch.net`；重複檢查**未逐行重驗** | 小修；可併入同一張 follow-up issue |
| **中** | duck-typing 殘量 | 全庫 938；`demo` 146、`player` 78、`customer` 54 | 新 API 進 `game_host.gd`；`demo` 禁止新增字串 `call` |
| **中** | `monolith-merge-gate.md`／`runtime-perf-audit.md`／`appearance.md` 引用舊位置 | PR #177 審閱時指出部分函式已搬家（本輪**未逐一重驗**） | 文件對齊（Markdown 即可） |
| **低** | `fonts/ZenMaruGothic` 19MB 疑未引用 | `.gd`／`.tres`／`project.godot` 無引用；其他資源檔未查 | 確認後移出或標註用途 |
| **低** | 凍結目錄佔 repo | v0.3 ~36MB；本輪**未重量** | 可選 archive／LFS |

### 可持續「及格線」（相對 v0.3 更新）

v0.3 及格線：`demo` ≤~3900 ✅（3608）；新技能不堆 `skill_caster` ✅（編排器＋族模組）；正式 App ID ❌；字型子集同步新技能 ⚠️（11/21、11/23 已重建，本輪**未重核**新字）；敘事程式預設拒收 ➜ **已被 11/27 決議取代**（第1／2章進 EA）。

**本輪新及格線：**

1. `game_state.gd` 不再淨增，或每次增加伴隨等量抽出（建議先設水位 ≈ 目前 2939，並規劃把分店／主題店狀態集中到 `session/branch_*`）  
2. `prep_menu`／`prep_pages`／`customer` 同樣設水位；新頁面進 `prep/` 子模組  
3. 章節狀態機／事件 runtime **一開始就放獨立目錄**（例如 `story/`、`events/`），不得先塞 `demo`／`game_state` 再抽  
4. `godot-checks` 進 CI，或至少每個 EA 里程碑前以 `run_godot_checks.py` 跑一次並留紀錄  
5. 跨模組新增呼叫一律走型別 API，禁止再讀寫他類私有成員  
6. 正式 App ID＋Partner 表（#152）

---

## 3. 效能（Performance）

### 現況判斷

- **地板假設不變：** Switch 1 最緊（`console-business.md`／v0.1–v0.3 §3）。  
- **本輪未做任何新效能量測**（未跑 J1 probe、未開 Profiler）；以下為依賴沿用 v0.3／`perf-baseline-j1.md` 的判斷，**不是**新數字。  
- **已做（勿重審）：** 髒刷新、SKU 索引、字型子集、A* 預算、地板單節點、VFX／drop 池、GameHost 熱路徑 typed 化等（`runtime-perf-audit.md`、J2）。  
- **新壓力源（自 v0.3 起）：** 分店結算與多店營運（#173）、精英店員多崗、自助收銀、傳送門、頭目日、6 個小遊戲場景（`.tscn` 8→14）、`art` +27MB、`fonts` +19MB（疑未引用）。

### 本輪效能項

| 優先 | 項目 | 狀態／建議 |
| --- | --- | --- |
| P0 | 實機／目標硬體幀時間基線 | 桌面滿載輔測已有（[`perf-baseline-j1.md`](perf-baseline-j1.md)）；**Deck／Switch／雙人 Profiler 仍待填**（#155） |
| P1 | 分店＋精英店員＋頭目日場景重跑 J1 `--load` | **未量測**；上述新壓力源出現後從未重跑 |
| P1 | 安裝體積 | 235MB；先確認 `ZenMaruGothic` 19MB 是否出貨；`art/src`（38MB）是否應排除出匯出 |
| P2 | PC Forward+ vs Compatibility | 仍合理；非阻塞 |
| P2 | 十呎／TV 安全區 UI | PlatformServices 有 profile；主機認證級未到 |

**結論：** 效能分維持 7.5 是**沿用而非重證**；瓶頸仍是驗收迴路。下一輪若仍無新量測，應下調。

---

## 4. 遊戲設計標準（Design Quality）

| 標準 | 評級 | 說明 |
| --- | --- | --- |
| **核心循環清晰度** | 優 | 準備 → 補貨 → 營運 → 結算未變；分店是加在日結算旁的新層 |
| **操作爽感／節奏** | 優 | Ambient Peek、短按 radial、手把重映射、RT 衝刺手感持續打磨 |
| **系統深度 vs 複雜稅** | 中高風險 | 技能＋ops＋任務＋精英店員＋分店＋6 小遊戲；認知負擔續升，EA 玩家引導（#168）尚未設計落地 |
| **進度與長期動機** | 中→中高 | **設計：** 序章→1→2→選章→分店＋日循環已拍板；**產品：** 仍只有序章＋頭目日；#170 進度上限未定 |
| **難度曲線** | 弱–中 | `difficulty.md` 仍 stub；倍率未接流量（#151） |
| **新手引導／失敗可讀** | 中 | 11/27 決議改為劇情內體驗式教學、失敗可擋事件／劇情不擋日結算；**實作皆未開始**（#168、#153） |
| **Live-ops／事件內容** | 弱 | `eventsystem.md` 仍是占位，但**已升為 EA P0（#172）** |
| **平衡工具** | 中上 | `tuning.gd`；缺遙測；EA 可接受；資金門檻暫用分析值 |
| **多人設計完整性** | 中 | 權威模型清楚，但 11/27 決議延後重設計（#167）；分店與多人的關係未定 |
| **內容管線** | 優 | 歷史主題、客人皮膚、小遊戲、頭目日內容；六主題故事全寫但只開安桃山 |
| **無障礙／輸入包容** | 中 | InputMap＋手把＋觸控；TV／色盲／完整重映射未到認證級 |

**設計結論：**

- **單日動作經營**仍是整個產品最強的部分，且本週再加「分店」這個 EA 後半的長期動機層。  
- **EA 的敘事骨幹（章節機→第1章→第2章破局→選章）完全沒有活線程式**；事件系統在 `docs` 已升 P0，但 `godot/game` 內無 `EventDirector`。這是目前**範圍與實作差距最大**的一塊。  
- Demo（序章＋第1章）是 EA 的子集，因此 #161／#162／#172 同時是 Demo 的前置，建議以 Demo 作為第一個可驗收里程碑。

---

## 5. 平台評估（更新）

| 面向 | Steam | Switch／Xbox |
| --- | --- | --- |
| 技術路徑 | Godot 4.7 + GodotSteam；M3 大廳已驗收；Cloud／成就 API 已接 | 仍需 W4／埠接；釘版見 `godot-middleware-pin.md`；本輪**無進展** |
| 產品缺口 | **正式 App ID（仍 480）**、Partner Cloud／成就表、商店頁、Deck 清單填實；**Demo 是否需獨立 App ID、匯出與商店導流（#166）未定**；Demo 存檔不轉入 EA | 開發者帳號／devkit／Lotcheck·TCR；認證測項未做 |
| 檔期（Next Fest） | 官方規則：已以 EA 發行的遊戲不能再參加 Next Fest；是否為參加而把 EA 發售排在某屆之後，**尚待 Jackson 決議**（見 `steam-productization.md`） | — |
| 建議順序 | **Demo 可玩（#161／#162／#172）→ 換正式 ID（#152）→ 商店頁／Demo 頁 → EA** → 再主機 | 禁止主機專用專案複本 |

差的仍然是商店身分與 Partner 配置，以及 Demo／EA 的可玩內容，不是再寫一層抽象。

---

## 6. 建議路線（v0.4）

| 階段 | 目標 | 工作 |
| --- | --- | --- |
| **R · 回歸網補強** | 工程信頼 | `godot-checks` 進 CI（#154）；#149 營運回歸；分店切片補自動檢查 |
| **S · 分店收尾小票** | 可持續 | PR #176 殘留點一張票：branch_state 私有 API、多人結算守衛、負數淨額、精英檢查去重 |
| **T · 門禁擴充** | 可持續 | `monolith-merge-gate` 納入 `game_state`／`prep_menu`／`prep_pages`／`customer`；更新舊函式位置文件 |
| **U · EA／Demo 內容骨幹** | 可上架 | 章節機（#161）→ 事件系統（#172）→ 第1章（#162）→ Demo 組建（#166）→ 第2章（#163）→ 選章（#164）＋存檔（#165）；全部放獨立目錄 |
| **V · Steam 收尾** | 可上架 | 正式 App ID（#152）、Partner 表、移除劇本選擇（#169）、關閉 `TEST_TOOLS` |
| **W · 效能驗收** | 硬體地板 | J1 `--load` 在分店／精英場景重跑；Deck／Switch（#155） |
| **X · 多人重設計** | 後置 | #167；先決定分店結算在多人下的語意 |

玩法內容（難度倍率 #151、培育獎勵池 #158 等）可並行，但**章節機與事件系統若先塞進 `demo`／`game_state`，A 分會再掉**。

---

## 7. 跟進清單（對應 GitHub issue）

### 繼承 v0.3（未完）

- [ ] **H1** 正式 Steam App ID（仍 480）— #152（含 Cloud／成就煙測、關閉 `TEST_TOOLS`）
- [ ] **K1** 主機帳號／釘版重查 — #155（含 Deck／Switch 滿載基線）
- [x] **Q1** 無頭 Godot 檢查進 CI — #154（`.github/workflows/ci.yml` `godot-checks`：Godot 4.7.2-stable＋`run_godot_checks.py`）

### 本輪新增

- [x] **R1** 營運回歸：精英店員、熟食檔、釣魚、傳送門、自助收銀、節點生命週期 — #149（`tools/run_ops_checks.py`：7 支無頭 wrapper；進 `godot-checks` job）
- [x] **S1** PR #176 殘留點（branch_state 私有 API、多人結算守衛、`$-120`、`world_build` 精英檢查重複）— #179
- [ ] **T1** `monolith-merge-gate.md` 擴充到 `game_state`／`prep_menu`／`prep_pages`／`customer`，並對齊 `runtime-perf-audit.md`／`appearance.md` 舊函式位置 — **尚無 issue**（純文件，可直接做）
- [ ] **U1–U7** EA／Demo 骨幹：#161 章節機、#162 第1章、#163 第2章、#164 選章、#165 存檔欄與 SAVE_VERSION、#166 Demo 組建、#172 事件系統（P0）
- [ ] **U8** #169 移除劇本選擇；#168 體驗式教學設計；#170 進度上限；#171 分店系統落地（分店垂直切片已入，EA 版仍待）
- [ ] **V1** `fonts/ZenMaruGothic` 19MB 是否出貨 — **尚無 issue**
- [ ] **其他仍開** #151 難度倍率、#153 教學打磨、#157 影分身煙霧 VFX、#158 培育獎勵池、#159 多人 M4 web_ws、#160 技能解鎖表與 LV11–99、#167 專用多人設計

### v0.3 已完成（勿重開）

- [x] **L1** `demo.gd` ≤~3900 — 現 **3608**（#148 ✅ 已關）
- [x] **L2** 拆 `skill_caster` — 編排器＋族模組，現 <1000
- [x] **L3** `pause_menu` 瘦身 — 1683→1422（`hud` 1409→1480 小增）
- [x] **L4** 合併紀律 — [`monolith-merge-gate.md`](monolith-merge-gate.md)（本輪建議擴充，見 T1）
- [x] **M2** 字型子集重跑 — 11/21、11/23 皆有重建
- [x] **N1／N2** 文件閘門與 `eventsystem.md` 占位 — N2「不排活線」已被 11/27 決議取代
- [x] **O1** J1 桌面滿載一列 — Deck 仍待（#155）
- [x] **#175** `player.gd` <3000 — 現 **2897**（#177）
- [x] **#178** `day_begin` typed array 執行期崩潰修正
- [x] **#173／#176** 分店垂直切片與結算跟進（殘留點見 S1）

### v0.2 已完成（勿重開）

- [x] F1–F3、G1–G2、H2、H3（已被 11/27 決議更新）、I1、J1、J2

---

## 結論

相對 v0.3：**架構止血見效（`demo` 3608、`player` 2897），但總量 +35% 且重量轉到無門禁檔；內容與日循環持續超標；EA／Demo 的決議已清楚，卻幾乎沒有對應活線實作；回歸網沒有跟上。**

以業界獨立團隊標尺：**綜合約 7.0／10，與上輪持平**——內部結構改善（A +0.5）、設計內容加厚（G +0.5）被工程信頼（C −0.5）與多人（F −0.5）抵銷。真正卡住上架的是 **EA／Demo 內容骨幹尚未開工**與 **正式 App ID**；真正卡住速度的是 **門禁覆蓋面不足**與 **無頭 Godot 未進 CI**。不必換引擎；建議先做小而高回報的三件事（S1 小票、R 回歸網、T 門禁擴充），再以 Demo（序章＋第1章）為第一個可驗收里程碑展開 U 階段，並把章節機與事件系統放在獨立目錄開始。
