# 長線設計文件缺口

- 對照日：2026-10-22（對齊 PR #3–#40：含掉貨瞄準／丟掉上架／丟掉砸小偷 KO／近遠散落／離店可抓／得手橫幅／客人離店不卡門／Pages／docs align；另含 #3–#17 工程項）
- 範圍：只讀 `docs/systemdesign/`（含 `savesystem.md`、`pausemenu.md`），**不含** Demo scope
- 工程落地對照：`docs/alpha/implementation-status.md`
- 執行期優化分析（非玩法缺口）：`docs/alpha/runtime-perf-audit.md`
- 問題是文件本身的矛盾、缺系統與未定義，不是 Demo 實作差異（Demo 試玩數字只當「長線未定」的註記）

| 設計檔 | 記下的問題 | 建議先拍板 (P0) | 缺整塊系統 |
| --- | --- | --- | --- |
| 見下表（開：P1 5 · Alpha 15 · Beta 2；已處理 31） | 見下表 | 0 | 見下（存檔已補） |

**一局時長已拍板：** 現實 30 秒上貨 + 3 分鐘營運。

**資金、準備回合、店舖設計、店員、存檔已有檔。** 操作以 InputMap 為準。雇員上限已暫時跟到規模 LV3。經驗來源已跟 `ecosystem.md`，只增不減。開放表裡叮叮飯、收銀機、規模等級和起始資金已寫。幫忙取貨、COMBO 和全部 P2 見 `docs/alpha/design.md`。客人流量、污物與小偷流量見 `docs/beta/design.md`。工程活線見 `docs/versioning.md`。

