# Godot 小版本 ↔ console middleware 對齊

- **對應：** tech-review §6 最後一點（釘版政策，非立即降版）
- **對齊日：** 2026-10-21
- **活線現況：** `godot/game` → Godot **4.7** + **GL Compatibility**（`project.godot` `config/features`）
- **首選 middleware：** W4 Consoles（見 `docs/alpha/console-business.md`）
- **公開來源：** [W4 Consoles FAQ](https://www.w4games.com/w4consoles)、[Godot release policy](https://docs.godotengine.org/en/stable/about/release_policy.html)、[Godot 4.7 發佈說明](https://godotengine.org/releases/4.7/)  
  （以查表當日官方頁為準；下表會過期，進主機衝刺前必重查。）

## 結論（釘版政策）

| 軌道 | Godot 小版本 | 說明 |
| --- | --- | --- |
| **桌面／Steam／Web（日常開發）** | **維持 4.7** | 活線已標 4.7；未使用必須 4.7 才有的 Forward+／HDR 等功能；GL Compatibility 與主機友善路徑一致 |
| **主機衝刺／購買 W4 當日** | **以 W4 公開支援表的最高小版本為準** | 2026-10-21 查表：**4.6**（另列 4.5／4.4；4.3 僅部分平台）。**4.7 尚未列在 W4 FAQ** |
| **降／釘時機** | 僅在「確認買 W4 或開主機里程碑」時執行 | 現在**不**降版、**不**開 `godot/game_46` 複本 |
| **升版** | 桌面可跟 Godot 穩定小版本；主機包必須再對一次 middleware 表 | 禁止「桌面已 4.8、主機還假設同一 editor 可匯」 |

**一句話：** 日常繼續 4.7；主機開衝前重查 W4——若已支援 4.7 就不動；若仍停在 4.6，再把**同一條**活線釘到 4.6.x（或等 W4 追上），禁止第二份專案。

---

## 1. 支援表快照（2026-10-21）

### 本專案

| 項目 | 值 |
| --- | --- |
| Editor／features | **4.7** |
| Renderer | **gl_compatibility**（桌面／mobile／web 皆同） |
| 語言 | GDScript（非 C#） |
| 4.7 專屬依賴 | **無**（未用 HDR 輸出、未釘 Forward+）；降到 4.6 風險偏低，但仍須開專案回歸 |

### W4 Consoles（公開 FAQ）

| Godot | Switch 1 | Switch 2 | Xbox Series | PS5 |
| --- | --- | --- | --- | --- |
| **4.6** | ✓ | ✓ | ✓ | ✓ |
| **4.5** | ✓ | ✓ | ✓ | ✓ |
| **4.4** | ✓ | ✓ | ✓ | ✓ |
| **4.3** | ✓ | （未列） | ✓ | （未列） |
| **4.7** | **未列** | **未列** | **未列** | **未列** |

W4 自稱會在引擎穩定版發布後**數月內**跟上；4.7 於 2026-06 穩定，至本對齊日 FAQ 仍寫到 4.6——落差屬預期，不是本專案獨有。

### Godot 上游支援（參考）

| 版本 | 狀態（release policy，約 2026-10） |
| --- | --- |
| 4.7 | 現行穩定；收 bug／安全／平台支援修補 |
| 4.6 | 仍收修補（適合當 middleware 釘版候選） |
| 4.5 | 偏向安全／平台支援 |
| 4.8 | master／開發中（勿當產品釘版） |

---

## 2. 決策樹（主機開衝前執行）

```text
重查 W4 FAQ「What version of Godot are your ports compatible with?」
        │
        ├─ 已列 4.7（或更高且含我們的小版本）
        │     → 活線維持該版本；購買／啟用 W4；開始主機衝刺
        │
        └─ 最高仍為 4.6（或低於活線）
              ├─ 選項 A（偏好）：等 W4 公布 4.7 埠（數週～數月量級）
              │     → 桌面繼續 4.7；不阻塞 Steam
              └─ 選項 B（有主機硬 deadline）：活線降／釘到 W4 最高版（現為 4.6.x）
                    → 同一 `godot/game`；改 features、用 4.6 editor 開一次並修回歸
                    → 禁止另開 game_switch／game_46 目錄
```

**埠接商路徑：** 簽約前同樣索取「支援的 Godot 小版本表」，套用同一決策樹（表源改為該商）。

---

## 3. 若必須釘到 4.6 的工程檢查清單

僅在選項 B 觸發時執行：

1. 安裝 Godot **4.6.x**（與 W4 提供的 port 小版本一致的最新 patch）。  
2. 備份／分支後用 4.6 打開 `godot/game`；接受必要的專案遷移提示。  
3. 將 `project.godot` `config/features` 與 README／`export_presets.cfg` 註解改為釘定小版本。  
4. 回歸：準備選單、營運日、存檔讀寫、暫停／掛起、手把 InputMap、Web／Win／Linux 匯出。  
5. 確認未誤開 Forward+／HDR；維持 **GL Compatibility**。  
6. 文件：更新本檔「對齊日」與支援表快照；在 PR 註明「主機釘版」。

---

## 4. 重查儀式（建議節奏）

| 時機 | 動作 |
| --- | --- |
| 每季或 Godot 新小版本穩定後 | 掃 W4 FAQ；更新本檔快照日期 |
| 申請／續訂 W4 前 | 必查；截圖或摘錄 FAQ 進 PR／issue |
| 開始 Lotcheck／TCR 前 | 再查一次（避免衝刺中途引擎與埠錯位） |

**擁有者：** 工程；商務買 W4 前以本檔「主機衝刺」列為 gate。

---

## 5. 與其他文件的關係

| 文件 | 關係 |
| --- | --- |
| `docs/alpha/console-business.md` | 商務選 W4；**版本閘門**以本檔為準 |
| `docs/alpha/export-presets.md` | 桌面／Web 匯出跟活線 editor；主機模板來自 middleware（不進公開 repo） |
| `docs/versioning.md` | 單一 `godot/game`；版本用 feature／釘 editor，不用目錄分叉 |

---

## 6. 決策記錄

| 項目 | 狀態（2026-10-21） |
| --- | --- |
| 桌面活線 | **釘在 4.7**（繼續開發） |
| Middleware 對齊目標 | W4 表：**4.6** 為當前主機最高可用；**等待 4.7 埠或屆時降釘** |
| 立即降版 | **否** |
| 專案複本 | **禁止** |
| §6 本項 | 政策與支援表已對齊並入文件；執行降版屬後續閘門，非本項未完成 |
