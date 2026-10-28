# 音效需求表（不含 BGM）

- 依現有**角色行動**與**物件互動**設計整理（`playeraction.md`、`playermovement.md`、`replenishmentsystem.md`、`cashiersystem.md`、`cleaningsystem.md`、`thiefsystem.md`、技能／奧義、客人／店員、準備／暫停 UI）
- **不含 BGM／環境床**（店內 Ambient 另表；本檔只列事件 SFX）
- 活線：`godot/game`。Alpha 已接 `SfxBus` autoload；素材在 `godot/game/audio/sfx/<id>.wav`（程序生成佔位，之後由音效設計師替換）
- 測試頁：準備選單（`TEST_TOOLS`）→「音效測試」；或直接跑 `res://scenes/sfx_test.tscn`。每列在 `▶` 後標註本表「觸發（設計）」＝映射的遊戲動作／效果
- 再生素材：`python3 tools/gen_alpha_sfx.py`；再生 catalog（含 trigger）：`python3 tools/gen_sfx_catalog.py`
- 優先：P0＝玩法必聽回饋 · P1＝節奏與辨識 · P2＝可延後／可共用變體

## 命名建議

`sfx_{系統}_{事件}[_變體]`，例如 `sfx_box_pull`、`sfx_ko_screen`。  
短聲優先 mono；UI 可 stereo。同一邏輯事件可共用一條素材，用 pitch／volume 變體區分。

## 1. 移動與身體狀態

| ID | 觸發（設計） | 建議質感 | 優先 | 來源檔 |
| --- | --- | --- | --- | --- |
| `sfx_move_foot_walk` | 走路步伐循環（可跟動畫幀） | 店內鞋底／輕踩 | P1 | `playermovement.md` |
| `sfx_move_foot_run` | 奔跑步伐（較密／較重） | 急促踩踏 | P1 | `playermovement.md` |
| `sfx_move_dash` | 衝刺出手 | 短促破風／whoosh | P0 | `playermovement.md` |
| `sfx_move_stamina_empty` | 氣力見底無法再跑／衝 | 短虛脫／失敗嗶 | P2 | `playermovement.md` |
| `sfx_move_overcarry` | 超重移動開始／持續層（可極輕） | 負重拖曳 | P2 | `playermovement.md` |
| `sfx_move_crowd` | 進入擁擠（3 身位內多人） | 短擠擁／「唔該」可選 VO | P2 | `playermovement.md` |
| `sfx_move_slip` | 水漬上奔跑／衝刺滑倒 | 滑倒＋撞擊 | P0 | `cleaningsystem.md` |
| `sfx_move_stun` | 滑倒後暈眩／打擊失敗倒地 | 倒地悶響 | P1 | `cleaningsystem.md`／`thiefsystem.md` |
| `sfx_move_dirt_step` | 踩上污物（可與腳步疊極輕） | 濕／黏腳 tip | P2 | `cleaningsystem.md` |

## 2. 補貨／貨箱互動

| ID | 觸發（設計） | 建議質感 | 優先 | 來源檔 |
| --- | --- | --- | --- | --- |
| `sfx_box_pull` | 補貨點輕放執貨成功（即時） | 紙箱吸入／提起 | P0 | `replenishmentsystem.md`／`playeraction.md` |
| `sfx_box_pull_fail` | 補貨點空／負重已滿 | 乾碰／拒絕 | P1 | `replenishmentsystem.md` |
| `sfx_box_sku_open` | 補貨點長按打開 SKU 清單 | UI 開頁短音 | P1 | `replenishmentsystem.md` |
| `sfx_box_sku_move` | 清單上／下改選 | 輕 tick | P2 | `replenishmentsystem.md` |
| `sfx_box_sku_confirm` | 放手確認 SKU | 短確認 | P2 | `replenishmentsystem.md` |
| `sfx_box_sku_cancel` | 取消選貨 | 關閉 | P2 | `replenishmentsystem.md` |
| `sfx_shelf_stock_loop` | 近身上架 Circle 進行中（可極短循環或無聲＋完成音） | 輕放貨沙沙 | P2 | `playeraction.md` |
| `sfx_shelf_stock_done` | 近身上架完成一箱／一段 | 貨箱就位／噴出 | P0 | `replenishmentsystem.md` |
| `sfx_shelf_stock_blocked` | SKU 不符／貨架已滿（叉） | 錯誤 buzz | P0 | `replenishmentsystem.md` |
| `sfx_shelf_stock_instant` | 瞬間補貨 LV3 略過 Circle 完成 | 同上完成音略尖／加速 | P1 | `playeractiveskills.md` |
| `sfx_box_drop_aim` | 長按取消達丟掉瞄準門檻 | 瞄準鎖定 tip | P1 | `playeraction.md` |
| `sfx_box_toss` | 放手丟出（有方向飛出） | 拋出 whoosh | P0 | `playeraction.md` |
| `sfx_box_drop_feet` | 無方向掉腳邊 | 紙箱落地 | P0 | `playeraction.md` |
| `sfx_box_land` | 飛箱落地（地／剩貨） | 落地頓音 | P0 | `playeraction.md` |
| `sfx_box_shelf_toss` | 丟掉軌道命中可接受貨架並補架 | 落地＋入架 | P0 | `replenishmentsystem.md` |
| `sfx_box_pickup_floor` | 撿起地上貨箱 | 提起 | P0 | `playeraction.md` |

