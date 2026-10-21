# Alpha v0.1 技術設計審查

- **範圍：** 審查時以 `godot/alpha_v0_1` 為準；**之後實作只改** `godot/game`（見 `docs/versioning.md`）
- **對照：** `docs/alpha/`、`docs/systemdesign/`（含 `savesystem.md`）、`docs/systemdesign-gaps.md`
- **目標平台：** Steam · Nintendo Switch · Xbox（及現行 Web 試玩）
- **產出／更新：** 2026-10-20；2026-10-21 對齊已落地項（凍結活線、存檔、InputMap）
- **狀態：** 審查結論供團隊跟進；非玩法規格。玩法仍以 `docs/systemdesign/` 與各版 design／plan 為準。

## 總評

玩法閉環與 Voxel 美術管線已經能支撐「繼續做內容」；但三個千行級腳本（`player` / `prep_menu` / `demo`）加上整專案複製的版次策略，會讓功能越多越難改。

- **Steam：** 可行；缺的是存檔、InputMap、桌面匯出與平台服務，而非換引擎。
- **Switch／Xbox：** 玩法與 2D Voxel 架構適合主機，但 Godot **沒有公開主機匯出**，必須走平台開發者資格 + 中介埠（如 W4 Consoles）或外包埠接商，並以 **Switch 1 當效能與記憶體下限**。
- **最大槓桿：** 單一主線工程 + 平台服務抽象，不要為每台主機複製一份 Godot 專案。

| 指標 | 數值 |
| --- | --- |
| GDScript 約略行數 | ~7.7k |
| ≥1000 行腳本 | 3（`player` · `prep_menu` · `demo`） |
| 存檔 / Autoload 平台層 / 自動化測試 | 0 |
| 現有匯出預設 | Web only |

---

## 1. 現況架構

幾乎無 `.tscn` 組合：世界、傢俬、UI 多半在腳本裡 `new()`。實體透過 game host 的字串 `call()` / `has_method()` 互相協調。

```text
demo.gd（場面主控 · ~1000 行）
  階段：prep → restock → open → closed
  職責：生成客人／污物／小偷 · 尋路轉發 · 結算

  ├─ 狀態：game_state · tuning · skills
  ├─ 實體：player · customer · clerk · shelf · dirt
  └─ 表現：voxel_sprite · hud · prep_menu · touch_pad
```

**值得保留**

- `tuning.gd` 集中數值
- Voxel 檔名插座（`art/catalog.json` + 烘焙腳本）
- 設計檔驅動（`docs/systemdesign/`）

**主要風險**

- God Object／胖腳本
- 整包複製版次（`demo_v0_*` + `alpha_v0_1`）
- 無存檔／無平台抽象層

---

## 2. 能否持續開發？

短期（再疊內容）可以；中期若不拆主循環與版次策略，改動成本會指數上升。多平台目標會放大「單一主線 + 平台介面」的必要性。

### 已具備、值得保留

| 面向 | 現況 | 為何有助延續 |
| --- | --- | --- |
| 數值集中 | `tuning.gd` ~300 行常數 | 平衡調參不必到處搜字面量 |
| 進度狀態分離 | `game_state.gd` 管錢／等級／擺放 | 經營與準備可分開演進；也是存檔序列化的自然邊界 |
| 美術插座 | `art/catalog.json` + `tools/voxel_sprites.py` | 換 PNG／.vox 不必動玩法；主機與 PC 可共用精靈 |
| 設計先行 | `docs/systemdesign` 27 檔 + gaps | 規則拍板有據 |
| 實體模組 | `customer` / `clerk` / `shelf` / `pathfinder` | 有邊界的子系統可單獨改 |

### 會卡住連續開發的結構問題

| 嚴重度 | 問題 | 證據 | 建議方向 |
| --- | --- | --- | --- |
| 高 | 三個胖腳本承載主循環 | `player` 1521 · `prep_menu` 1549 · `demo` 1000 | 先抽營業日循環／輸入／互動；prep 改分頁場景 |
| 高 | 版次 = 整專案複製 | `demo_v0_1`…`v0_6` + `alpha_v0_1` | 單一主線 + 功能旗標；舊 demo 凍結為 tag |
| 高 | 無持久化／無平台 I/O | 計畫有 `user://save.json`，程式無 serialize | `game_state` `to_dict`／`from_dict`；經 PlatformServices |
| 高 | 輸入綁死鍵位 | 直讀 `KEY_W`／joy axis；無 InputMap | 全改 action；主機認證要求手把可完整遊玩 |
| 中 | duck-typing 協調 | 大量 `_game.call("…")` | GameSession 介面或事件匯流排 |
| 中 | UI 全程式碼組裝 + 觸控優先 | `prep_menu`／`hud`／`touch_pad` | `.tscn` + 手把焦點導航；觸控變可選皮層 |
| 中 | 文件與實作漂移 | `plan.md` 與 alpha 現況不一致 | 以 alpha 回寫 scope；數值進 tuning |
| 低 | 無自動化測試 | repo 無 test | 先測 `game_state`、結算、`pathfinder` |

