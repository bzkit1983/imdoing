# 巨石合併紀律（tech-review L4／T1）

- **對照：** [`tech-review-v0.3.md`](tech-review-v0.3.md) §2／§7 **L4**；[`tech-review-v0.4.md`](tech-review-v0.4.md) §2／§7 **T1**
- **目的：** 抽出後禁止再把新功能只堆回已監視巨石；v0.4 起覆蓋重量轉移熱點（`game_state`／`prep_*`／`customer`）
- **性質：** 工程流程閘門（文件）；非玩法規格
- **水位 tip（T1）：** 2026-11-28 · `demo` 3608 · `player` 2897 · `skill_caster` 407 · `game_state` 2949 · `prep_menu` 3510 · `prep_pages` 2036 · `customer` 2737

## 監視檔（淨增需說明）

### 既有（L1–L4）

| 檔 | 水位（約） | 新功能應落點 |
| --- | ---: | --- |
| `godot/game/scripts/demo.gd` | **≤ ~4000** | `host/*`（deploy／cast／ops／spawn／toss／net／settle／boss_world／day_*／branch_settle） |
| `godot/game/scripts/player.gd` | **≤ ~3000**（#175 後 tip ~2897） | `player/*` controllers（`frame_ticker`／`interact_*`／`checkout`／`work_ticker`／`input_controller`／`player_view`／`toss`／`fight`） |
| `godot/game/scripts/player/skill_caster.gd` | 編排器 **~400**；族模組另檔 | `player/skill_*_caster.gd` 或新族檔 |

### v0.4 T1 擴充（重量轉移熱點）

| 檔 | 水位（約） | 新功能應落點 |
| --- | ---: | --- |
| `godot/game/scripts/game_state.gd` | **≤ ~3000**（tip ~2949） | 分店／主題店 → `session/branch_*`／`theme_store_snapshot`；精英表／規則 → `session/elite_*`；存檔欄／migration 可留本檔但須對帳 |
| `godot/game/scripts/prep_menu.gd` | **≤ ~3600**（tip ~3510） | 新頁／子流程 → `prep/*`（已有 `prep_pages`、小遊戲、設定）；選單殼只保留導航與狀態 |
| `godot/game/scripts/prep/prep_pages.gd` | **≤ ~2100**（tip ~2036） | 再拆到 `prep/<page>_*.gd` 或依 hub 分檔；避免單頁巨型函式繼續堆 |
| `godot/game/scripts/customer.gd` | **≤ ~2800**（tip ~2737） | 新 AI／狀態／小偷行為優先抽 `customer/`（若尚未建目錄則先開檔再建）；勿再塞通用工具進本體 |

**章節機／事件 runtime：** 一開始就放獨立目錄（例如 `story/`、`events/`），**禁止**先塞進 `demo`／`game_state` 再抽（v0.4 及格線）。

## PR 要求

改動上述任一檔且 **淨增行數 > 0** 時，PR 說明須含其一：

1. **搬遷對帳：** 列出搬出的等量（或更多）行／模組路徑；或  
2. **豁免一句：** 為何必須留在巨石（熱修／單行委託／契約測試錨點／SAVE schema 欄位），並標後續搬遷 issue（可選）

純刪減、純搬遷（巨石行數下降）、或只改註解／字串 **不需** 豁免。

## 靜態錨點

- `tools/test_demo_host_extract.py`：L1 模組 preload／bind／`demo.gd` 行數預算（≤4000）  
- `tools/test_player_extract.py`：`cast_slot`／`cast_ultimate` 仍在編排器；`player.gd` 控制器委託  

合併前必須跑：`python3 tools/run_ci_static.py`（與 GitHub CI 相同；本地 hook 見 [`ci-local.md`](ci-local.md)）。無頭營運回歸見 `tools/run_ops_checks.py`（R1／#149）。

## 熱路徑函式落點（對齊 #175／#148）

歷史審計裡的行號可能過期；以模組為準（詳見 [`runtime-perf-audit.md`](runtime-perf-audit.md)「Path remapping」）：

| 關注點 | 現行落點 |
| --- | --- |
| 玩家每幀／互動掃描 | `player/frame_ticker.gd`（`physics_process`／`update_target`）；輔助 `player/interact_scan.gd` |
| HUD fingerprint／視覺 | `player/player_view.gd`（`hud_fingerprint`／`emit_stats_if_changed`）；`player.gd` 仍持有 `_model_id`／薄委託 |
| 結算／日開始 | `host/day_settle.gd`／`host/day_begin.gd`／`host/branch_settle.gd` |
| 外觀 tint／Vox 播放 | `player/player_view.gd` 經 host；設計見 [`appearance.md`](../systemdesign/appearance.md) |

## 不要做的事

1. 新主動／奧義世界效果只加在 `demo.gd` 本體大段 `func`。  
2. 新技能只加在 `skill_caster.gd` 巨型 `if sid`／`if bool(sk.get` 鏈（應進族模組或表項）。  
3. 為圖省事把 `host/`／`player/`／`session/`／`prep/` 邏輯再 inline 回巨石「暫時方便」。  
4. 把分店／存檔／Prep 新頁／客人 AI 繼續堆進 `game_state`／`prep_menu`／`prep_pages`／`customer` 而不對帳。  
