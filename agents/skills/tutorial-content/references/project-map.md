# Project map (imdoing / godot/game)

Bindings for [`../SKILL.md`](../SKILL.md). Other products replace this file only.

## Contract

| Concern | Path |
| --- | --- |
| Tutorial system contract | [`docs/systemdesign/tutorial.md`](../../../../docs/systemdesign/tutorial.md) |
| Pause review entry | [`docs/systemdesign/pausemenu.md`](../../../../docs/systemdesign/pausemenu.md) |
| Prep／劇本 5 | [`docs/systemdesign/storepreparationphase.md`](../../../../docs/systemdesign/storepreparationphase.md) |
| Ops task metrics (wired list) | [`docs/systemdesign/tasksystem.md`](../../../../docs/systemdesign/tasksystem.md), [`task_catalog.gd`](../../../../godot/game/scripts/session/task_catalog.gd) |
| Status mirror | [`docs/alpha/implementation-status.md`](../../../../docs/alpha/implementation-status.md) |

## Runtime

| Concern | Path |
| --- | --- |
| Lesson catalog | [`godot/game/scripts/tutorial/tutorial_catalog.gd`](../../../../godot/game/scripts/tutorial/tutorial_catalog.gd) |
| Director (trigger／steps／hard gates／HUD rows) | [`godot/game/scripts/tutorial/tutorial_director.gd`](../../../../godot/game/scripts/tutorial/tutorial_director.gd) |
| Paged modal | [`godot/game/scripts/tutorial/tutorial_modal.gd`](../../../../godot/game/scripts/tutorial/tutorial_modal.gd), [`godot/game/scenes/tutorial_modal.tscn`](../../../../godot/game/scenes/tutorial_modal.tscn) |
| Progress save | [`godot/game/scripts/game_state.gd`](../../../../godot/game/scripts/game_state.gd) → `tutorial_progress` |
| Day host／`note_*`／settle gates | [`godot/game/scripts/demo.gd`](../../../../godot/game/scripts/demo.gd) |
| Prep open-day gate／consider／`prep_restrict` soft-lock | [`godot/game/scripts/prep_menu.gd`](../../../../godot/game/scripts/prep_menu.gd)、[`prep_pages.gd`](../../../../godot/game/scripts/prep/prep_pages.gd) |
| Pause「教學」review | [`godot/game/scripts/pause_menu.gd`](../../../../godot/game/scripts/pause_menu.gd) |
| Scenario 5 | `game_state._scenario_tutorial()`（無開局贈罐；採購課買 `can`×99；技能全空；鎖 Easy）；list in [`prep_pages.gd`](../../../../godot/game/scripts/prep/prep_pages.gd) when `ProductVersion.test_tools_enabled()`；prep `open_shop`→`buy_stock`→`shop_layout`（day0）＋`allocate_stats`→`equip_skills`（finish_day 後）＋`develop_goods`→`buy_new_goods`→`buy_new_furn`→`layout_expand`（use_skills 結算後）＋`buy_cashier`→`hire_clerk`（rating 結算後；教學鏈終點）；ops day0 `shelve`→`clean`→`checkout`→`thief`→`deliver`→`finish_day`＋tip `empty_shelf`；ops day1 `use_skills`；ops day2 `rating`（OP-TUT-001 練習＋首客完美交付 tip） |

### Triggers

| Field | Meaning |
| --- | --- |
| `when` | `scenario`／`day_index`／`flag`／`first_unseen` |
| `scenario`／`day_index`／`requires_done` | As in [`docs/systemdesign/tutorial.md`](../../../../docs/systemdesign/tutorial.md) |
| `prep_page` | Optional. Prep Lesson only begins（or re-opens unacked pages）when `consider_prep(page)` matches；active＋`pages_acked` may resume on any prep page |
| `flag` | Runtime flag via `TutorialDirector.notify_flag`（e.g. `dirt_present` from dirt spawn；`thief_present` from thief spawn；`shelf_empty` from stocked→empty shelf；`guest_present` from normal／elite guest spawn）；cleared each ops day start／`reset_runtime`。`tut.ops.rating` 另用 `guest_present` 作課內完美交付 tip（非獨立 Lesson） |

