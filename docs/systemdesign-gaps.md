# 長線設計文件缺口

- 對照日：2026-10-15
- 範圍：只讀 `docs/systemdesign/`（17 檔），**不含** Demo scope
- 問題是文件本身的矛盾、缺系統與未定義，不是 v0.3 實作差異

| 設計檔 | 記下的問題 | 建議先拍板 (P0) | 缺整塊系統 |
| --- | --- | --- | --- |
| 17 | 31（7 已處理） | 2 | 9 |

**一局時長已拍板：** 現實 30 秒上貨 + 3 分鐘營運。

**其餘仍建議先拍：** 資金／準備回合。

用語：P0 不定則長線系統互相卡住；P1 已有系統但規則或數值不夠寫程式；P2 可晚點、或只是錯字。

分類：缺檔／缺系統 · 互相矛盾 · 未定數值 · 規則含糊 · 用詞／錯字

# 問題清單

| Pri | 分類 | 問題 | 說明 | 檔案 |
| --- | --- | --- | --- | --- |
| 已處理 | 互相矛盾 | 一局現實時間互相打架 | 已統一：現實 30 秒上貨 + 3 分鐘營運（合計約 3 分 30 秒）。遊戲時計仍為 06:00–08:00 補貨、08:00–22:00 營運。 | gameconcept.md, storeoperationphase.md |
| 已處理 | 互相矛盾 | 不滿度是加還是減 | 內部 0–100 累積怒氣，滿 100 離開。安撫＝減少目前不滿度（LV1 −25%／LV2 −50%／LV3 歸零；已離開不拉回）。儀表相反顯示（0 綠滿→100 紅見底）。排隊每秒 +100/15（15 秒由 0 到 100）。找不到貨／污物數字仍見 Demo。 | customer.md, playeractiveskills.md |
| 已處理 | 互相矛盾 | 技能加速到底改 AGI 還是改 % | 技能不改寫 STR／AGI／INT。只影響移動的技能只乘移動速度，上架／清潔不變；收銀技能不改 INT；上架技能不改 AGI。移動倍率見 AGI 換算表。 | playermovement.md, playerstats.md, playeractiveskills.md |
| P0 | 缺檔／缺系統 | 沒有資金／採購／經營值文件 | cashiersystem 只說營業額結算後才入商店資金。gameconcept 有採購、獲得經營值與資金。起始資金、日結公式、虧損、採購箱數與價格如何扣款，全部沒有檔。 | cashiersystem.md, gameconcept.md, stockpricesystem.md |
| P0 | 缺檔／缺系統 | 店鋪準備回合只有口號 | 能力配置、技能配置、外觀、採購、開發新貨、擴張、貨架配置、店員管理都寫在 gameconcept，沒有獨立流程、畫面或限制。control.md 卻已有準備回合操作鍵。 | gameconcept.md, control.md, playerskills.md |
| 已處理 | 未定數值 | STR／AGI／INT 沒有換算表 | 移動、STR 負重／氣力、AGI 上架／清潔 Circle、INT 收銀 Circle（2→0.2s）與 CD 回復（INT10＝100%、INT50＝150%）已定。 | playerstats.md, playeraction.md, playermovement.md |
| 已處理 | 互相矛盾 | 收銀指令次數表在 10 件重疊 | 9–10 件＝4 次；**11 件或以上＝5 次**（上限 5）。 | cashiersystem.md |
| 已處理 | 互相矛盾 | 執貨要求「空手」卻允許身上多種貨 | 執貨條件：空手，**或**未滿負重即可再取；滿載不能取。可同時帶多種貨。 | playeraction.md, replenishmentsystem.md |
| 已處理 | 互相矛盾 | 不能超重取貨，卻有「超出可容上限」減速 | 執貨不能把負重帶過上限。頂硬上結束後多出來的貨不掉落，超出當前上限才減速，上架回到上限內後恢復。剛好滿載不減速、也不能再取。 | replenishmentsystem.md, playermovement.md, playeractiveskills.md |
| 已處理 | 互相矛盾 | INT 加速 CD 與技能表寫死秒數衝突 | 表列 CD 為 INT 10。實際 CD = 表列 / 回復倍率（INT 50＝150% 回復）。 | playerstats.md, playeractiveskills.md, playerultimateskills.md |
| 已處理 | 規則含糊 | COST 佔格與 5 個具名插槽對不起來 | COST 是數值（1 格＝1），總和 ≤ 5。5 個具名插槽只是畫面／施放位置；2／3 COST 技能仍只放進其中一格。空格＝沒裝備。奧義不佔 COST。 | playerskills.md, playerpassiveskills.md |
| 已處理 | 規則含糊 | Buff／時停疊加未定義 | 客人完全停止則不能再疊移速。加速+減速依施放先後、一招結束才換下一招。同向加速（含被動）% 相乘疊加。瞬間補貨 LV3 略過被動上架。CD／持續用現實秒。補貨時段可放技能。 | playeractiveskills.md, playerultimateskills.md, storeoperationphase.md, playerskills.md |
| 已處理 | 規則含糊 | The World「變慢 50%／80%」語意不清 | 減慢 X%＝世界流速剩 (100−X)%（LV1 50%、LV2 20%、LV3 0%）。時鐘、生成、不滿、排隊、客人動作一併變慢。玩家行動／Circle／CD／持續仍用現實秒。 | playerultimateskills.md, customer.md |
| P1 | 規則含糊 | Yes! My Lord! 破壞購物／收銀規則 | 「無視購買上限」搶最近貨架：是否清空貨架、是否加入該客人清單、沒錢／未開發 SKU、搶完是否仍要收銀指令、與清單上限 15 件關係。 | playerultimateskills.md, customer.md, cashiersystem.md |
| P1 | 規則含糊 | 全體集資「一半客人」沒有選法 | LV1 只處理排隊。LV2 全店一半：進位、是否含離開中、是否略過指令與 Circle、營業額是否全額、購物未完成者是否白送。 | playerultimateskills.md, cashiersystem.md |
| P1 | 規則含糊 | 衝刺撞飛與客人尋路互相打架 | 購物客人不互撞以免堵塞；衝刺卻 Screen KO 撞飛。不滿四種貨品條件（空手／錯貨／對貨／齊貨）沒有數值。路人減速「唔該借借」與撞飛如何並行。小偷被撞飛後是否算打擊。 | playermovement.md, customer.md, playeraction.md |
| P1 | 缺檔／缺系統 | 劇情／事件層沒有設計檔 | 三層循環的第一層：特殊過關條件、特別客人、購物異常。playerlevel 說劇情跟級數走。沒有事件表、觸發、失敗條件。 | gameconcept.md, playerlevel.md |
| P1 | 缺檔／缺系統 | 清潔與打擊只有行動列，沒有系統 | 污物生成頻率、位置、清潔指令串長度、AGI 清潔秒數皆無。小偷出現率、行為、打擊指令、霸王色「減少 50%」的基數皆無。 | playeraction.md, customer.md, playerpassiveskills.md, playermovement.md |
| P1 | 缺檔／缺系統 | 店員是誰 | gameconcept 寫「貨架清空後店員補貨」「店員收錢」「店員管理」。是玩家角色、可雇 NPC，還是導出角色（playerexport）？NPC AI、工資、能否收銀未定。 | gameconcept.md, playerexport.md |
| P1 | 缺檔／缺系統 | 幫忙取貨與 COMBO 交貨沒有規則 | 核心節奏寫客人找不到貨可幫忙提取、清單貨物可一口氣交付 COMBO。沒有互動對象、指令、計分、與收銀／不滿的關係。 | gameconcept.md, customer.md, playeraction.md |
| P1 | 缺檔／缺系統 | 店面空間與擴張未定義 | 無格線、走道、初始傢俬上限、增購收銀機／貨架規則、品質與容量表。冰櫃種類有了，沒有溫度、腐壞或與凍櫃的操作差異。 | replenishmentsystem.md, stocksystem.md, cashiersystem.md |
| P1 | 未定數值 | 級數系統全是待填 | 上限待討論；經驗跟表現／事件「有所增減」無表；每級 N 點能力值的 N 未知；幾級解哪招技能未知。 | playerlevel.md, playerskills.md |
| P1 | 未定數值 | 客人流量幾乎沒有長線數值 | 有清單上限 15、逗留 1 秒、思考 3 秒。沒有生成間隔、在店人數上限、客人類別移速表。壓迫感無法設計。 | customer.md, gameconcept.md |
| P2 | 未定數值 | 移動只有倍率上限，沒有基礎值 | 上限 5 倍、下限「最少移動單位」。無走路速度、奔跑倍率、衝刺距離／時間、氣力上限／每秒消耗／回復、污物倍率、擁擠減速。輕放衝刺與長按奔跑的時間門檻未寫。 | playermovement.md, control.md |
| P2 | 規則含糊 | 方向指令如何抽 | 收銀「隨機生成」：四向均勻？可否連續重複？清潔／打擊「如 上左」是固定串還是也隨機、多長。 | cashiersystem.md, playeraction.md |
| 已處理 | 規則含糊 | 安撫 25%／50% 的基數 | 相對**目前不滿度**（不是上限 100 的固定點）。已離開者不拉回。 | playeractiveskills.md, customer.md |
| P2 | 規則含糊 | 多台收銀機未定義 | 可增購收銀機，但客人選哪一隊、玩家如何對準後台、會不會交叉排隊，都沒有。 | cashiersystem.md |
| P2 | 用詞／錯字 | 攜帶清單 FILO 說明含混 | 寫 First In Last Out，又說最後一件才能上架（堆疊）。例子編號 1,2,3,9 跳號。應明確為堆疊：後取先上。 | replenishmentsystem.md |
| P2 | 缺檔／缺系統 | 角色導出只有一句 | 導出什麼數值、對方如何限制、是否佔店員欄、連線／檔案格式、權限，皆無。 | playerexport.md |
| P2 | 缺檔／缺系統 | HUD 以外的介面層空白 | storeoperationphase 列出時計／營業額／人數／狀態。無暫停、設定、失敗／過關、存檔、教學。技能 Cut Scene 期間能否操作未寫。 | storeoperationphase.md, playerskills.md, control.md |
| P2 | 用詞／錯字 | 用詞與錯字會改規則解讀 | 以為→以下；三能種力值；配塔；商內；排隊其間；輸入指力；技能技令（兩處奧義仍用技令）；身上沒有貨品而（句子斷掉）。 | storeoperationphase.md, gameconcept.md, playerskills.md, customer.md, playeraction.md, playerultimateskills.md, playermovement.md |

