# 營運 HUD／情境 UI 美術 brief

- 狀態：對齊 [`player-context-ui.md`](player-context-ui.md) 實作後可換皮
- 工程：`godot/game`；Filter＝**Nearest**；圖內**不寫玩家文案**（❌ 符號可畫入圖）

## 螢幕共用（Canvas）

| 資產 | 用途 | 建議 |
| --- | --- | --- |
| `art/ui/hud/panel_shared.9.png` | 左上手稿橫排（時計＋時間｜時段／營業額列） | 半透明深底＋青／金邊 9-slice；矮横板 |
| （可選）時計錶盤／針 | 取代程式 `clock_face`（約 56px） | 可後期 |
| 暫停小掣 | 僅 VJ 時顯示 | 可复用 pause mini 或新做 |

## 角色情境（世界空間·每 seat 一套）

| 資產 | 路徑建議 | 說明 |
| --- | --- | --- |
| 圓盤取消中心 | `art/ui/hud/radial_cancel.png` | 圓圈 ✕；技能／道具共用 |
| 技能槽井 | `art/ui/hud/skill_well.png` | 外圈五點陣底板（可程式圓代替） |
| 道具槽井 | `art/ui/hud/bag_well.png` | 十字四格 |
| 持貨焦點框 | `art/ui/hud/carry_focus.png` | 三格預覽中格金框 |
| 腳下耐力 track／fill | `art/ui/hud/stam_track.png`、`stam_fill.png` | 角色下方（只耐力） |
| 技能 CD 環 | （程式 `draw_arc` 或可選 `cd_ring.png`） | 圍技能圓盤格；唔再腳底小條 |

內容 icon 仍走既有：`art/ui/skill/<id>.png`、`art/ui/ops_item/<id>.png`、`art/ui/sku/<id>.png`。

## 不做（本 brief）

- 螢幕右下常駐技能 chip／道具十字／右上耐力持貨列（已改角色側）
- 觸控 VJ chrome（另開）
- 暫停選單全套（已有 `pause_menu_ui`）
