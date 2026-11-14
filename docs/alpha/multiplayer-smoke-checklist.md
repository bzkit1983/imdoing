# 多人煙霧清單（tech-review v0.2 · G2）

- **目的：** 最短路徑確認「Host＋Client 意圖 → 開日 → 日結」沒斷。  
- **性質：** **手動**回歸（可先不做無頭自動化）。規格細節仍以 [`docs/systemdesign/multiplayer.md`](../systemdesign/multiplayer.md) 為準。  
- **靜態錨點：** `python3 tools/test_multiplayer_smoke_contract.py`（CI 會跑；不替代本清單）。

## 前置

- 桌面活線 `godot/game`（Godot 4.7）；兩機或同機兩程序皆可。  
- **優先 transport：** `lan_enet`（LAN）。Steam（`transport=steam`）見 §13；通過可額外勾。  
- Host 有可用存檔；Join 端亦須有主存檔（無檔 join 應被拒——若測到請記在備註）。

## 煙霧步驟（最少一條）

| # | 步驟 | 通過標準 | ☑ |
| --- | --- | --- | --- |
| 1 | Host 開房（LAN）；Client 輸入位址 join（claim 1 即可） | 兩邊進同一 Session；名額顯示合理 | ☐ |
| 2 | 各 seat ready；**僅 Host** `start_run`／開日 | Client 收到世界／可操作本座角色；開日後無法再 join | ☐ |
| 3 | Client（或 Host 遠端座）移動／互動，送出 **intent** | Host 模擬驅動；對端見 puppet／世界一致（至少移動可見） | ☐ |
| 4 | 打完或提早關店 → **日結** | 兩邊進結算；XP／評價分母含開日人數；無卡死／無單邊黑屏 | ☐ |
| 5 | （可選）開日後斷一 peer | 該座角色移除且座位凍結至日結；留下的人仍可日結 | ☐ |

## 回歸閘（勿破壞）

- [ ] `transport=local` 本機單人／二人仍可開日打完（M1 不回歸）  
- [ ] （若有時間）`./tools/m3_steam_smoke.sh` — Steam class／閘門煙霧（需本機 Godot＋GodotSteam）

## 記錄

| 日期 | 執行人 | transport | 結果 | 備註 |
| --- | --- | --- | --- | --- |
| | | lan_enet / steam / local | pass／fail | |

## 之後可升級

- 無頭雙 peer 腳本（環境允許時）  
- 滿座壓力／snapshot 頻率另列 J／效能項，**不**塞進本 G2 最少集  
