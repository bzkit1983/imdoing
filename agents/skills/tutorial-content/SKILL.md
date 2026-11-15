---
name: tutorial-content
description: >-
  When designing, validating, or shipping a full tutorial Lesson (pages, forced
  steps, triggers, conditions, tut.* copy, tutorial_catalog), run the design →
  Validation Report → catalog/locale land workflow. Use for 教學, tutorial
  lesson, 教學步驟, tutorial.md, 劇本5, or tutorial content generation. Do not
  mark the task done until the Validation Report has no Fail items.
---

# Tutorial content (design → validate → ship)

Read this skill whenever a **tutorial Lesson** (or its Steps／Pages／triggers／copy) is added, updated, or completed. Finish the workflow and emit a **Validation Report** before claiming completion.

Also read: [`references/project-map.md`](references/project-map.md) for this product’s paths, and [`references/lesson-template.md`](references/lesson-template.md) for the Chinese-first draft form.

If player-visible strings change, also read [`../i18n-content/SKILL.md`](../i18n-content/SKILL.md).

**Deliverable unit:** one `TutorialLesson` (not a lone Step). Validate every Step inside, but “done” means the whole Lesson can hang on the live tutorial framework.

## Rules

1. **Validate before done.** Any Fail must be fixed or recorded in follow-ups; do not mark the task complete with open Fails.
2. **Evidence required.** Every checklist row is **Pass** / **Fail** / **N/A** plus a file path or short citation.
3. **Contract first.** Structure must match [`docs/systemdesign/tutorial.md`](../../../docs/systemdesign/tutorial.md). Do not invent a parallel schema.
4. **Design Chinese-first.** Designer notes may live under `docs/systemdesign/` or the lesson draft; player-facing copy goes through locale tables (hand off to i18n-content).
5. **Conditions must be achievable.** Prep metrics must be evaluated by TutorialDirector (see project-map). Ops metrics must be in `TaskCatalog.WIRED_METRICS` and fed via `demo.note_*` → Director `note_metric`. Unwired = Fail, or wire first in the same change.
6. **Hard-gate escape.** A forced step may block open-day (prep) or settle／skip／early-close (ops), but the player must have a clear in-phase path to complete it. Review mode is never forced.
7. **Formal tutorials do not use `task_test_mode` / `OP-TUT-*`.** Those stay test-task packs; content Lessons hang via TutorialDirector.

## Workflow

Run in order. Skip a step only with **N/A** and a reason.

### 1. Scope

- Lesson `id` (stable `tut.…` form).
- `phase`: `prep` | `ops` | `either`.
- Trigger: `when` + `scenario` / `day_index` / `flag` / `requires_done`.
- Whether this replaces a stub (e.g. `tut.stub.*`) or adds a new chain link.
- Surfaces: design draft, `tutorial_catalog.gd`, locale keys, Director wiring (if new metric).

### 2. Draft

Fill [`references/lesson-template.md`](references/lesson-template.md):

- Pages: `title_key` / `body_key` / optional `image_path` (empty or existing asset only).
- Steps: `id`, `order`, `condition` (`metric` / `op` / `target` / `filters`), `next` (empty string ends the Lesson).
- `ops_task` name／desc keys (HUD／pause task row).
- Expected player actions and hard-gate escape path.

### 3. Validate

Run axes A–H below. Emit the Validation Report (template at the end). Do not land catalog／locale while Fails remain open.

### 4. Land

After a clean report (or Fail→follow-up only with explicit deferral that does not leave the Lesson half-shipped):

1. Add／update the Lesson in [`godot/game/scripts/tutorial/tutorial_catalog.gd`](../../../godot/game/scripts/tutorial/tutorial_catalog.gd).
2. Upsert `tut.<lesson>.*` (and related) rows in `godot/game/locale/strings.csv` via i18n-content (`zh_TW`＋`en`＋`zh_CN`＋`ja`).
3. If a new Prep／Ops metric is required: wire Director／`demo.note_*` in the same change.
4. If replacing stubs or documenting a new campaign beat: touch `docs/systemdesign/tutorial.md` and／or `docs/alpha/implementation-status.md` with one Chinese sentence when useful.

### 5. Acceptance

- 1–3 testable behaviors (prefer 劇本 5 when `TEST_TOOLS`, or the Lesson’s real trigger).
- Explicit non-goals (no multiplayer sync, no art generation, etc.).

## Validation axes

| Axis | Check |
| --- | --- |
| **A Identity** | Stable `tut.…` id; `phase`／`trigger`／`pages`／`steps`／`ops_task` present; step `next` chain has no cycle; last step `next=""` |
| **B Conflicts** | No id clash with existing Lessons; every `requires_done` id exists; no `requires_done` cycle; does not steal formal path from `task_test_mode`／`OP-TUT-*` |
| **C Conditions** | Prep／Ops metrics wired (project-map); `op`／`target` sensible; `filters` match event payloads (e.g. `sku`) |
| **D Hard-gate escape** | Incomplete step blocks the right phase advance; completion path is doable in that phase; review never forced |
| **E Copy／i18n** | All title／body／task keys exist with four locales; no new hard-coded display strings in live `.gd`／`.tscn`; i18n-content handoff |
| **F UX／length** | Page count／length scannable; step count not overloaded; `image_path` empty or resource exists |
| **G Parity** | Catalog ↔ draft ↔ locale agree; stub replacement noted in docs when applicable |
| **H Acceptance** | Testable steps listed; non-goals listed |

## Validation Report template

Copy into the reply (or PR body). Keep every axis.

```markdown
## Tutorial lesson validation report

- Lesson: `<tut.…>`
- Phase: prep | ops | either
- Surfaces: design / catalog / i18n / director-wiring

| Axis | Result | Evidence |
| --- | --- | --- |
| A Identity | Pass \| Fail \| N/A | |
| B Conflicts | Pass \| Fail \| N/A | |
| C Conditions | Pass \| Fail \| N/A | |
| D Hard-gate escape | Pass \| Fail \| N/A | |
| E Copy／i18n | Pass \| Fail \| N/A | |
| F UX／length | Pass \| Fail \| N/A | |
| G Parity | Pass \| Fail \| N/A | |
| H Acceptance | Pass \| Fail \| N/A | |

### Fails / follow-ups
- …

### Explicit non-goals
- …
```

## Out of scope

- Signing off a whole opening tutorial campaign’s economy／balance in one pass (ship one Lesson at a time).
- Implementing multiplayer tutorial sync.
- Replacing i18n-content (hand off only).
- Auto-generating art (empty `image_path` or existing preview paths only).
