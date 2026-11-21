# 巨石合併紀律（tech-review L4）

- **對照：** [`tech-review-v0.3.md`](tech-review-v0.3.md) §2／§7 **L4**
- **目的：** 抽出後禁止再把新功能只堆回 `demo.gd`／`player.gd`／`skill_caster.gd` 本體
- **性質：** 工程流程閘門（文件）；非玩法規格

## 監視檔（淨增需說明）

| 檔 | 抽出後水位（約） | 新功能應落點 |
| --- | ---: | --- |
| `godot/game/scripts/demo.gd` | **≤ ~4000**（L1 後；頭目日薄掛線後） | `host/*`（deploy／cast／ops／spawn／toss／net／settle／boss_world） |
| `godot/game/scripts/player.gd` | 維持 F2 後趨勢；勿再吞控制器 | `player/*` controllers |
| `godot/game/scripts/player/skill_caster.gd` | 編排器 **~400**；族模組另檔 | `player/skill_*_caster.gd` 或新族檔 |

## PR 要求

改動上述任一檔且 **淨增行數 > 0** 時，PR 說明須含其一：

1. **搬遷對帳：** 列出搬出的等量（或更多）行／模組路徑；或  
2. **豁免一句：** 為何必須留在巨石（熱修／單行委託／契約測試錨點），並標後續搬遷 issue（可選）

純刪減、純搬遷（巨石行數下降）、或只改註解／字串 **不需** 豁免。

## 靜態錨點

- `tools/test_demo_host_extract.py`：L1 模組 preload／bind／`demo.gd` 行數預算  
- `tools/test_player_extract.py`：`cast_slot`／`cast_ultimate` 仍在編排器  

合併前建議跑：`python3 tools/run_ci_static.py`

## 不要做的事

1. 新主動／奧義世界效果只加在 `demo.gd` 本體大段 `func`。  
2. 新技能只加在 `skill_caster.gd` 巨型 `if sid`／`if bool(sk.get` 鏈（應進族模組或表項）。  
3. 為圖省事把 `host/` 邏輯再 inline 回 demo「暫時方便」。  
