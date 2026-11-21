---
name: imdoing-pause-ui-chrome
description: "ImDoing 全遊戲 UI Chrome 母本 — 動森暖系 Cozy；Pause／HUD／Prep 共用 tokens"
---

# ImDoing — UI Chrome（動森暖系 Cozy 風）

> **Repo 唯一色票／材質母本。** 給 Gemini／Canva／任何圖像模型用的自包含 skill。  
> 整份貼上作 System instruction／Gem 知識／對話開頭即可。**唔需要**讀其他專案檔案。  
> 字級／間距另見工程 `docs/systemdesign/uitypography.md`（本檔唔重複定義 Type Scale）。

**Theme:** warm daylight · cozy rounded-pill · 1.5D soft bevel（無死黑框、無模糊陰影）  
**Scope:** 便利店遊戲 **全部 Canvas／選單 chrome**——Pause 完整雙層卡＋膠囊掣；營運 HUD／情境 UI／Prep 殼用**同一套 tokens**（板可半透明／更矮）。  
**唔做:** SKU／技能／道具**內容** icon、世界 voxel、整頁網站 hero collage、深色 cyber／sci-fi 玻璃 HUD

---

## 一句定調

參考《集合啦！動物森友會》UI 的治癒手感：棄用刺眼撞色與 1px 死黑線框，改用 **奶油白＋暖羊皮紙雙層大圓角卡片**、**全圓角膠囊按鈕（Full-Capsule Pill）**，並以 **底部 4–5px 暖色實體厚邊（1.5D Bevel）** 營造軟膠按鍵立體感；選中（Focus）時直接以 **暖金黃 `#FFD43B` 整顆填滿**，無文字烤入 PNG，方便 Godot 疊加執行期多語系字型。

**全遊戲統一呢套皮。** Pause＝置中實心雙層卡（動森手感）；營運 HUD＝**同色票**、材質改走《Kirby's Dream Buffet》式 **甜點菜單板**（暖橙／蜜糖 ornate 外框、奶油內頁、餐具圓章、可選緞帶／扇貝邊），半透明睇到店面；禁止另開深灰／黑半透明「cyber」語彙。人眼截圖細節見工程 `hud-art-brief.md`（唔餵 AI、唔抄角色面）。

---

## Surfaces（同一 tokens · 不同密度）

| Surface | 板 | 圓角 | 備註 |
|---------|----|------|------|
| **Pause** | 實心雙層 Cream／Parchment | 外 28／內 20 | 下方完整素材包；手感參考 ACNH（可後遷 Dream Buffet modal 語彙） |
| **Ops HUD／情境** | **半透明** Cream 菜單內頁＋暖橙食物外框（簡化） | ~14–16 | **主參考：** Kirby Dream Buffet；清單／可抄表見 `hud-art-brief.md` |
| **Prep** | 目標同 Pause 家族 | 跟選單密度 | 過渡深底佔位須遷向本 tokens |

---

## Tokens — Colors（必須遵守）

| Name | Hex | 用法（全遊戲 chrome） |
|------|-----|------------|
| Cream Canvas | `#FFFDF2` | 主面板外殼、標準按鈕底色、貼紙外圈白邊 |
| Warm Parchment | `#F7EED6` | 主面板內凹底板、音量小鍵底色 |
| Soft Sand Border | `#DFD3B8` | 面板與按鈕的柔和邊線及 4–5px 底部厚邊 |
| Cocoa Ink | `#5C4938` | 執行期文字色（取代純黑 `#000000`，圖內無字） |
| Muted Taupe | `#9C8B7A` | 次要資訊／Disabled 文字色 |
| Stone Mist | `#EAE3D2` | Disabled 按鈕填色（底邊 `#D5CCB8`） |
| Sunlit Gold | `#FFD43B` | **Focus 焦點整顆填色**（底邊 `#E0AC16`）＋ 八角星貼紙 |
| Pressed Amber | `#F2B824` | 按下態填色（下壓 3px，底邊 `#D99B14`） |
| Cozy Coral | `#F0645A` | 危險鍵（結束本日營業，底邊 `#C9463D`） |
| Mint Leaf | `#35B59B` | 頂部浮起標題膠囊、音量格亮色、圓形角標 |
| Sky Pastel | `#6EC6E6` | 晴空藍圓形裝飾貼紙 |

