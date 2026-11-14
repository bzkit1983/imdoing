# 技術評估 v0.2（業界質素／可續寫／效能／遊戲設計）

- **範圍：** 活線 `godot/game`（Godot **4.7** · 產品 **`v1.4.0`**）；設計以 `docs/systemdesign/` 為準
- **對照 tip：** `origin/main` @ `f37a8d73`（2026-11-14）
- **前一輪：** [`tech-review-v0.1.md`](tech-review-v0.1.md)（2026-10-20／21，當時約以 `godot/alpha_v0_1` 為準）
- **並行證據：** [`runtime-perf-audit.md`](runtime-perf-audit.md) · [`implementation-status.md`](implementation-status.md) · [`systemdesign-gaps.md`](../systemdesign-gaps.md) · [`multiplayer.md`](../systemdesign/multiplayer.md)
- **目標平台：** Steam · Nintendo Switch · Xbox（及現行 Web 試玩）
- **性質：** 工程＋產品可交付性評估；**非**玩法規格。玩法仍以 `docs/systemdesign/` 為準。

## 總評

v0.1 清單（產品骨架＋主機準備文件）已兌現；專案已從「可玩 Alpha」推進到「可連線的內容密集活線」（多人 M1～M3、技能／任務／評價大量落地）。  
**最大風險已從「缺平台骨架」轉移為「上帝腳本膨脹＋內容／連線同時堆在同一熱路徑」。**

| 面向 | v0.1 → v0.2 | 一句話 |
| --- | --- | --- |
| 可持續開發 | 骨架 ✅；體積 🔴 | 單一活線做對了，但 `player`／`demo` 已到 indieshipping 警戒線 |
| 執行期效能 | P0–P2 ✅ | 現規模（十餘客）桌面／Web 仍輕；Switch 地板仍要再壓測 |
| 平台／上架 | Steam 候選半程 | 正式 App ID／Cloud／成就／BGM／教學未到；主機仍卡 middleware |
| 遊戲設計標準 | 核心循環強；外層弱 | 日循環／技能幻想清楚；劇情·教學·流量長線·失敗條件仍欠 |
| 多人 | 設計＋M3 驗收強於同規模獨立團隊 | Net 邏輯浸入 God Object，回歸成本高 |

### 分數卡（業界獨立／中小型工作室標尺 · 10 分制）

| 維度 | 分 | 依據摘要 |
| --- | --- | --- |
| **A. 架構與可持續** | **5.5** | 活線／Autoload／GameHost 起步佳；兩支 4k+ 腳本＋593× duck-call 拖垮中期 |
| **B. 效能與擴展** | **7.0** | 髒刷新、SKU 索引、A* 預算、字型子集已落地；缺主機實機與物件池 |
| **C. 工程質素／測試** | **6.0** | `tools/` 設計／契約測試可觀；無 CI workflow；場景組合極薄 |
| **D. 內容管線** | **7.0** | Voxel bake／catalog／i18n CSV／技能驗證 skill 成熟於獨立團隊平均 |
| **E. 平台就緒** | **5.5** | Desktop＋Steam transport 驗收；Cloud／成就 stub；主機未開工 |
| **F. 多人／網路** | **7.5** | 規格完整、M1–M3 落地；權威模型清楚；實作耦合重 |
| **G. 遊戲設計完整度** | **6.5** | 核心爽感循環完整；三層循環的「劇情／事件」層與新手引導仍空 |
| **H. 文件／流程** | **8.0** | systemdesign＋gaps＋versioning＋agent skills 遠超多數同規模專案 |
| **綜合（等權）** | **~6.6** | **Steam Early Access 候選可談；「完整零售＋主機」尚早** |

---

## 1. 相對 v0.1 的變化（證據）

