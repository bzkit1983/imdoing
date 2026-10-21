# Alpha v1.0 動作／動畫 — 待處理表

- 對照：本輪已落地項見 [`animation-v1.0.md`](animation-v1.0.md)；需求盤點 canvas／`docs/alpha/plan.md` 動畫插座
- 規則：未勾項之後再生成（MagicaVoxel 細修或加幀）；**不要**為動畫再開 `godot/` 專案複本
- 烘焙：`python3 tools/voxel_character_anims.py`（不覆寫 `art/src/*.vox`）

## 已生成（本輪）

| 角色 | 動畫 | 幀×向 | 狀態 |
| --- | --- | --- | --- |
| player | idle / walk / run / dash / clean / fight / checkout / slip / down / restock | 見 manifest | 已接 `AnimatedSprite2D` |
| customer | idle / walk / angry / leave | 見 manifest | 已接 |
| thief | idle / walk / fight / leave / fly | 見 manifest | 已接 |
| clerk_cashier | idle / walk / checkout | 見 manifest | 已接 |
| clerk_restock | idle / walk / restock | 見 manifest | 已接 |

檔名：`art/sprites/{id}_{anim}_{facing}_{frame}.png` · 清單：`art/sprites/anim_manifest.json`

## 待處理（之後生成）

| 優先 | 對象 | 缺什麼 | 說明 |
| --- | --- | --- | --- |
| P1 | player | walk／run／dash 美術精修 | 現為程序肢體偏移初模；設計師可在 MagicaVoxel 重做姿再擴烘焙 |
| P1 | player | clean／fight／checkout 多幀 | 現 1–2 幀；可加掃把／抓住／按鍵節奏感 |
| P1 | 全角色 | 與 `art/src/*.vox` 外觀對齊 | 動畫姿來自 blockout 模板，未讀設計師已改的靜態 `.vox` |
| P2 | customer | 趕時間／慢客外觀變體 | plan：三模型，非整身改色 |
| P2 | customer | angry 多幀＋不滿表情 | 現單幀舉手 |
| P2 | thief | fly／fight 精修 | 撞飛弧線、打擊對抗姿 |
| P2 | clerk_* | 持箱 walk 專用姿 | 現 restock 姿＋BoxStack 未綁店員 |
| P2 | shelf_* | `fill_0`…`fill_3` | 貨架填滿級；現用 SKU 小圖疊加 |
| P2 | 特效 | suck／spray／coin／combo／timestop／clean_spark／skid | 掛事件；非角色方向表 |
| P2 | 工程 | SpriteFrames 圖集打包 | tech-review：比每幀 load 更省 |
| P3 | 技能演出 | 全身技能姿 | 現 UI＋tint／camera zoom |
| P3 | 幫忙取貨／COMBO | 專用交付姿 | 玩法規則仍在 `docs/alpha/design.md` |
| P3 | 污物 | 清潔中變形／透明水漬 | 現靜態 trash／puddle／vomit |
| P3 | 命名對齊 plan | `walk_s_01` 目錄結構 | 現用 `{id}_{anim}_{facing}_{frame}`；可加轉檔 |

## 驗收（本輪）

- [x] 玩家走路／跑步時腳步循環（四向）
- [x] 客人／小偷／店員移動播 walk
- [x] 清潔／打擊／收銀／滑倒／暈眩切到對應姿（可再精修）
- [ ] 設計師重雕 `.vox` 後自動從源檔抽肢體做動畫（未做；仍走程序模板）