## Conditions (axis C)

### Prep metrics (Director `_current_for_condition`)

| metric | Meaning |
| --- | --- |
| `placed_count` | `state.placed.size()` |
| `owned_furniture_kinds` | `state.owned.size()` |
| `cashier_count` | `state.cashier_count()`（已放置收銀機數） |
| `clerk_count` | `state.clerks.size()`（招募店員課） |
| `open_ready` | `1` if `state.open_blockers().is_empty()` else `0` |
| `stock_pieces` | `state.stock[filters.sku]`（需 `filters.sku`） |
| `unspent` | `state.unspent`（能力配點課） |
| `loadout_changed` | `1` if `skill_sets`／`skill_set_index` fingerprint ≠ lesson-start baseline（裝備技能課） |
| `developed_has` | `1` if `state.developed.has(filters.sku)`（開發課） |
| `owned_qty` | `state.owned[filters.type]`（家具數量；擴充購入課） |
| `unplaced_qty` | `owned−placed`；有 `filters.type` 則單型，否則加總全部 owned（擴充設計課） |
| `restock_defaults_distinct` | `1` if 每座 restock 皆有非空 `default_sku` 且互異 |

Any other Prep metric = Fail until Director evaluates it.

### Ops metrics

- Must appear in `TaskCatalog.WIRED_METRICS` ([`task_catalog.gd`](../../../../godot/game/scripts/session/task_catalog.gd)), **or** be a tutorial-only metric noted only via `_tutorial.note_metric`（e.g. `day_settled` from Host `_finish_day`）.
- Progress must reach Director via `demo.note_*` → `_tutorial.note_metric`／`sync_metric_absolute` (already wired for common paths such as `clean_count`, `shelve_count`, `deliver_count`, `checkout_count`, `thief_caught`, `skill_cast`, `ult_cast`; verify the metric you need).
- Do **not** attach formal Lessons through `task_test_mode` or `OP-TUT-*` packs.

### Ops

| op | Meaning |
| --- | --- |
| `>=` `>` `==` `<` `<=` | Same compare style as task tracker |

## Locale keys (axis E)

| Prefix | Table | Notes |
| --- | --- | --- |
| `tut.<lesson>.pN.title`／`.body` | `godot/game/locale/strings.csv` | Explain pages |
| `tut.<lesson>.task.name`／`.desc` | `strings.csv` | HUD／pause task row (`ops_task`) |
| `tut.modal.*`／`tut.gate.*`／`tut.prep.restrict.*` | `strings.csv` | Shell chrome + prep soft-lock copy |
| Lesson optional `prep_restrict` | catalog | `home_hub_allow`／`shop_hub_allow`／`goods_hub_allow`／`char_hub_allow`／`pages_allow`／`furniture_owned_cap`／`goods_sku_allow`／hint keys |
| `pause.tutorial.*` | `strings.csv` | Pause review submenu |
| `prep.scenario.s5` | `strings.csv` | Test scenario label |

Handoff: [`agents/skills/i18n-content/SKILL.md`](../../i18n-content/SKILL.md). Spec: [`docs/alpha/i18n.md`](../../../../docs/alpha/i18n.md).

## Hard gates (axis D)

| Phase | Blocked while forced step active |
| --- | --- |
| Prep | Start day（含大廳 Host 開工） |
| Ops | Settle／early close／test skip operate — **except** lessons with `allow_settle: true`（e.g. `tut.ops.finish_day`） |

Review／重溫: pages only, never forced.

## Test entry

- 劇本 **5**（教學模式）：LV1、空店、$3000；intro traffic easing like scenario 1.
- Visible only when `ProductVersion.test_tools_enabled()`.
