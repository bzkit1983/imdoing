# 存檔

- 此檔是長線存檔規則
- 工程活線：`godot/game`（見 `docs/versioning.md`）
- 實作：`game_state.gd` 的 `to_dict`／`from_dict`／`save_to_disk`／`load_from_disk`
- I/O 經 Autoload **`PlatformServices`**（Desktop：`scripts/platform/desktop_platform.gd` → `user://save.json`）
- **劇情選章（EA 要做／尚未實作）：** 2026-11-27 起，EA 進程需要存 `story_slot`、`active_theme_id`、`themes_cleared[]`、`theme_run_flags` 等（形狀見 `storysystem.md` §存檔欄位）。落地時再升 `SAVE_VERSION`（現行 9 不足涵蓋選章）並在本檔補 migration。序章內容閘欄位已在 `SAVE_VERSION` 7。完整十章其餘槽位與分店欄仍可後加；分店預設暫緩
- **分店／主題店（設計先行／未實作）：** `theme_stores`、`origin_store`、精英 `assignment`、每店獨立 `shop_rating`；**共用**頂層 `money`。形狀見 [`branchstore.md`](branchstore.md)
- **免費 Demo 存檔（2026-11-27 已決／尚未實作）：** Demo 進度**不轉入**付費 EA。Demo 組建須用**獨立的 `user://` 路徑或槽，或明確標記**，讓付費 EA 不會載入或覆寫該檔；Cloud 亦須分開。精確檔名在實作時補本節（現行 EA 本體仍為 `user://save.json`）。見 [`steam-productization.md`](../alpha/steam-productization.md)


# 路徑與格式

- 本機檔：`user://save.json`（**店主＋店舖**完整進度）
- JSON 物件。頂層必有整數欄 **`version`**（與產品 SemVer tag 分開；目前實作 `SAVE_VERSION = 9`：含精英店員 `elite_clerks` 等；見 `docs/versioning.md`／`game_state.gd`）
- `version` 過新：拒絕載入並提示更新遊戲。之後升版時在此檔補 migration 規則

`game_state.gd` 現行升版與 migration：

| `SAVE_VERSION` | 新增／語意 |
| --- | --- |
| 1 | 初版存檔形狀（當時含技能組等欄，不另升版） |
| 2 | `stock` 改為**件**；載入 v1 時各 SKU 箱數 ×4 |
| 3 | 評價／難度：`shop_rating`、`rating_history`、`difficulty`、`last_ops_rating`／`last_grade`、`difficulty_prompt_acked` |
| 4 | 任務：`day_index`、`active_tasks_by_seat`、測試任務選擇 |
| 5 | 待領商品培養 `cultivation` |
| 6 | 創世問答 `light_quiz_passed` |
| 7 | 內容閘：`unlocked_skus`、`unlocked_furniture`、`prologue_boss_unlocked`（舊檔由等級表＋已開發重建） |
| 8 | 魚缸／釣魚：`fish_stock`、`fishing_taro_played` |
| 9 | 精英店員 `elite_clerks` |

## 訪客角色槽（本機雙人 M1）

- 用途：本機 coop 的 P2 **只含角色進度**（無店舖／資金／倉庫／擺放）。規則見 `multiplayer.md` §11.2。
- 路徑：`user://guest_slots.json`（經 `PlatformServices` `read`／`write`／`has`／`delete_guest_slots`）。獨立檔，自有 `version` 欄（目前為 1），與店主存檔的 `SAVE_VERSION`（目前 9）分開，不因此升主存檔版號。
- 上限 **3** 槽。可從店主**複製**等級／能力／技能／`tint`／`skin_id`／`unlocked_skins`，或新建空白；外觀細節見 [`appearance.md`](appearance.md)。
- JSON：`{ "version": 1, "slots": [ dict|{}, … ] }`；角色 dict 含 `xp`／`level`／`unspent`／`base_*`／`*_stat`／`slots`／`ult_id`／`skill_sets`／`flags`／`tint`／`skin_id`／`unlocked_skins`／`display_name`；設計另加 **`support_rating`**（支援別店評價，見 `ratingsystem.md`）（**無** money／stock／layout／`shop_rating`）。
- 日結：店主檔寫資金＋平分後 XP＋Host 商店評價／評級歷史；選中槽寫入訪客 XP（平分公式見 multiplayer §11.7）與 `support_rating` 更新。清除主存檔時一併 `delete_guest_slots`。

