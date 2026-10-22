# Alpha 版本設計

- 這裡記留到 Alpha 才設計的問題
- 長線規則仍以 `docs/systemdesign/` 為準
- 對照：`docs/systemdesign-gaps.md`（2026-10-22）；工程落地對照：`docs/alpha/implementation-status.md`

# 幫忙取貨與 COMBO

核心節奏寫了兩句：客人找不到貨時可幫忙提取；清單上的貨可以一口氣交付，做出 COMBO。

仍未寫：對誰按、按什麼指令、怎樣算完成、分數或營業額怎樣加、跟收銀和客人不滿的關係。

檔案：`gameconcept.md`、`customer.md`、`playeraction.md`

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

# 角色導出

`playerexport.md` 只說導出後以店員身分幫忙。`clerksystem.md` 補了：佔一個雇員欄、用導出的 STR／AGI／INT、工資仍付。連線、檔案、權限仍無。

檔案：`playerexport.md`、`clerksystem.md`

# 暫停、設定、存檔與教學

時計、營業額、人數、狀態、被偷、提早關店的詢問已有。

- **存檔／暫停／操作／字串表／準備 UI／工程路徑：** 已寫進長線或工程文件（見前次對照）。
- 仍未寫（玩法／產品）：設定（音量）、失敗／過關流程、教學、技能演出期間能否操作。外觀配置只有一句。

# 用詞

寫回原設計檔：

- 「以為」→「以下」（`storeoperationphase.md`）
- 「三能種力值」→「三種能力值」（`gameconcept.md`）
- 奧義「技令」→「指令」（`playerultimateskills.md`）
- 衝刺句子已重寫（`playermovement.md`）
