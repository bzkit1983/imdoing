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
- 正式 prep 鏈：
  1. `tut.prep.open_shop`「開店第一步」：重選／進入劇本 5 準備即觸發；條件 `owned_furniture_kinds >= 3`（買齊三件）；soft-lock 僅購入商店物品。
  2. `tut.prep.buy_stock`「採購入門」：購入完成後鏈式觸發；條件 `stock_pieces(can) >= 99`；soft-lock 只准貨品管理→採購；不開局贈罐。
  3. `tut.prep.shop_layout`「店鋪設計入門」：採購完成後鏈式觸發；條件 `open_ready`（三件擺進店，位置不限）；soft-lock **只准店鋪設計**（鎖購入／擴張）；Pages 含補貨架長按設預設貨品提示。
  - 家具限購 `cashier`／`restock_dry`／`shelf_dry_4` 各 1（`prep_restrict`）。
- 正式 ops 鏈（`day_index == 0`）：
  1. `tut.ops.shelve`「貨品上架」：開工即彈（`requires_done` 店鋪設計課）；條件 `shelve_count >= 4`；Pages 含執貨／上架操作；結課彈完成視窗。
  2. `tut.ops.clean`「清潔入門」：上架完成後才開始生成污物；runtime flag `dirt_present`（污物首次出現）才彈；條件 `clean_count >= 1`。上架課完成前不生成污物。
  3. `tut.ops.checkout`「收銀入門」：清潔完成後鏈式觸發；條件 `checkout_count >= 2`（玩家座收銀；店員代收不計）；Pages 含方向指令／環形計；結課彈完成視窗。收銀結課前不生成小偷。
  4. `tut.ops.thief`「捉小偷」：收銀結課後強制刷一隻（flag `thief_present`）；條件 `thief_caught >= 1`（近戰／衝刺／丟貨皆可）；逃走（`record_stolen`）後立刻再刷練習隻。
  5. `tut.ops.deliver`「客人交付」：捉賊結課後鏈式；Pages 含購物清單／親手與投擲交付；條件 `deliver_count >= 3`。
  6. `tut.ops.finish_day`「完成一日營運」：交付結課後鏈式；講解後自由營業；條件 `day_settled >= 1`；`allow_settle: true`（本課不擋結算）。
  7. `tut.ops.empty_shelf`「空貨架提示」（純 tip）：收銀完成後、首次貨架由有貨變空（flag `shelf_empty`）彈講解；`steps` 為空＝看完即 done、不硬閘結算。
  - Lesson 結課統一經完成視窗（`complete_pages` 或預設 `tut.complete.*`）再鏈式下一課。

## 多人

本系統先單機／Host 本地；聯機同步另開。

## 實作索引

| 檔 | 職責 |
| --- | --- |
| `tutorial_catalog.gd` | Lesson 定義（劇本 5 正式鏈） |
| `tutorial_director.gd` | 觸發、步驟、硬閘、metric、HUD 行 |
| `tutorial_modal.gd` | 分頁講解視窗 |
| `game_state.gd` | `tutorial_progress` 存讀 API |
| `prep_menu.gd`／`demo.gd`／`pause_menu.gd` | 掛載與閘門 |
