# Beta 版本設計

- 這裡記留到 Beta 才設計的流量數字與解鎖表
- 長線規則仍以 `docs/systemdesign/` 為準。這些數字先不寫進長線檔
- 各 Demo 繼續用自己的 scope 數字
- 對照：`docs/systemdesign-gaps.md`（2026-10-22）

劇情和事件也留待 Beta。經驗不從那裡增減。見 `playerlevel.md`、`ecosystem.md`。事件表、觸發和失敗條件仍未寫。

# 技能解鎖表

技能本身的 LV1–LV3 效果已寫在長線。  
**角色升到幾級學會哪一招**、被動為何只有 LV1 等解鎖表，留待 Beta 再設計。

檔案：`playerskills.md`、`playerlevel.md`、`playeractiveskills.md`、`playerpassiveskills.md`

# 客人流量

已有：清單上限 15 件、逗留 1 秒、思考 3 秒、不滿 0–100、排隊 15 秒滿。抽出件數由各 Demo scope 訂，不多於 15 件。

仍未寫：生成間隔、在店人數上限、客人類別和移速、找不到貨的長線不滿點數。Demo v0.3 找不到貨是 +18，那不是長線數字。

檔案：`customer.md`、`gameconcept.md`

# 污物與小偷流量

污物已有三類效果、清潔計和空手轉搖桿。仍未寫：生成間隔、同時上限、垃圾扣氣力的每秒數字、三類不滿的每秒數字。

小偷已有不付款、被偷另計、連按傷害、5 秒失敗、衝刺即逃走。仍未寫：清單件數、同時人數、出現間隔。霸王色寫「減少 50%」，沒有基礎出現率可乘。

檔案：`cleaningsystem.md`、`thiefsystem.md`、`playerpassiveskills.md`