## 線上訪客寫回（M2，見 `multiplayer.md` §12）

- **角色來源：** Join 端上傳本機 **`user://save.json` 主角色欄**（非訪客槽）；Host 持副本。無主存檔不可加入。
- **M2 日結（角色）：** Host 結算後以 RPC 下發各遠端 seat 的**平分 XP**與 Host 評級；client 寫入**本機主存檔角色欄**的 XP／等級相關欄與 **`support_rating`**（可與訪客槽同欄名語意，但路徑是主存檔）；claim2 第二席寫入 **`guest_slots`**。
- **斷線凍結座位：** 仍按**開日人數**平分；凍結 seat 仍收到 XP／`support_rating`（若該 peer 已離線則 Host 保留待重連寫回——首刀可不做重連，離線則該份進度暫存至房解散丟棄，**實作：離線 peer 的角色進度不寫回其磁碟**；仍在線的凍結不適用——凍結＝角色已移除但 peer 可仍在房內等日結。若 peer 已斷，則無法寫其本機檔，該 seat 的平分份作廢僅影響該玩家——**拍板補充：** 斷線 peer 的平分 XP／support **不寫回**（無人收）；分母仍含該 seat，避免留下來的人變相多拿。  
  （與「凍結座位仍分到」並存時：僅 **peer 仍連線至日結** 才寫回該 seat；已斷線 peer 跳過寫回。）
- **M2.1／結算刀（已交）：** 日結 RPC 另帶 Host 當日 **`revenue`（營業額）**。每位仍連線遠端 peer 對**本機主存檔**執行一次 `money += revenue`（與 Host 同額、非平分）。**不**改 client 的 `shop_rating`／`day_procurement`／`last_loss`／評級歷史。訪客槽與本機 M1 P2 **無**店舖資金欄，不寫。時機：與角色日結同一 RPC、同一 `save_to_disk`。

# 寫入時機

1. **準備回合結束**：玩家通過開店檢查、扣當日工資、即將進入營運回合時寫一次  
2. **關店結算後**：營業日 `settle`（含提早關店、營業結束／跳過營運）完成後寫一次  
3. **改自訂技能組合當下**：改五格、卸下、換奧義、改選中組、改名，立刻把整份存檔寫進磁碟。買貨、改店、分配能力本身仍不觸發寫檔；若先做了那些改動再改技能組合，這次整份寫入會一併帶上記憶體裡的進度。

不在營運中途自動存（營運中當機則回到「準備結束當下」的狀態）。補貨、開店、暫停不能改技能組合。

# 讀取時機

- 啟動進入準備選單時嘗試讀取  
- 成功：略過劇本選擇，直接進準備 home，並顯示摘要（劇本／等級／資金）  
- 失敗或無檔：進入劇本選擇  

# 清除

- 準備選單提供「清除存檔並重選劇本」：刪除 `user://save.json`，回到劇本選擇  
- 選新劇本會覆寫記憶體中的進度；下次寫入時機才蓋掉磁碟檔  

# 存進什麼

進度狀態（準備回合可改、關店後保留），至少包括：

