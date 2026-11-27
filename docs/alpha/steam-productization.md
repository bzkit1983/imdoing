# Steam 產品化衝刺（H1–H3）

- 對照日：2026-11-27（H3／付費 EA／免費 Demo 範圍已更新；H1 App ID 仍開）
- 活線：`godot/game`
- tech-review：[`tech-review-v0.3.md`](tech-review-v0.3.md)（H1 仍開）；細節拍板見 [`tech-review-v0.2.md`](tech-review-v0.2.md) §7 H1–H3
- GodotSteam 接入：[`godotsteam-setup.md`](godotsteam-setup.md)
- EA 範圍：[`docs/versioning.md`](../versioning.md)「Early Access／現行產品範圍」

## 狀態總覽

| 項 | 狀態 | 說明 |
| --- | --- | --- |
| **H3** EA 範圍聲明 | **已更新（2026-11-27）** | 付費 Steam EA：序章 → 第1章 → 第2章（破局）→ 自選一章（只有安桃山）。免費 Demo＝序章 + 第1章。見 `versioning.md` |
| **免費 Demo 組建** | **Open** | 第1章結束內容閘、教學（劇本 5）、獨立 App ID／匯出、分離存檔、結束畫面導流；暫不含多人 |
| **H1** Cloud／成就 API | **接線已落地** | `steam_platform.gd`：本機寫入後 `fileWrite`；冷啟可 `fileRead`；`setAchievement`＋`storeStats` |
| **H1** 正式 App ID | **Open** | 現仍測試 **480**；需 Steam Direct 正式 ID 後改下列檔 |
| **H2** 完整設定頁 | **Done** | 暫停「設定」子選單＋準備「系統工具→設定」；寫入既有 `user://settings.cfg` |
| **H2** 第一日引導打磨 | **Done** | 新檔劇本頁先問開始／跳過教學；模態可跳過整條；進度寫存檔；暫停可重溫 |

## H1 — 正式 App ID 切換清單（取得 ID 後）

1. 改 [`godot/game/steam_appid.txt`](../../godot/game/steam_appid.txt)
2. 改 `project.godot` 的 `steam/initialization/app_data/app_id`
3. 確認 Partner 已開 **Steam Cloud**（配額／路徑與 `save.json`／`guest_slots.json` 一致）
4. 在 Partner 登記成就 API 名稱，與 `PlatformServices.unlock_achievement(id)` 呼叫一致
5. 重跑 [`tools/m3_steam_smoke.sh`](../../tools/m3_steam_smoke.sh)＋手動 Cloud／成就煙測
6. **勿**把成就／Cloud 邏輯寫死只認 480

## H1 — Cloud／成就行為（現行）

- 權威仍是本機 `user://`；Cloud 為同步／還原層
- `write_save`／`write_guest_slots`／`checkpoint` → 成功寫盤後嘗試 Cloud `fileWrite`
- 本機無檔時 `read_*`／`has_*` 可從 Cloud 拉回
- `unlock_achievement` → `setAchievement`＋`storeStats`；Steam 未開或 id 未登記則 log，不崩

## H2 — 完整設定頁（驗收）

收束現有碎片為單一「設定」入口（暫停或準備皆可進）：

- [x] BGM 開／關與音量
- [x] 事件 SFX 開／關與音量
- [x] 語言（四語）
- [x] 鏡頭視野
- [x] 虛擬搖桿（觸控 profile）
- [x] 寫入既有 `user://settings.cfg`（不另開設定存檔格式）

實作：暫停主列 →「設定」子頁；準備「系統工具」→「設定」頁（`prep_pages._settings`）。

## H2 — 第一日引導打磨（驗收）

- [x] 非「測試工具→劇本 5」的**預設新檔**也會進入最小教學鏈（或明確一次詢問）— 劇本頁「開始教學／跳過教學」
- [x] 可跳過；進度寫入存檔（`tutorial_skipped`＋各課 `done`；模態「跳過教學」）
- [x] 暫停可重看已完成課（既有）

產品教學仍走 scenario 5 經濟（$3000／簡易／空白技能組）；測試工具清單可另列劇本 5。

## H3 — EA 範圍（2026-11-27 更新）

見 [`docs/versioning.md`](../versioning.md) 與 [`docs/alpha/design.md`](design.md)。

2026-11-18 原拍板（純日循環、敘事留 Beta）已被 **2026-11-27 Jackson 決議**取代。

**付費 Steam Early Access（先上市）：** 日循環、技能、評價、教學框架、中期美術、多人至 M3；劇情進程＝序章 → 第1章 → 第2章（破局）→ 自選一章（只有安桃山可選）。正式 App ID 仍 Open（現為測試 480，見上方 H1）。

