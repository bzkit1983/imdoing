# 技術評估 v0.3（業界質素／可續寫／效能／遊戲設計）

- **範圍：** 活線 `godot/game`（Godot **4.7** · 產品 **`v1.5.0`**）；設計以 `docs/systemdesign/` 為準
- **對照 tip：** `origin/main` @ `f301053f`（2026-11-20）
- **前一輪：** [`tech-review-v0.2.md`](tech-review-v0.2.md)（2026-11-14，`f37a8d73` · 當時產品 `v1.4.0`）
- **並行證據：** [`runtime-perf-audit.md`](runtime-perf-audit.md) · [`implementation-status.md`](implementation-status.md) · [`systemdesign-gaps.md`](../systemdesign-gaps.md) · [`steam-productization.md`](steam-productization.md) · [`storysystem.md`](../systemdesign/storysystem.md)
- **目標平台：** Steam · Nintendo Switch · Xbox（及現行 Web 試玩）
- **性質：** 工程＋產品可交付性評估；**非**玩法規格。玩法仍以 `docs/systemdesign/` 為準。

## 總評

v0.2 跟進清單（F／G／H2–H3／I／J）**大多已兌現**；產品從「可連線內容密集活線」推進到「中期美術＋教學／設定殼＋任務 HUD＋技能／道具擴充」的 **Steam EA 候選面**。  
**最大風險從「缺平台骨架／缺抽出」轉移為「抽出後紀律失效：巨石回脹＋設計外層開檔但未進活線」。**

| 面向 | v0.2 → v0.3 | 一句話 |
| --- | --- | --- |
| 可持續開發 | 抽出 ✅；淨增 🔴 | F1–F3 做過，但 `demo` 已高於抽出前；及格線「停止淨增長」未守住 |
| 執行期效能 | J1／J2 ✅ | 熱路徑與池化仍優；Deck／Switch 實機列仍空 |
| 平台／上架 | H2／H3／Cloud ✅ | 設定＋教學＋EA 範圍＋Cloud／成就 API 齊；**正式 App ID 仍 480** |
| 遊戲設計標準 | 日循環更滿；外層設計跳級 | 劇情框架／成長三分析／失敗擋 UX 已寫；活線仍＝純日循環（刻意） |
| 多人 | 穩 | M3 維持；固定速率 client 呈現；回歸仍靠手動煙霧＋靜態契約 |
| 工程信頼 | CI 落地 | PR 靜態套件＋更多 `test_*`／`*_check`；仍缺無頭 Godot／RPC 整合測 |

### 分數卡（業界獨立／中小型工作室標尺 · 10 分制）

| 維度 | v0.2 | **v0.3** | 依據摘要 |
| --- | --- | --- | --- |
| **A. 架構與可持續** | 5.5 | **5.0** | 抽出模組在；`demo` 5.4k／`player` 3.9k 回脹；`prep_menu`／`pause_menu`／`skill_caster` 成第二波胖腳本 |
| **B. 效能與擴展** | 7.5 | **7.5** | J1 配方＋J2 池；規模仍十餘客；新 UI／技能壓力未改「缺實機」結論 |
| **C. 工程質素／測試** | 6.0 | **7.0** | `.github/workflows/ci.yml`＋`tools/run_ci_static.py`；可選 `godot-checks` job；18× `*_check.gd` 部分已進 CI |
| **D. 內容管線** | 7.0 | **7.5** | v1.5 中期美術、pause-ui-chrome skill、任務／ops 圖示；新技能 CJK 字型子集有債 |
| **E. 平台就緒** | 5.5 | **6.0** | H2／Cloud／成就接線；正式 ID／Partner 表／Deck 清單未完；主機未開工 |
| **F. 多人／網路** | 7.5 | **7.5** | 規格＋M3 不變；`@rpc` 集中 `session_service`；耦合仍重 |
| **G. 遊戲設計完整度** | 6.5 | **7.0** | 教學／設定／任務／ops／新技能加厚日循環；劇情框架設計優於實作；`eventsystem`／難度倍率仍缺 |
| **H. 文件／流程** | 8.0 | **8.5** | story／growth／steam-productization／agent skills 再加一層；implementation-status 需跟本輪對齊 |
| **綜合（等權）** | ~6.6 | **~7.0** | **Steam EA 產品面更近；架構債未減反略升——上架衝刺必須綁「禁止巨石淨增」** |

