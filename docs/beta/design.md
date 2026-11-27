# Beta 版本設計

- 這裡記留到 Beta 才設計的流量數字與解鎖表
- 長線規則仍以 `docs/systemdesign/` 為準。這些數字先不寫進長線檔
- 各 Demo 繼續用自己的 scope 數字
- 對照：`docs/systemdesign-gaps.md`（2026-10-22）

劇情**框架**與**三份成長分析**已開：`docs/systemdesign/storysystem.md`、`story/growth-character.md`、`growth-economy.md`、`growth-skills.md`。**付費 EA（2026-11-27）**只要做到序章、第1章、第2章破局與安桃山一章（內容細則多為開檔 TBD）。**免費 Demo**只含序章＋第1章＋教學（劇本 5）；暫不含多人；存檔不轉入 EA。其餘五主題、終章與完整事件 pack 仍待各章詳設並留本 Beta。**任務 XP／頭目大額／學會表**以成長分析為產品建議；活線落地可標工程 Beta。見 `playerlevel.md`、`ecosystem.md`、`story/progression-crossref.md`。事件占位：`eventsystem.md`（**預設不**排 EA 活線；是否為 EA 章節所必需尚未確定）。

任務系統條件語意與測試內容已進長線：`docs/systemdesign/tasksystem.md`。本 Beta 檔仍欠：

- **任務報酬系統**（XP、`shop_rating`、學技能、貨品開發解鎖、外觀解鎖等發放時機與表）
- **店鋪進度以任務／章節解鎖**的詳細機制（改 `shopprogress.md`；對齊混合解鎖）
- 完整事件／劇情任務內容表（章開檔見 `story/`；pack stub 見 `taskcontent-event-stub.md`、`taskcontent-story-stub.md`）

# 技能解鎖表

技能本身的 LV1–LV3 效果已寫在長線。  
**角色升到幾級學會哪一招**、被動為何只有 LV1 等解鎖表，留待 Beta 再設計。

檔案：`playerskills.md`、`playerlevel.md`、`playeractiveskills.md`、`playerpassiveskills.md`

# 客人流量

已有：清單上限 15 件、逗留 1 秒、思考 3 秒、不滿 0–100、排隊 15 秒滿。抽出件數由各 Demo scope 訂，不多於 15 件。

仍未寫：生成間隔、在店人數上限、客人類別和移速、找不到貨的長線不滿點數。Demo v0.3 找不到貨是 +18，那不是長線數字。

**麻煩客人（EliteCustomer）：** 行為框架已進長線並落地活線，見 `docs/systemdesign/elitecustomer.md`。一般營運：每名進店 **1%–5%**；補貨時段不出；同回合無麻煩客人人數上限（仍受客人 cap）。本 Beta 檔仍欠：**LV 隨劇情解鎖表**、**事件強制／提高機率表**、詞綴效果 LV 的非預設 mapping。

檔案：`customer.md`、`elitecustomer.md`、`gameconcept.md`

# 污物與小偷流量

污物已有三類效果、清潔計和空手轉搖桿。仍未寫：生成間隔、同時上限、垃圾扣氣力的每秒數字、三類不滿的每秒數字。

小偷已有不付款、出口帶贓才計被偷＋橫幅、連按傷害、5 秒失敗；衝刺撞飛／丟掉砸中都算抓住（不計被偷）。仍未寫：清單件數、同時人數、出現間隔。霸王色寫「減少 50%」，沒有基礎出現率可乘。

檔案：`cleaningsystem.md`、`thiefsystem.md`、`playerpassiveskills.md`
