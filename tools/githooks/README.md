# Git hooks（本地 CI 閘門）

`pre-push` 在 push 前跑與 GitHub Actions 相同的：

```bash
python3 tools/run_ci_static.py
```

失敗則拒絕 push，減少遠端 CI FAIL 郵件。

## 啟用（每個 clone 一次）

在 repo 根目錄：

```bash
git config core.hooksPath tools/githooks
```

只改本 repo 的 local config，不碰 global。

## 緊急跳過

```bash
SKIP_CI_HOOK=1 git push
```

## 驗收

1. 弄壞一個契約測試 → `git push` 應被擋住  
2. `SKIP_CI_HOOK=1 git push` 可繞過  
3. 通過後遠端 `tools static (G1)` 應同綠  
