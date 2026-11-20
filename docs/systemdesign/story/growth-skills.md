# 技能／奧義分章分析（產品建議）

- 框架：[`../storysystem.md`](../storysystem.md)
- XP／日數：[`growth-character.md`](growth-character.md)
- 經濟：[`growth-economy.md`](growth-economy.md)
- 技能效果正文：`playeractiveskills.md`／`playerpassiveskills.md`／`playerultimateskills.md`
- **約束：** 學會＝劇情或事件任務獎勵；等級可作任務條件；**頭目任務解鎖奧義**（首次）

# 1. 配裝節奏（COST）

維持：主動＋被動 COST 總和 ≤5；奧義另槽、COST 0。

| 階段 | 章 | 配裝焦點 |
|------|-----|----------|
| 入門 | 序章–第1章 | 多 COST1；學會基礎吞吐 |
| 展開 | 第2–4章 | 導入 COST2（清潔／交付／收銀高階） |
| 系統 | 第5–6章 | 炮台／人力系 |
| 收束 | 第7–8章 | COST3 被動＋場域 |
| 終章 | 終章 | 全庫可配 |
| 後日談 | — | 隱藏奧義；挑戰可禁用某桶 |

# 2. 現有技能盤點（學會用 id）

## 2.1 主動（節錄 id）

| id | 名稱 | COST |
|----|------|-----:|
| `carry_boost` | 頂硬上 | 1 |
| `move_boost` | 無人可以喺我前面 | 1 |
| `checkout_rush` | 人肉數錢機 | 1 |
| `instant_restock` | 瞬間補貨 | 1 |
| `soothe` | 安撫 | 1 |
| `metal_rush` | 金屬狂潮 | 1 |
| `dash_deliver` | 衝刺交付 | 1 |
| `hoop_ace` | 投籃高手 | 1 |
| `dasher` | Dasher | 2 |
| `senior_cashier` | 資深收銀員 | 2 |
| `force_sell` | 我都賺夠啦比啲你賺 | 2 |
| `must_deliver` | 使命必達 | 2 |
| `summon_guest` | 召喚客人 | 2 |
| `harvest_chives` | 割韭菜 | 2 |
| `magneto` | 攝石人 | 2 |
| `sweeping_monk` | 掃地僧 | 2 |
| `shelf_sniper` | 狙擊手（貨架） | 2 |
| `guest_sniper` | 狙擊手（客人） | 2 |
| `thief_sniper` | 狙擊手（小偷） | 2 |
| `self_checkout` | Self Checkout | 2 |
| `calm_zone` | 你定少少先 | 2 |
| `universal_cannon` | 萬用炮 | 2 |
| `shelf_cannon` | 上架炮 | 2 |
| `kind_cannon` | 善良的炮 | 2 |
| `elite_guest_cannon` | 西客炮 | 2 |
| `elite_guest_specialist` | 西客專家（若獨立） | 2 |
| `dark_side` | Dark Side | 2 |
| `shadow_clone` | 多重影分身 | 3 |

## 2.2 被動

| id | 名稱 | COST |
|----|------|-----:|
| `carry_passive` | 負重增加 | 1 |
| `move_passive` | 移動速度增加 | 1 |
| `checkout_speed` | 收銀速度增加 | 1 |
| `restock_speed` | 上架速度增加 | 1 |
| `quick_swallow` | 快吞轟 | 2 |
| `polite_dash` | 禮貌衝撞 | 2 |
| `wave_step` | 凌波微步 | 2 |
| `cold_smile` | 笑到你心寒 | 3 |
| `haki` | 霸王色 | 3 |

## 2.3 現有奧義（6）

| id | 名稱 |
|----|------|
| `the_world` | The World! |
| `yes_my_lord` | Yes! My Lord! |
| `fundraise` | 全體集資 |
| `close_gate` | 落閘放狗 |
| `guest_dusk` | 諸客的黃昏 |
| `three_volley` | 三段火槍陣 |

# 3. 分章學會表（主動／被動）

