# 本地 CI 閘門（減少遠端 FAIL）

GitHub Actions 唯一 gate：`python3 tools/run_ci_static.py`（見 [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml)）。

## 手動跑（與 CI 相同）

```bash
python3 tools/run_ci_static.py
```

## pre-push hook

版控 hook：[`tools/githooks/`](../../tools/githooks/)。每個 clone 啟用一次：

```bash
git config core.hooksPath tools/githooks
```

緊急跳過：`SKIP_CI_HOOK=1 git push`。

細節見 [`tools/githooks/README.md`](../../tools/githooks/README.md)。

## Agent

改動活線遊戲／契約測試／locale／manifest／InputMap 後，完成前必須跑上述指令（見根目錄 [`AGENTS.md`](../../AGENTS.md)）。`demo.gd` 行數預算見 [`monolith-merge-gate.md`](monolith-merge-gate.md)。
