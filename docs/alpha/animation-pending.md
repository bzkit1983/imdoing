# Alpha v1.0 動作／動畫 — 待處理表

- 對照：已落地項見 [`animation-v1.0.md`](animation-v1.0.md)；需求盤點 canvas／`docs/alpha/plan.md` 動畫插座
- 規則：**不要**為動畫再開 `godot/` 專案複本
- 烘焙：`python3 tools/voxel_character_anims.py` · `python3 tools/voxel_alpha_props.py`（不覆寫 `art/src/*.vox`）

## 已生成（Alpha 表現 enrichment）

| 角色／物件 | 動畫 | 幀×向 | 狀態 |
| --- | --- | --- | --- |
| player | idle / walk / walk_carry / run / dash / clean / fight / checkout / slip / down / restock / cast / deliver | 見 manifest | 已接 `AnimatedSprite2D` |
| customer / customer_hurry / customer_slow | idle / walk / angry / leave | 見 manifest | 已接；spawn 抽 pace |
| thief | idle / walk / fight / leave / fly | 見 manifest | 已接 |
| clerk_cashier | idle / walk / walk_carry / checkout | 見 manifest | 已接 |
| clerk_restock | idle / walk / walk_carry / restock | 已接 |
| shelf_dry／frozen／ice | fill_0…fill_3 | 四向 | 已接 `shelf.gd` |
| trash／puddle／vomit | clean_0…clean_2 | 清潔中 | 已接 `dirt.gd` |
| fx | suck／spray／coin／combo／timestop／clean_spark／skid | 短序列 | 已接 `fx_burst.gd` |
| fx | smoke（多重影分身消失） | 短序列 | **未做**。規則見 `docs/systemdesign/shadowclone.md`；實作可先用現有 burst 佔位 |

檔名：`art/sprites/{id}_{anim}_{facing}_{frame}.png` · 清單：`art/sprites/anim_manifest.json` · 道具：`props_manifest.json`

## 仍待設計師／之後版本

| 優先 | 對象 | 缺什麼 | 說明 |
| --- | --- | --- | --- |
| P1 | 全角色 | 與 `art/src/*.vox` 外觀對齊 | 動畫姿仍來自程序模板，未讀設計師已改的靜態 `.vox` |
| P1 | player | walk／run／dash／clean／fight MagicaVoxel 精修 | 現為程序肢體偏移；覆寫同名 PNG 即可 |
| P2 | 工程 | SpriteFrames 圖集打包 | tech-review：比每幀 load 更省 |
| P3 | 幫忙取貨／COMBO | 玩法規則＋正式交付姿 | Alpha 已有 `deliver` 姿插座；規則見 `docs/alpha/design.md` |
| P3 | 命名對齊 plan | `walk_s_01` 目錄結構 | 現用 `{id}_{anim}_{facing}_{frame}`；可加轉檔 |

## 驗收

- [x] 玩家走路／跑步時腳步循環（四向）
- [x] 客人／小偷／店員移動播 walk；趕時間／慢客不同模型
- [x] 清潔／打擊／收銀／滑倒／暈眩／施法切到對應姿
- [x] 貨架填滿級、執貨／上架／收銀／時停等短特效
- [ ] 設計師重雕 `.vox` 後自動從源檔抽肢體做動畫（未做；仍走程序模板）