**發放：** 標「事件」＝建議事件任務為主；「劇情」＝可掛主線。皆可附 XP。  
未列之技能於終章前補完事件，或終章「全庫」收束任務。

| 章 | 新學會（建議） | 發放 |
|----|----------------|------|
| 序章 | 主動：`carry_boost` `move_boost` `checkout_rush` `instant_restock` `soothe`；被動：`carry_passive` `move_passive` `checkout_speed` `restock_speed` | 事件為主（小型教學向事件）；劇情可發 1–2 個 |
| 第1章 | `dash_deliver` `dasher` `hoop_ace` `metal_rush`；`quick_swallow` | 事件 |
| 第2章 | `sweeping_monk`；`polite_dash` `wave_step`；`thief_sniper` | 事件 |
| 第3章 | `shelf_sniper` `must_deliver` `magneto` | 事件 |
| 第4章 | `senior_cashier` `self_checkout` `harvest_chives` `force_sell` | 事件 |
| 第5章 | `universal_cannon` `shelf_cannon` `guest_sniper` | 事件 |
| 第6章 | `dark_side` `shadow_clone` `summon_guest` | 事件 |
| 第7章 | `calm_zone` `kind_cannon` | 事件 |
| 第8章 | `cold_smile` `haki`；`elite_guest_cannon`（及 specialist 若保留） | 事件 |
| 終章 | 漏網主動／被動收束；配裝無學會牆 | 劇情大事任務可發 |
| 後日談 | 無新主動／被動必要；挑戰禁用桶 | 隱藏／挑戰 |

# 4. 奧義時間軸（頭目任務）

每章**頭目首次通關**解鎖一項奧義（任務獎勵；重試不重複）。

| 章 | 奧義 | 狀態 |
|----|------|------|
| 序章 | `the_world` | 現有 |
| 第1章 | **節奏逆流**（新，暫名 `tempo_rewind`） | **需新設**：短時緩解尖峰擁擠／重置局部動線壓力 |
| 第2章 | `yes_my_lord` | 現有 |
| 第3章 | `fundraise` | 現有 |
| 第4章 | **詠唱結帳**（新，暫名 `chant_checkout`） | **需新設**：範圍內輔助完成收銀指令段 |
| 第5章 | `close_gate` | 現有 |
| 第6章 | `guest_dusk` | 現有 |
| 第7章 | `three_volley` | 現有 |
| 第8章 | **規則改寫許可**（新，暫名 `rule_permit`） | **需新設**：短時覆寫一條場規（對齊第8章規則貨） |
| 終章 | **全宇宙關店協議**（新，暫名 `universal_close`） | **需新設**：多階段頭目用全域穩定／清場 |
| 後日談隱藏 | 第零班次／雙店鏡像／最後的折扣日（暫名） | 隱藏條件；非主線頭目 |

現有 6 ＋ 主線新 4 ＋ 隱藏 3 ≈ **13**。新奧義效果細節另開設計時補；本檔只釘**登場章與學會途徑**。

# 5. 頭目獎勵打包（與成長／經濟交叉）

頭目任務首次通關建議同時發：

1. 大額 XP（見 `growth-character.md` §4.1）  
2. 大額資金（見 `growth-economy.md` §6.2）  
3. 本表 §4 對應奧義學會  

日常劇情／事件仍可另發主動／被動學會（§3）。

# 6. 與 Prep 全開的關係

- 活線 Prep 全開＝測試便利，**產品應改為未學會不可裝備**。
- 學會旗標進存檔（與 `unlocked_skins` 類似）；訪客槽規則見 `multiplayer.md`（單機優先）。

# 7. 回填

| 目標 | 動作 |
|------|------|
| 各章技能槽 | 引用 §3／§4 |
| `docs/beta/design.md` 技能解鎖表 | 以本檔為準 |
| 新奧義 4＋隱藏 | 另開 `playerultimateskills.md` 條目後再實作 |

# 8. 預設

- 劇情任務可發學會（含非奧義）
- 事件失敗不擋劇情；學會未拿到可重接期間限定或支線補
