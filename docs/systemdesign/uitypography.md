# UI 字級與間距（Design Guide）

- 活線：`godot/game`
- 基準解析度：1280×720
- 字型執行期：`scripts/ui_font.gd`（Noto Sans CJK 子集；見 `docs/alpha/fonts-subset.md`）
- Pause 色票／素材：`agents/skills/pause-ui-chrome/`（字級以**本檔**為準，唔喺 Gemini 包重複定義）
- 暫停落地對照：`pausemenu.md`

## 字重（Faces）

| Face | 檔案 | `UiFont` | 用途 |
| --- | --- | --- | --- |
| Regular | `NotoSansTC-Game.ttf` | `FACE`／`WEIGHT_REGULAR` | 預設正文／掣字 |
| Bold | `NotoSansTC-Game-Bold.ttf` | `FACE_BOLD`／`WEIGHT_BOLD` | 面板標題（暫停「暫停」「設定」） |
| Black | `NotoSansTC-Game-Black.ttf` | `FACE_BLACK`／`WEIGHT_BLACK` | Splash／display 預留 |

API：`apply_label(..., weight)`、`apply_title_bold`、`apply_button_literal`（`px()` 唔 ×2）。Prep 等舊呼叫可繼續 `apply_button`（`px_btn` ×2）。

## 原則

1. 遊戲內常駐 UI（暫停、準備、HUD）只用下表 **caption → heading**。
2. `heading-lg`／`display`／`display-xl`／`hero` 僅限 Splash、章節大字等全螢幕標題；**唔**用於選單掣或面板標題。
3. Godot Label／Button 本輪只鎖定 **px 字級**；CSS letter-spacing／精準 line-height 唔強制。
4. 奶油 Pause 面板上的標題／掣字用 Cocoa Ink；次要說明用 Muted Taupe（色見 pause-ui-chrome）。

## Type Scale

| Role | Size | Token | 遊戲用途 |
| --- | --- | --- | --- |
| caption | 16px | `--text-caption` | Hint、次要提示 |
| body-sm | 22px | `--text-body-sm` | 選單掣字、音量 ± |
| body | 29px | `--text-body` | 段落說明（body） |
| subheading | 36px | `--text-subheading` | 次標題（可選） |
| heading-sm | 43px | `--text-heading-sm` | 暫停／設定面板標題 |
| heading | 50px | `--text-heading` | 較大面板標題（慎用） |
| heading-lg | 72px | `--text-heading-lg` | Splash／章節（非常駐） |
| display | 115px | `--text-display` | 全螢幕大字（非常駐） |
| display-xl | 202px | `--text-display-xl` | 同上，極少用 |
| hero | 346px | `--text-hero` | 同上，極少用 |

### 暫停選單映射（已落地）

| UI | Token | Size |
| --- | --- | --- |
| Hint | caption | 16 |
| 掣字（主列／設定／±） | body-sm | 22 |
| Body 說明 | body | 29 |
| 「暫停」「設定」標題 | heading-sm + **Bold** | 43 |

### 同舊 `UiFont` 對照（尚未全域改碼）

| `ui_font.gd` | 舊值 | 建議對齊 |
| --- | --- | --- |
| `WORLD` | 22 | body-sm 22 |
| `BODY`／`BUTTON` | 24 | body-sm 22 或 body 29（視場景） |
| `TITLE` | 28 | subheading 36 或 heading-sm 43 |
| `HUGE` | 44 | heading-sm 43 |

全域改 `ui_font.gd`／Prep／HUD 另開工作，唔一次爆改。

## Spacing

- **Base unit：** 6px  
- **Density：** spacious  

| Name | Value | Token | 本輪暫停用法 |
| --- | --- | --- | --- |
| 12 | 12px | `--spacing-12` | 掣列 gap |
| 24 | 24px | `--spacing-24` | 標題區 inset／頂距 |
| 30 | 30px | `--spacing-30` | 面板內容左右 inset（可選） |
| 60 | 60px | `--spacing-60` | 大區塊（本輪唔強加） |
| 108 | 108px | `--spacing-108` | 大區塊（本輪唔強加） |

暫停掣行高目標約 **56px**（配 body-sm）；音量 mini ± 約 **48×48** 垂直置中。
