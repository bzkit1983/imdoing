# 角色情境 UI（Ambient Peek＋持貨／道具／技能）

- 工程活線：`godot/game`
- 交叉：[`control.md`](control.md)、[`opsitems.md`](opsitems.md)、[`replenishmentsystem.md`](replenishmentsystem.md)、[`art-interim-v1.5.md`](art-interim-v1.5.md)、[`hud-art-brief.md`](hud-art-brief.md)
- **Chrome：** [`imdoing-pause-ui-chrome.md`](../../agents/skills/pause-ui-chrome/imdoing-pause-ui-chrome.md) tokens；Ops HUD 形狀／材質主參考 **Kirby's Dream Buffet**（見 [`hud-art-brief.md`](hud-art-brief.md)；禁深色 cyber）
- 實作：`scripts/player/player_bag_diamond.gd`、`player_carry_strip.gd`、`player_skill_pips.gd`、`player_floor_bars.gd`、`skill_menu.gd`、`scripts/player/skill_caster.gd`、`scripts/hud.gd`

## 目標

Overcooked 式：螢幕常駐只留**店共用**資訊；個人技能／道具／持貨／耐力跟**角色**走。支援同屏 1–4 seat。  
程式 Flat／`StyleBox` 先落地（同任務欄）；換皮後補。

## 螢幕共用（Canvas HUD）

左上**手稿兩行**：時計直跨兩行；右上單行 `營業額 · 評價 · 被偷`；右下數位時間｜營運／補貨時段。其下**獨立任務板**（無任務時隱藏）。  
暫停掣：僅虛擬搖桿顯示時出現。

## 持貨（身下）

### 顯示

- 位置：耐力條**下面**（`player_carry_strip`）
- **平常：** 只顯示**焦點一格**；空手隱藏
- **長按 LB（≥220ms）／鍵 Y·I：** 展開固定 **5 格**，**中間第 3 格＝焦點**：`[−2][−1][FOCUS][+1][+2]`；焦點可再放大 5–10%
- 總種類 >5：循環捲入視窗
- **持貨環：非主路徑**（廢主操作）

### 操作

| 輸入 | 行為 |
| --- | --- |
| 長按 LB（≥220ms） | 展開五格揀選 |
| 長按 LB + X／B | 焦點循環左／右（借用 X／B） |
| 放開 LB | 收攏 |
| 鍵盤 **Y**／**I** | 焦點左／右（短展開五格後 linger） |

左搖桿／WASD 揀選期間可移動。

## 道具（斜十字 Ambient）

### 顯示

- 角色側／髖旁**鑽石四井**（上右下左＝袋格 0–3）；`StyleBoxFlat` 語意同任務欄
- 袋 ≥1 顯示；清空隱藏；用盡 linger ~1.2s
- 空格幽靈；有貨＝`OpsItemIcons`
- **廢道具環主路徑 ≠ 刪斜十字**（獨立 `player_bag_diamond.gd`）
- 螢幕 `OpsBagCross`：非主顯示

### 操作

| 輸入 | 行為 |
| --- | --- |
| D-Pad 上／右／下／左 | 即用對應袋格 |
| 鍵盤 ↑→↓← | 同上 |

## 技能

### 操作

| 輸入 | 行為 |
| --- | --- |
| 長按 RB（≥220ms） | 開技能環（可邊行） |
| 右搖桿 | 瞄中外圈＝即施放 |
| B／中心／放開 RB | 取消關環 |
| 鍵盤 1–5 | 穴 1–5 直放（主動序） |

奧義：LT+RT／K。短按 LB／RB、面鍵 Y：備用。

### 環穴（只主動）

1 上 · 2 右 · 3 下 · 4 左 · 5 **右上** · 中心❌  
被動**唔入環**。

### 顯示

- **開環：** 只主動格＋CD 弧
- **關環頭頂**（`player_skill_pips`）：`[被動常駐…][主動 CD／buff…]`；就緒主動暫唔出

## 腳下

- 只有耐力條；技能 CD 唔喺腳底

## 刻意不做

- 角色資訊欄；螢幕底技能／道具常駐列；MH LB+X／B 以外嘅 chord；觸控本輪未對齊