# 缺了整份檔的系統

gameconcept 的三層循環裡，只有「經營回合」有較完整的拆檔。下列主題被點名，但沒有對應設計文件。

- **循環與進度：** 劇情／事件、過關與失敗、經營值、角色級數表、存檔
- **準備回合：** 配點 UI、技能裝備畫面、採購、開發新貨、擴張與貨架擺放、外觀
- **店內系統：** 清潔、小偷與打擊、店員 AI、幫忙取貨與 COMBO 交貨、多收銀台規則、冰櫃特殊規則
- **幾乎是空檔：** `playerexport.md` 只有一句。Voxel Art 只在概念出現，沒有製作規範

# 已有檔但仍寫不進程式的數值

| 主題 | 已寫的 | 仍缺的 |
| --- | --- | --- |
| 能力值 | STR／AGI／INT 主要換算已定（各項 50 封頂） | — |
| 移動 | AGI 基值 3 身位/秒、上限 5×；跑 −20 氣力/秒；衝刺 −50；氣力 0 不能跑 | 擁擠／污物倍率、撞飛不滿數字、輕放／長按門檻 |
| 客人 | 清單上限 15、逗留 1s、思考 3s、不滿 0–100、排隊 15 秒滿 | 生成間隔、在店上限、找不到貨／污物長線數字、客人類別 |
| 貨架／箱 | 一箱 4 件、同類連續上架 | 貨架品質→容量、初始店面、冰櫃差異 |
| 級數 | 經驗來自回合與事件、升級配點、升級解技能 | 上限、N 點、經驗表、解鎖表 |
| 指令 | 收銀件數→次數、錯則重來、先指令後 Circle | 10 件歸哪檔、方向如何抽、清潔／打擊串 |

# 建議拍板順序

這不是實作清單，是文件決策序。

1. ~~統一一局時長與時計~~ **已處理：** 現實 30 秒上貨 + 3 分鐘營運；遊戲時計 06:00–08:00／08:00–22:00。
2. ~~定不滿量表~~ **已處理：** 0–100 累積怒氣；安撫減少目前不滿；儀表相反顯示；排隊 15 秒滿。找不到貨／污物長線數字仍可再拍。
3. ~~能力值換算表~~ **已處理**（STR／AGI／INT 主表）。Buff／時停如何相乘仍見 P1。
4. 資金與準備回合最小閉環（沒有這層，採購成本與擴張都是空的）。
5. 補清潔／小偷，或從長線行動表刪掉，避免操作與技能（霸王色、禮貌衝撞）懸空。