用語：P0 不定則長線系統互相卡住；P1 已有系統但規則或數值不夠寫程式。Alpha、Beta 是改放到該版本才設計，不在這份長線清單裡先拍。

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
| 已處理 | 缺檔／缺系統 | 打擊只有行動列 | `thiefsystem.md` 已對齊活線：近距 KO 散落／衝刺遠距散落（≤5 身位）／方向丟掉砸中（Screen KO、贓物原地掉落、算抓住）、離店途中仍可抓／砸／撞、得手出口才計被偷＋橫幅、Screen KO／連打晃動。 | thiefsystem.md, playeraction.md, playermovement.md, playerstats.md, replenishmentsystem.md |
| 已處理 | 未定數值 | 移動沒有基值 | AGI 10＝每秒 3 身位、上限 5×、跑 −20 氣力/秒、衝刺 −50、氣力 0 不能跑、污物 ×0.5 已寫進長線。擁擠減速與輕放／長按門檻仍缺。 | playermovement.md, playerstats.md |
| 已處理 | 缺檔／缺系統 | 沒有資金／採購／經營值文件 | 已有 `ecosystem.md`、`procurement.md`、`stockpricesystem.md`、`shopitem.md`、`shopprogress.md`。虧損＝當日營業額低於當日買入倉庫的貨；開發費、傢俬、工資不算；被偷不入帳。關店把當日營業額加入資金。「經營值」這個詞仍無定義，見下方未處理項。 | ecosystem.md, procurement.md, stockpricesystem.md, cashiersystem.md |
| 已處理 | 缺檔／缺系統 | 店鋪準備回合只有口號 | `storepreparationphase.md` 有準備選單與開始營業條件（已放置收銀機，以及至少一組同類型補貨架和貨架）。配點、技能、採購、擴張、店舖設計、店員各有檔。外觀仍只有一句。 | storepreparationphase.md, playersetup.md, shopsetup.md, clerksystem.md |
| 已處理 | 缺檔／缺系統 | 店員是誰 | `clerksystem.md`：可雇 NPC，日薪 $100，崗位為補貨或收銀，人數不大於收銀機數。補貨會補空貨架上的新貨，沒有空架才補已有貨。 | clerksystem.md, gameconcept.md, playerexport.md |
| 已處理 | 互相矛盾 | 雇員上限寫到規模 LV4，店舖規模只到 LV3 | 暫時把雇員上限跟到現有規模：LV1＝0、LV2＝1、LV3＝2。規模 LV4 的人數先不寫，等有第四級面積再定。角色 LV4 升規模到 LV2，角色 LV7 升規模到 LV3。 | clerksystem.md, shopsetup.md, shopprogress.md |
| 已處理 | 缺檔／缺系統 | 店面空間未定義 | `shopsetup.md` 有格線、總面積（LV1＝100、LV2＝225、LV3＝400）、闊度與長度可互換（每邊最少 8）、拖放放置。展示貨架每種有 4／8／12／24 件四款。冰櫃與凍櫃的操作差異仍缺。 | shopsetup.md, shopitem.md, replenishmentsystem.md |
| 已處理 | 未定數值 | 級數系統全是待填 | 每級 +5 能力值。LV2–LV10 的經驗表已寫。上限寫 99，但 LV10 之後的表未寫。幾級解哪招技能仍無表。 | playerlevel.md, playerskills.md |
| 已處理 | 互相矛盾 | 經驗從哪裡來，兩處不一致 | 暫時跟 `ecosystem.md`：關店 +100、每成功收銀 +2、每抓住小偷 +10、每成功清潔 +5。經驗只增不減。事件和劇情的經驗留待 Beta。LV11–99 的升級經驗仍未寫。 | ecosystem.md, playerlevel.md |
| 已處理 | 互相矛盾 | 貨架容量兩套說法 | 品質是不同款式。乾貨、凍櫃、冰櫃各有 4／8／12／24 件，容量越大越貴。12 件維持原價（$100／$200／$300），其餘按件數比例取整。 | shopitem.md, replenishmentsystem.md |
| 已處理 | 未定數值 | 開放表沒寫完 | 叮叮飯為角色 LV10。收銀機、乾貨補貨架、乾貨貨架為 LV1。凍櫃架跟凍櫃補貨架在 LV4，冰櫃架跟冰櫃補貨架在 LV7。起始資金 $2500。角色 LV4 升店舖規模 LV2，角色 LV7 升店舖規模 LV3。 | shopprogress.md, shopitem.md, shopsetup.md, ecosystem.md |
| 已處理 | 規則含糊 | Yes! My Lord! 破壞購物／收銀規則 | 清空最近還有貨的貨架，貨加入該客人清單並算已取到。客人沒有錢上限，拿多少付多少；未開發貨不會在店。只加清單，原本清單未完成也立刻去排隊，收銀指令仍要做，未取到的原清單不計價。這招可以把清單加到多過 15 件。11 件或以上仍是 5 次指令。 | playerultimateskills.md, customer.md, cashiersystem.md |
| P1 | 規則含糊 | Yes! My Lord! 包不包括小偷 | 施放對象寫全體客人。小偷算不算在裡面仍未寫。 | playerultimateskills.md, thiefsystem.md |
| 已處理 | 規則含糊 | 全體集資「一半客人」沒有選法 | LV1 只處理排隊。LV2、LV3 都不含離開中客人和小偷。略過指令與 Circle，馬上收錢。已拿走的貨按售價全額入帳；未買完的貨不入帳、不白送，客人當已付款離開。 | playerultimateskills.md, cashiersystem.md |
| 已處理 | 規則含糊 | 全體集資 LV2 一半怎樣取 | 單數向上取整。已拿走件數最多的客人優先。件數相同時，銷售金額最高者優先。件數和金額都相同時，不滿度較高者優先。不滿度也相同時，隨意選一位。 | playerultimateskills.md |
| P1 | 規則含糊 | 衝刺撞飛客人與尋路互相打架 | 長線 `playermovement.md` 仍寫衝刺 Screen KO 撞飛**客人**＋四種不滿條件；**活線只撞小偷**（`player._try_dash_thief`），客人 KO **未實作**。不滿數字長線仍空（Alpha plan 有草稿 +25/+40/0/歸零）。路人減速「唔該借借」與撞飛如何並行未定。**小偷**撞飛已定：飛離＋遠距散落可撿、不計被偷、**不算抓住、不算逃走**（見 `thiefsystem.md`）。拍板：刪長線客人 KO，或補實作＋數字。 | playermovement.md, customer.md, playerpassiveskills.md |
| P1 | 缺檔／缺系統 | 劇情／事件層沒有設計檔 | 已標明留待 Beta，現階段經驗不從這裡增減。三層循環的第一層仍無事件表、觸發、失敗條件。`gameconcept.md` 的「經營值」沒有定義。 | gameconcept.md, playerlevel.md, ecosystem.md |
| Alpha | 缺檔／缺系統 | 幫忙取貨與 COMBO 交貨沒有規則 | 留待 Alpha 設計，見 `docs/alpha/design.md`。核心節奏有兩句，沒有互動對象、指令、計分、與收銀／不滿的關係。 | gameconcept.md, customer.md, playeraction.md |
| Beta | 未定數值 | 客人流量幾乎沒有長線數值 | 留待 Beta 設計，見 `docs/beta/design.md`。有清單上限 15、逗留 1 秒、思考 3 秒。抽出件數交給各 Demo。沒有生成間隔、在店人數上限、客人類別移速表。找不到貨長線點數未定（Demo v0.3 為 +18）。 | customer.md, gameconcept.md |
| Beta | 未定數值 | 污物／小偷的長線流量未定 | 留待 Beta 設計，見 `docs/beta/design.md`。清潔檔的生成頻率、同時上限、垃圾氣力、三類不滿長線未定。小偷清單件數、同時人數、出現間隔長線未定。霸王色「減少 50%」沒有基礎出現率可乘。 | cleaningsystem.md, thiefsystem.md, playerpassiveskills.md |
| P1 | 規則含糊 | 凌波微步只寫不減速 | 污物現有垃圾扣氣、水漬滑倒、嘔吐物禁技能／−30% 能力。此被動是否只忽略 ×0.5 移速，還是三類額外效果一併免疫？「穿過客人」減速長線仍無數字。 | playerpassiveskills.md, cleaningsystem.md, playermovement.md |
| P1 | 未定數值 | 技能幾級學會仍無表 | 技能本身的 LV1–LV3 效果已寫。角色升到幾級學會哪一招、被動為什麼只有 LV1，沒有表。 | playerskills.md, playerlevel.md, playeractiveskills.md, playerpassiveskills.md |
| Alpha | 未定數值 | 擁擠與操作門檻 | 留待 Alpha 設計，見 `docs/alpha/design.md`。「唔該借借」沒有人數／倍率。輕放／長按門檻僅 Demo。重置能力值沒有費用。 | playermovement.md, control.md, playersetup.md |
| Alpha | 規則含糊 | 收銀方向如何抽 | 留待 Alpha 設計，見 `docs/alpha/design.md`。四向是否均勻、可否連續重複未寫。 | cashiersystem.md |
| Alpha | 規則含糊 | 多台收銀機客人選哪一隊 | 留待 Alpha 設計，見 `docs/alpha/design.md`。沒有寫選最短隊、最近台，或人數相同怎麼分。 | cashiersystem.md, customer.md, clerksystem.md |
| Alpha | 規則含糊 | 掉落物歸誰 | **部分已處理：** 玩家丟掉／水漬掉箱／小偷三種落地（近距散落／衝刺遠散落／丟掉原地）都可撿；方向丟掉可補同款貨架；小偷掉落**不計被偷**，得手出口才計被偷。**仍缺：** 客人會否撿走地上的箱、會否算進該客人清單（見 `docs/alpha/design.md`）。 | cleaningsystem.md, thiefsystem.md, customer.md, playeraction.md, replenishmentsystem.md |
| Alpha | 規則含糊 | 丟掉多目標怎麼選 | 軌道／落點同時可命中多名小偷或多個可接受貨架時，長線未寫選法。活線：小偷＝路徑＋落點最近且 ≤`DROP_THIEF_HIT_RADIUS`；貨架＝僅落點最近且 ≤`DROP_SHELF_HIT_RADIUS`；**小偷優先於貨架**（已寫）。需否寫死「只砸最近一個／只補最近一架」。 | thiefsystem.md, replenishmentsystem.md, playeraction.md |
| Alpha | 規則含糊 | 丟掉會否砸一般客人 | 活線只打 `is_active_thief`；箱子穿過一般客人無效果。長線未寫「是否可撞飛／加不滿／無視」。 | playeraction.md, customer.md, thiefsystem.md |
| Alpha | 規則含糊 | 贓物三種落地是否定案為長線數值 | `thiefsystem.md` 已寫活線近似：近距 0.55–1.75 身位、衝刺 2.2–5 身位、丟掉原地（`LOOT_INPLACE_MAX`≈0.35 身位）。需標正式長線拍板，或註「活線暫定、可再收」。 | thiefsystem.md |
| 已處理 | 規則含糊 | 衝刺撞飛計入哪種結算人數 | 已寫死：衝刺撞飛不算抓住、不計被偷、**不算逃走**；近身 KO／丟掉砸中才加抓住。活線：dash 不 `record_caught`／不 `thieves_escaped`。 | thiefsystem.md, storeoperationphase.md, ecosystem.md |
| Alpha | 規則含糊 | 丟掉上架與近身上架的技能差異 | 已寫：不走 Circle、剩貨掉地、腳邊不上架。仍可補：是否吃「上架速度／瞬間補貨」（活線丟掉路徑瞬間、技能無關）；補貨時段可否丟掉上架（活線可）。若長線要鎖應寫死。 | replenishmentsystem.md, playeractiveskills.md |
| Alpha | 規則含糊 | 清潔可否邊走邊起動 | 留待 Alpha 設計，見 `docs/alpha/design.md`。長線未寫起手時能否仍在走。**活線註記：** 清潔／打擊進入後即鎖移動。 | playeraction.md, cleaningsystem.md, thiefsystem.md |
| Alpha | 規則含糊 | 小偷與污物／時停以外的世界規則 | 留待 Alpha 設計，見 `docs/alpha/design.md`。小偷踩污物、是否算全體客人、是否佔在店人數，未寫。 | thiefsystem.md, customer.md, playeractiveskills.md |
| Alpha | 用詞／錯字 | 攜帶清單 FILO 說明含混 | 留待 Alpha 設計，見 `docs/alpha/design.md`。標籤仍是 First In Last Out，例子已是堆疊。 | replenishmentsystem.md |
| Alpha | 缺檔／缺系統 | 角色導出只有一句 | 留待 Alpha 設計，見 `docs/alpha/design.md`。雇員欄規則已有。連線、檔案、權限仍無。 | playerexport.md, clerksystem.md |
| 已處理 | 缺檔／缺系統 | 存檔 | 已有 `savesystem.md`：`user://save.json` + `version`；關店與準備結束寫入。活線已實作。 | savesystem.md, storepreparationphase.md, storeoperationphase.md |
| 已處理 | 規則含糊 | 操作是否綁死鍵位 | 長線以 InputMap 為準（`control.md`）；預設仍 WASD／Xbox。活線 Autoload `Controls`。 | control.md |
| 已處理 | 缺檔／缺系統 | 暫停選單／掛起 | 已有 `pausemenu.md`；活線接 `PlatformServices` suspend／resume。 | pausemenu.md, storeoperationphase.md, savesystem.md |
| Alpha | 缺檔／缺系統 | HUD 以外的介面層空白 | 存檔／InputMap／暫停／字串表已補。仍缺：設定（音量）、失敗／過關、教學、技能演出期間能否操作。 | storeoperationphase.md, playerskills.md, control.md, playersetup.md |
| Alpha | 用詞／錯字 | 用詞與錯字會改規則解讀 | **部分已處理：** `storeoperationphase.md`「以為→以下」已修。**仍缺：** `gameconcept.md`「三能種力值」；`playerultimateskills.md` 兩處「技令」；`playermovement.md`「身上沒有貨品而」斷句。見 `docs/alpha/design.md`。 | gameconcept.md, playerultimateskills.md, playermovement.md |