---

## 1. 相對 v0.2 的變化（證據）

自 `f37a8d73` → `f301053f` 約 **81** commits。

| 指標 | v0.2（tip） | v0.3（本 tip） | 解讀 |
| --- | --- | --- | --- |
| 產品 SemVer | `v1.4.0` | **`v1.5.0`** | 中期美術錨點；`SAVE_VERSION` 仍 4 |
| GDScript 約略行數 | ~29.2k | **~41.3k** | ≈ **1.4×**／6 日曆日量級；技能・UI・教學・任務・雇員是主因 |
| ≥1000 行腳本 | 5 | **10** | +`prep_menu` 2983、`pause_menu` 1683、`hud` 1409、`prep_pages` 1406、`skill_caster` 1227、`session_service` 1155 |
| `demo.gd`／`player.gd` | 4474／4610 | **5414／3862** | 抽出後曾降至 ~3859／~3273；**demo 已高於 v0.2 審查時**；player 仍低於當時但較抽出後 +~600 |
| `call`／`has_method` | ~593 | **~675** | F3 後 player／customer 熱路徑改善；**demo 230** 仍為最大 duck 熱點 |
| `@rpc` | 19（散在大腳本） | **22**（主在 `session_service`） | 邊界略清；契約測試仍薄 |
| Autoload | 8 | **9**（+ `BgmBus`） | 產品殼加分 |
| 自動化測試 | 37× `test_*`＋15× `*_check` | **45× `test_*`＋18× `*_check`**＋**CI** | 設計／契約層再強；CI 為本輪工程最大正向 |
| 活線磁碟 | ~186MB（art~89＋addon~93） | **~180MB**（art~58＋addon~93） | 策略不變；addon 仍可考慮產物分離 |
| `.tscn`（專案場景） | 7 | **8**（+ `tutorial_modal`；不含 addon） | 仍偏程式碼組裝 |
| 存檔／設定／教學 | 已有骨架 | **H2 設定殼＋首日引導／跳過**；任務板進 HUD | EA 可玩性加厚 |
| 多人 | M1–M3 驗收 | 維持＋固定速率 client 呈現 | 無新里程碑 |
| Steam | App ID 480；Cloud stub | **Cloud／成就 API 已接**；ID **仍 480** | H1 半程→差正式 ID |
| 設計外層 | 缺 events／劇情 | **`storysystem`＋`story/`＋成長三分析**；活線**未做** | 文件跳級；實作仍遵 EA＝純循環 |
| 凍結複本 | ~36MB 在 tree | **同** | 可選清理 |

### 現況架構（簡圖）

```text
SessionService / SeatTable / InteractLock / NetTransport / TaskTracker
        │
        ▼
demo.gd（GameHost · ~5.4k）──── 日循環 · 生成 · 技能世界效果 · 結算 · 雇員／ops
        │
        ├─ host/  world_build · net_world · day_settle · game_host（~90+ API）
        ├─ player.gd（~3.9k）── 輸入 · 互動 · 持貨 · 物理
        │     └─ player/  skill_caster(~1.2k) · toss · fight · bag_caster · floor UI
        ├─ customer.gd（~2.2k）── AI · 小偷 · Elite
        ├─ prep_menu（~3.0k）+ prep_pages（~1.4k）
        ├─ pause_menu（~1.7k）+ hud（~1.4k）+ tutorial/*
        ├─ game_state / tuning / skills / ops_items
        └─ PlatformServices → desktop | steam（Cloud／成就已接；正式 ID 未換）
```

**值得保留：** v0.2 所列（`tuning`、Voxel catalog、GameHost、Session、agent skills）＋ **CI 靜態網**、**task_tracker／task_catalog**、**ops 道具袋**、**教學導演**、**story 設計樹**。

**主要風險：**  
1. **巨石回脹**（抽出成果被新功能吃回 `demo`／`skill_caster`）。  
2. **設計／產品雙軌**：劇情框架已寫到可估成長帶，活線仍無章節狀態機——易讓貢獻者誤開敘事 PR。  
3. **上架閘門單一**：正式 App ID／Partner 表未換，其餘 Steam 產品化已到位。

