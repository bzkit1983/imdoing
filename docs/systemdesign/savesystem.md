# 存檔

- 此檔是長線存檔規則
- 工程活線：`godot/game`（見 `docs/versioning.md`）
- 實作：`game_state.gd` 的 `to_dict`／`from_dict`／`save_to_disk`／`load_from_disk`
- I/O 經 Autoload **`PlatformServices`**（Desktop：`scripts/platform/desktop_platform.gd` → `user://save.json`）

# 路徑與格式

- 本機檔：`user://save.json`
- JSON 物件。頂層必有整數欄 **`version`**（與產品 SemVer tag 分開；目前實作 `SAVE_VERSION = 1`）
- `version` 過新：拒絕載入並提示更新遊戲。之後升版時在此檔補 migration 規則

# 寫入時機

1. **準備回合結束**：玩家通過開店檢查、扣當日工資、即將進入營運回合時寫一次  
2. **關店結算後**：營業日 `settle`（含提早關店、測試結算）完成後寫一次  

不在營運中途自動存（營運中當機則回到「準備結束當下」的狀態）。

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
- 已開發貨、倉庫箱數、已購傢俬、店舖擺放、店規模與格線  
- 店員崗位、技能裝備格、奧義（活線各一組。五組自訂組合尚未進存檔，見 `customizedskillset.md`）  
- 當日進貨支出累計、上一局是否虧損、升級備註  

不存：當日營運中的客人、污物、時鐘進度、玩家手上貨箱、地上散落貨（營運中狀態）。關店時貨架／地上／手上／店員持箱／已完成清單未付款購物車的未售件數會先換算退回倉庫箱數再寫檔（見 `storeoperationphase.md`）。

# 平台

- 玩法只呼叫 `PlatformServices`（`write_save`／`read_save`／`has_save`／`delete_save`／`checkpoint`）  
- Desktop stub：`user://save.json`；Web／mobile UI profile 為 `touch`，桌面為 `gamepad`（隱藏 TouchPad）  
- 掛起前 `checkpoint` 與暫停選單銜接見 `pausemenu.md`  
- 日後 Steam Cloud／Switch／Xbox 換 backend，不另開玩法存檔格式（商務／釘版見 `docs/alpha/console-business.md`、`docs/alpha/godot-middleware-pin.md`）