### Quick color reference

- Panel outer: `#FFFDF2` · Panel inner: `#F7EED6` · Soft border／bevel: `#DFD3B8`
- Button normal: `#FFFDF2` + sand bevel
- Focus fill: `#FFD43B` + bevel `#E0AC16`
- Pressed: `#F2B824` + bevel `#D99B14`（視覺下壓約 3px）
- Disabled: `#EAE3D2` + bevel `#D5CCB8`
- Danger: `#F0645A` + bevel `#C9463D`
- Runtime text (engine only): `#5C4938` — **never bake into PNG**
- Never use pure black `#000000` / `#101010` strokes

---

## Tokens — Shape & 1.5D Bevel

| Element | Radius | Bevel / Notes |
|---------|--------|---------------|
| Main Panel Outer | `28px` | `#FFFDF2` 底，2px `#DFD3B8` 邊 + 5px 底部厚邊 |
| Main Panel Inner | `20px` | `#F7EED6` 內嵌底板 |
| Action Pill Buttons | `999px`（全膠囊） | 底部 4–5px 實心厚邊；Focus 時整顆變 `#FFD43B` |
| Mini Buttons (− / +) | `12px–16px`（Squircle） | 圓角方塊小鍵；Focus 變 `#FFD43B` |
| Sticker Badges | 全圓 / 圓角八角星 | 必須帶 4px `#FFFDF2` 貼紙白邊 + 暖沙底邊 |

**1.5D Bevel 規則：** 立體感只來自 **底部實心色塊厚邊**（同色系略深），唔係模糊陰影。按鈕像軟膠／橡皮章。

**絕對禁止：**

- 禁止 `#000000` / `#101010` 純黑描邊
- 禁止高斯模糊陰影（Drop Shadow / Blur）
- 禁止將遊戲文字烤入 PNG 素材內
- 禁止刺眼撞色 flat sticker bomb、死黑細線網頁風

---

## Layout（Pause 適配）

- 主 UI = 置中 **雙層圓角面板**（外 Cream Canvas、內 Warm Parchment）。
- 面板內：標題區留空（執行期字）→ 直向全膠囊按鈕堆疊 → 底部可放危險鍵。
- 音量列用 mini squircle −／＋。
- 可選 1–2 枚白邊貼紙角標貼面板外角；**唔旋轉整列按鈕**。
- Focus = **整顆 Sunlit Gold 填滿**（唔係幼黃 ring 描邊）。

---

## Components

### Panel（`pause_panel.9.png`）

雙層：外殼 `#FFFDF2`、圓角 28px、2px `#DFD3B8` 邊 + 5px 底厚邊；內凹 `#F7EED6`、圓角 20px。中央大面積淨色方便 9-slice。透明底、無字。

### Action pills

| 態 | Fill | Bevel |
|----|------|-------|
| normal | `#FFFDF2` | `#DFD3B8` 4–5px 底 |
| focus | `#FFD43B` | `#E0AC16` |
| pressed | `#F2B824` | `#D99B14`；形體略下移 3px |
| disabled | `#EAE3D2` | `#D5CCB8` |
| danger | `#F0645A` | `#C9463D` |
| danger_focus | `#F0645A` + 外圈暖金光環感（實色／扁平板，無 blur） | `#C9463D`；外圈可用 `#FFD43B` |

全膠囊 `999px`；無字。

### Mini (− / +)

Squircle 12–16px 圓角；normal 用 Warm Parchment／Cream；focus 整顆 `#FFD43B`。圖內無字形（執行期疊 −／＋）。

### Badges

白邊 4px `#FFFDF2` + 暖沙底邊；Mint／Gold 八角星／Sky 圓形；無字。

---

## Do

- 嚴格用上表 hex；Focus 用整顆暖金黃填滿
- 用底部 4–5px 實心厚邊做 1.5D；面板雙層大圓角
- 按鈕全膠囊；小鍵 squircle；貼紙必有奶油白邊
- 透明 PNG、無文字、無純黑線、無模糊陰影

## Don't

- 唔用死黑描邊、高斯陰影、玻璃擬態厚漸變
- 唔用舊佔位**深底＋金**、深灰半透明 cyber／sci-fi HUD、亦唔用 Fictional 撞色 sticker／2px 黃 ring 當主 focus 語彙
- 唔把選單／HUD 文案烤進圖
- 唔令列表按鈕旋轉成 collage
- 唔為營運 HUD 另造一套與上表衝突的色票