| 指標 | v0.1 審查時 | v0.2（本 tip） | 解讀 |
| --- | --- | --- | --- |
| GDScript 約略行數 | ~7.7k（alpha） | **~29.2k**（`scripts/**/*.gd`） | ≈ **3.8×**；內容與多人是主因 |
| ≥1000 行腳本 | 3（player／prep／demo） | **5**（+ `customer` 2002、`game_state` 1547）；player／demo 各 **4.4k+** | God Object 惡化 |
| `call`／`has_method` 出現次數 | 高（未量化） | **~593**（player 172 · demo 165 · customer 98） | 熱路徑已部分 cache；整體仍鬆散 |
| `@rpc` | 無 | **19** | 連線面存在；仍集中在大腳本 |
| Autoload | 少／無平台層 | Controls · PlatformServices · InputMode · Loc · SfxBus · SeatTable · InteractLock · SessionService | 產品化及格 |
| 自動化測試 | **0** | `tools/test_*.py|cjs` **37** + `*_check.gd` **15** | 設計／契約層佳；缺引擎內整合 CI |
| 存檔／InputMap／暫停／i18n | 缺或草稿 | **已落地**（`SAVE_VERSION=4`；四語 CSV） | v0.1 §6 已勾完 |
| 多人 | 文件構想 | **M1～M2.9 落地 · M3 §13.4 驗收** | 質素上是本輪最大正向 |
| 凍結複本策略 | 風險項 | **已停複本**；`demo_*`＋`alpha` 仍佔 ~36MB 在 tree | 策略對；清理可選 |
| 匯出 | Web | Web + Win／Linux／macOS；Steam App ID **480**（測試） | 上架前必須換正式 ID |

### 現況架構（簡圖）

```text
SessionService / SeatTable / InteractLock / NetTransport
        │
        ▼
demo.gd（GameHost · ~4.5k）──── 日循環 · 生成 · 技能世界效果 · 結算 · 多數 RPC
        │
        ├─ player.gd（~4.6k）── 輸入 · 互動 · 技能施放 · 多人意圖
        ├─ customer.gd（~2.0k）── AI · 小偷 · Elite
        ├─ prep_menu + prep/* ── 準備 UI（已部分拆頁）
        ├─ game_state / tuning / skills
        └─ PlatformServices → desktop | steam（Cloud／成就仍 stub）
```

**值得保留：** `tuning.gd`、Voxel／`art/catalog.json` bake、設計檔驅動、`GameHost` 契約、Session 模組邊界、agent skills（i18n／playerskillvalidator）。

**主要風險：** 兩支 4k+ 腳本同時承載玩法＋網路；場景幾乎全程式碼組裝（僅 7 個 `.tscn`）；文件少數檔（如 `docs/alpha/design.md`）落後於 `implementation-status.md`。

---

## 2. 可持續發展（Maintainability / Continuity）

### 業界對照（獨立團隊常見門檻）

| 實踐 | 業界期望 | 本專案 |
| --- | --- | --- |
| 單一產品線 | 禁止分叉整專案 | ✅ `godot/game` + `versioning.md` |
| 系統邊界 | 子系統可獨立改／測 | ⚠️ Session／host／prep 有拆；player／demo 仍巨石 |
| 資料驅動 | 數值／字串／內容表 | ✅ tuning · locale CSV · task catalog；技能仍偏腳本表 |
| 回歸網 | CI + 煙霧 | ⚠️ 本地 `tools/` 多；**無** `.github/workflows` |
| 抽象平台 I/O | 存檔／成就／UI profile | ✅ 介面在；Steam 後端未填滿 |
| 文件即契約 | 設計可驗收 | ✅ 強；少數 Alpha 檔需回寫 |

### 嚴重度表（本輪）

| 嚴重度 | 問題 | 證據 | 建議 |
| --- | --- | --- | --- |
| **高** | `player.gd`／`demo.gd` 持續膨脹 | 4610／4474 行；各 200+ `func` | **凍結新功能進巨石**：新技能世界效果進獨立模組；從 demo 抽 `SpawnDirector`／`DaySettle`／`NetWorld`；player 抽 `SkillCaster`／`TossController`／`FightController`（interact_scan 已開先例） |
| **高** | 多人邏輯浸入巨石 | demo／player 內大量 M2 註解與 puppet 狀態 | Net 表示層與模擬命令佇列抽出；RPC 表集中單檔並做契約測試 |
| **中** | duck-typing 協調 | ~593 `call`／`has_method` | 擴大 `GameHost` 實作覆蓋；熱路徑禁止字串 `call` |
| **中** | UI／世界少場景組件 | 7× `.tscn`；prep／hud 部分落地 | 傢俬與顧客預製體化；減少 `new()` 樹 |
| **中** | 文件漂移 | `docs/alpha/design.md` 仍寫 COMBO「仍未寫」；實作與 gaps 已關 | 以 `implementation-status` 為準回寫或標過時 |
| **低** | 凍結目錄佔 repo | ~36MB demos＋alpha；game art 89MB | 大資產 LFS 或 Pages 產物分離（可選） |
| **低** | 腳本內殘 CJK | 19 個 `.gd` 仍含漢字（多為註解／技能內部 id 註） | 玩家可見串繼續收割；註解可留中文 |

