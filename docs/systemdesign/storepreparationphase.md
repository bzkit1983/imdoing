#營運準備設定
- 此檔案包含營運準備設定
- 工程活線：`godot/game`。版控見 `docs/versioning.md`。存檔見 `docs/systemdesign/savesystem.md`


- 營運準備選單
開店前, 關店後進入營運準備選單。操作沿用 `docs/systemdesign/control.md` 的選單鍵（InputMap：`move_*`／`interact`／`cancel`；店舖設計轉向用 `rotate`）。實作：殼層 `godot/game/scenes/prep_menu.tscn`，分頁填充分散在 `godot/game/scripts/prep/`（協調者仍為 `prep_menu.gd`）。可見文案走 `Loc`（`prep.*`；見 `docs/alpha/i18n.md`）。畫面分頁：

1. 角色配置
- 能力值分配
- 裝備技能
- 角色外觀
2. 採購
- 開發新貨
- 採購貨品
3. 店舖配置
- 購入商店物品
- 擴張
- 店舖設計
4. 店員管理
- 召募
- 店員配置
5. 開始營業
6. **測試用**（僅測試版）：增加資金 $1000 — 受 `ProductVersion.TEST_TOOLS` 開關控制；正式版關閉或移除

按開始營業前先檢查店舖設計裡已經放好的物品。沒有通過就不能進入營運回合：
- 至少一台收銀機
- 至少一組同類型的補貨架和貨架（乾貨配乾貨、凍櫃配凍櫃，或冰櫃配冰櫃）
只購入、還沒放到店舖設計圖上，不算已設置。

按開始營業：通過檢查後扣當日工資，**寫入存檔**，再進入營運回合。營運完結並確定後返回營運準備頁。

#存檔與劇本

- 啟動時若有合法 `user://save.json`：略過劇本選擇，直接進準備 home  
- 無存檔：先選劇本（空店／中期／後期等試玩起點）  
- 準備 home 可「清除存檔並重選劇本」