**免費 Demo（EA 的子集）：** 只含**序章 + 第1章**，並含**教學（劇本 5）**。第1章通關後必須停下，不進破局／選章／安桃山。需獨立 Steam Demo App／組建設定（正式 Demo App ID 尚未取得；勿把 Demo 綁死在 480 或尚未核發的 EA App ID）。**暫不含多人**（見下方）。

### 免費 Demo 已拍板細則（2026-11-27，Jackson）

- **存檔不轉入付費 EA。** Demo 組建須使用**獨立存檔路徑／槽，或明確的版本標記**，讓付費 EA 不會讀到、也不會覆寫 Demo 檔。精確檔名在實作時寫進 [`savesystem.md`](../systemdesign/savesystem.md)（例如另開 `user://` 路徑），此處不預先鎖定檔名。Cloud 亦須分開，勿把 Demo 進度寫進 EA Cloud。
- **結束畫面：** 原話為「引導玩家加入願望清單或直接購買」。**文件詮釋（假設，尚未另確認）：** 付費 EA **尚未開賣**時，結束畫面以**願望單**為主；EA **已可購買**後，提供**直接購買**，願望單改為次要。實作須能依商店狀態切換，文案 TBD。
- **教學：** Demo **包含**現有教學鏈（劇本 5）。與劇情序章如何銜接，仍見 `storysystem.md` 開放問題 1。
- **多人：** Demo **暫時不做多人**。方向（待設計、尚未拍板）：可能另開**固定地圖／場景、開局即可用中期技能**的專用多人體驗，與現行本機／LAN／Steam 日循環多人分開。見 [`multiplayer.md`](../systemdesign/multiplayer.md)。

### Steam Next Fest（調研摘要，2026-11-27）

官方說明：Next Fest 是一年三屆（二月／六月／十月）、以**尚未發行**遊戲的可玩 Demo 為核心的一週活動。以下依 Steamworks 文件整理，細則以官方頁為準。

**資格（須同時符合）：** Steamworks 帳號狀態良好；**本體（base game）商店頁已公開**；活動開始前有**公開可玩 Demo**；**在該屆結束前不得發行**（含不得先進入 Early Access）；不是已在 Steam 上架作品的序章／預覽／短篇版；同一作品**只能參加一屆**。

**關鍵：已經以 Early Access 發行的遊戲不能再參加。** 官方 FAQ：「Are Early Access or free games eligible…? Yes, however, only unreleased titles are eligible… If you plan on entering Early Access or launching your game for free, that's fine, but the game must not yet be released to remain eligible for Next Fest。」若在活動前或活動期間發行，會立刻失去資格。來源：[Steam Next Fest](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest)。

**如何報名：** 在 **本體 App**（不是 Demo App）的 Steamworks App Landing Page 報名並完成清單、存檔，見到綠色勾。也可走該屆報名／申訴頁。二月屆：<https://partner.steamgames.com/optin/sale/nextfest_feb_2027>；六月屆：<https://partner.steamgames.com/optin/sale/nextfest_june_2027>。說明同上頁「How Do I Register?」。

**已公布的 2027 年檔期**（官方時刻；括號為歐洲／倫敦）：

| 屆次 | 活動期間 | 報名截止 | 其他節點 |
| --- | --- | --- | --- |
| [February 2027](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest/feb_2027) | 2027-02-22 10:00 PST（倫敦 18:00 GMT）→ 2027-03-01 10:00 PST（倫敦 18:00 GMT） | **2027-01-10 23:59 PST**（倫敦 2027-01-11 07:59 GMT） | 新聞預覽用 Demo／商店頁建議 01-18 前提審；全部必備項 02-01 前提審；新聞預覽 02-11 10:00 PST（倫敦 18:00 GMT）開始 |
| [June 2027](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest/june_2027) | 2027-06-14 10:00 PDT（倫敦 18:00 BST）→ 2027-06-21 10:00 PDT（倫敦 18:00 BST） | **2027-04-25 23:59 PDT**（倫敦 2027-04-26 07:59 BST） | 新聞預覽用提審建議 05-10；全部必備項 05-24 前提審；新聞預覽 06-03 10:00 PDT（倫敦 18:00 BST）開始 |

十月屆慣例會有，六月屆文件寫「下一屆預定 2027 年 10 月」，但 [Upcoming Steam Events](https://partner.steamgames.com/doc/marketing/upcoming_events) 目前只列出二、六月，**十月日期與報名截止尚未公布**。

**對本專案檔期的含義：** 產品已決「先以付費 EA 上市」。官方規則是：要參加某一屆 Next Fest，本體必須在該屆**結束前都尚未發行**（含尚未進 EA），結束後才可上 EA。一旦已經以 EA 上架，就不能再參加。是否為參加 Next Fest 而把付費 EA 發售日排在某一屆結束之後，**尚未另作檔期決議**。

**範圍外（兩者都不做）：** 其餘五主題、終章／後日談、完整事件表、技能解鎖表、長線流量定稿、分店（預設暫緩）。
