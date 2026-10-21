# Noto Sans TC 子集化方案

- 活線：`godot/game`
- 目的：把完整 `NotoSansTC-Regular.otf`（約 5.5MB）換成遊戲字集子集，降低 Switch／Web 記憶體與載入（tech-review P0）
- 授權：SIL OFL 1.1（見 `godot/game/fonts/OFL.txt`）

## 現況

| 檔案 | 角色 |
| --- | --- |
| `godot/game/fonts/NotoSansTC-Game.otf` | **執行期**字型（約 170KB；由字集重建） |
| `godot/game/fonts/charset_game.txt` | 目前收進子集的字元表（工具產出，可提交） |
| `godot/game/fonts/source/NotoSansTC-Regular.otf` | 完整字型，**僅重建用**，已 `.gitignore`，不進版控 |
| `tools/fonts/subset_notosans_tc.py` | 收字＋`fonttools subset` |

`project.godot`／`themes/default.tres`／`scripts/ui_font.gd` 皆指向 `NotoSansTC-Game.otf`。

## 流程

1. 改了玩家可見文案（`scripts/`、`scenes/`）後，在 repo 根執行：

```bash
pip install fonttools
# 若尚無完整字型：放到 godot/game/fonts/source/NotoSansTC-Regular.otf
# （或保留舊路徑 godot/game/fonts/NotoSansTC-Regular.otf）
python3 tools/fonts/subset_notosans_tc.py
```

2. 工具會：
   - 掃活線字串／`.tscn` 的 `text=`，加上數字、基本拉丁與常用標點
   - 寫入 `charset_game.txt`
   - 對完整 Noto Sans TC 做 subset → `NotoSansTC-Game.otf`

3. 用 Godot 開 `godot/game` 確認無豆腐字；缺字就補文案或把字加進 FORCE 清單後重跑。

## 規則

- **只維護活線子集**；凍結的 `alpha_v0_1`／`demo_v0_*` 仍可留完整字型，不跟這套重建。
- 新字串進版前應重跑 subset；CI 可選加「charset 與腳本字元差集」檢查（尚未強制）。
- `allow_system_fallback=true` 仍開著，極端缺字會退系統字，但目標是子集自給。
- 不要把完整 5.5MB Regular 再提交進 `godot/game/fonts/`。

## 驗證（本機曾測）

- 字元約 550；子集約 **168KB**（約完整檔的 **3%**）
- 遊戲內抽樣字串（營運準備／貨架／小偷／劇本等）皆在 `charset_game.txt` 內
