# 角色情境 UI（三環＋腳下條＋持貨預覽）

- 工程活線：`godot/game`
- 交叉：[`control.md`](control.md)、[`opsitems.md`](opsitems.md)、[`replenishmentsystem.md`](replenishmentsystem.md)、[`art-interim-v1.5.md`](art-interim-v1.5.md)、[`hud-art-brief.md`](hud-art-brief.md)
- **Chrome：** [`imdoing-pause-ui-chrome.md`](../../agents/skills/pause-ui-chrome/imdoing-pause-ui-chrome.md) tokens；Ops HUD 形狀／材質主參考 **Kirby's Dream Buffet**（見 [`hud-art-brief.md`](hud-art-brief.md)；禁深色 cyber）
- 實作：`scripts/skill_menu.gd`、`scripts/bag_menu.gd`、`scripts/carry_menu.gd`、`scripts/player/skill_caster.gd`、`scripts/player/bag_caster.gd`、`scripts/player/carry_caster.gd`、`scripts/player/player_floor_bars.gd`、`scripts/player/player_carry_strip.gd`、`scripts/hud.gd`

## 目標

Overcooked 式：螢幕常駐只留**店共用**資訊；個人技能／道具／持貨／耐力跟**角色**走，互動時先出。支援同屏 1–4 seat。

## 螢幕共用（Canvas HUD）

左上**手稿兩行**：時計直跨兩行；右上單行 `營業額 · 評價 · 被偷`；右下數位時間（首位）｜營運／補貨時段。其下另有**獨立任務板**（進行中任務；闊度跟文案；無任務時隱藏）。  
暫停掣：僅虛擬搖桿顯示時出現（Esc／Start 仍可暫停）。

## 三環（短按開）

| 盤 | 開盤 | 揀選 | 確認／取消 |
| --- | --- | --- | --- |
| 技能 | 短按 LB／字母 Y | 左搖桿／WASD | 外圈＝施放；中心 ❌／B／J／再開＝取消 |
| 道具 | 短按 RB／I | 左搖桿／WASD | 外圈＝用袋格；中心 ❌／B／J／再開＝取消 |
| 持貨 | 短按面鍵 Y／U | 左搖桿／WASD | 外圈＝改焦點 SKU；中心 ❌／B／J／再開＝取消 |

- 三盤互斥；開盤期間指令模式（唔行路）
- **無長按開盤**；**無** LB 短放技能1
- D-Pad 營運無綁定；唔再做持貨 ±1 主路徑
- 四人同屏：完整選貨靠角色身邊持貨環，**唔做**四人常駐螢幕橫列主路徑

### 技能外圈方位（loadout 槽 0–4）

中心＝❌取消（不佔技能槽）。外圈：1 上、2 左上、3 右上、4 左下、5 右下。  
**技能 CD：** 開盤時圍住該技能格畫剩餘弧（唔喺腳底）。

### 道具外圈方位

中心＝❌。外圈：1 上、2 左、3 右、4 下 → 袋格。

### 持貨外圈

中心＝❌。外圈＝`inventory.grouped()` 各 SKU（icon×n；最多約 8）；選定＝`set_focus_index`。

## 持貨頭頂三格

有貨時頭頂：`[下鄰] ← [焦點] → [上鄰]`。空手隱藏；切焦點後可短留再淡出。完整清單用持貨環直選。

## 腳下條

- **耐力：** dash／跑扣氣後顯示；回氣滿且閒置淡出  
- **技能 CD：** 唔喺腳底；見技能圓盤格外弧 

## 衝刺／跑

Xbox：**X** 輕放＝衝刺、長按＝跑。鍵盤 **Space**。RT 唔再 dash（只參與 LT+RT 奧義）。
