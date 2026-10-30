# 長線設計文件缺口

- 對照日：2026-10-30（含 v1.1.0 拍板＋v1.2.0 客人交付／技能組／三招狙擊手／Dark Side／多重影分身設計 #63–#117；對齊至 main tip）
- 範圍：只讀 `docs/systemdesign/`（含 `savesystem.md`、`pausemenu.md`），**不含** Demo scope
- 工程落地對照：`docs/alpha/implementation-status.md`
- 執行期優化分析（非玩法缺口）：`docs/alpha/runtime-perf-audit.md`
- 問題是文件本身的矛盾、缺系統與未定義，不是 Demo 實作差異（Demo 試玩數字只當「長線未定」的註記）

| 設計檔 | 記下的問題 | 建議先拍板 (P0) | 缺整塊系統 |
| --- | --- | --- | --- |
| 見下表 | 見下表 | 0 | 見下（存檔已補） |

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
| 已處理 | 缺檔／缺系統 | 店員是誰 | `clerksystem.md`：可雇 NPC，日薪 $100，崗位為補貨或收銀，人數不大於收銀機數。補貨會補空貨架上的新貨，沒有空架才補已有貨；有計劃時每幀跟隨，閒置才用 0.35s 掃描冷卻。 | clerksystem.md, gameconcept.md, playerexport.md |
| 已處理 | 互相矛盾 | 雇員上限寫到規模 LV4，店舖規模只到 LV3 | 暫時把雇員上限跟到現有規模：LV1＝0、LV2＝1、LV3＝2。規模 LV4 的人數先不寫，等有第四級面積再定。角色 LV4 升規模到 LV2，角色 LV7 升規模到 LV3。 | clerksystem.md, shopsetup.md, shopprogress.md |
| 已處理 | 缺檔／缺系統 | 店面空間未定義 | `shopsetup.md` 有格線、總面積（LV1＝100、LV2＝225、LV3＝400）、闊度與長度可互換（每邊最少 8）、拖放放置。展示貨架每種有 4／8／12／24 件四款。冰櫃與凍櫃的操作差異仍缺。 | shopsetup.md, shopitem.md, replenishmentsystem.md |
| 已處理 | 未定數值 | 級數系統全是待填 | 每級 +5 能力值。LV2–LV10 的經驗表已寫。上限寫 99，但 LV10 之後的表未寫。幾級解哪招技能仍無表。 | playerlevel.md, playerskills.md |
| 已處理 | 互相矛盾 | 經驗從哪裡來，兩處不一致 | 暫時跟 `ecosystem.md`：關店 +100、每成功收銀 +2、每抓住小偷 +10、每成功清潔 +5。經驗只增不減。事件和劇情的經驗留待 Beta。LV11–99 的升級經驗仍未寫。 | ecosystem.md, playerlevel.md |
| 已處理 | 互相矛盾 | 貨架容量兩套說法 | 品質是不同款式。乾貨、凍櫃、冰櫃各有 4／8／12／24 件，容量越大越貴。12 件維持原價（$100／$200／$300），其餘按件數比例取整。 | shopitem.md, replenishmentsystem.md |
| 已處理 | 未定數值 | 開放表沒寫完 | 叮叮飯為角色 LV10。收銀機、乾貨補貨架、乾貨貨架為 LV1。凍櫃架跟凍櫃補貨架在 LV4，冰櫃架跟冰櫃補貨架在 LV7。起始資金 $2500。角色 LV4 升店舖規模 LV2，角色 LV7 升店舖規模 LV3。 | shopprogress.md, shopitem.md, shopsetup.md, ecosystem.md |
| 已處理 | 規則含糊 | Yes! My Lord! 破壞購物／收銀規則 | 清空最近還有貨的貨架，貨加入該客人清單並算已取到。客人沒有錢上限，拿多少付多少；未開發貨不會在店。只加清單，原本清單未完成也立刻去排隊，收銀指令仍要做，未取到的原清單不計價。這招可以把清單加到多過 15 件。11 件或以上仍是 5 次指令。 | playerultimateskills.md, customer.md, cashiersystem.md |
| 已處理 | 規則含糊 | Yes! My Lord! 包不包括小偷 | **不包括小偷**，只包括一般客人（與全體集資一致）。 | playerultimateskills.md, thiefsystem.md |
| 已處理 | 規則含糊 | 全體集資「一半客人」沒有選法 | LV1 只處理排隊。LV2、LV3 都不含離開中客人和小偷。略過指令與 Circle，馬上收錢。已拿走的貨按售價全額入帳；未買完的貨不入帳、不白送，客人當已付款離開。 | playerultimateskills.md, cashiersystem.md |
| 已處理 | 規則含糊 | 全體集資 LV2 一半怎樣取 | 單數向上取整。已拿走件數最多的客人優先。件數相同時，銷售金額最高者優先。件數和金額都相同時，不滿度較高者優先。不滿度也相同時，隨意選一位。 | playerultimateskills.md |
| 已處理 | 規則含糊 | 衝刺撞飛客人與尋路互相打架 | 衝刺撞客人：Screen KO 飛起再**原地落地**（不離店）；停止 2 秒；+50 不滿（基值；禮貌衝撞則 +0）；購物車貨品原地掉落；**購物清單不變**（不重抽），已取貨放回清單後從頭尋貨。路人擁擠：玩家 3 身位內有客人／小偷 → 移速 ×0.5＋頭頂「唔該借借⋯」。小偷被衝刺撞飛或貨箱砸中都**算抓住**。 | playermovement.md, customer.md, playerpassiveskills.md, thiefsystem.md, ecosystem.md |
| P1 | 缺檔／缺系統 | 劇情／事件層沒有設計檔 | 已標明留待 Beta，現階段經驗不從這裡增減。三層循環的第一層仍無事件表、觸發、失敗條件。`gameconcept.md` 的「經營值」沒有定義。 | gameconcept.md, playerlevel.md, ecosystem.md |
| Alpha | 缺檔／缺系統 | 幫忙取貨與 COMBO 交貨沒有規則 | 留待 Alpha 設計，見 `docs/alpha/design.md`。核心節奏有兩句，沒有互動對象、指令、計分、與收銀／不滿的關係。 | gameconcept.md, customer.md, playeraction.md |
| Beta | 未定數值 | 客人流量幾乎沒有長線數值 | 留待 Beta 設計，見 `docs/beta/design.md`。有清單上限 15、逗留 1 秒、思考 3 秒。抽出件數交給各 Demo。沒有生成間隔、在店人數上限、客人類別移速表。找不到貨長線點數未定（Demo v0.3 為 +18）。麻煩客人行為已寫進 `elitecustomer.md` 並落地；仍欠劇情 LV 解鎖／事件表。 | customer.md, elitecustomer.md, gameconcept.md |
| Beta | 未定數值 | 污物／小偷的長線流量未定 | 留待 Beta 設計，見 `docs/beta/design.md`。清潔檔的生成頻率、同時上限、垃圾氣力、三類不滿長線未定。小偷清單件數、同時人數、出現間隔長線未定。霸王色「減少 50%」沒有基礎出現率可乘。 | cleaningsystem.md, thiefsystem.md, playerpassiveskills.md |
| 已處理 | 規則含糊 | 凌波微步只寫不減速 | 發動時：污物不減速；dash 遇污物高速繞過（特效）；垃圾不扣氣；水漬跑／衝不滑（自水漬 dash 則高速離污）；嘔吐物不禁技能、不減能力。擁擠減速見衝刺／擁擠項。 | playerpassiveskills.md, cleaningsystem.md, playermovement.md |
| Beta | 未定數值 | 技能幾級學會仍無表 | 留待 Beta（見 `docs/beta/design.md`）。技能 LV1–LV3 效果已寫；角色幾級解鎖哪招仍無表。 | playerskills.md, playerlevel.md, docs/beta/design.md |
| 已處理 | 未定數值 | 擁擠與操作門檻 | 擁擠見上（3 身位、×0.5、「唔該借借⋯」）。輕放／長按門檻跟活線：衝刺／跑 0.18s、丟掉 0.45s、選貨／技能選單 0.18s。重置能力值費用＝角色等級 × $1000。 | playermovement.md, control.md, playersetup.md |
| 已處理 | 規則含糊 | 收銀方向如何抽 | **隨機**四向，**可連續重複**。 | cashiersystem.md |
| 已處理 | 規則含糊 | 多台收銀機客人選哪一隊 | 先最短隊；人數相同選最近台；距離相同則隨機。 | cashiersystem.md, customer.md, clerksystem.md |
| 已處理 | 規則含糊 | 掉落物歸誰 | 地上箱只有玩家可撿。客人**不會**撿走、**不會**算進該客人清單。 | cleaningsystem.md, thiefsystem.md, customer.md, playeraction.md, replenishmentsystem.md |
| 已處理 | 規則含糊 | 清潔可否邊走邊起動 | 清潔可邊走邊起動；走手（長按開始填計）後進行中鎖移動。打擊同：起手可走，抓住後不移動。 | playeraction.md, cleaningsystem.md, thiefsystem.md |
| 已處理 | 規則含糊 | 小偷與污物／時停以外的世界規則 | 小偷踩污物不受影響。小偷不佔在店客人數，另計在店小偷數。The World 時小偷一併停止／減慢。Yes! My Lord!／全體集資不含小偷。 | thiefsystem.md, customer.md, playerultimateskills.md |
| 已處理 | 用詞／錯字 | 攜帶清單 FILO 說明含混 | 以**堆疊**為準：後取先上（最上一段先上架／丟掉）；去掉誤導用詞與跳號例子。 | replenishmentsystem.md |
| Alpha | 缺檔／缺系統 | 角色導出只有一句 | 留待 Alpha 設計，見 `docs/alpha/design.md`。雇員欄規則已有。連線、檔案、權限仍無。 | playerexport.md, clerksystem.md |
| 已處理 | 缺檔／缺系統 | 存檔 | 已有 `savesystem.md`：`user://save.json` + `version`；關店與準備結束寫入。活線已實作。 | savesystem.md, storepreparationphase.md, storeoperationphase.md |
| 已處理 | 規則含糊 | 操作是否綁死鍵位 | 長線以 InputMap 為準（`control.md`）；預設仍 WASD／Xbox。活線 Autoload `Controls`。 | control.md |
| 已處理 | 缺檔／缺系統 | 暫停選單／掛起 | 已有 `pausemenu.md`；活線接 `PlatformServices` suspend／resume。 | pausemenu.md, storeoperationphase.md, savesystem.md |
| Alpha | 缺檔／缺系統 | HUD 以外的介面層空白 | 存檔／InputMap／暫停／字串表已補。暫停選單已有**事件 SFX 開／關與聲量**（見 `pausemenu.md`）。仍缺：BGM／整體設定頁、失敗／過關、教學、技能演出期間能否操作。 | storeoperationphase.md, playerskills.md, control.md, playersetup.md, pausemenu.md |
| Alpha | 用詞／錯字 | 用詞與錯字會改規則解讀 | 留待 Alpha 改回原檔，見 `docs/alpha/design.md`。以為→以下；三能種力值；奧義「技令」；衝刺句子斷掉。 | storeoperationphase.md, gameconcept.md, playerultimateskills.md, playermovement.md |

