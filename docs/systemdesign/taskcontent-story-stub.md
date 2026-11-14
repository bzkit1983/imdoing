# 劇情任務內容（Stub）

- 語意與 schema 見 `tasksystem.md`
- 主線綁定的特別任務；**做完一次即完結**，並推進劇情進度
- **失敗擋劇情推進**；營運／一般事件任務與劇情分開
- 詳細章節與對話待劇情設計補完；本檔只留占位形狀與一則測試用 stub

# 接口

```json
{
  "pack_id": "ST-PROLOGUE-001",
  "kind": "story",
  "tasks": [],
  "on_complete": { "advance_story": "prologue.clear" },
  "on_fail": { "block_story_advance": true }
}
```

- `on_complete`／`on_fail` 為劇情側鉤子占位（正式欄位名由劇情檔定）
- Host／訪客共同解決與進度落後判定：**劇情設計補完**（見 `tasksystem.md`）

# ST-PROLOGUE-001 — 序章占位（測試）

可與營運教學包 `OP-TUT-001` 並行掛載；劇情是否要求教學全清由劇情檔定。

```json
{
  "pack_id": "ST-PROLOGUE-001",
  "kind": "story",
  "tasks": [
    {
      "id": "ST-PROLOGUE-001-A",
      "metric": "checkout_count",
      "op": ">=",
      "target": 3,
      "scope": { "type": "day" },
      "filters": {},
      "loc_key": "quest.st_prologue_001_a",
      "rewards": []
    }
  ],
  "on_complete": { "advance_story": "prologue.clear" },
  "on_fail": { "block_story_advance": true }
}
```

| id | 說明 |
| --- | --- |
| A | 當日成功收銀 3（對齊 Alpha 教學事件草案；正式劇情可改） |

# 流水編號慣例

- 劇情任務組合：`ST-<章節>-###`