## 3. 收銀

| ID | 觸發（設計） | 建議質感 | 優先 | 來源檔 |
| --- | --- | --- | --- | --- |
| `sfx_checkout_enter` | 進入收銀指令模式（隊首就緒） | 收銀機就緒 | P1 | `cashiersystem.md` |
| `sfx_checkout_dir_ok` | 單一方向指令正確 | 輕快 tick／鍵 | P0 | `cashiersystem.md` |
| `sfx_checkout_dir_fail` | 方向錯誤（整串重置） | 錯誤 buzz＋X | P0 | `cashiersystem.md` |
| `sfx_checkout_seq_done` | 指令串全部正確 → Circle 出現 | 小成功 chime | P1 | `cashiersystem.md` |
| `sfx_checkout_circle_done` | Circle 填滿、完成收銀 | 收銀鈴／錢匣 | P0 | `cashiersystem.md` |
| `sfx_checkout_cash_pop` | 完成後彈出 $ 圖示 | 硬幣／錢音 | P0 | `cashiersystem.md` |
| `sfx_checkout_release_reset` | 收銀中放手重置指令 | 短取消 | P2 | `cashiersystem.md` |
| `sfx_checkout_clerk` | 店員自動收銀完成（可共用完成鈴變體） | 較淡收銀鈴 | P1 | `clerksystem.md` |

## 4. 清潔

| ID | 觸發（設計） | 建議質感 | 優先 | 來源檔 |
| --- | --- | --- | --- | --- |
| `sfx_clean_start` | 開始對污物填清潔計 | 拿起清潔工具 | P1 | `cleaningsystem.md` |
| `sfx_clean_scrub` | 搖桿有效推進清潔計（可節奏點） | 刷洗／拖地 | P0 | `cleaningsystem.md` |
| `sfx_clean_done` | 清潔計滿、污物消失 | 清爽完成＋spark | P0 | `cleaningsystem.md` |
| `sfx_clean_cancel` | 清潔中放手重置 | 停刷 | P2 | `cleaningsystem.md` |

## 5. 打擊／小偷／衝刺碰撞

