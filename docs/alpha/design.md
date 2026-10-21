# Alpha 版本設計

- 這裡記留到 Alpha 才設計的問題
- 長線規則仍以 `docs/systemdesign/` 為準。這些項目先不寫進長線檔
- 對照：`docs/systemdesign-gaps.md`（2026-10-17）

# 幫忙取貨與 COMBO

核心節奏寫了兩句：客人找不到貨時可幫忙提取；清單上的貨可以一口氣交付，做出 COMBO。

仍未寫：對誰按、按什麼指令、怎樣算完成、分數或營業額怎樣加、跟收銀和客人不滿的關係。

檔案：`gameconcept.md`、`customer.md`、`playeraction.md`

# 擁擠與操作門檻

「太多客人同一地區」會出現「唔該借借」，沒有人數，也沒有移速倍率。

輕放衝刺和長按奔跑的時間門檻只在 Demo，長線未寫。重置能力值有功能，沒有費用。

檔案：`playermovement.md`、`control.md`、`playersetup.md`

# 收銀方向如何抽

四向是否均勻、可否連續重複，未寫。清潔和打擊已改為轉搖桿或連按，不再是方向串。

檔案：`cashiersystem.md`

# 多台收銀機客人選哪一隊

可以買多台。店員各看自己那台。客人完成購物後「前往收銀機」，沒有寫選最短隊、最近一台，或人數相同時怎樣分。

檔案：`cashiersystem.md`、`customer.md`、`clerksystem.md`

# 掉落物歸誰

水漬掉下的箱、丟掉的貨箱、打倒小偷掉下的贓物，都可以撿。客人會不會撿走、會不會算進該客人清單或被偷統計，未寫。

檔案：`cleaningsystem.md`、`thiefsystem.md`、`customer.md`、`playeraction.md`

# 清潔與打擊能否邊走邊起手

上架已寫可以在移動中起手，Circle 進行中不走。清潔和打擊只寫進行中不移動。起手時角色是否仍在走，未寫。

檔案：`playeraction.md`、`cleaningsystem.md`、`thiefsystem.md`

# 小偷與污物、時停以外的世界規則

小偷踩到污物會不會減速，未寫。安撫和金屬狂潮的「全體客人」包不包括小偷，未寫。小偷佔不佔在店人數上限，未寫。

檔案：`thiefsystem.md`、`customer.md`、`playeractiveskills.md`

# 攜帶清單的先後用詞

仍寫 First In Last Out。下文例子已是堆疊：後取的在最上層，空架先上最後一箱。標籤和例子還沒合成同一句。

檔案：`replenishmentsystem.md`

# 角色導出

`playerexport.md` 只說導出後以店員身分幫忙。`clerksystem.md` 補了：佔一個雇員欄、用導出的 STR／AGI／INT、工資仍付。連線、檔案、權限仍無。

檔案：`playerexport.md`、`clerksystem.md`

# 暫停、設定、存檔與教學

時計、營業額、人數、狀態、被偷、提早關店的詢問已有。

- **存檔：** 已寫進長線 `docs/systemdesign/savesystem.md`（`user://save.json` + `version`；關店與準備結束寫入）。活線已實作。  
- **操作：** 長線以 InputMap 為準，見 `docs/systemdesign/control.md`。  
- **工程路徑：** 凍結 Demo／Alpha；v1 只維護 `godot/game`，見 `docs/versioning.md`。  
- 仍未寫：暫停選單、設定（音量）、失敗／過關流程、教學、技能演出期間能否操作。外觀配置只有一句。

檔案：`savesystem.md`、`storeoperationphase.md`、`storepreparationphase.md`、`playerskills.md`、`control.md`、`playersetup.md`

# 用詞

寫回原設計檔，不改已經拍板的規則：

- 「以為」改為「以下」（`storeoperationphase.md`）
- 「三能種力值」改為「三種能力值」（`gameconcept.md`）
- 奧義兩處的「技令」改為「指令」（`playerultimateskills.md`）
- 衝刺「身上沒有貨品而」句子補完（`playermovement.md`）
