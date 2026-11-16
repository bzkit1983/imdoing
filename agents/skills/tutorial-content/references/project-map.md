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
| Scenario 5 | `game_state._scenario_tutorial()`（含 `can`×12）；list in [`prep_pages.gd`](../../../../godot/game/scripts/prep/prep_pages.gd) when `ProductVersion.test_tools_enabled()`；prep `open_shop`→`shop_layout`；ops `shelve`→`clean` |

### Triggers

| Field | Meaning |
| --- | --- |
| `when` | `scenario`／`day_index`／`flag`／`first_unseen` |
| `scenario`／`day_index`／`requires_done` | As in [`docs/systemdesign/tutorial.md`](../../../../docs/systemdesign/tutorial.md) |
| `prep_page` | Optional. Prep Lesson only begins（or re-opens unacked pages）when `consider_prep(page)` matches；active＋`pages_acked` may resume on any prep page |
| `flag` | Runtime flag via `TutorialDirector.notify_flag`（e.g. `dirt_present` from `demo._spawn_dirt`）；cleared each ops day start／`reset_runtime` |

## Conditions (axis C)

### Prep metrics (Director `_current_for_condition`)

| metric | Meaning |
| --- | --- |
| `placed_count` | `state.placed.size()` |
| `owned_furniture_kinds` | `state.owned.size()` |
| `cashier_count` | `state.cashier_count()` |
| `open_ready` | `1` if `state.open_blockers().is_empty()` else `0` |

Any other Prep metric = Fail until Director evaluates it.

### Ops metrics

- Must appear in `TaskCatalog.WIRED_METRICS` ([`task_catalog.gd`](../../../../godot/game/scripts/session/task_catalog.gd)).
- Progress must reach Director via `demo.note_*` → `_tutorial.note_metric`／`sync_metric_absolute` (already wired for common paths such as `clean_count`, `shelve_count`, `deliver_count`; verify the metric you need).
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
| Lesson optional `prep_restrict` | catalog | `home_hub_allow`／`shop_hub_allow`／`pages_allow`／`furniture_owned_cap` |
| `pause.tutorial.*` | `strings.csv` | Pause review submenu |
| `prep.scenario.s5` | `strings.csv` | Test scenario label |

Handoff: [`agents/skills/i18n-content/SKILL.md`](../../i18n-content/SKILL.md). Spec: [`docs/alpha/i18n.md`](../../../../docs/alpha/i18n.md).

## Hard gates (axis D)

| Phase | Blocked while forced step active |
| --- | --- |
| Prep | Start day（含大廳 Host 開工） |
| Ops | Settle／early close／test skip operate |

Review／重溫: pages only, never forced.

## Test entry

- 劇本 **5**（教學模式）：LV1、空店、$3000；intro traffic easing like scenario 1.
- Visible only when `ProductVersion.test_tools_enabled()`.
