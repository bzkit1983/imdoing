# 幫忙取貨與 COMBO

- 工程活線：`godot/game`
- 交付互動細節見 `customerdelivery.md`；多人連段見 `multiplayer.md` §11.7
- 任務 metric 語意對齊本檔（見 `tasksystem.md`）

## 達標（現行）

任何**成功**交付客人一次（親手／衝刺交付／使命必達／強塞／投擲交對）：

1. 交付 seat 的**個人 COMBO +1**
2. **全隊 COMBO +1**（可接棒：另一 seat 成功交付可延續全隊累加）

**失誤／交錯**（親手交不到、投擲拒收等）→ **個人 COMBO RESET**；全隊不因此清零。

## 完美交付

一次交付把該客**剩餘購物清單交清**（件數 ≥1 即可，不再要求 ≥3）：

1. 該客不滿 **−40**
2. 該筆結帳營收 **×1.2**
3. 營運評級 **P5_COMBO**（+1）一次

## HUD

- 單人：`COMBO n · TEAM n`（通常同值）
- 本機雙人：`COMBO P1 a · P2 b · TEAM t`

## 實作

- `scripts/session/combo_state.gd`
- 鉤子：`player._note_delivery_combo`（手交／使命必達／強塞；衝刺交付走 `_hand_deliver`）；投擲／狙擊手客人路徑在 `demo._resolve_toss_guest`／`_resolve_sniper_guest_landing`
