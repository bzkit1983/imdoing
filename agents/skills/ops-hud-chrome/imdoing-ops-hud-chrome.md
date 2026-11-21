---
name: imdoing-ops-hud-chrome
description: "ImDoing 營運 HUD chrome — 甜點菜單板語彙；Gemini 自包含 paste"
---

# ImDoing — Ops HUD Chrome（甜點派對菜單板）

> **給 Gemini／圖像模型用的自包含 skill。** 整份貼上作 System instruction／Gem 知識／對話開頭即可。**唔需要**讀其他專案檔案、**唔需要／唔准**餵任何遊戲截圖或第三方 UI 圖。  
> 色票與 Pause 全遊戲母本一致；本檔只定 **營運 HUD／情境 UI** 的形狀與密度。

**Theme:** warm candy daylight · dessert-menu plaque · ornate food frame · soft 1.5D bevel  
**Scope:** 便利店遊戲 **營運中常駐 HUD**＋情境板（手稿／任務／圓盤井／耐力／持貨框）  
**唔做:** Pause 完整雙層卡包、SKU／技能內容 icon、世界 voxel、cyber 玻璃、空白厚塑料軟膠空框

---

## 一句定調

營運 UI 要像甜點派對裡的 **實體菜單板／餐牌**：暖橙或蜜糖色 **ornate 外框**、奶油／羊皮 **內頁**、可選頂中 **餐具圓章**、可選 **扇貝／波浪邊** 與 **緞帶標題形**；Focus 掣可用 **薄荷青綠斜紋**＋左側 **暖金星圓章**。板是「食物道具」，不是系統視窗、不是羊皮收銀小票、不是深色 HUD。

色票必須用下方 Tokens（與全遊戲 Cozy 母本相同 hex）。圖內 **禁止任何玩家文案**；執行期用 Cocoa Ink 疊字。

---

## Tokens — Colors（必須遵守）

| Name | Hex | HUD 用法 |
|------|-----|----------|
| Cream Canvas | `#FFFDF2` | 內頁外層、貼紙白邊、次要掣底 |
| Warm Parchment | `#F7EED6` | 內頁凹底、板心淨色區 |
| Soft Sand Border | `#DFD3B8` | 柔邊、4px 底厚邊 |
| Honey Frame | `#F2A65A` | **菜單外框主色**（暖橙蜜糖） |
| Honey Frame Deep | `#D9843A` | 外框底厚邊／角飾加深 |
| Cocoa Ink | `#5C4938` | 執行期文字 only（唔烤入圖） |
| Muted Taupe | `#9C8B7A` | 次要執行期字 |
| Sunlit Gold | `#FFD43B` | 星章、左 tab、Focus 金填 |
| Gold Bevel | `#E0AC16` | 金元件底邊 |
| Mint Leaf | `#35B59B` | Focus 掣主填、斜紋 |
| Mint Deep | `#2A9A84` | Mint 掣底厚邊 |
| Cozy Coral | `#F0645A` | 取消／危險小件 |
| Sky Pastel | `#6EC6E6` | 可選裝飾圓點 |

### Quick

- Panel fill: `#FFFDF2` / `#F7EED6` · Frame: `#F2A65A` + deep `#D9843A`
- Focus pill: `#35B59B` stripes + star badge `#FFD43B`
- Never `#000000` / `#101010` strokes · Never gaussian blur shadows

---

## Shape language（可描述 · 唔抄第三方）

用文字描述生成，**禁止**要求模型模仿某款已上市遊戲截圖或角色臉。

| 元素 | 規則 |
|------|------|
| 外框 | 暖橙／蜜糖；圓角；角可有輕微卷飾；邊可有**極淡**食物／餐具 silhouette 紋（刀叉、杯子、簡化甜點），對比要低 |
| 內頁 | 奶油／羊皮；中央大面積**平坦淨色**（方便 9-slice）；可略半透明感（淺色、唔係灰玻璃） |
| 扇貝邊 | 可選；上下邊輕微波浪／扇貝，唔好過度花俏到無法 9-slice |
| 圓章 | 可選；頂中圓形，內為簡化 **叉＋匙** 或抽象店章；白／奶油 rim |
| 緞帶 | 可選獨立素材；橫向 banner 形，**無字** |
| 1.5D | 只准 **實心底色厚邊** 4–5px；禁止模糊陰影 |
| 常駐密度 | HUD 常駐板＝**簡化**外框＋內頁；紋樣淡、圓章可省略 |
| Modal 密度 | 若另做大提示板，先可用完整 ornate＋圓章＋緞帶（本 P0 以常駐為主） |

---

## Do

- 嚴格用上表 hex
- 透明 PNG、無文字、無純黑線、無 blur 陰影
- 中間留空給引擎字／列表
- 看起來像菜單／餐牌道具
- Focus＝Mint 斜紋掣或整顆 Gold（與 Cozy 一致時可用整顆 `#FFD43B`）

## Don't

- 唔做空白厚塑料「軟膠電視框」
- 唔做深灰／黑半透明 cyber／sci-fi glass
- 唔做羊皮鋸齒小票當主線
- 唔做迷你 Pause 雙層奶油卡（那是另一 surface）
- 唔烤入文字、logo、角色臉、第三方商標
- 唔要求／接受「上傳參考截圖再模仿」——只用本 skill 文字

---

## Export spec

| 規則 | 值 |
|------|-----|
| 格式 | PNG，sRGB，**真透明底**（alpha） |
| Filter 目標 | Godot Nearest（邊緣乾淨） |
| 圖內文字 | **禁止**（❌ 符號可畫入取消鈕） |
| 執行期字色 | Cocoa `#5C4938` |

---

## 素材清單（P0 · 8 件）