---

## Export spec

| 規則 | 值 |
|------|-----|
| 格式 | PNG，sRGB，透明底 |
| 面板 | 640×640；9-slice margin 建議各邊 64–80px（含圓角＋底厚邊） |
| 主按鈕 | 512×128；左右 margin 約 64px（膠囊端）；上下含底 bevel |
| Mini | 128×128 |
| Badge | 256×256 |
| 圖內文字 | **禁止** |
| 執行期字色 | Cocoa Ink `#5C4938` |

---

## 素材包檔案清單（12 件透明 PNG）

1. `pause_panel.9.png` (640×640) — 雙層圓角主面板（可 9-slice 拉伸）
2. `pause_btn_normal.png` (512×128) — 奶油白全圓角膠囊鍵（預設態）
3. `pause_btn_focus.png` (512×128) — 暖金黃 `#FFD43B` 全圓角膠囊鍵（焦點態）
4. `pause_btn_pressed.png` (512×128) — 琥珀黃 `#F2B824` 下壓位移膠囊鍵（按下態）
5. `pause_btn_disabled.png` (512×128) — 暖石灰 `#EAE3D2` 膠囊鍵（停用態）
6. `pause_btn_danger.png` (512×128) — 柔和珊瑚紅 `#F0645A` 膠囊鍵（危險鍵）
7. `pause_btn_danger_focus.png` (512×128) — 珊瑚紅膠囊鍵＋暖金黃外圈光環
8. `pause_btn_mini_normal.png` (128×128) — 圓角方塊音量小鍵（預設態）
9. `pause_btn_mini_focus.png` (128×128) — 暖金黃圓角方塊音量小鍵（焦點態）
10. `pause_badge_circle_violet.png` (256×256) — 薄荷葉 `#35B59B` 白邊圓形貼紙（檔名沿用；色為 Mint）
11. `pause_badge_starburst_yellow.png` (256×256) — 暖金黃 `#FFD43B` 白邊圓角八角星貼紙
12. `pause_badge_circle_lime.png` (256×256) — 晴空藍 `#6EC6E6` 白邊圓形貼紙（檔名沿用；色為 Sky）

---

## English prompts（逐張複製）

共用前綴：

```text
Game UI asset for a cozy convenience-store pause menu. Animal Crossing–inspired warm daylight UI: cream and parchment dual-layer cards, full-capsule soft-rubber buttons, 1.5D solid bottom bevel (4–5px warmer/darker edge), NO pure black outlines (#000/#101010), NO gaussian drop shadows, NO blur, NO baked text or letters, NO watermarks. Transparent background outside the shape. Crisp clean edges. Soft sand borders #DFD3B8. Not a loud sticker-bomb website; single panel or control only.
```

### `pause_panel.9.png`

```text
[USE SHARED PREFIX]
Asset: pause_panel.9.png. Canvas 640x640 PNG. Dual-layer rounded panel for nine-slice: OUTER shell cream canvas #FFFDF2, corner radius ~28px, 2px soft sand #DFD3B8 border plus 5px solid bottom bevel in #DFD3B8. INNER inset panel warm parchment #F7EED6, corner radius ~20px, generous empty flat center. No text. Transparent outside outer shell.
```

### `pause_btn_normal.png`

```text
[USE SHARED PREFIX]
Asset: pause_btn_normal.png. Canvas 512x128 PNG. Full-capsule pill (radius 999) filled cream canvas #FFFDF2 with soft sand #DFD3B8 4–5px solid bottom bevel. Flat soft-rubber look. Empty center for in-engine label. No text. Transparent outside.
```

### `pause_btn_focus.png`

```text
[USE SHARED PREFIX]
Asset: pause_btn_focus.png. Canvas 512x128 PNG. Full-capsule pill filled solid sunlit gold #FFD43B with bottom bevel #E0AC16 4–5px. Entire button gold (focus = filled, not a thin ring). No text. Transparent outside.
```

### `pause_btn_pressed.png`

