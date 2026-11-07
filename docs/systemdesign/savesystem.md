# 存檔

- 此檔是長線存檔規則
- 工程活線：`godot/game`（見 `docs/versioning.md`）
- 實作：`game_state.gd` 的 `to_dict`／`from_dict`／`save_to_disk`／`load_from_disk`
- I/O 經 Autoload **`PlatformServices`**（Desktop：`scripts/platform/desktop_platform.gd` → `user://save.json`）

# 路徑與格式

- 本機檔：`user://save.json`（**店主＋店舖**完整進度）
- JSON 物件。頂層必有整數欄 **`version`**（與產品 SemVer tag 分開；目前實作 `SAVE_VERSION = 2`）
- `version` 過新：拒絕載入並提示更新遊戲。之後升版時在此檔補 migration 規則

## 訪客角色槽（本機雙人 M1）

- 用途：本機 coop 的 P2 **只含角色進度**（無店舖／資金／倉庫／擺放）。規則見 `multiplayer.md` §11.2。
- 路徑：`user://guest_slots.json`（經 `PlatformServices` `read`／`write`／`has`／`delete_guest_slots`；與店主 `SAVE_VERSION=2` 分開，不升主存檔版號）。
- 上限 **3** 槽。可從店主**複製**等級／能力／技能／`tint`／`skin_id`／`unlocked_skins`，或新建空白；外觀細節見 [`appearance.md`](appearance.md)。
- JSON：`{ "version": 1, "slots": [ dict|{}, … ] }`；角色 dict 含 `xp`／`level`／`unspent`／`base_*`／`*_stat`／`slots`／`ult_id`／`skill_sets`／`flags`／`tint`／`skin_id`／`unlocked_skins`／`display_name`（**無** money／stock／layout）。
- 日結：店主檔寫資金＋平分後 XP；選中槽寫入訪客 XP（平分公式見 multiplayer §11.7）。清除主存檔時一併 `delete_guest_slots`。

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
- 已開發貨、倉庫**件數**、已購傢俬、店舖擺放、店規模與格線  
- 店員崗位、技能裝備格、奧義。另有五組 `skill_sets` 和選中編號 `skill_set_index`（`SAVE_VERSION` 仍是 1）。`slots`／`ult_id` 是目前選中那一組的副本。每組可另存 `levels`（Dark Side、多重影分身準備頁選等；沒選預設 LV3）。見 `customizedskillset.md`、`darkside.md`、`shadowclone.md`  
- 外觀：`tint`、`skin_id`、`unlocked_skins`（空＝全開）。見 [`appearance.md`](appearance.md)  
- 當日進貨支出累計、上一局是否虧損、升級備註  

不存：當日營運中的客人、污物、時鐘進度、玩家手上貨、地上散落貨、分身（營運中狀態）。關店時貨架／地上／手上／店員持貨／分身持貨／Dark Side 臨時補貨持貨／已完成清單未付款購物車的未售件數會先**原數**退回倉庫再寫檔（見 `storeoperationphase.md`）。`SAVE_VERSION` ≥2 起 `stock` 語意為件；載入 v1 存檔時各 SKU 箱數 ×4。

# 平台

- 玩法只呼叫 `PlatformServices`（`write_save`／`read_save`／`has_save`／`delete_save`／`checkpoint`）  
- Desktop stub：`user://save.json`；Web／mobile UI profile 為 `touch`，桌面為 `gamepad`（隱藏 TouchPad）。VJ 另受 `InputMode`＋`[ui] virtual_stick`（預設關）約束，見 `inputmodes-vj.md`
- 掛起前 `checkpoint` 與暫停選單銜接見 `pausemenu.md`  
- 日後 Steam Cloud／Switch／Xbox 換 backend，不另開玩法存檔格式（商務／釘版見 `docs/alpha/console-business.md`、`docs/alpha/godot-middleware-pin.md`）
