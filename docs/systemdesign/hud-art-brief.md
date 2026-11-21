# 營運 HUD／情境 UI 美術 brief

- 狀態：行為已落地（程式 Flat／`draw_arc`）；**`art/ui/hud/` 待換皮**
- **Gemini 貼上（Ops HUD 自包含）：** [`agents/skills/ops-hud-chrome/imdoing-ops-hud-chrome.md`](../../agents/skills/ops-hud-chrome/imdoing-ops-hud-chrome.md)
- **色票同源：** [`imdoing-pause-ui-chrome.md`](../../agents/skills/pause-ui-chrome/imdoing-pause-ui-chrome.md)
- **形狀語彙來源（人眼）：** [Kirby's Dream Buffet @ GUIDB](https://www.gameuidatabase.com/gameData.php?id=1502)；截圖 `godot/game/art/ui/hud/_qa/kirby_dream_buffet_ref/`（**唔餵 AI；唔抄角色面／商標**）
- Pause 仍跟動森雙層卡；HUD **唔做成迷你 Pause**
- **生圖：** Gemini 用 Ops skill；**唔用** Canva Magic 當主路徑
- 流程：[`game-ui-ux-architect`](../../agents/skills/game-ui-ux-architect/SKILL.md)
- 工程：`godot/game`；Filter＝**Nearest**；圖內**不寫玩家文案**（❌ 可畫入）
- 交叉：[`player-context-ui.md`](player-context-ui.md)

本檔只列 **要畫咩／檔名／尺寸**；色票、1.5D、禁止事項跟母本。

---

## 方向一句

營運板＝**甜點派對菜單板**：奶油內頁＋暖橙／蜜糖外框＋餐具圓章／緞帶標；唔係羊皮小票、唔係深色玻璃、唔係空白厚塑料框。

---

## 從截圖抽出（可抄 · 不可抄）

| 可抄（語彙） | 不可抄 |
| --- | --- |
| 暖橙／蜜糖 **ornate 外框**（角有裝飾、邊可有食物 silhouette 紋） | Kirby 面、Nintendo／系列 logo |
| 頂中 **圓章**（叉匙／店章）騎在框上 | 原作文案、關卡名 |
| 奶油／羊皮 **內頁**；邊可 **波浪／扇貝 scallop** | 直接貼 GUIDB 圖入包 |
| Focus 掣：**青綠／Mint 斜紋**＋左圓星章（對齊母本 Mint／Gold） | 原作資產再导出當正式皮 |
| 次要掣：奶油底＋左黃／金 tab；可有輕撕紙邊 | |
| 標題可用 **緞帶 banner** 形（字仍執行期疊） | |
| 高飽和糖果色溫；板「像食物道具」多過「像系統窗」 | |

**密度分級**

- **Ops HUD 常駐**（`panel_shared`）：外框＋內頁簡化版；圓章可選、紋樣要淡，半透明睇店
- **Modal／結算／大提示**：可用完整 ornate＋圓章＋緞帶（之後 Pause／結算若遷向此線再開）

---

## 而家要唔要畫？

| 類 | 要做？ | 說明 |
| --- | --- | --- |
| **HUD chrome**（P0） | **要** | 人手／向量跟上表語彙＋Cozy hex |
| 技能／道具／SKU icon | **唔使今輪** | 已有 |
| Pause 全套 | **唔使** | 已有；語彙可後遷 |
| 觸控 VJ chrome | **唔使** | 另開 |

---

## P0 — 必做（8 張）

| # | 檔名 | 建議尺寸 | 用途 |
| --- | --- | --- | --- |
| 1 | `panel_shared.9.png` | 128×64（中間淨色） | 左上手稿＋任務板；9-slice ~16–24；**簡化版菜單板框** |
| 2 | `radial_cancel.png` | 64×64 | 圓盤中心 ❌ |
| 3 | `skill_well.png` | 80×80 | 技能格空井（甜點碟／軟糖邊） |
| 4 | `bag_well.png` | 80×80 | 道具格空井 |
| 5 | `stam_track.png` | 96×16 | 耐力槽底 |
| 6 | `stam_fill.png` | 96×16 | 耐力填充 |
| 7 | `carry_focus.png` | 48×48 | 持貨焦點空框 |
| 8 | `pause_fab.png` | 64×64 | VJ 暫停小掣（可复用 pause mini） |

輸出：`godot/game/art/ui/hud/`。檢收：真 alpha、無烤字、色票跟母本、形似菜單板／食物框（唔似 cyber／唔似空白厚軟膠）。

## P1

時計盤／針、CD 環、well focus——可程式代替則跳。圓章／緞帶可作獨立小素材疊在板上。

## 工程掛載

`res://art/ui/hud/<檔名>` → `hud.gd`／`skill_menu`／`bag_menu`／`player_floor_bars`／`player_carry_strip`（另開工程）。