```text
[USE SHARED PREFIX]
Asset: pause_btn_pressed.png. Canvas 512x128 PNG. Full-capsule pill filled pressed amber #F2B824 with bottom bevel #D99B14. Shape sits ~3px lower (pressed). No text. Transparent outside.
```

### `pause_btn_disabled.png`

```text
[USE SHARED PREFIX]
Asset: pause_btn_disabled.png. Canvas 512x128 PNG. Full-capsule pill filled stone mist #EAE3D2 with bottom bevel #D5CCB8. Soft muted. No text. Transparent outside.
```

### `pause_btn_danger.png`

```text
[USE SHARED PREFIX]
Asset: pause_btn_danger.png. Canvas 512x128 PNG. Full-capsule pill filled cozy coral #F0645A with bottom bevel #C9463D. Soft, not neon. No text. Transparent outside.
```

### `pause_btn_danger_focus.png`

```text
[USE SHARED PREFIX]
Asset: pause_btn_danger_focus.png. Canvas 512x128 PNG. Full-capsule cozy coral #F0645A with bevel #C9463D, plus a flat solid sunlit gold #FFD43B outer halo/ring (no blur glow). No text. Transparent outside.
```

### `pause_btn_mini_normal.png`

```text
[USE SHARED PREFIX]
Asset: pause_btn_mini_normal.png. Canvas 128x128 PNG. Squircle (12–16px radius) filled warm parchment #F7EED6 or cream #FFFDF2, soft sand bottom bevel. Empty center — no minus/plus glyphs. Transparent outside.
```

### `pause_btn_mini_focus.png`

```text
[USE SHARED PREFIX]
Asset: pause_btn_mini_focus.png. Canvas 128x128 PNG. Same squircle fully filled sunlit gold #FFD43B with bevel #E0AC16. No glyphs. Transparent outside.
```

### `pause_badge_circle_violet.png`

```text
[USE SHARED PREFIX]
Asset: pause_badge_circle_violet.png (mint badge). Canvas 256x256 PNG. Circle sticker mint leaf #35B59B with 4px cream #FFFDF2 white sticker rim and soft sand bottom edge. No text. Transparent outside.
```

### `pause_badge_starburst_yellow.png`

```text
[USE SHARED PREFIX]
Asset: pause_badge_starburst_yellow.png. Canvas 256x256 PNG. Rounded octagonal/starburst sticker sunlit gold #FFD43B with 4px cream #FFFDF2 rim and soft sand bottom edge. No text. Transparent outside.
```

### `pause_badge_circle_lime.png`

```text
[USE SHARED PREFIX]
Asset: pause_badge_circle_lime.png (sky badge). Canvas 256x256 PNG. Circle sticker sky pastel #6EC6E6 with 4px cream #FFFDF2 rim and soft sand bottom edge. No text. Transparent outside.
```

---

## 一次出成包（總指令）

```text
You are generating a pause-menu UI chrome asset pack for ImDoing. Follow the ImDoing Pause UI Chrome skill (Animal Crossing cozy warm: dual-layer cream/parchment panel, full-capsule pills, 1.5D solid bottom bevel, focus = full #FFD43B fill). Exact hexes. No pure black strokes. No gaussian shadows. No baked text.

Produce (or give ready-to-run image prompts for) this complete set, one asset at a time, consistent style:

1. pause_panel.9.png
2. pause_btn_normal.png
3. pause_btn_focus.png
4. pause_btn_pressed.png
5. pause_btn_disabled.png
6. pause_btn_danger.png
7. pause_btn_danger_focus.png
8. pause_btn_mini_normal.png
9. pause_btn_mini_focus.png
10. pause_badge_circle_violet.png (mint #35B59B)
11. pause_badge_starburst_yellow.png
12. pause_badge_circle_lime.png (sky #6EC6E6)

After each image, restate the filename.
```

---

## 你點用素材包

1. 將本 md 全文貼入 Gemini Gem／對話。
2. 貼「一次出成包」或逐張 prompt 出 PNG。
3. 匯入 Godot：`NinePatchRect`／`StyleBoxTexture`／Theme；文案用 Cocoa Ink＋Loc／Noto。
4. **唔**把文字烤進 PNG。

---

## Out of scope

- 改 Pause 開關／線上行為契約（除非另開任務）
- SKU／技能／道具 icon、宣傳整頁 collage
- 要求模型讀任何 repo 路徑
