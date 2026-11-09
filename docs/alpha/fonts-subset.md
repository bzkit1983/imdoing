# Noto Sans CJK 子集化方案（多語）

- 活線：`godot/game`
- 目的：把完整 Noto Sans CJK（約 16MB 區段 OTF）換成遊戲字集子集，涵蓋 **繁中／簡中／日文假名**，降低 Switch／Web 記憶體與載入（tech-review P0）
- 授權：SIL OFL 1.1（見 `godot/game/fonts/OFL.txt`）

## 現況

| 檔案 | 角色 |
| --- | --- |
| `godot/game/fonts/NotoSansTC-Game.ttf` | **執行期**字型（TrueType 子集；檔名沿用；字形含 TW+CN+JA） |
| `godot/game/fonts/charset_game.txt` | 目前收進子集的字元表（工具產出，可提交） |
| `godot/game/fonts/source/NotoSansCJKjp-Regular.otf` | 完整字型（**優先**，含假名），僅重建用，已 `.gitignore` |
| `godot/game/fonts/source/NotoSansCJKtc-Regular.otf` | 可作備援來源（無假名時 ja 會缺字） |
| `tools/fonts/subset_notosans_tc.py` | 收字＋`fonttools subset` |

`project.godot`／`themes/default.tres`／`scripts/ui_font.gd` 皆指向 `NotoSansTC-Game.ttf`。

## 流程

1. 改了玩家可見文案（`scripts/`、`scenes/`、`locale/*.csv` 任一語系欄、SFX catalog trigger）後，在 repo 根執行：

```bash
pip install fonttools cu2qu
# 若尚無完整字型：放到 godot/game/fonts/source/NotoSansCJKjp-Regular.otf
python3 tools/fonts/subset_notosans_tc.py
```

2. 工具會：
   - 掃活線字串／`.tscn` 的 `text=`，加上數字、基本拉丁、常用標點、**完整平假名／片假名**
   - 掃 `locale/strings.csv` 與 `locale/data.csv` 的 **全部語系欄**（`zh_TW`／`en`／`zh_CN`／`ja`…）
   - 寫入 `charset_game.txt`
   - 對完整 Noto Sans CJK JP（優先）做 subset，再轉成 TrueType → `NotoSansTC-Game.ttf`

3. 用 Godot 開 `godot/game`，切 `Loc.set_locale("ja")`／`"zh_CN"` 確認無豆腐字；缺字就補文案或把字加進 FORCE 清單後重跑。

## 規則

- **只維護活線子集**；凍結的 `alpha_v0_1`／`demo_v0_*` 仍可留完整字型，不跟這套重建。
- 新字串進版前應重跑 subset；CI 可選加「charset 與腳本字元差集」檢查（尚未強制）。
- `allow_system_fallback=true` 仍開著（桌面缺字可退系統字）；**HTML5／iOS Safari 不支援系統字型**，缺字會變豆腐／亂碼，因此子集必須自給，且使用 **TrueType（glyf）** 而非 CFF/OTF。
- 不要把完整 16MB Regular 再提交進 `godot/game/fonts/`（僅 `source/`，gitignored）。
- 日文必須用 **JP** 來源；只用 TC 來源會缺假名。

## 驗證

- 字元約 1400+（含假名）；TrueType 子集約 **0.8–1MB**（視字集）
- 抽樣：`缶詰`／`暂停`／`あカ`／技能選單日文須在 `charset_game.txt` 與 TTF cmap 內
