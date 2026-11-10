---
name: playerskillvalidator
description: >-
  When adding, updating, or fixing player skills (active, passive, ultimate),
  run a mandatory conflict and gap checklist: catalog duplicates, environment
  conflicts, multiplayer Intent/authority, input, timing, save/loadout, and
  i18n handoff. Use for skill design, skill cast code, COST/loadout, skill
  Intent, 技能設計, 奧義, or 被動 changes. Do not mark the task done until the
  Validation Report has no Fail items.
---

# Player skill validator

Read this skill whenever a **player skill** (design and/or implementation) is added, updated, or fixed. Finish the workflow and emit a **Validation Report** before claiming completion.

Also read: [`references/project-map.md`](references/project-map.md) for this product’s concrete paths. Other products may replace that map without changing this file.

If player-visible names or blurbs change, also read the product’s i18n skill (this repo: [`../i18n-content/SKILL.md`](../i18n-content/SKILL.md)).

## Rules

1. **Validate before done.** Any Fail must be fixed or recorded in the Gap Registry; do not mark the task complete with open Fails.
2. **Evidence required.** Every checklist row is **Pass** / **Fail** / **N/A** plus a file path or short citation.
3. **Authority stays on Sim Authority (Host).** Client presentation must not authoritatively resolve casts, CDs, rewards, or world mutations.
4. **Do not rewrite base stats.** Skills must not permanently overwrite STR / AGI / INT; only multiply allowed derived values (move speed, Circle times, carry pieces, etc.) as the Design Catalog allows.
5. **Design Catalog is Chinese-first** when this product uses Chinese design docs; do not translate those docs as the deliverable.
6. **Stay product-agnostic in reasoning.** Use the abstract terms below; resolve paths only via the project map.

### Abstract terms

| Term | Meaning |
| --- | --- |
| Design Catalog | Authoritative skill entries (active / passive / ultimate) |
| Gap Registry | Living list of contradictions, missing systems, open numbers |
| Sim Authority | Host / server that owns simulation and settlement |
| Intent | Seat-scoped player command sent to Sim Authority |
| Seat | Controllable character slot (not the same as network peer) |
| Loadout | Equipped skill slots + COST budget + ultimate slot |

## Workflow

Run in order. Skip a step only with **N/A** and a reason (e.g. design-only change).

### 1. Scope the change

- List skill ids touched (add / update / fix).
- Note surfaces: Design Catalog, code cast path, Tuning constants, locale keys, multiplayer Intent.

### 2. A — Identity and catalog completeness

- Stable program id; correct active / passive / ultimate file or section.
- Required fields for the category: name, category, target, description, slot/COST, effect tiers, cooldown and/or command (as required by catalog rules).
- Design id matches code catalog / cast path when implementation is in scope.

### 3. B — Duplicates and skill–skill conflicts

- No colliding id, display name, or near-identical effect with another entry.
- COST / ultimate slot exclusivity and Loadout budget still hold.
- Buff stacking: same-direction %, mutual exclusion, stopped targets, skip-Circle overrides, etc.
- Confirm base STR / AGI / INT are not rewritten.

### 4. C — Environment conflicts and gaps

- Search Gap Registry for related rows: resolved vs still open; do not reopen closed rules without an explicit decision.
- Target sets explicit: guests, thieves, temps, clones, leaving actors, elites, and any “everyone” claims.
- Cross-systems: dirt, checkout commands, delivery/combo, floor drops ownership, clerk roles, economy / rating / XP side effects (no double-count).
- New contradictions → Gap Registry entry or fix in the same change.

### 5. D — Multiplayer / networked play

- Casts go through Seat Intent; Sim Authority settles CD and effects.
- Remote seats: input lines (dash / skill hold / ult hold / hotkeys) not crossed or latched on puppets.
- World agents, temps, drops, carry, list chrome: decide if a new absolute snapshot is required; avoid dual-sim and double rewards.
- Local single-process / `transport=local` co-op must not regress.

### 6. E — Input, timing, save, presentation, parity

- **Input:** conflicts with hold, direction mode, checkout arrows, cancel, hotkey slots.
- **Timing:** table CD at baseline INT; real-time vs world-time for duration/CD; consistent with time-stop skills.
- **Prep / save:** Loadout / level persistence on character sheet; mid-day change rules.
- **Presentation / i18n:** player-facing copy via locale tables (hand off to i18n skill); no new hard-coded display strings in live game code.
- **Parity:** design without code (or code without design) called out; Tuning / catalog constants match docs.
- **Acceptance:** 1–3 testable solo behaviors and, if net-relevant, 1–3 LAN behaviors; list explicit non-goals.

### 7. Emit Validation Report

Copy this template into the reply (or PR body). Replace rows as needed; keep every axis.

```markdown
## Skill validation report

- Skills: `<id…>`
- Surfaces: design / code / i18n / net

| Axis | Result | Evidence |
| --- | --- | --- |
| A Identity / catalog | Pass \| Fail \| N/A | |
| B Skill conflicts | Pass \| Fail \| N/A | |
| C Environment / gaps | Pass \| Fail \| N/A | |
| D Multiplayer | Pass \| Fail \| N/A | |
| E Input | Pass \| Fail \| N/A | |
| E Timing | Pass \| Fail \| N/A | |
| E Prep / save | Pass \| Fail \| N/A | |
| E Presentation / i18n | Pass \| Fail \| N/A | |
| E Design↔code parity | Pass \| Fail \| N/A | |
| E Acceptance notes | Pass \| Fail \| N/A | |

### Fails / follow-ups
- …

### Explicit non-goals
- …
```

## Out of scope

- Auto-balancing numeric tables or replacing human design sign-off.
- Shipping an in-game runtime “skill validator”.
- Hard-coding another product’s file paths into this `SKILL.md` (use that product’s `references/project-map.md`).
