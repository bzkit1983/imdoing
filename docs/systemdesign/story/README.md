# 劇情章節開檔目錄

框架總則：[`../storysystem.md`](../storysystem.md)

> **EA 範圍（2026-11-27，Jackson）：** 付費 Steam EA＝序章 → 第1章 → 第2章（破局）→ 自選一章（只有安桃山可選）。**免費 Demo**＝序章 + 第1章＋**劇情內體驗式教學**（**不是**劇本 5；第1章通關後停下；暫不含多人；存檔不轉入 EA）。正式組建**無劇本選擇**。第1／2章要事件系統；打完安桃山後可開分店並續日循環（上限 TBD）；選章畫面顯示其他主題，只能選安桃山。完整十章／其餘五主題活線正文／終章仍是設計先行。序章內容閘與經濟（劇本 8）及頭目戰測試（劇本 6）已在活線（皆測試入口）；第1／2章、選章 runtime、事件／分店與 Demo 組建 **尚未實作**（現屬已核准範圍）。安桃山玩法／id 見 [`themes/theme-historic.md`](themes/theme-historic.md)；現有劇本皆為測試沙盒。見 [`../storysystem.md`](../storysystem.md)、[`docs/versioning.md`](../../versioning.md)。  
> **進程模型：** `story_slot`（序／1／2／槽3–8／終／後日談）× `theme_id`（破局固定＋六可選）。第 3–8 章檔＝**進程槽模板**，內容讀主題檔。

| 檔案 | 章／用途 |
|------|----------|
| [`prologue.md`](prologue.md) | 序章（教學＋營運入門） |
| [`chapter-01.md`](chapter-01.md) | 第1章（一般營運實踐） |
| [`chapter-02.md`](chapter-02.md) | 第2章（固定破局 `theme_break`） |
| [`chapter-03.md`](chapter-03.md) … [`chapter-08.md`](chapter-08.md) | 第3–8**進程槽**（選主題填入） |
| [`themes/`](themes/) | 主題目錄：`theme_break`＋六可選；**`theme_historic` 玩法／id 已定稿** |
| [`finale.md`](finale.md) | 終章（六主題全清後） |
| [`afterstory.md`](afterstory.md) | 後日談 |
| [`progression-crossref.md`](progression-crossref.md) | 現有設計對照、決策、開放問題 |
| [`growth-character.md`](growth-character.md) | 角色成長分析（XP／等級帶 ↔ slot） |
| [`growth-economy.md`](growth-economy.md) | 貨品／資金／規模（SKU ↔ theme） |
| [`growth-skills.md`](growth-skills.md) | 技能／奧義（學會 ↔ theme） |
| [`growth-analyses.html`](growth-analyses.html) | **離線檢視畫布**（或過時；以 md 為準） |

章／主題檔為概念開檔（劇本詳情後補）。**期望成長帶／貨／技能數字以三份 `growth-*.md` 為準。**

精英店員：[`../eliteclerk.md`](../eliteclerk.md)。  
分店／主題店快照：[`../branchstore.md`](../branchstore.md)。  
頭目戰回合框架：[`../bossbattle.md`](../bossbattle.md)；各頭目專檔：[`../bosses/`](../bosses/)。