# 缺了整份檔的系統

經營回合與準備回合的主循環已有拆檔（含清潔、小偷、採購、店舖設計、店員）。下列主題被點名，但沒有對應設計，或檔案仍是一句。

- **循環與進度：** 劇情／事件表、過關與失敗、經營值、技能解鎖表。~~存檔~~ 見 `savesystem.md`。~~暫停／掛起~~ 見 `pausemenu.md`
- **店內系統：** 冰櫃與凍櫃的操作差異。幫忙取貨與 COMBO 留待 Alpha
- **幾乎是空檔：** 角色導出的連線與檔案留待 Alpha。Voxel 初模和給設計師加細節的規矩在 `docs/alpha/voxel-v0.1.md`。外觀配置只有一句
- **工程路徑：** Demo／Alpha 專案目錄已凍結；v1 只改 `godot/game`（`docs/versioning.md`）。平台商務／Godot 釘版見 `docs/alpha/console-business.md`、`docs/alpha/godot-middleware-pin.md`（非玩法規則）

# 已有檔但仍寫不進程式的數值

| 主題 | 已寫的 | 仍缺的 |
| --- | --- | --- |
| 能力值 | STR／AGI／INT 主表已定（各項 50 封頂）；打擊每下扣血已定；每級 +5 點 | 重置費用留待 Alpha |
| 移動 | AGI 基值 3 身位/秒、上限 5×；跑 −20 氣力/秒；衝刺 −50；氣力 0 不能跑；污物 ×0.5 | 客人衝刺 KO／不滿數字仍在長線（**活線未做客人撞飛**）。擁擠倍率、輕放／長按門檻留待 Alpha |
| 客人 | 清單上限 15、逗留 1s、思考 3s、不滿 0–100、排隊 15 秒滿 | 生成間隔、在店上限、抽出件數、找不到貨長線數字、客人類別留待 Beta |
| 清潔 | 三類效果框架、清潔計 AGI 秒數、空手轉搖桿 | 生成間隔／同時上限、垃圾氣力／秒、三類不滿／秒留待 Beta |
| 小偷 | 不付款；出口帶贓才計被偷＋橫幅；近距 KO 散落／衝刺遠散落（≤5 身位，不算抓住、不算逃走）／丟掉砸中 Screen KO＋原地掉落（算抓住）；離店途中仍可抓／砸／撞；連按 STR、5 秒失敗 | 出現間隔／同時上限／清單件數、霸王色基礎出現率留待 Beta；三種落地半徑是否正式拍板見上表 Alpha 列 |
| 資金 | 價格表、開發費、虧損定義、關店入帳、日薪 $100、起始資金 $2500 | |
| 店面 | 總面積三級、邊長最少 8、拖放、每種展示貨架 4／8／12／24 件、規模 LV2 要角色 LV4、規模 LV3 要角色 LV7 | 冰櫃與凍櫃的操作差異 |
| 級數 | LV2–LV10 經驗表、每級 +5、經驗只增不減（來源跟 ecosystem） | LV11–99、技能解鎖表。事件經驗留待 Beta |
| 店員 | 日薪、崗位、空貨架優先、人數不大於收銀機、上限跟到規模 LV3（0／1／2） | 規模 LV4 的人數，等有第四級面積再定 |
| 指令 | 收銀件數→次數、錯則重來、先指令後 Circle | 方向如何抽、多台時客人選隊，留待 Alpha |