### 可持續開發最低門檻（多平台版）

1. 停掉整包複製，只維護 alpha 主線  
2. 存檔 JSON + `version` 欄  
3. InputMap  
4. 拆 `prep_menu` 分頁  
5. **PlatformServices** 介面（存檔／成就／暫停／UI profile）

前四項服務所有平台；第五項是 Steam／Switch／Xbox 共用的分水嶺。

---

## 3. 效能：現況與改善

目前規模（在店上限約十餘人、污物個位數）對桌面與手機網頁偏輕。瓶頸不在繪圖，而在「每幀字串／UI 刷新」與「線性掃描」。多平台後以 **Switch 1** 為效能與記憶體地板。

### 為何現況還夠用

- 2D + GL Compatibility，主機友善  
- `AStarGrid2D` 與實體硬頂限制最壞情況  
- Voxel 已烘成精靈，非即時 3D voxel  
- `art/sprites` 體積小（約 0.5MB 級）

### 主機特別要盯

- 客人每 physics 幀 `_refresh_labels()`；player 每幀 `stats_changed` → HUD 全刷  
- `NotoSansTC-Regular.otf` ~5.5MB：應子集化或拆常用字  
- Switch 掌機／底座雙解析度  
- 掛起／恢復不得丟檔或卡死  

### 建議改動

| 優先 | 改動 | 預期收益 | 成本 |
| --- | --- | --- | --- |
| P0 | 標籤／HUD 改髒刷新 | PC／手機／Switch 更穩 | 低 |
| P0 | 貨架以 SKU 建索引 | 尋貨 O(1) | 低 |
| P0 | CJK 字型子集／壓縮 | 降 Switch 記憶體與載入 | 低–中 |
| P1 | 尋路節流＋物件池 | 多客同場幀時間更平 | 中 |
| P1 | 解析度／UI 縮放設定檔 | 掌機可讀、底座／TV 不空 | 中 |
| P2 | PC Forward+；主機／Web 留 Compatibility | 按平台選渲染器 | 低 |
| P2 | 動畫改 AnimatedSprite2D 圖集 | 比每向單張 load 更省 | 中 |

**註：** 店舖放置 `CELL=64` 與尋路 `CELL=20` 兩套語意並存；擴店前應文件化同一世界單位換算。

---

## 4. 平台評估：Steam · Switch · Xbox

### 發行路徑差異（比玩法架構更關鍵）

| 面向 | Steam | Nintendo Switch | Xbox |
| --- | --- | --- | --- |
| 誰能匯出 | 自行匯出 Windows／Linux | 需任天堂開發者資格 + SDK；Godot 無公開匯出 | 需 ID@Xbox／GDK；Godot 無公開匯出 |
| 常見技術路徑 | 官方匯出 + GodotSteam 等 | W4 Consoles 中介埠，或埠接商整包代工 | 同上（W4 以 Series 為主；舊代 Xbox One 多走埠接商） |
| 硬體地板 | Deck 約掌機級 | **Switch 1 是全平台最緊** | Series S/X 寬裕；若含 Xbox One 則接近 Switch 壓力 |
| 輸入預設 | 鍵鼠 + 手把 + Deck | Joy-Con／Pro；無鍵鼠假設 | 手把 + 十呎 UI（電視） |
| 存檔／雲 | `user://` + 可選 Steam Cloud | 平台存檔 API／帳號槽 | Xbox 連線存檔等 |
| 認證重點 | Deck Verified（較鬆） | Lotcheck：掛起、手把斷線、電子手冊等 | TCR／XR：掛起、登入、成就、存檔失敗 |
| 引擎版本 | 跟 Godot 穩定版即可 | 中介埠支援的小版本需對齊（公開資訊多在 4.3–4.6；專案標 4.7 要預留釘版／等待） | 同左 |

> **對本專案的直接含義：** 繼續用 Godot 上三平台是業界可行路徑，但不要假設「像匯 Web 一樣按一下」。商務上要排：開發者帳號、devkit、中介年費或埠接報價、分級（ESRB／CERO 等）。技術上要在玩法穩定前就避免「只在 Web／觸控成立」的假設。

### 與 Alpha 程式碼的落差

| 主題 | Alpha 現況 | Steam | Switch／Xbox 額外要求 |
| --- | --- | --- | --- |
| 匯出 | 僅 Web | 補桌面 | 私有 console export template；CI 需隔離 NDA 產物 |
| 輸入 | 硬編碼鍵 + 虛擬搖桿 | InputMap + Steam Input | 手把焦點導航；斷線重連；禁用「必須觸控」 |
| UI | 手機橫向密度＋觸控鍵 | 桌面／Deck 可調 | TV 安全區與字級；Switch 掌機可讀性；焦點框可見 |
| 存檔 | 無 | 本機 + 可選 Cloud | 經平台 API；處理儲存滿／失敗／多使用者 |
| 成就等 | 無 | Steamworks | Xbox Achievements；Switch 無對等成就系統（另議） |
| 生命週期 | 無暫停／掛起處理 | 暫停選單 | 強制處理 suspend／resume，不得損檔 |
| 字型 | 完整 NotoSansTC ~5.5MB | 可接受 | 子集化；注意授權與記憶體 |
| 網路 | 單機 | 單機可上架 | 單機較易過認證 |