1. `panel_shared.9.png` (512×256 建議；中間淨色) — 簡化菜單板；9-slice margin ~48–64px  
2. `radial_cancel.png` (128×128) — 圓盤中心取消；Coral 圓底＋白邊 ❌  
3. `skill_well.png` (160×160) — 技能格空井；甜點碟／軟糖圓框  
4. `bag_well.png` (160×160) — 道具格空井；略同族、可微不同邊飾  
5. `stam_track.png` (192×32) — 耐力槽底軌  
6. `stam_fill.png` (192×32) — 耐力填充條（Mint 或 Gold）  
7. `carry_focus.png` (96×96) — 持貨焦點空框  
8. `pause_fab.png` (128×128) — 小圓暫停掣（Cream＋Sand bevel；無字）

可選 P1（唔擋 P0）：`seal_utensil.png`、`banner_blank.png`

---

## English prompts（逐張複製）

共用前綴：

```text
Game UI chrome asset for a cozy convenience-store OPS HUD (not a pause menu). Dessert-party MENU BOARD language: honey-orange ornate outer frame #F2A65A with deeper bevel #D9843A, cream/parchment inner page #FFFDF2 / #F7EED6, optional faint food-silhouette border pattern, optional soft scalloped edge. Soft candy 1.5D = SOLID bottom color bevel only (4–5px), NO gaussian drop shadow, NO blur, NO pure black outlines (#000/#101010), NO baked text or letters, NO character faces, NO logos, NO cyber glass, NO blank thick plastic TV bezel, NO paper receipt. Transparent background outside the shape. Crisp edges. Single UI piece only.
```

### `panel_shared.9.png`

```text
[USE SHARED PREFIX]
Asset: panel_shared.9.png. Canvas 512x256 PNG. Simplified dessert menu plaque for nine-slice: honey-orange #F2A65A outer frame (corner radius ~16–20px) with #D9843A solid bottom bevel; inner cream #FFFDF2 / parchment #F7EED6 flat empty center (large clean area). Optional very subtle utensil silhouettes in the frame only. No top seal required. No text. Transparent outside.
```

### `radial_cancel.png`

```text
[USE SHARED PREFIX]
Asset: radial_cancel.png. Canvas 128x128 PNG. Circular soft-candy cancel well: cozy coral #F0645A fill, cream #FFFDF2 rim, solid deeper coral bottom edge. Center may include a simple white X mark only. No letters. Transparent outside.
```

### `skill_well.png`

```text
[USE SHARED PREFIX]
Asset: skill_well.png. Canvas 160x160 PNG. Empty round skill socket like a dessert plate / soft candy ring: cream rim, parchment well center empty, honey or sand bevel. No icons, no text. Transparent outside.
```

### `bag_well.png`

```text
[USE SHARED PREFIX]
Asset: bag_well.png. Canvas 160x160 PNG. Empty round item socket, same family as skill well but slightly different rim detail (e.g. tiny tab). Empty center. No text. Transparent outside.
```

### `stam_track.png`

```text
[USE SHARED PREFIX]
Asset: stam_track.png. Canvas 192x32 PNG. Horizontal stamina TRACK only: cream/parchment capsule trough with soft sand #DFD3B8 border and solid bottom bevel. Empty interior for a separate fill layer. No text. Transparent outside.
```

### `stam_fill.png`

```text
[USE SHARED PREFIX]
Asset: stam_fill.png. Canvas 192x32 PNG. Horizontal stamina FILL bar only: mint leaf #35B59B (or sunlit gold #FFD43B) capsule with deeper solid bottom bevel. No track, no text. Transparent outside.
```

### `carry_focus.png`

```text
[USE SHARED PREFIX]
Asset: carry_focus.png. Canvas 96x96 PNG. Empty rounded square focus frame for carried item: honey or gold rim #FFD43B / #F2A65A, cream inner hole fully transparent/empty, solid bottom bevel. No icon. No text. Transparent outside.
```

### `pause_fab.png`

```text
[USE SHARED PREFIX]
Asset: pause_fab.png. Canvas 128x128 PNG. Small circular pause FAB: cream #FFFDF2 fill, soft sand #DFD3B8 bevel, optional tiny mint accent dot. No pause glyph required (engine may overlay). No text. Transparent outside.
```

---

## 一次出成包（總指令）

```text
You are generating an OPS HUD UI chrome pack for ImDoing. Follow the ImDoing Ops HUD Chrome skill exactly (dessert-party menu board: honey-orange frame, cream inner page, soft solid bevels, cozy hex tokens). No pure black strokes. No gaussian shadows. No baked text. No character faces. No cyber UI. No blank thick plastic bezel. No receipt paper.

Produce one transparent PNG at a time, consistent style:

1. panel_shared.9.png
2. radial_cancel.png
3. skill_well.png
4. bag_well.png
5. stam_track.png
6. stam_fill.png
7. carry_focus.png
8. pause_fab.png

After each image, restate the filename. Prefer true alpha. If the tool cannot output alpha, say so and keep checkerboard OUT of the pixels.
```

---

## 你點用（Gemini）

1. 開 Gem 或新對話 → **貼上本 md 全文**（唔好只貼摘要）。  
2. 貼「一次出成包」，或逐張用 English prompts。  
3. **唔上傳**任何第三方遊戲截圖當 reference。  
4. 檢收：真 alpha、無烤字、有蜜糖外框語彙、唔係空白厚框。  
5. 合格先入工程 `art/ui/hud/`；失敗就改 prompt／人手修，唔好無限盲 regenerate。

---

## Out of scope

- 改 HUD 玩法／輸入契約  
- Pause 12 件素材包（另用 Pause chrome skill）  
- 要求模型讀 repo 路徑或外部網頁
