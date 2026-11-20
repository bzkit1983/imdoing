# 角色情境 UI（雙長按圓盤＋腳下條＋持貨預覽）

- 工程活線：`godot/game`
- 交叉：[`control.md`](control.md)、[`opsitems.md`](opsitems.md)、[`replenishmentsystem.md`](replenishmentsystem.md)、[`art-interim-v1.5.md`](art-interim-v1.5.md)
- 實作：`scripts/skill_menu.gd`、`scripts/bag_menu.gd`、`scripts/player/skill_caster.gd`、`scripts/player/bag_caster.gd`、`scripts/player/player_floor_bars.gd`、`scripts/player/player_carry_strip.gd`、`scripts/hud.gd`

## 目標

Overcooked 式：螢幕常駐只留**店共用**資訊；個人技能／道具／持貨／耐力跟**角色**走，互動時先出。支援同屏 1–4 seat。

## 螢幕共用（Canvas HUD）

左上**手稿兩行**：時計直跨兩行；右上單行 `營業額 · 評價 · 被偷`；右下數位時間（首位）｜營運／補貨時段。其下另有**獨立任務板**（進行中任務；闊度跟文案；無任務時隱藏）。  
暫停掣：僅虛擬搖桿顯示時出現（Esc／Start 仍可暫停）。

## 雙長按圓盤

| 盤 | 開盤 | 揀選 | 確認／取消 |
| --- | --- | --- | --- |
| 技能 | 長按 Y／L | 左搖桿 | 外圈放手＝施放；**中心 ❌**（開盤預設）或 B＝取消 |
| 道具 | 長按 X／I | 左搖桿 | 外圈放手＝使用袋格；中心 ❌ 或 B＝取消 |

- 兩盤互斥；開盤期間指令模式（唔行路）
- **Y＋肩／板機技能捷徑暫時關閉**
- D-PAD／鍵盤 1–4 短按即用道具：**暫非主路徑**（指令模式暫借 D-PAD 仍可用）

### 技能外圈方位（loadout 槽 0–4）

中心＝❌取消（不佔技能槽）。外圈：1 上、2 左上、3 右上、4 左下、5 右下。  
**技能 CD：** 開盤時圍住該技能格畫剩餘弧（唔喺腳底）。

### 道具外圈方位

中心＝❌。外圈：1 上、2 左、3 右、4 下 → `bag_slot_up`／`left`／`right`／`down`。

### 短按

- Y 短按（手掣）：仍直放 loadout 槽 0  
- L 短按（鍵盤）：開 latch 盤（預設 aim＝❌；方向即放；再 L 關盤）

## 持貨頭頂三格

LB／RB（鍵盤 `[`／`]`）切焦點。有貨時頭頂：`[下鄰] ← [焦點] → [上鄰]`。空手隱藏；切換後可短留再淡出。

## 腳下條

- **耐力：** dash／跑扣氣後顯示；回氣滿且閒置淡出  
- **技能 CD：** 唔喺腳底；見技能圓盤格外弧 

## 衝刺／跑

Xbox：**RT** 輕放＝衝刺、長按＝跑（由面鍵 X 遷過）。**LT 按下時**抑制 RT dash／跑（護 LT+RT 奧義）。鍵盤仍 **K**。
