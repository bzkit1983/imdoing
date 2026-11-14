# 事件任務內容（Stub）

- 語意與 schema 見 `tasksystem.md`
- 事件的規則修飾器（客人購物變數、生成率等）屬事件系統；本檔只列觸發後的**任務條件組合**
- 完整事件表待 `eventsystem.md`；此處僅接口＋測試範例

# 接口

事件觸發時向任務系統掛上一個 `kind: "event"` 的 pack（可疊加或替換當日營運清單——替換規則由事件系統定）。

失敗不擋劇情（與劇情任務分開）。

# EV-HEAT-001 — 夏日熱浪來襲（範例）

設計意圖（事件側，非本檔實作）：

- 客人對支裝凍飲需求急升（當日購物清單變數改變）

任務要求（本 pack）：

```json
{
  "pack_id": "EV-HEAT-001",
  "kind": "event",
  "tasks": [
    {
      "id": "EV-HEAT-001-A",
      "metric": "shelf_setup",
      "op": ">=",
      "target": 2,
      "scope": { "type": "day" },
      "filters": { "category": "cold_drink_bottle", "furniture": "restock_shelf" },
      "loc_key": "quest.ev_heat_001_a",
      "rewards": []
    },
    {
      "id": "EV-HEAT-001-B",
      "metric": "deliver_sku",
      "op": ">=",
      "target": 20,
      "scope": { "type": "day" },
      "filters": { "sku": "cold_drink_bottle", "mode": "any" },
      "loc_key": "quest.ev_heat_001_b",
      "rewards": []
    }
  ]
}
```

| id | 說明 |
| --- | --- |
| A | 營運回合須同時設置至少 2 個支裝凍飲補貨架 |
| B | 親手或投擲交付支裝凍飲達 20（`mode: any`） |

SKU／家具 id 以活線 `tuning`／傢俬表為準；stub 用可讀別名，落地時對齊正式 id。

# 流水編號慣例

- 事件任務組合：`EV-<主題縮寫>-###`
