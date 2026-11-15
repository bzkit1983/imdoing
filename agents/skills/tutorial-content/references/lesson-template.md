# Tutorial Lesson 草稿模板（中文優先）

複製本節填寫。玩家可見字最終以 locale 鍵為準；此稿是設計與 Validation 的來源。

## Meta

| 欄位 | 值 |
| --- | --- |
| Lesson id | `tut.…` |
| phase | `prep` \| `ops` \| `either` |
| 取代 stub？ | 否／是（原 id：） |
| 設計意圖（一句） | |

## Trigger

| 欄位 | 值 |
| --- | --- |
| when | `first_unseen` \| `day_index` \| `flag` \| `scenario` |
| scenario | （若 when=scenario） |
| day_index | （若需要） |
| flag | （若 when=flag；須先有運行時支援） |
| requires_done | `[ ]` Lesson id 列表 |

## Pages（講解；不計條件）

| # | title_key | body_key | image_path（可空） | 中文標題草稿 | 中文內文草稿 |
| --- | --- | --- | --- | --- | --- |
| 1 | `tut.…p1.title` | `tut.…p1.body` | | | |
| 2 | | | | | |

## Steps（強制練習）

| order | step id | metric | op | target | filters | next | 玩家要做什麼 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `tut.…s1` | | `>=` | | `{}` | `""` 或下一步 id | |

規則提醒：

- `next` 鏈無環；最後一步 `next` 為空字串。
- Prep metric 須已在 Director 評估；Ops metric 須 wired。
- 未完成時硬閘擋住對應階段前進，但本表「玩家要做什麼」必須可在該階段完成。

## ops_task（HUD／暫停任務列）

| 欄位 | 鍵 | 中文草稿 |
| --- | --- | --- |
| name | `tut.…task.name` | |
| desc | `tut.…task.desc` | |

## Hard-gate escape

- 擋住什麼：準備開業／營運結算（依 phase）
- 完成後如何解除：Step／Lesson done
- 若卡住的後備（設計備註，非正式跳過）：

## Acceptance（填進 Validation Report H）

1. …
2. …

## Explicit non-goals

- …