### 可持續「及格線」（相對 v0.1 已升級）

v0.1 的最低門檻（停複本／存檔／InputMap／拆 prep／PlatformServices）**已過**。  
**本輪新及格線：**

1. `player`／`demo` **停止淨增長**（新功能必須外置模組；允許搬遷 PR）  
2. 熱路徑零新增字串 `call`；GameHost 覆蓋率上升  
3. CI：至少跑 `tools/test_*.py` + 關鍵 `*_check` 於 PR  
4. Steam：正式 App ID＋Cloud／成就不再是 print stub  
5. 設計：新手引導／失敗·過關／BGM 設定寫進長線或明確標 EA 範圍外  

---

## 3. 效能（Performance）

### 現況判斷

- **地板假設不變：** 以 **Switch 1** 為全平台最緊（見 v0.1 §3、`console-business.md`）。  
- **已做（勿重審）：** HUD／標籤髒寫、SKU 索引、CJK 子集、SpriteFrames cache、A* 每幀預算＋路徑 cache、地板單節點、guest／thief 計數維護、interact `distance_squared` 等（見 `runtime-perf-audit.md` DONE 表）。  
- **現規模：** `guest_cap` 約 10–15、小偷 cap 2、污物 cap 6；路徑格約 1.2k–4.5k。對桌面／手機 Web **仍偏輕**。  
- **新壓力源：** 影分身／Dark Side／多座玩家／技能 VFX／任務 HUD → 實體與 UI 刷新次數上升；多人時 Host 模擬＋RPC 序列化。

### 本輪效能項

| 優先 | 項目 | 狀態／建議 |
| --- | --- | --- |
| P0 | 實機／目標硬體幀時間基線 | **未做**：Deck／低階筆電／（未來）Switch 剖面；建議固定「滿店＋2 影分身＋雙人」場景錄 Profiler |
| P1 | drop-flight／VFX 物件池 | audit 列為可選；技能增多後升為 P1 |
| P1 | 多人頻寬與 snapshot 頻率 | 文件已定意圖模型；需加「滿座壓力」自動化或手動清單 |
| P2 | PC Forward+ 與 Compatibility 分流 | 仍合理；非阻塞 |
| P2 | 解析度／TV 安全區 UI profile | PlatformServices 有 camera／touch；十呎 UI 未完成 |

**結論：** 效能工程在「紙上與程式熱路徑」已達獨立團隊優良水準；**缺的是目標硬體驗收迴路**，不是再找下一輪微優化清單。

---

## 4. 遊戲設計標準（Design Quality）

對照常見商業／獨立評審軸（核心循環、可讀性、進度、難度、內容層、多人公平、數據可調）。

| 標準 | 評級 | 說明 |
| --- | --- | --- |
| **核心循環清晰度** | 優 | 準備 → 30s 補貨 → 3min 營運 → 結算；幻想（忙亂便利店＋技能）一致（`gameconcept.md`） |
| **操作爽感／節奏** | 優 | 衝刺、丟掉、交付 COMBO、互動發光、技能節奏已落地；符合「高速多重任務」定位 |
| **系統深度 vs 複雜稅** | 中高風險 | 技能／COST／多人鎖／評價並存；有 `playerskillvalidator` 屬加分，但玩家認知負擔需教學消化 |
| **進度與長期動機** | 中 | 等級／店擴／技能／評價有骨幹；**技能解鎖表、事件／劇情、任務報酬**仍 Beta（外層循環空心） |
| **難度曲線** | 弱–中 | `difficulty.md` stub；活線多為 TEST_TOOLS 簡易／普通；流量數字仍 Demo／tuning 驅動 |
| **新手引導／失敗可讀** | 弱 | Alpha 仍列缺教學、失敗／過關流程、技能演出輸入鎖 |
| **平衡工具** | 中上 | `tuning.gd` 集中；缺試算表／遙測；獨立 EA 可接受 |
| **多人設計完整性** | 優 | `multiplayer.md` 里程碑、權威、斷線、結算拍板清楚；高於同規模均值 |
| **內容管線** | 中上 | Voxel／動畫／i18n／SKU 圖示契約；劇情內容表仍 stub |
| **無障礙／輸入包容** | 中 | InputMap＋手把＋觸控皮層；TV 焦點／色盲／重映射完整度未到主機認證級 |

