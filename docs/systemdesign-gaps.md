# 長線設計文件缺口

- 對照日：2026-10-17
- 範圍：只讀 `docs/systemdesign/`（**27** 檔），**不含** Demo scope
- 問題是文件本身的矛盾、缺系統與未定義，不是 Demo 實作差異（Demo 試玩數字只當「長線未定」的註記）

| 設計檔 | 記下的問題 | 建議先拍板 (P0) | 缺整塊系統 |
| --- | --- | --- | --- |
| 27 | 見下表 | 2 | 6 |

**一局時長已拍板：** 現實 30 秒上貨 + 3 分鐘營運。

**資金、準備回合、店舖設計、店員已有檔。** 仍建議先拍：**雇員上限與店舖規模對不齊**、**經驗從哪裡來**。

用語：P0 不定則長線系統互相卡住；P1 已有系統但規則或數值不夠寫程式；P2 可晚點、或只是錯字。

分類：缺檔／缺系統 · 互相矛盾 · 未定數值 · 規則含糊 · 用詞／錯字

# 問題清單

| Pri | 分類 | 問題 | 說明 | 檔案 |
| --- | --- | --- | --- | --- |
| 已處理 | 互相矛盾 | 一局現實時間互相打架 | 已統一：現實 30 秒上貨 + 3 分鐘營運（合計約 3 分 30 秒）。遊戲時計仍為 06:00–08:00 補貨、08:00–22:00 營運。 | gameconcept.md, storeoperationphase.md |
| 已處理 | 互相矛盾 | 不滿度是加還是減 | 內部 0–100 累積怒氣，滿 100 離開。安撫＝減少目前不滿度（LV1 −25%／LV2 −50%／LV3 歸零；已離開不拉回）。儀表相反顯示（0 綠滿→100 紅見底）。排隊每秒 +100/15。找不到貨／污物長線點數仍可再拍。 | customer.md, playeractiveskills.md |
| 已處理 | 互相矛盾 | 技能加速到底改 AGI 還是改 % | 技能不改寫 STR／AGI／INT。只影響移動的技能只乘移動速度，上架 Circle／清潔計不變；收銀技能不改 INT；上架技能不改 AGI。 | playermovement.md, playerstats.md, playeractiveskills.md |
| 已處理 | 未定數值 | STR／AGI／INT 沒有換算表 | 移動、STR 負重／氣力／打擊每下扣血、AGI 上架 Circle 與清潔計、INT 收銀 Circle 與 CD 回復（INT10＝100%、INT50＝150%）已定。 | playerstats.md, playeraction.md, playermovement.md, thiefsystem.md, cleaningsystem.md |
| 已處理 | 互相矛盾 | 收銀指令次數表在 10 件重疊 | 9–10 件＝4 次；**11 件或以上＝5 次**（上限 5）。 | cashiersystem.md |
| 已處理 | 互相矛盾 | 執貨要求「空手」卻允許身上多種貨 | 空手，**或**未滿負重即可再取；滿載不能取。可同時帶多種貨。 | playeraction.md, replenishmentsystem.md |
| 已處理 | 互相矛盾 | 不能超重取貨，卻有「超出可容上限」減速 | 執貨不能把負重帶過上限。頂硬上結束後多出來的貨不掉落，超出當前上限才減速。剛好滿載不減速、也不能再取。 | replenishmentsystem.md, playermovement.md, playeractiveskills.md |
| 已處理 | 互相矛盾 | INT 加速 CD 與技能表寫死秒數衝突 | 表列 CD 為 INT 10。實際 CD = 表列 / 回復倍率（INT 50＝150% 回復）。 | playerstats.md, playeractiveskills.md, playerultimateskills.md |
| 已處理 | 規則含糊 | COST 佔格與 5 個具名插槽對不起來 | COST 是數值（1 格＝1），總和 ≤ 5。5 個具名插槽只是畫面／施放位置；2／3 COST 仍只放進其中一格。空格＝沒裝備。奧義不佔 COST。 | playerskills.md, playerpassiveskills.md |
| 已處理 | 規則含糊 | Buff／時停疊加未定義 | 客人完全停止則不能再疊移速。加速+減速依施放先後。同向加速 % 相乘。瞬間補貨 LV3 略過被動上架。CD／持續用現實秒。補貨時段可放技能。 | playeractiveskills.md, playerultimateskills.md, storeoperationphase.md, playerskills.md |
| 已處理 | 規則含糊 | The World「變慢 50%／80%」語意不清 | 減慢 X%＝世界流速剩 (100−X)%。時鐘、生成、不滿、排隊、客人動作一併變慢。玩家行動／Circle／CD／持續仍用現實秒。打擊倒數亦用現實秒。 | playerultimateskills.md, customer.md, thiefsystem.md |
| 已處理 | 規則含糊 | 安撫 25%／50% 的基數 | 相對**目前不滿度**。已離開者不拉回。 | playeractiveskills.md, customer.md |
| 已處理 | 缺檔／缺系統 | 清潔只有行動列 | `cleaningsystem.md` 已有：三類污物、移速 ×0.5、長按＋轉搖桿清潔計、AGI 決定全力轉滿秒數、空手、放手重置。 | cleaningsystem.md, playeraction.md, playerstats.md |
| 已處理 | 缺檔／缺系統 | 打擊只有行動列 | `thiefsystem.md` 已有：清單但不付款、被偷另計、空手抓住後連按扣血、STR 每下傷害、5 秒失敗倒地、衝刺撞飛＝逃走不算抓住。 | thiefsystem.md, playeraction.md, playermovement.md, playerstats.md |
| 已處理 | 未定數值 | 移動沒有基值 | AGI 10＝每秒 3 身位、上限 5×、跑 −20 氣力/秒、衝刺 −50、氣力 0 不能跑、污物 ×0.5 已寫進長線。擁擠減速與輕放／長按門檻仍缺。 | playermovement.md, playerstats.md |
| 已處理 | 缺檔／缺系統 | 沒有資金／採購／經營值文件 | 已有 `ecosystem.md`、`procurement.md`、`stockpricesystem.md`、`shopitem.md`、`shopprogress.md`。虧損＝當日營業額低於當日買入倉庫的貨；開發費、傢俬、工資不算；被偷不入帳。關店把當日營業額加入資金。「經營值」這個詞仍無定義，見下方未處理項。 | ecosystem.md, procurement.md, stockpricesystem.md, cashiersystem.md |
| 已處理 | 缺檔／缺系統 | 店鋪準備回合只有口號 | `storepreparationphase.md` 有準備選單與開始營業條件（已放置收銀機，以及至少一組同類型補貨架和貨架）。配點、技能、採購、擴張、店舖設計、店員各有檔。外觀仍只有一句。 | storepreparationphase.md, playersetup.md, shopsetup.md, clerksystem.md |
| 已處理 | 缺檔／缺系統 | 店員是誰 | `clerksystem.md`：可雇 NPC，日薪 $100，崗位為補貨或收銀，人數不大於收銀機數。補貨會補空貨架上的新貨，沒有空架才補已有貨。規模 LV4 能雇 3 人與店舖規模只到 LV3 仍衝突，見下方。 | clerksystem.md, gameconcept.md, playerexport.md |
| 已處理 | 缺檔／缺系統 | 店面空間未定義 | `shopsetup.md` 有格線、總面積（LV1＝100、LV2＝225、LV3＝400）、闊度與長度可互換（每邊最少 8）、拖放放置。`shopitem.md` 有收銀機與三種貨架的價格和 12 件容量。貨架品質、冰櫃差異、傢俬開放等級仍缺。 | shopsetup.md, shopitem.md, replenishmentsystem.md |
| 已處理 | 未定數值 | 級數系統全是待填 | 每級 +5 能力值。LV2–LV10 的經驗表已寫。上限寫 99，但 LV10 之後的表未寫。幾級解哪招技能仍無表。 | playerlevel.md, playerskills.md |
| P0 | 互相矛盾 | 雇員上限寫到規模 LV4，店舖規模只到 LV3 | 店舖規模三級：總面積 100／225／400。雇員表卻有規模 LV4＝3 人。角色 LV4、LV7 寫「能提升店舖規模」，沒有寫對上規模 LV2 還是 LV3。 | clerksystem.md, shopsetup.md, shopprogress.md |
| P0 | 互相矛盾 | 經驗從哪裡來，兩處不一致 | `ecosystem.md` 寫死：關店 +100、每成功收銀 +2、每抓住小偷 +10、每成功清潔 +5。`playerlevel.md` 仍寫完成經營回合後「按表現有所增減」，以及完成事件會再加。沒有事件經驗表。LV10 之後的升級經驗也未寫。 | ecosystem.md, playerlevel.md |
| P1 | 互相矛盾 | 貨架容量兩套說法 | `shopitem.md` 三種展示貨架都是 12 件。`replenishmentsystem.md` 寫貨架品質越高、容量越大。沒有品質等級，也沒有寫 12 件是不是品質 1。 | shopitem.md, replenishmentsystem.md |
| P1 | 未定數值 | 開放表沒寫完 | 零食到凍肉的角色等級、凍櫃補貨架（LV4）、冰櫃補貨架（LV7）已寫。叮叮飯的等級未寫。收銀機、乾貨補貨架、三種展示貨架的開放等級未寫。起始資金未寫。 | shopprogress.md, shopitem.md, ecosystem.md |
| P1 | 規則含糊 | Yes! My Lord! 破壞購物／收銀規則 | 「無視購買上限」搶最近貨架：是否清空貨架、是否加入該客人清單、沒錢／未開發 SKU、搶完是否仍要收銀指令、與清單上限 15 件關係。小偷在不在「全體客人」裡未寫。 | playerultimateskills.md, customer.md, cashiersystem.md, thiefsystem.md |
| P1 | 規則含糊 | 全體集資「一半客人」沒有選法 | LV1 只處理排隊。LV2 全店一半：進位、是否含離開中／小偷、是否略過指令與 Circle、營業額是否全額、購物未完成者是否白送。 | playerultimateskills.md, cashiersystem.md, thiefsystem.md |
| P1 | 規則含糊 | 衝刺撞飛客人與尋路互相打架 | 購物客人不互撞以免堵塞；衝刺卻 Screen KO 撞飛。不滿四種貨品條件（空手／錯貨／對貨／齊貨）**沒有數值**。路人減速「唔該借借」與撞飛如何並行。禮貌衝撞只寫「不增加不滿」，基數仍空。小偷撞飛規則已寫（逃走、已偷算被偷）。 | playermovement.md, customer.md, playerpassiveskills.md |
| P1 | 缺檔／缺系統 | 劇情／事件層沒有設計檔 | 三層循環的第一層：特殊過關條件、特別客人、購物異常。`ecosystem.md` 只有「現在進度／已完成／達成度」三個欄位。沒有事件表、觸發、失敗條件。`gameconcept.md` 的「經營值」沒有定義，也沒有對上經驗或資金。 | gameconcept.md, playerlevel.md, ecosystem.md |
| P1 | 缺檔／缺系統 | 幫忙取貨與 COMBO 交貨沒有規則 | 核心節奏寫客人找不到貨可幫忙提取、清單貨物可一口氣交付 COMBO。沒有互動對象、指令、計分、與收銀／不滿的關係。 | gameconcept.md, customer.md, playeraction.md |
| P1 | 未定數值 | 客人流量幾乎沒有長線數值 | 有清單上限 15、逗留 1 秒、思考 3 秒。抽出件數交給各 Demo。沒有生成間隔、在店人數上限、客人類別移速表。找不到貨長線點數未定（Demo v0.3 為 +18）。 | customer.md, gameconcept.md |
| P1 | 未定數值 | 污物／小偷的長線流量未定 | 清潔檔自承生成頻率、同時上限、垃圾氣力、三類不滿「小／中／大」長線未定。小偷清單件數、同時人數、出現間隔長線未定。霸王色「減少 50%」沒有基礎出現率可乘。 | cleaningsystem.md, thiefsystem.md, playerpassiveskills.md |
| P1 | 規則含糊 | 凌波微步只寫不減速 | 污物現有垃圾扣氣、水漬滑倒、嘔吐物禁技能／−30% 能力。此被動是否只忽略 ×0.5 移速，還是三類額外效果一併免疫？「穿過客人」減速長線仍無數字。 | playerpassiveskills.md, cleaningsystem.md, playermovement.md |
| P1 | 未定數值 | 技能幾級學會仍無表 | 技能本身的 LV1–LV3 效果已寫。角色升到幾級學會哪一招、被動為什麼只有 LV1，沒有表。 | playerskills.md, playerlevel.md, playeractiveskills.md, playerpassiveskills.md |
| P2 | 未定數值 | 擁擠與操作門檻 | 「太多客人同一地區」唔該借借沒有人數／倍率。輕放衝刺與長按奔跑的時間門檻未寫進長線（僅 Demo）。重置能力值有功能、沒有費用。 | playermovement.md, control.md, playersetup.md |
| P2 | 規則含糊 | 收銀方向如何抽 | 四向均勻？可否連續重複？清潔／打擊已改為轉搖桿／連按，不再是方向串。 | cashiersystem.md |
| P2 | 規則含糊 | 多台收銀機客人選哪一隊 | 可買多台。店員各看自己那台。客人完成購物後「前往收銀機」，沒有寫選最短隊、最近台，或人數相同怎麼分。 | cashiersystem.md, customer.md, clerksystem.md |
| P2 | 規則含糊 | 掉落物歸誰 | 水漬掉箱、丟掉的貨箱、打倒小偷掉贓均可撿。客人會否撿走、會否算進該客人清單／被偷統計，未寫。 | cleaningsystem.md, thiefsystem.md, customer.md, playeraction.md |
| P2 | 規則含糊 | 清潔可否邊走邊起動 | 上架已寫可在移動中起動、Circle 中不走。清潔／打擊只寫進行中不移動，起手時能否仍在走未寫。 | playeraction.md, cleaningsystem.md, thiefsystem.md |
| P2 | 規則含糊 | 小偷與污物／時停以外的世界規則 | 小偷踩污物是否減速、會否被安撫／金屬狂潮當「全體客人」、是否佔在店人數上限，未寫。 | thiefsystem.md, customer.md, playeractiveskills.md |
| P2 | 用詞／錯字 | 攜帶清單 FILO 說明含混 | 仍寫 First In Last Out，下文例子已是堆疊（後取的在最上層、空架先上最後一箱）。標籤和例子還未改成同一句話。 | replenishmentsystem.md |
| P2 | 缺檔／缺系統 | 角色導出只有一句 | `playerexport.md` 仍只說導出後以店員身分幫忙。`clerksystem.md` 補了：佔一個雇員欄、用導出的 STR／AGI／INT、工資仍付。連線、檔案、權限仍無。 | playerexport.md, clerksystem.md |
| P2 | 缺檔／缺系統 | HUD 以外的介面層空白 | 時計／營業額／人數／狀態／被偷已列。提早關店的詢問已寫。無暫停、設定、失敗／過關、存檔、教學。技能 Cut Scene 期間能否操作未寫。外觀配置只有一句。 | storeoperationphase.md, playerskills.md, control.md, playersetup.md |
| P2 | 用詞／錯字 | 用詞與錯字會改規則解讀 | 以為→以下；三能種力值；奧義兩處仍用「技令」；衝刺「身上沒有貨品而」句子斷掉。 | storeoperationphase.md, gameconcept.md, playerultimateskills.md, playermovement.md |

