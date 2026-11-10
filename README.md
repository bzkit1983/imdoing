# iamdoing
Repository for game project

## 現在改哪裡？（v1.0 活線）

用 Godot **4.7** 打開 **`godot/game`**。  
版控策略：[`docs/versioning.md`](docs/versioning.md) · Godot 目錄說明：[`godot/README.md`](godot/README.md)

**Coding agents（任何工具）：** 先讀根目錄 [`AGENTS.md`](AGENTS.md)；多語言內容流程見 [`agents/skills/i18n-content/SKILL.md`](agents/skills/i18n-content/SKILL.md)。

**產品版：** `v1.4.0`（全單位改「件」；見 [`VERSION`](VERSION)、[`docs/versioning.md`](docs/versioning.md)；上一錨點 `v1.3.0`）  
**網頁試玩：** https://bzkit1983.github.io/imdoing/play/

技術設計審查（效能／Steam·Switch·Xbox／跟進清單）：[`docs/alpha/tech-review-v0.1.md`](docs/alpha/tech-review-v0.1.md)

## 凍結快照（勿開新功能）

以下目錄已凍結（見各目錄 `FROZEN.md`）。僅供對照或修展示損壞：

| 路徑 | 說明 | 試玩 |
| --- | --- | --- |
| `godot/alpha_v0_1` | Alpha v0.1 Voxel 開店 | [play-alpha-v01](https://bzkit1983.github.io/imdoing/play-alpha-v01/) |
| `godot/demo_v0_6` | 準備回合、資金、店員 | [play-v06](https://bzkit1983.github.io/imdoing/play-v06/) |
| `godot/demo_v0_5` | 小偷與連打 | [play-v05](https://bzkit1983.github.io/imdoing/play-v05/) |
| `godot/demo_v0_4` | 污物與清潔 | [play-v04](https://bzkit1983.github.io/imdoing/play-v04/) |
| `godot/demo_v0_31` | 長線數值與技能疊加 | [play-v031](https://bzkit1983.github.io/imdoing/play-v031/) |
| `godot/demo_v0_3` | 技能 LV3、觸控 | [play-v03](https://bzkit1983.github.io/imdoing/play-v03/) |
| `godot/demo_v0_2` | 經營時段、客人、收銀 | — |
| `godot/demo_v0_1` | 執貨／上架／移動 | — |

各 Demo scope：`docs/demo/`。Alpha Voxel 說明：`docs/alpha/voxel-v0.1.md`（歷史；新美術改 `godot/game`）。真 3D 遊玩相機延後：[`docs/alpha/voxel-3d-play-deferred.md`](docs/alpha/voxel-3d-play-deferred.md)。

## 設計文件

- 長線規則：`docs/systemdesign/`（含 [`savesystem.md`](docs/systemdesign/savesystem.md)、[`control.md`](docs/systemdesign/control.md)、[`pausemenu.md`](docs/systemdesign/pausemenu.md)、[`soundeffects.md`](docs/systemdesign/soundeffects.md)、[`elitecustomer.md`](docs/systemdesign/elitecustomer.md) 麻煩客人・已落地、[`appearance.md`](docs/systemdesign/appearance.md) 外觀／Look、[`fetchcombo.md`](docs/systemdesign/fetchcombo.md) 幫忙取貨與 COMBO、[`ratingsystem.md`](docs/systemdesign/ratingsystem.md) 評價・設計中、[`difficulty.md`](docs/systemdesign/difficulty.md) 難度 stub）
- 多人連線（本機二＋線上補滿至四人）：[`docs/systemdesign/multiplayer.md`](docs/systemdesign/multiplayer.md)（**M1 已落地**；**§12 M2 LAN 至 M2.9 已落地**；Steam／Web 見 M3／M4）
- 缺口檢視：`docs/systemdesign-gaps.md`
- Alpha 計劃／審查／設計：`docs/alpha/plan.md`、`docs/alpha/design.md`、`docs/alpha/tech-review-v0.1.md`
- 執行期優化分析：`docs/alpha/runtime-perf-audit.md`
- 工程對照：`docs/alpha/implementation-status.md`（存檔、InputMap、暫停／SFX／鏡頭視野、i18n、客人交付、技能組、互動發光、三招狙擊手、Dark Side、多重影分身、M1 本機雙人、Look 外觀、營運飄字、Pages 等）
- 字串表／字型／匯出：`docs/alpha/i18n.md`、`docs/alpha/fonts-subset.md`、`docs/alpha/export-presets.md`
- 角色動畫：`docs/alpha/animation-v1.0.md`（十六向面向）；合約／坑點：[`docs/alpha/animation-facing-8way.md`](docs/alpha/animation-facing-8way.md)；待辦：`docs/alpha/animation-pending.md`
- 主機：`docs/alpha/console-business.md`、`docs/alpha/godot-middleware-pin.md`
- 版控：`docs/versioning.md`
