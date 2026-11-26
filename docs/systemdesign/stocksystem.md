#貨品設定
- 此檔案包含貨品設定
- 主題擴充：[`cookedfoodsystem.md`](cookedfoodsystem.md)、[`fishingtaro.md`](fishingtaro.md)、[`story/themes/theme-historic.md`](story/themes/theme-historic.md)
- 程式 id／價：活線見 `tuning.gd`；顯示名 `locale/data.csv` → `sku.<id>`

#**貨品種類**
初始種類:
- 乾貨類（`dry`）
- 凍櫃類（`frozen`）
- 冰櫃類（`ice`）

主題擴充種類:
- 熟食類（`cooked`）— `theme_historic`；不可採購，只經熟食檔加工

後續開發會可持續新增種類.

#**乾貨類貨品**
| 顯示 | `sku_id` |
|------|----------|
| 罐頭 | `can` |
| 零食 | `snack` |
| 杯麵 | `cup` |
| 米 | `grain`（`theme_historic`；**不是**叮叮飯） |
| 醬油 | `soy_sauce`（`theme_historic`） |

#**凍櫃類貨品**
| 顯示 | `sku_id` |
|------|----------|
| 支裝凍飲 | `drink` |
| 牛奶 | `milk` |
| 汽水 | `soda` |

#**冰櫃類貨品**
| 顯示 | `sku_id` |
|------|----------|
| 雪糕 | `icecream` |
| 凍肉 | `meat` |
| 叮叮飯 | `rice` |

#**熟食類貨品**（`cooked`）
| 顯示 | `sku_id` | 食譜 |
|------|----------|------|
| 飯團 | `onigiri` | `grain`＋`grain` |
| 烤年糕 | `yakimochi` | `grain`＋`soy_sauce` |
| 手握壽司 | `nigiri` | `grain`＋任一魚材 |

#**魚材**（不可售；`fish_id`）
鯖魚 `saba`、鯛魚 `tai`、秋刀魚 `sanma`、竹筴魚 `aji`、香魚 `ayu` — 見 [`fishingtaro.md`](fishingtaro.md)

後續開發會可持續新增新貨品.