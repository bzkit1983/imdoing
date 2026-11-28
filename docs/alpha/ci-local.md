# 本地 CI 閘門（減少遠端 FAIL）

GitHub Actions：

| Job | 指令 | 何時 |
| --- | --- | --- |
| `static-tests`（必過） | `python3 tools/run_ci_static.py` | 每個 PR／`main` push |
| `godot-checks`（Q1／#154） | 下載 Godot **4.7.2-stable** 後跑 `python3 tools/run_godot_checks.py` | 同上；無頭跑 shelf_sniper／interact_glow／difficulty |

見 [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml)。

## 手動跑（與 CI 相同）

```bash
## 靜態（與 pre-push 相同）
python3 tools/run_ci_static.py

## 無頭 Godot（需本機 4.7.x）
GODOT=/path/to/Godot python3 tools/run_godot_checks.py
## macOS 預設也可：
##   GODOT=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/run_godot_checks.py
```

`run_godot_checks.py` 只收穩定的三支 wrapper；skill_cast／shadow_clone／dark_side 等需 bind 修復後才會加入。

## pre-push hook

版控 hook：[`tools/githooks/`](../../tools/githooks/)。每個 clone 啟用一次：

```bash
git config core.hooksPath tools/githooks
```

緊急跳過：`SKIP_CI_HOOK=1 git push`。

細節見 [`tools/githooks/README.md`](../../tools/githooks/README.md)。  
Hook **只跑靜態**；無頭 Godot 依賴本機編輯器，請在改技能／互動／難度契約後手動跑 `run_godot_checks.py`。

## Agent

改動活線遊戲／契約測試／locale／manifest／InputMap 後，完成前必須跑靜態指令（見根目錄 [`AGENTS.md`](../../AGENTS.md)）。`demo.gd` 行數預算見 [`monolith-merge-gate.md`](monolith-merge-gate.md)。