---

## 2. 可持續發展（Maintainability / Continuity）

### 業界對照（獨立團隊常見門檻）

| 實踐 | 業界期望 | 本專案（v0.3） |
| --- | --- | --- |
| 單一產品線 | 禁止分叉整專案 | ✅ `godot/game` + `versioning.md` |
| 系統邊界 | 子系統可獨立改／測 | ⚠️ host／player／session 有拆；**demo 再次成為匯流湖** |
| 資料驅動 | 數值／字串／內容表 | ✅ tuning · locale · task catalog；技能表仍腳本為主 |
| 回歸網 | CI + 煙霧 | ✅ PR 靜態 CI；⚠️ 無頭 Godot／RPC 整合仍缺 |
| 抽象平台 I/O | 存檔／成就／UI profile | ✅ Desktop 完整；Steam Cloud／成就已接；正式 ID 未換 |
| 文件即契約 | 設計可驗收 | ✅ 強；story 需標「設計先行／活線未做」以免漂移 |

### 嚴重度表（本輪）

| 嚴重度 | 問題 | 證據 | 建議 |
| --- | --- | --- | --- |
| **高→緩** | `demo.gd` 回脹 | L1 後 **~3784**（曾 5414）；見 [`monolith-merge-gate.md`](monolith-merge-gate.md) | 維持門禁；新世界效果只進 `host/` |
| **高→緩** | 技能施放集中於單檔 | L2 後編排器 **~401**＋族模組 | 新招進族檔；禁止只加編排器巨型 `if` |
| **中** | UI 胖腳本第二波 | L3 首刀：pause −261；prep／hud 小幅 | 可再拆 prep shell／hud chrome |
| **中** | duck-typing 殘量 | 全庫 ~675；demo 230 | 新 API 必進 `game_host.gd`；demo 內禁止新增字串 `call` |
| **中** | 劇情設計無活線錨點 | `storysystem.md` 明寫「活線未做」 | 在 prep／versioning 顯眼處標 EA 範圍；開 `StoryDirector` stub 前先過閘門 |
| **低** | 新技能 CJK 字型債 | gaps：西客炮／源頭減廢／有糧出… 未進執行期 TTF | 重跑 `subset_notosans_tc.py`（含 Bold／Black） |
| **低** | 凍結目錄佔 repo | ~36MB | 可選 archive／LFS |

### 可持續「及格線」（相對 v0.2 再升級）

v0.2 及格線中：**CI、H2／H3、J1／J2、GameHost 覆蓋**已過；**「player／demo 停止淨增長」未過**。

**本輪新及格線：**

1. `demo.gd` **行數 ≤ 抽出後水位（~3900）** 或證明等量搬出；合併前 CI／人工 diff 門禁  
2. 新主動／奧義 **不得** 只加在 `skill_caster` 巨型 `if` 鏈；必須模組或表項  
3. Steam：**正式 App ID**＋Partner Cloud／成就表與活線 id 對齊  
4. 字型子集與新技能名稱同步進執行期 TTF  
5. 敘事／章節程式：**預設拒收**，除非 milestone 明確改 EA 範圍或開 Beta 旗標  

---

## 3. 效能（Performance）

### 現況判斷

- **地板假設不變：** Switch 1 最緊（`console-business.md`／v0.1–v0.2 §3）。  
- **已做（勿重審）：** 髒刷新、SKU 索引、字型子集、A* 預算、地板單節點、VFX／drop 池、GameHost 熱路徑 typed 化等（`runtime-perf-audit.md`、J2）。  
- **現規模：** guest_cap 10–15、小偷 2、污物 6——桌面／Web 仍輕。  
- **新壓力源：** 世界空間 hold radial、地板個人 UI、ops 投放物、清潔／保全店員、影分身＋西客炮／專員、任務 HUD 刷新、雙人固定速率呈現。

### 本輪效能項