# 缺了整份檔的系統

經營回合與準備回合的主循環已有拆檔（含清潔、小偷、採購、店舖設計、店員）。下列主題被點名，但沒有對應設計，或檔案仍是一句。

- **循環與進度：** 劇情／事件表、過關與失敗、經營值、技能解鎖表、存檔
- **店內系統：** 幫忙取貨與 COMBO 交貨、冰櫃與凍櫃的操作差異、貨架品質
- **幾乎是空檔：** `playerexport.md` 只有一句（雇員欄規則在 `clerksystem.md`）。Voxel Art 只在概念出現，沒有製作規範。外觀配置只有一句

# 已有檔但仍寫不進程式的數值

| 主題 | 已寫的 | 仍缺的 |
| --- | --- | --- |
| 能力值 | STR／AGI／INT 主表已定（各項 50 封頂）；打擊每下扣血已定；每級 +5 點 | 重置費用 |
| 移動 | AGI 基值 3 身位/秒、上限 5×；跑 −20 氣力/秒；衝刺 −50；氣力 0 不能跑；污物 ×0.5 | 擁擠倍率、撞飛不滿數字、輕放／長按門檻 |
| 客人 | 清單上限 15、逗留 1s、思考 3s、不滿 0–100、排隊 15 秒滿 | 生成間隔、在店上限、抽出件數、找不到貨長線數字、客人類別 |
| 清潔 | 三類效果框架、清潔計 AGI 秒數、空手轉搖桿 | 生成間隔／同時上限、垃圾氣力／秒、三類不滿／秒 |
| 小偷 | 不付款、被偷另計、連按 STR 傷害、5 秒失敗、衝刺＝逃走 | 出現間隔／同時上限／清單件數、霸王色的基礎出現率 |
| 資金 | 價格表、開發費、虧損定義、關店入帳、日薪 $100 | 起始資金、叮叮飯開放等級、收銀機與展示貨架的開放等級 |
| 店面 | 總面積三級、邊長最少 8、拖放、貨架標價 12 件 | 貨架品質、規模 LV2／LV3 對上哪個角色等級、冰櫃差異 |
| 級數 | LV2–LV10 經驗表、每級 +5 | LV11–99、技能解鎖表、事件經驗 |
| 店員 | 日薪、崗位、空貨架優先、人數不大於收銀機 | 規模 LV4 與店舖只有 LV3 |
| 指令 | 收銀件數→次數、錯則重來、先指令後 Circle | 方向如何抽（清潔／打擊已不是方向串）、多台時客人選隊 |

# 建議拍板順序

這不是實作清單，是文件決策序。

1. ~~統一一局時長與時計~~ **已處理**
2. ~~定不滿量表~~ **已處理**（找不到貨／污物長線點數仍可再拍）
3. ~~能力值換算表~~ **已處理**（含清潔計與打擊每下）
4. ~~補清潔／小偷系統檔~~ **已處理**（流量數字與霸王色基數仍可再拍）
5. ~~資金與準備回合最小閉環~~ **已處理**（起始資金、叮叮飯等級、傢俬開放等級仍可再拍）
6. **雇員上限與店舖規模對齊**（刪掉規模 LV4，或寫出第四級面積；並寫明角色 LV4／LV7 各升到哪一級規模）
7. **經驗來源合成一張表**（以關店／收銀／抓小偷／清潔的固定值為準，或改回按表現；補上 LV10 之後）
8. 客人流量與貨架容量（品質制或固定 12 件，二擇一）
9. 衝刺撞飛客人的不滿數字，或從長線刪掉 Screen KO
10. 劇情／級數技能表，或先標「本階段不做」
