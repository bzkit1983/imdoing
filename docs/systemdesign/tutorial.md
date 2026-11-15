# 教學模式

- 活線：`godot/game`
- 工程：`scripts/tutorial/`（`tutorial_catalog.gd`、`tutorial_director.gd`、`tutorial_modal.gd`）、`scenes/tutorial_modal.tscn`
- 存檔：`GameState.tutorial_progress`（`user://save.json`）
- 文案：`Loc`（`tut.*`／`pause.tutorial.*`；見 `docs/alpha/i18n.md`）
- 營運任務交叉：`tasksystem.md`（教學不走 `task_test_mode`）
- 暫停重溫：`pausemenu.md`
- 劇本入口：劇本 5「教學模式」（僅 `ProductVersion.test_tools_enabled()`）

## 範圍

教學在**準備**與**營運**都會出現。依進度與時機觸發；營運會把當前步驟條件投影成任務列。

本檔定義系統契約。個別開局 Lesson 文案／圖／條件另表擴充。

## 名詞

| 名詞 | 意思 |
| --- | --- |
| **Lesson（教學）** | 一個可完成、可重溫的單元 |
| **Page** | 講解分頁（圖＋文）；僅說明，不計條件 |
| **Step** | 強制練習：順序、達成條件、下一步 |
| **Review** | 已完成 Lesson 可從暫停「教學」重看 Pages；不再 forced |

每則 Lesson 定義必須含：`id`、觸發、`pages`、`steps`（順序／條件／下一步）、完成標記規則。

## 資料模型

```text
TutorialLesson {
  id: String
  phase: prep | ops | either
  trigger: {
    when: first_unseen | day_index | flag | scenario
    scenario?: int          # when == scenario
    day_index?: int         # when == day_index
    flag?: String           # when == flag（之後擴充）
    requires_done?: [id…]   # 須先完成的 Lesson
  }
  pages: [{ image_path?, title_key, body_key }]
  steps: [{
    id: String
    order: int
    condition: {
      metric: String        # 營運對齊 TaskCatalog metric；準備可用 placed_count 等
      op: >= | > | == | < | <=
      target: int
      filters?: Dictionary
    }
    next: String | ""       # 下一步 step id；空＝本 Lesson 結束
  }]
  ops_task?: { name_key, desc_key }   # 營運 HUD／暫停任務列文案
}
```

完成狀態（每存檔）：

```text
GameState.tutorial_progress: {
  "<lesson_id>": {
    status: unseen | active | done
    step_id?: String
    pages_acked?: bool
  }
}
```

- 清檔後教學會再強勢出現。
- 重溫列表＝`status == done` 的 Lessons。

## 強制達成（硬閘）

有進行中且 **forced** 的教學步驟時，玩家仍可在該階段內自由操作，但：

| 階段 | 擋住 |
| --- | --- |
| 準備 | 「開始營運日」（含大廳 Host 開工） |
| 營運 | 結算、提早關店、測試「馬上完成營運」 |

未完成則不標記步驟完成、不開下一步。**重溫模式永不硬閘。**

## 流程

### 準備

1. 進入 Prep（home／切頁後）時，`TutorialDirector` 依 trigger 找下一則未完成且 `phase` 含 prep 的 Lesson。
2. 彈出講解視窗（分頁＋上一步／下一步；末頁「開始練習」）。
3. 進入 forced step；硬閘擋住開業。
4. Prep 條件由 Director 依 `GameState` 變更評估（例如 `placed_count`）。
5. Step 完成 → 下一步或 Lesson `done` → 解除硬閘。

### 營運

1. `_begin_day`／`_setup_day_tasks` 之後觸發 ops Lesson。
2. 同樣先講解（`get_tree().paused`＋`PROCESS_MODE_ALWAYS`）。
3. 講解結束：當前 step 條件投影成教學任務列；硬閘擋結算／skip。
4. 進度經 `demo.note_*` → Director `note_metric`（與 TaskTracker 並行，**不**佔用 `task_test_mode`）。
5. Step／Lesson 完成後解除硬閘。

與 `OP-TUT-001`：測試任務包仍僅供 Prep「測試任務」；正式教學由 Director 掛載。

### 重溫

- 暫停主列「教學」→ 列出已 `done` 的 Lesson；點選只播 Pages。
- 無已完成時顯示空狀態文案。

## 劇本 5

- id `5`；克隆空店開局，資金 **$3000**、LV1；流量緩和同劇本 1。
- 僅測試工具開啟時出現於劇本列表。
- 作為教學鏈入口（`scenario == 5`）。
- 正式首 Lesson：`tut.prep.open_shop`「開店第一步」（準備：空店→可開業；條件 `open_ready`）。
  - 強制步驟期間 soft-lock：主頁僅「店舖管理」；店舖內僅購入／配置；家具限購 `cashier`／`restock_dry`／`shelf_dry_4` 各 1（`prep_restrict`）。
  - 營運清潔仍為 stub（`tut.stub.ops_clean`，依賴前者）。

## 多人

本系統先單機／Host 本地；聯機同步另開。

## 實作索引

| 檔 | 職責 |
| --- | --- |
| `tutorial_catalog.gd` | Lesson 定義（含 stub） |
| `tutorial_director.gd` | 觸發、步驟、硬閘、metric、HUD 行 |
| `tutorial_modal.gd` | 分頁講解視窗 |
| `game_state.gd` | `tutorial_progress` 存讀 API |
| `prep_menu.gd`／`demo.gd`／`pause_menu.gd` | 掛載與閘門 |