| 優先 | 項目 | 狀態／建議 |
| --- | --- | --- |
| P0 | 實機／目標硬體幀時間基線 | **配方＋空店＋桌面滿載輔測已有**（[`perf-baseline-j1.md`](perf-baseline-j1.md)）；**Deck／Switch／雙人 Editor Profiler 仍待填** |
| P1 | 滿載手動 Profiler 一筆桌面數字 | O1：headless `--load` 已入表；雙人 ≥30s Editor Profiler 仍建議補 |
| P1 | 技能／ops 生成節流 | 部署體與炸彈殘留需有 cap／despawn（對照既有 thief／dirt cap 紀律） |
| P2 | PC Forward+ vs Compatibility | 仍合理；非阻塞 |
| P2 | 十呎／TV 安全區 UI | PlatformServices 有 profile；主機認證級未到 |

**結論：** 效能工程仍屬獨立團隊優良水準；**瓶頸仍是驗收迴路而非新的紙上微優化清單。** 巨石回脹會間接傷害「誰敢動熱路徑」。

---

## 4. 遊戲設計標準（Design Quality）

對照常見商業／獨立評審軸（核心循環、可讀性、進度、難度、內容層、多人公平、數據可調）。

| 標準 | 評級 | 說明 |
| --- | --- | --- |
| **核心循環清晰度** | 優 | 準備 → 補貨 → 營運 → 結算未變；幻想一致 |
| **操作爽感／節奏** | 優 | 持貨 focus／丟掉、世界 hold radial、技能 CD 徑向、ops 袋、收銀 INT 重做——手感層加厚 |
| **系統深度 vs 複雜稅** | 中高風險 | 技能表極密＋ops＋任務＋教學；有 validator／tutorial skill，但認知負擔續升 |
| **進度與長期動機** | 中→中高（設計）／中（產品） | **設計：** 十章框架＋成長三分析＋失敗擋 UX 已拍。**產品：** EA＝純日循環；等級／店擴／評價仍是主動機 |
| **難度曲線** | 弱–中 | `difficulty.md` 仍 stub；簡易／普通測試殼；倍率表未接流量 |
| **新手引導／失敗可讀** | 中→中上 | H2 首日引導／跳過／暫停重溫；失敗敘事仍＝**EA 不做**（正確對齊） |
| **Live-ops／後製內容** | 弱–中 | 任務條件活線＋隨機 ops 條件；報酬／章節解鎖仍 Beta；`eventsystem.md` 仍不存在 |
| **平衡工具** | 中上 | `tuning.gd`；缺遙測；獨立 EA 可接受 |
| **多人設計完整性** | 優 | 同 v0.2；權威模型清楚 |
| **內容管線** | 中上→優 | v1.5 中期美術＋pause chrome＋SKU／技能圖；劇情內容表仍 stub |
| **無障礙／輸入包容** | 中 | InputMap＋手把＋觸控；TV／色盲／完整重映射未到認證級 |

**設計結論：**  
- **單日動作經營**已達可 EA 打磨品質，且較 v0.2 更「完整店」感（雇員角色、ops、任務板、教學）。  
- **劇情＋事件＋經營三層產品**在文件上已有可信骨架，但**不可對外承諾檔期**——與 `versioning.md` EA 範圍一致即可，避免行銷／貢獻者超車。

---

## 5. 平台評估（更新）

| 面向 | Steam | Switch／Xbox |
| --- | --- | --- |
| 技術路徑 | Godot 4.7 + GodotSteam 4.24；M3 大廳已驗收 | 仍需 W4／埠接；釘版見 `godot-middleware-pin.md` |
| 產品缺口 | **正式 App ID（仍 480）**、Partner Cloud／成就表、商店頁、Deck 驗證清單填實 | 開發者帳號／devkit／Lotcheck·TCR；掛起鉤子在、認證測項未做 |
| 建議順序 | **換正式 ID → 煙測 Cloud／成就 → EA 頁** → 再主機 | 禁止主機專用專案複本 |

PlatformServices：Desktop 完整；Steam **磁碟＋Cloud fileWrite／fileRead＋UserStats stub→接線**（見 `steam-productization.md`）；差的是商店身分與 Partner 配置，不是再寫一層抽象。

---

## 6. 建議路線（v0.3）

