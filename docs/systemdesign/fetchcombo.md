# 幫忙取貨與 COMBO

- 工程活線：`godot/game`
- 交付互動細節見 `customerdelivery.md`；多人連段見 `multiplayer.md` §11.7

## 達標（Alpha）

一次親手交付（含使命必達／衝刺交付／強塞等清清單路徑）**清完該客剩餘購物清單，且該次清掉件數 ≥ 3**：

1. 該客不滿 **−40**
2. 該筆結帳營收 **×1.2**
3. 交付 seat 的**個人 COMBO +1**；**全隊 COMBO +1**（可接棒：另一 seat 達標延續全隊、不重置）

未達標的交付只斷**個人**連段（全隊不動）。

## HUD

- 單人：`COMBO n · TEAM n`（通常同值）
- 本機雙人：`COMBO P1 a · P2 b · TEAM t`

## 實作

- `scripts/session/combo_state.gd`
- 鉤子：`player._note_delivery_combo`（手交／使命必達／強塞；衝刺交付走 `_hand_deliver`）