**設計結論：** 作為「動作經營」**單日循環**已達可演示、可 EA 打磨的品質；作為構想中的「劇情＋事件＋經營」三層產品，**第一層仍基本缺席**，不宜用完整 RPG／敘事經營的標準對外承諾檔期。

---

## 5. 平台評估（更新）

| 面向 | Steam | Switch／Xbox |
| --- | --- | --- |
| 技術路徑 | Godot 4.7 桌面匯出 + GodotSteam 4.24；**M3 大廳已驗收** | 仍需 W4／埠接；釘版政策見 `godot-middleware-pin.md` |
| 產品缺口 | 正式 App ID（現 480）、Cloud、成就、商店頁、Deck 驗證清單、BGM | 開發者帳號／devkit／Lotcheck·TCR；掛起已有鉤子但仍要主機認證測項 |
| 建議順序 | **先 Steam EA／正式** → 再主機 | 架構上繼續禁止主機專用專案複本 |

PlatformServices：Desktop 實作完整；Steam 後端 **磁碟路徑可用、Cloud／UserStats 仍 stub**（`steam_platform.gd`）。

---

## 6. 建議路線（v0.2）

| 階段 | 目標 | 工作 |
| --- | --- | --- |
| **F · 巨石止血** | 可持續 | 模組搬遷（不改玩法）；禁止 player／demo 淨增；RPC／Spawn／Skill 外置 |
| **G · 回歸網** | 工程信頼 | PR CI 跑 tools 測試；補 2–3 個「開日→關店」無頭煙霧（若環境允許） |
| **H · Steam 產品化** | 可上架 | 正式 App ID、Cloud、成就、BGM／設定頁、教學最小集、Deck 檢查 |
| **I · 設計外層** | 產品完整度 | 事件／任務報酬／解鎖表（Beta 項分批）；或公開宣告 EA＝純循環無劇情 |
| **J · 效能驗收** | 硬體地板 | 滿載 Profiler 基線；物件池；必要時降 VFX |
| **K · 主機** | 可選衝刺 | 帳號＋釘版閘門後再買工具；不與 F／H 搶同一人力 |

玩法內容可與 F／G 並行，但**新技能若再寫進 player／demo 本體，可持續分數會再掉**。

---

## 7. 跟進清單（建議開 issue）

- [ ] **F1** 從 `demo.gd` 抽出世界生成／日結／網路世界同步模組（行為不變）
- [ ] **F2** 從 `player.gd` 抽出技能施放／丟掉／打擊控制器（延續 `interact_scan.gd`）
- [ ] **F3** GameHost 覆蓋殘餘熱路徑 `call()`；新增 API 必須進 `game_host.gd`
- [ ] **G1** GitHub Actions：`python3 -m pytest`／既有 `tools/test_*.py` 於 PR
- [ ] **H1** 正式 Steam App ID；Cloud 接 `write_save`；成就接 `unlock_achievement`
- [ ] **H2** BGM＋完整設定頁；最小教學／第一日引導
- [ ] **H3** 失敗／提早關店／過關敘事（或文件標明 EA 不做）
- [ ] **I1** 回寫過時 `docs/alpha/design.md`（COMBO／取貨等）
- [ ] **J1** 滿店＋技能＋雙人 Profiler 基線文件化
- [ ] **J2** drop-flight／技能 VFX 物件池
- [ ] **K1** 主機帳號／釘版重查（執行閘門，非玩法）

---

## 結論

相對 v0.1：產品骨架與效能熱路徑**達標**，多人與內容速度**超標**，架構體積與設計外層**未跟上**。  

以業界獨立團隊標尺：**綜合約 6.6／10**——適合把 Steam 早期存取／正式頁當下一商業里程碑；不適合在巨石未止血前並行開主機與大型敘事層。不必換引擎；必須把「寫新功能」與「搬遷巨石」綁成同一發布紀律。