| 階段 | 目標 | 工作 |
| --- | --- | --- |
| **L · 巨石再止血** | 可持續 | `demo` 壓回抽出水位；`skill_caster` 分族；prep／pause 再拆；合併門禁「淨增必搬出」 |
| **M · Steam 收尾** | 可上架 | 正式 App ID、Partner 表、Deck 清單、字型子集債清掉 |
| **N · 設計外層閘門** | 產品誠實 | 維持 EA＝純循環；`eventsystem.md` 可開檔但不排活線；章節 runtime 進 Beta milestone |
| **O · 效能驗收** | 硬體地板 | 填 J1 桌面滿載一筆＋Deck；必要時 ops／部署 cap |
| **P · 主機** | 可選 | 帳號＋釘版閘門後再買工具；不與 L／M 搶人力 |
| **Q · 回歸加深** | 工程信頼 | CI 可選 job：關鍵 `*_check.gd`（需 `GODOT=`）；RPC 契約測 1–2 條 |

玩法內容可與 L／M 並行，但**新技能／雇員／世界效果若再只寫進 `demo`／`skill_caster` 本體，A 分會再掉，且拖慢 Steam 熱修速度。**

---

## 7. 跟進清單（建議開 issue）

### 繼承 v0.2（未完）

- [ ] **H1** 正式 Steam App ID（仍 480）— Cloud／成就 API 已接；換 ID＋Partner 表後收尾（見 [`steam-productization.md`](steam-productization.md)）
- [ ] **K1** 主機帳號／釘版重查（執行閘門，非玩法）

### 本輪新增

- [x] **L1** `demo.gd` 壓回 ≤~3900 行— `host/skill_deploy`／`skill_cast`／`clerk_cast`／`ops_world`／`world_spawn`／`toss_world`；`demo.gd` **~3784**（自 5414）
- [x] **L2** 拆 `skill_caster`— `skill_cannon`／`sniper`／`clone`／`ultimate`／`range`／`instant`；編排器 **~401**（自 ~1227）；`cast_slot`／`cast_ultimate` 仍在編排器
- [x] **L3** `prep_menu`／`pause_menu`／`hud` 第二波瘦身— `ui/settings_actions`、`pause/pause_chrome`、`session/task_hud_format`（pause −261 為主）
- [x] **L4** 合併紀律— [`monolith-merge-gate.md`](monolith-merge-gate.md)；淨增須搬遷對帳或豁免
- [x] **M2** 重跑 CJK 字型子集（西客炮／源頭減廢／有糧出…；含 Bold／Black）— 三款 `NotoSansTC-Game*.ttf` cmap 已含目標字
- [x] **N1** 文件閘門：README／`godot/game`／versioning／design／`storysystem` 顯式「劇情框架＝設計；活線未做／EA 不做」
- [x] **N2** （可選）開 `eventsystem.md` 占位——**不**排活線實作
- [x] **O1** J1 紀錄表補桌面滿載列— `j1_perf_probe.sh -- --load`（15 客＋3 分身；process 2.85／physics 13.12 ms）；Deck 仍待
- [x] **Q1** CI 可選 Godot job 跑 3 個關鍵 `*_check.gd`— `tools/run_godot_checks.py`（shelf_sniper／interact_glow／difficulty）；`.github/workflows/ci.yml` `godot-checks` 改動在工作樹（需 `workflow` scope 才能推）

### v0.2 已完成（勿重開）

- [x] F1–F3 抽出／GameHost／熱路徑 typed  
- [x] G1–G2 CI＋多人煙霧清單／靜態錨點  
- [x] H2 設定頁＋首日引導  
- [x] H3 EA 範圍拍板  
- [x] I1 `design.md` 回寫  
- [x] J1 配方文件＋實驗室 probe  
- [x] J2 VFX／drop 池  

---

## 結論

相對 v0.2：產品殼與工程回帰網**達標**，內容與日循環手感**超標**，架構體積**回潮**，設計外層**文件超車、程式未跟（且 EA 不應跟）**。  

以業界獨立團隊標尺：**綜合約 7.0／10**——比上輪更接近「可談 Steam Early Access」；真正卡住上架的是 **正式 App ID／Partner**，卡住中期速度的是 **巨石紀律**。不必換引擎；必須把「寫新招／新世界效果」與「搬出 `demo`／`skill_caster`」綁成同一發布紀律，否則分數會在下一輪再掉回 6 分帶。
