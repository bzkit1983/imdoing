# 事件系統（占位）

- **狀態：** 開檔占位；**不排活線實作**（tech-review v0.3 **N2**）
- **產品範圍：** Steam EA／現行產品＝**純日循環**；完整事件表留 Beta（見 [`docs/versioning.md`](../versioning.md)、[`docs/beta/design.md`](../beta/design.md)）
- **對照：** 劇情框架 [`storysystem.md`](storysystem.md)；任務條件 [`tasksystem.md`](tasksystem.md)；事件 pack stub [`taskcontent-event-stub.md`](taskcontent-event-stub.md)

# 本檔要定義什麼（之後再填）

| 槽位 | 說明 |
|------|------|
| 觸發來源 | 日循環相位、評價、隨機池、劇情章節（Beta） |
| 修飾器 | 流量／污物／小偷／價格／任務條件等短時修正 |
| 與任務關係 | 一次性事件任務 vs 期間限定可重覆 |
| 與劇情關係 | 章節事件 vs 日常營運事件；解鎖權威仍歸劇情／任務 |
| 活線邊界 | EA 不做；開 runtime 前須過 versioning 閘門 |

# 明確不做（現在）

- 不在 `godot/game` 加 `EventDirector`／事件狀態機
- 不把隨機 ops／任務板假裝成完整事件層
- 不承諾檔期或商店文案中的「事件季節」

細節與表待 Beta 填；在此之前本檔只作缺口錨點，避免誤開實作 PR。