### 建議的平台抽象

在 Autoload（例如 `PlatformServices`）後面接：Desktop／Steam／Switch／Xbox。玩法只呼叫介面。

**介面最小集合**

- `save` / `load` / `delete`
- 掛起前安全 checkpoint
- `achievement_unlock`（主機可 no-op）
- `get_ui_profile`（`touch`／`gamepad`／`tv`）

**Alpha 立刻可做的 stub**

- Desktop：寫 `user://save.json`
- UI profile：隱藏 TouchPad、開焦點
- pause 選單接通知
- 成就先打 log，之後接各 SDK

### 建議維持／提早擋掉

**維持**

- 繼續 2D 俯瞰 + Voxel 烘精靈，不要為平台轉即時 3D  
- SKU／傢俬／技能用資料表擴充  
- 手機網頁當行銷試玩；販售走桌面與主機 build  

**提早擋掉**

- 不要讓觸控或鍵鼠成為唯一可通關路徑  
- 不要複製專案當「Switch 版／Xbox 版」  
- 存檔格式加 `version`；掛起前要能快速 flush  
- Godot 小版本與中介埠支援表對齊再衝主機里程碑  

---

## 5. 建議路線（含主機）

| 階段 | 目標 | 具體工作 |
| --- | --- | --- |
| A · 穩定主線 | 可連續開發 | 凍結舊 demo；單一 alpha 主線；對齊 tuning／文件 |
| B · 產品骨架 | 三平台共用前提 | 存檔 version、暫停、InputMap、手把焦點 UI、拆 prep；PlatformServices stub |
| C · 效能地板 | 以 Switch 1 為準 | 髒刷新、SKU 索引、字型子集、尋路節流；雙解析度 UI |
| D · PC 上架 | Steam 候選 | Windows／Linux 匯出、Steamworks、Cloud、成就鉤子、字串表 |
| E · 主機 | Switch／Xbox 候選 | 開發者資格與 devkit；選 W4 自埠或埠接商；釘 Godot 版本；Lotcheck／TCR；分級 |

玩法內容（COMBO、事件、流量等）可與 B／C 並行。主機商務啟動可與 D 重疊，但不要在 B 完成前開「主機專用玩法分叉」。

**上架優先順序（資源有限時）：** Steam → Switch → Xbox。  
**架構投資順序相反：** 先做 PlatformServices 與 InputMap，三台才共用得起來。

---

## 6. 跟進清單（建議開 issue 時可拆）

版控與「凍結 Alpha → 單一 `godot/game` 活線」見 `docs/versioning.md`。v1.0 起這些項目應開在 Milestone `v1.0`，只改活線，不改 `godot/alpha_v0_1`。

可直接複製為 GitHub Issues：

- [x] 凍結 `godot/demo_v0_*`，只維護 `godot/alpha_v0_1`（或合併為單一 `godot/game`）— 活線為 `godot/game`；凍結目錄見各 `FROZEN.md`；版控見 `docs/versioning.md`
- [x] `game_state` 序列化 + `user://save.json`（含 `version`）— 長線 `docs/systemdesign/savesystem.md`；關店與準備結束寫入
- [x] 全專案改 InputMap action（移動／互動／取消／技能）— 長線 `docs/systemdesign/control.md`；Autoload `Controls`
- [x] 拆 `prep_menu.gd` 分頁；關鍵 UI 改 `.tscn` — 殼層 `scenes/prep_menu.tscn`；分頁 `scripts/prep/prep_pages.gd`；格線 `scripts/prep/prep_grid_view.gd`
- [ ] 新增 `PlatformServices` Autoload stub（Desktop 實作）
- [ ] HUD／客人標籤改髒刷新
- [ ] 貨架 SKU 索引
- [ ] NotoSansTC 子集化方案
- [ ] 暫停選單 + 掛起／恢復鉤子
- [ ] Windows／Linux 匯出預設（Steam 候選）
- [ ] 字串表（i18n）抽出
- [ ] 主機：開發者帳號／中介埠或埠接商評估（商務）
- [ ] 對齊 Godot 小版本與 console middleware 支援表

---

## 結論

Alpha v0.1 作為「可玩的系統 + Voxel 初模」是成功的技術驗證。若目標含 Steam、Switch、Xbox，評估從「補 Steam 產品化」升級為「用單一 Godot 主線 + 平台介面，對接三套生態」。不必換引擎；必須接受主機不能自助匯出、要以 Switch 當效能地板，並把存檔／輸入／掛起／UI 模式從玩法裡抽乾淨。愈晚做抽象，愈容易變成多份無法合流的專案複本。