| ID | 觸發（設計） | 建議質感 | 優先 | 來源檔 |
| --- | --- | --- | --- | --- |
| `sfx_fight_grab` | 空手長按抓住小偷進打擊 | 抓住／鎖住 | P0 | `thiefsystem.md` |
| `sfx_fight_hit` | 連按行動扣血（每有效一下） | 打擊 hit | P0 | `thiefsystem.md` |
| `sfx_fight_fail` | 5 秒內未打倒：玩家被撞開倒地 | 撞開＋倒地 | P0 | `thiefsystem.md` |
| `sfx_ko_screen` | Screen KO（近身打倒／丟掉砸中小偷） | 衝擊＋閃白 stinger | P0 | `thiefsystem.md` |
| `sfx_ko_guest_dash` | 衝刺撞一般客人 Screen KO（原地落地） | KO 變體略輕 | P0 | `playermovement.md` |
| `sfx_thief_dash_out` | 衝刺撞飛小偷離場 | 飛出 whoosh | P0 | `thiefsystem.md`／`playermovement.md` |
| `sfx_loot_scatter` | 贓物近／遠散落飛行 | 多箱落地滾動 | P1 | `thiefsystem.md` |
| `sfx_loot_inplace` | 丟掉砸中：贓物原地掉落 | 箱堆落地 | P1 | `thiefsystem.md` |
| `sfx_box_hit_thief` | 飛箱命中小偷（可與 KO 疊或作前導） | 紙箱砸中 | P1 | `thiefsystem.md` |
| `sfx_box_hit_guest_ok` | 丟掉砸中客人且 SKU 在清單 | 正向交接／謝謝 | P1 | `playeraction.md` |
| `sfx_box_hit_guest_reject` | 丟掉砸中客人且 SKU 不在清單 | 拒絕／不滿 tip | P1 | `playeraction.md` |
| `sfx_thief_escape` | 小偷持贓走到出口：橫幅「你已經被偷了！」 | 警鈴／失敗 stinger | P0 | `thiefsystem.md` |
| `sfx_thief_spawn` | 小偷進店（可選） | 鬼祟 tip | P2 | `thiefsystem.md` |

## 6. 客人（非玩家操控）

| ID | 觸發（設計） | 建議質感 | 優先 | 來源檔 |
| --- | --- | --- | --- | --- |
| `sfx_guest_enter` | 一般客人進店 | 門鈴聲淡 | P2 | `customer.md` |
| `sfx_guest_take` | 客人貨架取貨完成（逗留後） | 輕取貨 | P2 | `customer.md` |
| `sfx_guest_think` | 找不到貨、短暫思考 | 疑惑／唔 | P2 | `customer.md` |
| `sfx_guest_queue` | 加入收銀排隊（可選） | 腳步停佇 | P2 | `cashiersystem.md` |
| `sfx_guest_angry_leave` | 不滿滿 100 生氣離開 | 氣憤短音 | P1 | `customer.md` |
| `sfx_guest_paid_leave` | 付完款離開 | 滿足短音 | P2 | `cashiersystem.md` |
| `sfx_guest_dash_land` | 被衝刺撞飛後落地暈 2 秒 | 落地 | P1 | `playermovement.md` |

## 7. 技能／奧義（事件音；不含主題曲）

| ID | 觸發（設計） | 建議質感 | 優先 | 來源檔 |
| --- | --- | --- | --- | --- |
| `sfx_skill_cast` | 主動技能施放成功（通用層） | 施法 whoosh | P0 | `playeractiveskills.md` |
| `sfx_skill_menu_open` | 短按或長按技能開選單 | UI 開 | P1 | `control.md` |
| `sfx_skill_menu_move` | 選單方向改選 | tick | P2 | `control.md` |
| `sfx_skill_menu_cancel` | 取消鍵關閉技能選單 | 關 | P2 | `control.md` |
| `sfx_skill_cd_deny` | CD 中／不能施放 | 拒絕 | P1 | `playerskills.md` |
| `sfx_ult_prep` | 長按奧義進入指令準備 | 蓄力低音 | P1 | `playerultimateskills.md` |
| `sfx_ult_dir_ok` | 奧義方向指令正確 | tick（可較沉） | P0 | `playerultimateskills.md` |
| `sfx_ult_dir_fail` | 奧義指令錯誤重置 | 錯誤 | P0 | `playerultimateskills.md` |
| `sfx_ult_cancel` | 奧義蓄力放手取消 | 消散 | P2 | `control.md` |
| `sfx_ult_the_world` | The World! 發動 | 時停 stinger（短） | P0 | `playerultimateskills.md` |
| `sfx_ult_the_world_end` | The World! 結束恢復流速 | 時間回流 tip | P1 | `playerultimateskills.md` |
| `sfx_ult_yes_my_lord` | Yes! My Lord! 發動 | 號令／搶購起哄短層 | P0 | `playerultimateskills.md` |
| `sfx_ult_fundraise` | 全體集資發動／批次入帳 | 錢潮／批量收銀 | P0 | `playerultimateskills.md` |
| `sfx_skill_soothe` | 安撫生效 | 柔和減壓 | P1 | `playeractiveskills.md` |