# 缺了整份檔的系統

經營回合與準備回合的主循環已有拆檔（含清潔、小偷、採購、店舖設計、店員）。下列主題被點名，但沒有對應設計，或檔案仍是一句。

- **循環與進度：** 劇情／事件表、過關與失敗、經營值、技能解鎖表。~~存檔~~ 見 `savesystem.md`。~~暫停／掛起~~ 見 `pausemenu.md`
- **店內系統：** 冰櫃與凍櫃的操作差異。幫忙取貨與 COMBO 留待 Alpha
- **幾乎是空檔：** 角色導出的連線與檔案留待 Alpha。Voxel 初模和給設計師加細節的規矩在 `docs/alpha/voxel-v0.1.md`。外觀配置只有一句
- **工程路徑：** Demo／Alpha 專案目錄已凍結；v1 只改 `godot/game`（`docs/versioning.md`）。平台商務／Godot 釘版見 `docs/alpha/console-business.md`、`docs/alpha/godot-middleware-pin.md`（非玩法規則）

# 已有檔但仍寫不進程式的數值

| 主題 | 已寫的 | 仍缺的 |
| --- | --- | --- |
| 能力值 | STR／AGI／INT 主表已定（各項 50 封頂）；打擊每下扣血已定；每級 +5 點；重置＝等級 × $1000 | |
| 移動 | AGI 基值 3 身位/秒、上限 5×；跑 −20 氣力/秒；衝刺 −50；污物 ×0.5；擁擠 3 身位 ×0.5；衝刺撞客人 +50／暈 2s／不重抽清單；門檻跟活線 | |
| 客人 | 清單上限 15、逗留 1s、思考 3s、不滿 0–100、排隊 15 秒滿；丟掉交齊→立刻收銀；衝刺撞後清單不變 | 生成間隔、在店上限、抽出件數、找不到貨長線數字、客人類別留待 Beta |
| 清潔 | 三類效果框架、清潔計 AGI 秒數、空手轉搖桿；清潔只顯示藍計（無黃 Circle） | 生成間隔／同時上限、垃圾氣力／秒、三類不滿／秒留待 Beta |
| 小偷 | 不付款、被偷另計、連按 STR 傷害、5 秒失敗；衝刺撞飛／丟掉砸中／狙擊手（小偷）都算抓住；不佔客人數、不受污物 | 出現間隔／同時上限／清單件數、霸王色基率留待 Beta |
| 資金 | 價格表、開發費、虧損定義、關店入帳、日薪 $100、起始資金 $2500 | |
| 店面 | 總面積三級、邊長最少 8、拖放、每種展示貨架 4／8／12／24 件、規模 LV2 要角色 LV4、規模 LV3 要角色 LV7 | 冰櫃與凍櫃的操作差異 |
| 級數 | LV2–LV10 經驗表、每級 +5、經驗只增不減（來源跟 ecosystem） | LV11–99。技能解鎖表留待 Beta |
| 店員 | 日薪、崗位、空貨架優先、計劃中每幀跟隨、閒置 0.35s 掃描、人數不大於收銀機、上限跟到規模 LV3（0／1／2） | 規模 LV4 的人數，等有第四級面積再定 |
| 指令 | 收銀件數→次數、錯則重來、先指令後 Circle；方向隨機可重複；多台最短→最近→隨機 | |

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
9. ~~衝刺撞飛客人的不滿數字~~ **已處理**（+50 基值；禮貌衝撞 +0；Screen KO 原地落地；清單不重抽）
10. 劇情／事件已標 Beta。~~技能解鎖表~~ **改標 Beta**（見 `docs/beta/design.md`）
