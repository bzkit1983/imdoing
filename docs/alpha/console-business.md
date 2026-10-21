# 主機商務評估：開發者帳號／中介埠／埠接商

- **對應：** tech-review §6 第 12 點（商務評估，非工程里程碑）
- **評估日：** 2026-10-21
- **前提：** 活線 `godot/game`（Godot **4.7**、GL Compatibility）；上架順序 Steam → Switch → Xbox（見 tech-review §5）
- **公開來源：** [Godot Console Support](https://godotengine.org/consoles/)、[W4 Consoles](https://www.w4games.com/w4consoles)、[Nintendo Developer Portal](https://developer.nintendo.com/)、[ID@Xbox / GDK docs](https://devdocs.xbox.com/)  
  （費用／審核時程以官方當時頁面為準；devkit 報價多半 NDA。）

## 結論（給本專案的建議）

| 決策 | 建議 |
| --- | --- |
| **何時動手** | 產品骨架已齊；可與 Steam 候選**並行**開帳號，但**不要**在玩法／UI 仍大改時買 middleware 或簽埠接合同 |
| **帳號** | 先申請 **Nintendo Developer Portal**（Switch 存取）＋ **ID@Xbox**（免費加入、審核約數週起跳） |
| **技術路徑** | 首選 **W4 Consoles 自埠**（Switch 1 + Xbox Series）；團隊小、2D／Compatibility、已有 `PlatformServices` 時成本可控 |
| **埠接商** | 當備援：工程人力不足、要含 Xbox One／大量認證代跑、或需發行商包辦時再比價 |
| **Godot 版本** | W4 公開相容多為 **4.3–4.6**（並有 Switch 2 beta）；進主機衝刺前須完成 §6 第 13 點「釘版／對齊 middleware」——**4.7 不可假設可直接匯出** |
| **不做** | 不複製 `godot/game_switch`；不把觸控當唯一通關路徑；NDA 產物不進公開 repo |

**一句話：** 商務上「帳號先開、錢後花」；工程上繼續 Steam + Desktop stub，等內容凍結＋Godot 釘版後再買 W4 或談埠接。

---

## 1. 為什麼 Godot 不能「按一下匯主機」

Godot Foundation **不維護**公開主機匯出（開源授權與主機 NDA／SDK 不相容）。可行路徑只有：

1. 取得平台開發者資格與 SDK／devkit  
2. 使用**私有** console export template（自建或向已授權第三方取得）  
3. 通過分級與認證（Lotcheck／TCR 等）後上架  

對本專案：玩法架構適合主機；缺口在**商務＋私有工具鏈**，不是換引擎。

---

## 2. 開發者帳號（必經、可提早）

| 平台 | 入口 | 成本（公開資訊） | 要點 |
| --- | --- | --- | --- |
| **Nintendo Switch（及後續 Switch 2）** | [developer.nintendo.com](https://developer.nintendo.com/) 註冊 → 再申請平台存取 | 帳號申請本身無公開「入場費」；devkit／工具另計（多半保密） | 可 Individual／Organization；需填開發經歷與計畫專案；通過後才見 SDK。發行另需 Publisher 合約、Game Code、分級、Lotcheck |
| **Xbox** | [ID@Xbox](https://developer.microsoft.com/games/xbox/)／Partner Center | **加入免費**；公開文件寫審核「至少約兩週」量級 | 通過後才下載 **GDK**。可先在 Windows PC 開發；真機測試再買／借 **dev kit**。Microsoft 公開 Godot sample 目前偏 **Xbox on PC**，**主機**仍需 middleware／埠接（見下） |
| **PlayStation** | 本階段**非優先**（tech-review 上架序未列 PS） | — | 若日後擴平台，同樣需開發者資格；W4 亦有 PS5 方案 |

**建議動作（負責人／法人名義）：**

1. 用公司或個人名義註冊 Nintendo + ID@Xbox（可與 Steam 頁面並行）。  
2. 申請文案對齊現況：Godot 2D 便利店經營、已有存檔／暫停／InputMap、目標 Steam 後 Switch。  
3. **先不要**為帳號進度阻塞桌面功能開發。

---

## 3. 路徑比較：中介埠自埠 vs 埠接商

### A. Middleware 自埠 — W4 Consoles（首選候選）

| 項目 | 內容（公開頁面摘要，2025–2026） |
| --- | --- |
| 平台 | Nintendo Switch、Xbox Series X\|S、PlayStation 5；Switch 2 有 **beta** |
| Godot | 標榜 4.3+；FAQ 列 **4.4／4.5／4.6**（及 4.3 部分平台）；**與本專案 4.7 有落差 → 見第 13 點** |
| 取得方式 | 填申請 → W4 **核對你已是平台認可開發者** → 發票 → 私有 repo／匯出模板 |
| 公開價（年訂） | **Starter**（公司 ≤30 人、營收／募資 &lt;$300k）：約 **US$800／平台／年**，三平台打包約 **US$2,000／年**；**Pro** 門檻較高（約 US$4,000／平台／年）。Enterprise 報價、可買斷。埠接商用授權規則另有限制 |
| 團隊仍要做的事 | 手把焦點／TV UI、掛起與存檔（已有 stub）、Lotcheck／TCR 清單、分級、效能（Switch 1 地板）、平台服務接真 API |

**適合本專案的理由：** 單機、2D、體量中小；已有 `PlatformServices`／暫停／InputMap；自埠可保留工程控制、年費相對可預期。

**不適合／延後購買的理由：** 尚無平台帳號核可；Godot 4.7 未對齊；玩法與 UI 仍大幅迭代時買年費浪費；團隊若完全無人力跑認證則應改找埠接。

### B. 埠接商／發行代工（備援）

Godot 官方列表（非背書、需自行比價）含例如：Pineapple Works、mazette!、Olde Sküül、Seaven Studio、Sickhead Games、Lone Wolf、RAWRLAB、Tuanisapps 等——服務範圍從「只做埠」到「埠＋發行」不一。

| 何時改選埠接 | 訊號 |
| --- | --- |
| 自埠人力不足 | 認證／多區上架／實體卡帶要外包 |
| 要舊世代 Xbox One | W4 公開主打 Series；One 多走埠接 |
| 需要發行商資源 | 行銷、預購、實體通路 |
| 報價優於「W4 年費 + 自跑認證」 | 收到 2–3 家 NDA 報價後再定 |

**建議流程：** 內容接近可玩且 Steam 頁面成形後，向 2 家埠接要 **Switch + Xbox Series** 粗報（含是否包 Lotcheck／分級協調）；同時用 W4 Starter 報價當對照。

---

## 4. 建議時程（對齊 tech-review 階段）

```text
現在（B 已大致完成 · D 進行中）
  ├─ 申請 Nintendo + ID@Xbox（低成本閘門）
  ├─ Steam 候選包／Steamworks（桌面）
  └─ 不買 W4、不簽埠接（除非有外部 deadline）

內容＋手把 UI 凍結 · 完成 §6「Godot／middleware 釘版」
  ├─ 確認 W4 支援的 Godot 小版本（必要時活線降／釘版）
  ├─ 購買 W4（建議先 Switch，或 All Platforms 打包）
  └─ 或選定埠接商並簽 SOW

E · 主機衝刺
  ├─ Devkit、真機效能、Lotcheck／TCR
  ├─ PlatformServices → 平台 backend（存檔／掛起已接鉤子）
  └─ 分級（ESRB／PEGI／CERO 等，依發行區）
```

**上架序不變：** Steam → Switch → Xbox。Xbox 帳號可早開；真機衝刺可晚於 Switch。

---

## 5. 成本粗框（僅公開／量級，非報價）

| 項目 | 量級備註 |
| --- | --- |
| Nintendo／ID@Xbox 帳號 | 申請本身通常無公開年費；時間成本為主 |
| Devkit | 保密；編預算時向平台／代理詢問 |
| W4 Starter（示例） | ~US$800／平台／年 或 ~US$2,000 三平台／年（資格符合時） |
| 埠接商 | 專案報價，常見遠高於 middleware 年費（含人力＋認證） |
| 分級 | 依區域與商業方案；獨立開發者常有較低檔方案 |
| 平台抽成 | 例如 eShop 公開資料常見約 30% 代理抽成量級（以合約為準） |

---

## 6. 與活線工程的銜接（不另開複本）

已具備、主機可直接沿用：

- `PlatformServices` Desktop stub → 日後換 Switch／Xbox backend  
- 暫停／掛起鉤子、`user://save.json` + `version`  
- InputMap／`Controls`（認證要求手把可完整遊玩）  
- 字型子集、髒刷新、SKU 索引（Switch 1 地板）  
- `Loc` 字串表（語言包／電子手冊另議）

主機開始前仍應完成：tech-review §6 **第 13 點**（Godot 小版本與 middleware 支援表對齊）。

---

## 7. 決策記錄

| 項目 | 狀態 |
| --- | --- |
| 路徑偏好 | **W4 自埠為預設**；埠接商為備援 |
| 帳號 | **建議立即申請** Nintendo + ID@Xbox（負責人執行；本檔不代替送件） |
| 購買 W4／簽埠接 | **延後**至 Godot 釘版＋內容凍結後 |
| PS5 | 本階段不做 |
| 文件擁有者 | 商務／製作；工程只消費結論與釘版結果 |