> 頂硬上／移速／收銀加速／瞬間補貨：可用通用 `sfx_skill_cast`＋各自極短 buff tip（P2），不必各做長床。

## 8. 店員

| ID | 觸發（設計） | 建議質感 | 優先 | 來源檔 |
| --- | --- | --- | --- | --- |
| `sfx_clerk_pull` | 補貨店員取箱（可共用 `sfx_box_pull` 降音量） | 紙箱 | P2 | `clerksystem.md` |
| `sfx_clerk_stock` | 補貨店員上架完成 | 入架淡 | P2 | `clerksystem.md` |

## 9. 回合／世界事件（非 BGM）

| ID | 觸發（設計） | 建議質感 | 優先 | 來源檔 |
| --- | --- | --- | --- | --- |
| `sfx_phase_restock` | 進入補貨時段（日開始） | 短號角／店開準備 | P1 | `storeoperationphase.md` |
| `sfx_phase_open` | 補貨結束→營運時段 | 開門鈴 | P1 | `storeoperationphase.md` |
| `sfx_phase_close` | 關店結算畫面出現 | 結帳／一日完 | P0 | `storeoperationphase.md` |
| `sfx_early_close_ask` | 提早關店詢問彈出 | UI 問號 | P1 | `storeoperationphase.md` |
| `sfx_dirt_spawn` | 污物生成（可極淡） | 滴落／掉垃圾 | P2 | `cleaningsystem.md` |

## 10. UI（準備／暫停／通用）

| ID | 觸發（設計） | 建議質感 | 優先 | 來源檔 |
| --- | --- | --- | --- | --- |
| `sfx_ui_move` | 選單游標移動 | tick | P1 | `control.md`／`storepreparationphase.md` |
| `sfx_ui_confirm` | 選單確定 | 確認 | P1 | `control.md` |
| `sfx_ui_cancel` | 選單取消／返回 | 取消 | P1 | `control.md` |
| `sfx_ui_deny` | 不能執行（開店條件不足、買不起等） | 拒絕 | P0 | `storepreparationphase.md` |
| `sfx_ui_purchase` | 採購／購入傢俬／開發成功扣款 | 付錢 | P1 | `procurement.md`／`shopitem.md` |
| `sfx_ui_place` | 店舖設計放置成功 | 放置 | P1 | `shopsetup.md` |
| `sfx_ui_pickup_item` | 店舖設計收回傢俬 | 收回 | P2 | `shopsetup.md` |
| `sfx_ui_rotate` | 店舖設計轉向 | 旋轉 tip | P2 | `control.md` |
| `sfx_ui_pause_open` | 暫停選單開啟 | 暫停 | P1 | `pausemenu.md` |
| `sfx_ui_pause_close` | 暫停繼續 | 恢復 | P1 | `pausemenu.md` |
| `sfx_ui_level_up` | 結算升級（若有） | 升級 chime | P1 | `ecosystem.md` |
| `sfx_ui_test_skip` | 測試「馬上完成營運」等（測試版） | 可共用 UI 確認 | P2 | `pausemenu.md` |

## 統計（初稿）

| 優先 | 約略條數（可合併素材後更少） |
| --- | ---: |
| P0 | ~28 |
| P1 | ~30 |
| P2 | ~25 |

製作時建議先交 **P0 全集**，再補移動腳步與 UI；P2 多用變體／降音量共用。

## 明確不在本表

- BGM、店內環境床、天氣層
- 語音對白長句（頭頂「謝謝！」等可用極短 VO 或純 SFX；長 VO 另表）
- 平台系統音（系統通知、成就）

## 相關文件

- 行動：`playeraction.md` · 移動：`playermovement.md` · 操作：`control.md`
- 補貨：`replenishmentsystem.md` · 收銀：`cashiersystem.md` · 清潔：`cleaningsystem.md`
- 小偷：`thiefsystem.md` · 客人：`customer.md` · 店員：`clerksystem.md`
- 技能：`playeractiveskills.md` · 奧義：`playerultimateskills.md`
- 回合：`storeoperationphase.md` · 準備：`storepreparationphase.md` · 暫停：`pausemenu.md`
- 動畫插座（視覺對齊）：`docs/alpha/animation-v1.0.md`；plan 註明本階段原不做音效：`docs/alpha/plan.md`
