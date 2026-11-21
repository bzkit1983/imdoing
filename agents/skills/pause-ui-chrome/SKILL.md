---
name: pause-ui-chrome
description: >-
  ImDoing 全遊戲 UI Chrome 母本（動森暖系 Cozy）。Pause／HUD／Prep 換皮或生圖時必讀；
  Gemini／Canva paste: imdoing-pause-ui-chrome.md。
---

# UI chrome（動森暖系 Cozy → 全遊戲母本）

**Canonical body（自包含 — 整份貼上生成模型）：**  
[`imdoing-pause-ui-chrome.md`](imdoing-pause-ui-chrome.md)

## When to use

- Pause／Prep／**營運 HUD**／情境 UI 任何 **chrome**（面板、掣、井、耐力條框）
- 用戶提到 Cozy／動森風／統一遊戲 UI 皮
- 階段 3 風格橋：[`game-ui-ux-architect`](../game-ui-ux-architect/SKILL.md) 掛本母本

## Rules

1. Prefer [`imdoing-pause-ui-chrome.md`](imdoing-pause-ui-chrome.md)；**唔好**叫模型讀一堆 repo 路徑。  
2. 其他文件（`hud-art-brief`、`ops-hud-chrome`、`uitypography`）只**引用**本母本，唔另開衝突色票。  
3. Assets: 透明 PNG、圖內無玩家文案；執行期 Cocoa `#5C4938` via Loc。  
4. 無純黑描邊、無 blur 陰影；Focus＝整顆 `#FFD43B`。  
5. Type sizes／spacing：[`uitypography.md`](../../../docs/systemdesign/uitypography.md)。  
6. HUD 生圖用專檔 [`imdoing-ops-hud-chrome.md`](../ops-hud-chrome/imdoing-ops-hud-chrome.md)（唔只靠 Surfaces 一句）。

## Workflow

1. 打開／貼上 `imdoing-pause-ui-chrome.md`。  
2. Pause 用「一次出成包」；HUD 用 Surfaces 規則＋`hud-art-brief` P0 清單。  
3. 匯入 Godot；唔擅自改玩法合約。
