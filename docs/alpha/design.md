# Alpha 版本設計

- 這裡記**曾留到 Alpha 才拍板／收口**的題；**不是**現況規格全文。
- 長線規則仍以 `docs/systemdesign/` 為準。
- 工程落地對照：[`implementation-status.md`](implementation-status.md)；缺口表：[`systemdesign-gaps.md`](../systemdesign-gaps.md)；執行期優化：[`runtime-perf-audit.md`](runtime-perf-audit.md)。
- **讀法：** 「已拍板／已實作」以 `implementation-status`＋長線檔為準；本檔若與它們衝突，以它們為準。

---

# 幫忙取貨與 COMBO（已實作）

核心節奏：客人找不到貨時玩家可代取／交付；成功交付累加 COMBO；完美交清清單有額外回饋。

| 問題（舊「仍未寫」） | 現況 |
| --- | --- |
| 對誰按、按什麼 | 營運時段對清單未完成的一般／麻煩客人；空手／持貨對貨架短按取 1 件；持貨長按行動＝親手交付；方向＋短按取消＝丟 1 件等——見 `customerdelivery.md`、`playeraction.md` |
| 怎樣算完成 | 清單交清 → 去收銀排隊（交付當下不收錢） |
| 分數／營業額／不滿 | 每交對 1 件不滿 −15；完美交付（一次交清剩餘清單）不滿 −40、該筆結帳 ×1.2、評級 P5_COMBO——見 `fetchcombo.md`、`customerdelivery.md` |
| 與收銀／COMBO | 成功交付 → 個人＋全隊 COMBO +1；失誤個人 RESET；多人接棒見 `multiplayer.md` §11.7 |

- **長線：** [`customerdelivery.md`](../systemdesign/customerdelivery.md)、[`fetchcombo.md`](../systemdesign/fetchcombo.md)  
- **工程：** [`implementation-status.md`](implementation-status.md)「客人貨品交付」；`session/combo_state.gd`  
- **gaps：** `systemdesign-gaps.md` 已標「幫忙取貨與 COMBO」為已處理  

---

# 已拍板並寫回長線（原 Alpha 項）

下列原 Alpha 開放項已於 2026-10-22 拍板，規則見 `docs/systemdesign/`（並關 `systemdesign-gaps.md`）：

| 原項 | 結論（摘要） |
| --- | --- |
| 擁擠與操作門檻 | 3 身位擁擠 ×0.5＋「唔該借借⋯」；輕放／長按跟活線常數；重置＝等級 × $1000 |
| 收銀方向如何抽 | 隨機，可重複 |
| 多台收銀選隊 | 最短 → 最近 → 隨機 |
| 掉落物歸誰 | 客人永不撿、不算進清單 |
| 清潔邊走邊起手 | 可起手；填計後鎖移動 |
| 小偷與污物／世界 | 小偷不受污物；不佔客人數；The World 含小偷 |
| 攜帶清單 FILO | 改為堆疊說明（後取先上） |

---

# 角色導出（連線仍缺）

`playerexport.md` 只說導出後以店員身分幫忙。`clerksystem.md` 補了：佔一個雇員欄、用導出的 STR／AGI／INT、工資仍付。**連線、檔案、權限仍無**（長線未關）。

檔案：`playerexport.md`、`clerksystem.md`

---

# 暫停、設定、存檔與教學

時計、營業額、人數、狀態、被偷、提早關店的詢問已有。

- **已寫進長線或工程：** 存檔／暫停／操作／字串表／準備 UI／工程路徑／事件 SFX 音量／BGM Bus＋音量（見 `pausemenu.md`、`soundeffects.md`、`bgm.md`、`implementation-status.md`）。**教學框架**已落地（`tutorial.md`；劇本 5 鏈見 `implementation-status.md`）。
- **仍缺（玩法／產品；對齊 tech-review H）：** 技能演出期間能否操作、外觀配置仍只有一句。正式 App ID 仍 Open；Cloud／成就 API 已接；**H2 設定頁＋首日引導已落地**（見 [`steam-productization.md`](steam-productization.md)）。
- **EA 範圍（H3 已拍板，2026-11-18）：** Steam Early Access／現行產品以**純日循環**為準；**不做**失敗／過關／提早關店敘事層（可重玩當日與資金保留仍依現有結算）。敘事／事件表留待 Beta（見 `docs/beta/design.md`、`docs/versioning.md`）。
- **劇情框架閘門（N1）：** `storysystem.md`／`story/` 的十章選章／章節狀態機仍是設計文件，活線未接。準備回合／HUD／任務板仍以日循環為主。活線已有劇本 8 序章內容閘／經濟與劇本 6 頭目測試；**序章是否計入 EA 尚未決定**。事件占位 [`eventsystem.md`](../systemdesign/eventsystem.md) 不排活線。

---

# 用詞（歷史）

已寫回原設計檔：

- 「以為」→「以下」（`storeoperationphase.md`）
- 「三能種力值」→「三種能力值」（`gameconcept.md`）
- 奧義「技令」→「指令」（`playerultimateskills.md`）
- 衝刺句子已重寫（`playermovement.md`）