- 劇本、資金、經驗、等級、未分配點數  
- STR／AGI／INT 與劇本基底  
- 已開發貨、**可售旗標**（`for_sale`；缺省＝可售；至少一項可售）、倉庫**件數**、已購傢俬、店舖擺放、店規模與格線（活線＝單店頂層欄；設計多店時上述店舖欄進 `theme_stores`／`origin_store`，見 [`branchstore.md`](branchstore.md)）  
- 店員崗位、技能裝備格、奧義。另有五組 `skill_sets` 和選中編號 `skill_set_index`（此欄自 `SAVE_VERSION` 1 起即寫入，當時不升版）。`slots`／`ult_id` 是目前選中那一組的副本。每組可另存 `levels`（Dark Side、多重影分身準備頁選等；沒選預設 LV3）。見 `customizedskillset.md`、`darkside.md`、`shadowclone.md`  
- **內容閘（`SAVE_VERSION` ≥7）：** `unlocked_skus`、`unlocked_furniture`、`prologue_boss_unlocked`（序章／劇本 8；見 [`story/prologue.md`](story/prologue.md)）
- **商品培養（`SAVE_VERSION` ≥5）：** `cultivation`（待領批次）
- **創世問答（`SAVE_VERSION` ≥6）：** `light_quiz_passed`
- **魚缸／釣魚（`SAVE_VERSION` ≥8）：** `fish_stock`、`fishing_taro_played`（見 [`fishingtaro.md`](fishingtaro.md)）
- **精英店員（`SAVE_VERSION` ≥9）：** `elite_clerks` 陣列；每項 `id`／`level`／`on_duty`／`roles`／`register`／`source`。另占欄、不扣日薪；見 [`eliteclerk.md`](eliteclerk.md)。**設計擴欄：** `assignment{theme_id, post}` 與本店 `on_duty` 互斥（分店派駐）  
- 外觀：`tint`、`skin_id`、`unlocked_skins`（空＝全開）。見 [`appearance.md`](appearance.md)  
- 當日進貨支出累計、上一局是否虧損、升級備註  
- **評價／難度（`SAVE_VERSION` ≥3）：** `shop_rating`（商店評價，下限 0）、`rating_history`（最近最多 30 筆日結評級）、`difficulty`（easy／normal／hard，見 `difficulty.md`）、`last_ops_rating`／`last_grade`、`difficulty_prompt_acked`。規則見 `ratingsystem.md`。**設計多店：** 每間主題店自有評價欄；頂層／本店 hydrate 後的 `shop_rating`＝當前本店  
- **分店（設計／未實作）：** `theme_stores`、`origin_store`、`policy`／`branch_posts`；細節 [`branchstore.md`](branchstore.md)  


訪客槽另可含 **`support_rating`**（支援別店評價；見 `ratingsystem.md`／`multiplayer.md`）。

不存：當日營運中的客人、污物、時鐘進度、玩家手上貨、地上散落貨、分身（營運中狀態）、**當日進行中的營運點**（局內狀態；關店後以歷史／last_* 保留結果）。關店時貨架／地上／手上／店員持貨／分身持貨／Dark Side 臨時補貨持貨／已完成清單未付款購物車的未售件數會先**原數**退回倉庫再寫檔（見 `storeoperationphase.md`）。`SAVE_VERSION` ≥2 起 `stock` 語意為件；載入 v1 存檔時各 SKU 箱數 ×4。

# 平台

- 玩法只呼叫 `PlatformServices`（`write_save`／`read_save`／`has_save`／`delete_save`／`checkpoint`）  
- Desktop stub：`user://save.json`；Web／mobile UI profile 為 `touch`，桌面為 `gamepad`（隱藏 TouchPad）。VJ 另受 `InputMode`＋`[ui] virtual_stick`（預設關）約束，見 `inputmodes-vj.md`
- 掛起前 `checkpoint` 與暫停選單銜接見 `pausemenu.md`  
- 日後 Steam Cloud／Switch／Xbox 換 backend，不另開玩法存檔格式（商務／釘版見 `docs/alpha/console-business.md`、`docs/alpha/godot-middleware-pin.md`）