# 建議拍板順序

這不是實作清單，是文件決策序。

1. ~~統一一局時長與時計~~ **已處理**
2. ~~定不滿量表~~ **已處理**（找不到貨／污物的長線點數留待 Beta）
3. ~~能力值換算表~~ **已處理**（含清潔計與打擊每下）
4. ~~補清潔／小偷系統檔~~ **已處理**（流量數字與霸王色基數留待 Beta）
5. ~~資金與準備回合最小閉環~~ **已處理**（起始資金 $2500、叮叮飯 LV10、傢俬開放等級已寫）
6. ~~雇員上限與店舖規模對齊~~ **已處理**（暫時 LV1＝0、LV2＝1、LV3＝2。角色 LV4→規模 LV2，角色 LV7→規模 LV3）
7. ~~經驗來源合成一張表~~ **已處理**（跟 ecosystem，只增不減。事件經驗留待 Beta。LV11–99 仍未寫）
8. ~~貨架容量~~ **已處理**（每種 4／8／12／24 件，越大越貴）。客人流量數字留待 Beta
9. 衝刺撞飛**客人**：補不滿數字並實作，或從長線刪 Screen KO（活線目前只撞小偷）
10. 劇情／事件已標 Beta。技能解鎖表仍未寫
11. 丟掉多目標選法、會否砸一般客人、三種贓物落地半徑是否正式拍板
12. 衝刺撞飛結算：長線寫死「不算逃走」（對齊活線）
