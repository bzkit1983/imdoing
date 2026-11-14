# 效能基線 J1（滿店＋技能＋雙人）

- **對應：** tech-review v0.2 **J1**／§3 P0「實機幀時間基線」  
- **目的：** 固定**可重跑配方**＋至少一筆實驗室數字；之後優化／換硬體用同一配方對照。  
- **不是：** 再掃一輪微優化清單（見 [`runtime-perf-audit.md`](runtime-perf-audit.md) DONE）；物件池見 **J2**。

---

## 1. 滿載配方（手動 Profiler · 正式基線）

在 Editor 或桌面匯出包上重現：

| 項 | 設定 |
| --- | --- |
| 活線 | `godot/game` · Godot **4.7** |
| 流量情境 | `game_state.scenario == 3` → `guest_cap() == 15`（否則預設 10） |
| 客人 | 開日後讓店內靠近 **guest_cap**（滿店） |
| 小偷／污物 | 允許自然生成；cap：小偷 `Tuning.THIEF_CAP=2`、污物 `DIRT_CAP=6` |
| 技能壓力 | 至少維持 **多重影分身 Lv3（最多 3 體）**；可再疊進行中的主動／VFX（狙擊手、冷靜力場等） |
| 雙人 | `transport=local` **本機 2 seat**（或 LAN 2 peer；記在紀錄表） |
| 量測時段 | 營運 `phase=open`，兩邊都在動／互動，持續 **≥30 s** 再讀 Profiler 平均 |

### Editor 擷取步驟

1. 以 Debug 執行 `scenes/demo.tscn`（或匯出包＋遠端診斷）。  
2. **Debugger → Profiler**：勾 Script／Physics／Idle 等需要的軌道。  
3. 依上表進入滿載後，Profiler **Clear** → 錄 **30 s** → Stop。  
4. 記錄：平均／峰值幀時間（或 1/FPS）、`TIME_PROCESS`／`TIME_PHYSICS_PROCESS` 熱點前幾名、節點數（Monitor）。  
5. 把一列填進下方「紀錄表」。

---

## 2. 自動化輔測（demo settle · 非正式滿載）

無頭腳本只載入主場景並取樣，**多半停在 `prep`、0 客**，用來確認工具鏈與「空店地板」，**不能**代替 §1。

```bash
# repo root
./tools/j1_perf_probe.sh
# 或: GODOT=/path/to/Godot ./tools/j1_perf_probe.sh
```

輸出前綴 `J1_PROBE`。

---

## 3. 實驗室首筆（2026-11-14）

| 欄位 | 值 |
| --- | --- |
| 機器 | Apple **M3** · 8 GB · arm64 · macOS |
| Godot | 4.7.2.stable |
| 方式 | `./tools/j1_perf_probe.sh`（headless） |
| 場景 | `demo.tscn` warmup 2 s ＋ sample 4 s |
| phase | `prep` |
| guest_cap / guests / clones | 10 / 0 / 0 |
| samples | 579 |
| avg frame (from FPS) | **6.92 ms**（≈144 FPS 上限附近，headless 參考價值有限） |
| max frame | 6.99 ms |
| avg `TIME_PROCESS` | **0.56 ms** |
| avg `TIME_PHYSICS_PROCESS` | **0.52 ms** |
| nodes / resources | 73 / 175 |
| static mem | ~122.7 MiB |

**解讀：** 空店 prep 在 M3 上腳本＋物理合計 **約 1 ms／幀** 量級，桌面餘裕大。滿店＋影分身＋雙人的瓶頸仍須 §1 手動 Profiler 才能定 Switch／Deck 地板。

---

## 4. 紀錄表（請追加列）

| 日期 | 機器／匯出 | 配方（cap／分身／雙人） | avg frame ms | process ms | physics ms | 備註 |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-11-14 | M3 8GB · headless | prep settle（非正式） | 6.92* | 0.56 | 0.52 | *受 FPS 回報限制；看 process／physics |
| | Deck／低階筆電 | 滿店 15＋分身 3＋雙人 open 30s | | | | 待測 |
| | （未來）Switch | 同上 | | | | 待測 |

---

## 5. 與 audit 的關係

- 已做熱路徑優化：勿在 J1 重審（見 `runtime-perf-audit.md`）。  
- J1 只建立**硬體／滿載對照點**；若滿載 process ≫ 預算，再開 J2（drop-flight／VFX 池）或降 VFX。
