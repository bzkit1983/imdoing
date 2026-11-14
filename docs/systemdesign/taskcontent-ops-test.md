# 營運任務內容（測試）

- 語意與 schema 見 `tasksystem.md`
- 本檔為測試／序章教學用組合；正式長線內容另表擴充
- 文案 key 進 `locale`（`quest.*`）；此處只列 id 與條件

# OP-TUT-001 — 序章教學包

- `pack_id`: `OP-TUT-001`
- `kind`: `ops`
- 測試入口：`pack_tutorial_prologue`

```json
{
  "pack_id": "OP-TUT-001",
  "kind": "ops",
  "tasks": [
    {
      "id": "OP-TUT-001-A",
      "metric": "shelve_count_sku",
      "op": ">=",
      "target": 12,
      "scope": { "type": "day" },
      "filters": { "sku": "canned" },
      "loc_key": "quest.op_tut_001_a",
      "rewards": []
    },
    {
      "id": "OP-TUT-001-B",
      "metric": "clean_count",
      "op": ">=",
      "target": 6,
      "scope": { "type": "day" },
      "filters": {},
      "loc_key": "quest.op_tut_001_b",
      "rewards": []
    },
    {
      "id": "OP-TUT-001-C",
      "metric": "deliver_count",
      "op": ">=",
      "target": 10,
      "scope": { "type": "day" },
      "filters": {},
      "loc_key": "quest.op_tut_001_c",
      "rewards": []
    },
    {
      "id": "OP-TUT-001-D",
      "metric": "perfect_deliver_count",
      "op": ">=",
      "target": 3,
      "scope": { "type": "day" },
      "filters": {},
      "loc_key": "quest.op_tut_001_d",
      "rewards": []
    },
    {
      "id": "OP-TUT-001-E",
      "metric": "checkout_count",
      "op": ">=",
      "target": 3,
      "scope": { "type": "day" },
      "filters": {},
      "loc_key": "quest.op_tut_001_e",
      "rewards": []
    },
    {
      "id": "OP-TUT-001-F",
      "metric": "angry_leave",
      "op": "<",
      "target": 5,
      "scope": { "type": "day" },
      "filters": {},
      "loc_key": "quest.op_tut_001_f",
      "rewards": []
    }
  ]
}
```

| id | 說明（設計用） | 備註 |
| --- | --- | --- |
| A | 罐頭上架 12 | 需上架計數 |
| B | 清潔 6 | 對齊既有 `cleaned` |
| C | 總交付 10 | 需交付計數 |
| D | 完美交付 3（清單一次交清） | 見 `tasksystem.md` |
| E | 成功收銀 3 | 對齊 Alpha LV1 草案 |
| F | 不滿離開 &lt; 5 | 上限型；測即時 X（可選開啟） |

# OP-MAN-001 — 單條件回歸例（金額／評價）

測試入口：`pack_manual_OP-MAN-001`

```json
{
  "pack_id": "OP-MAN-001",
  "kind": "ops",
  "tasks": [
    {
      "id": "OP-MAN-001-A",
      "metric": "sales_revenue",
      "op": ">=",
      "target": 500,
      "scope": { "type": "day" },
      "filters": {},
      "loc_key": "quest.op_man_001_a",
      "rewards": []
    },
    {
      "id": "OP-MAN-001-B",
      "metric": "day_grade",
      "op": ">=",
      "target": 1,
      "scope": { "type": "day" },
      "filters": {},
      "loc_key": "quest.op_man_001_b",
      "rewards": []
    }
  ]
}
```

# OP-MAN-002 — 跨日累計例

測試入口：`pack_manual_OP-MAN-002`

```json
{
  "pack_id": "OP-MAN-002",
  "kind": "ops",
  "tasks": [
    {
      "id": "OP-MAN-002-A",
      "metric": "clean_count",
      "op": ">=",
      "target": 20,
      "scope": { "type": "accumulate", "max_days": 3 },
      "filters": {},
      "loc_key": "quest.op_man_002_a",
      "rewards": []
    },
    {
      "id": "OP-MAN-002-B",
      "metric": "shop_rating",
      "op": ">=",
      "target": 5,
      "scope": { "type": "accumulate" },
      "filters": {},
      "loc_key": "quest.op_man_002_b",
      "rewards": []
    }
  ]
}
```

# 流水編號慣例

- 教學：`OP-TUT-###`
- 手動測試組合：`OP-MAN-###`
- 隨機生成輸出：`OP-RAND`（帶 `seed`；見 `tasksystem.md`）
- 正式內容日後另開長線表，沿用 `OP-` 前綴與三位流水
