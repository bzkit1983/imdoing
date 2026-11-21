#角色級數設定
- 此檔案包含角色級數設定

#**角色級數**
角色級數由獲得經驗值提升
角色級數上限為99
- 劇情主線（序章→終章）期望結束等級約 **60**；**61–99** 為後日談再練空間（見 `storysystem.md`）
- 各章期望等級帶、LV11–99 表：**不寫死**；待角色成長分析後回填（`story/progression-crossref.md`）

#**經驗值**
經驗只會增加，不會減少。
**活線已接**產品曲線／日結帶：見 [`story/growth-character.md`](story/growth-character.md)；實作 `godot/game/scripts/session/xp_rules.gd`（上限 LV99）。  
日結基礎 XP 暫以**角色等級帶**代理章段（尚無 `story_chapter_id`）：LV1–18／19–36／37–60／61–99 → 關店／收銀／麻煩／賊／清潔見該文 §3。  
**劇情／事件任務可以給 XP**（已拍板）：給否與量由**個別任務報酬**設計。任務報酬表見 `docs/beta/design.md`、`story/progression-crossref.md` §6。

#**級數與技能**
**等級從不直接解鎖技能。** 學會一律由**劇情／事件任務獎勵**發放；任務可要求 `player_level >= N`。  
分章學會表見 [`story/growth-skills.md`](story/growth-skills.md)。

#**級數與能力值**
級數提升時會獲得5點能力值（產品建議暫維持；見成長分析）。
玩家可自由分配點數
如果升級後能力值還沒分配會一直累積直至分配完成

#**級數與劇情**
劇情模式框架見 `storysystem.md`。等級＝成長與任務條件，**不是**解鎖權威。

#**角色升級所需經驗值**
起始 LV 1；滿級 **99**。  
產品公式與累計錨點（至 LV60 ≈ 130,250；滿級 ≈ 311,600）見 [`story/growth-character.md`](story/growth-character.md)。  
舊 LV2–10 測試表已退役。