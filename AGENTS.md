# Agent instructions (any coding agent)

This file is the **vendor-neutral entry point** for Cursor, Claude Code, Codex, Copilot, Aider, and similar tools. Do not assume Cursor-only paths.

## Always

- Live game project: `godot/game` (Godot 4.7). Do not add features in frozen `godot/demo_*` / `godot/alpha_v0_1`.
- Design docs under `docs/systemdesign/` stay **Chinese-first**. Do not translate design markdown into other languages.
- Player-facing strings belong in locale CSV tables, not as hard-coded display text in `.gd` / `.tscn`.

## Skills (read when relevant)

Canonical skills live under [`agents/skills/`](agents/skills/). Index: [`agents/README.md`](agents/README.md).

| Skill | When to read |
| --- | --- |
| [`agents/skills/i18n-content/SKILL.md`](agents/skills/i18n-content/SKILL.md) | Adding or editing player-visible copy: skill names/blurbs, SKU/furniture names, events, story, HUD/menu strings — even if the task is “write the design in Chinese”. |

## i18n quick pointers

- Spec: [`docs/alpha/i18n.md`](docs/alpha/i18n.md)
- UI table: `godot/game/locale/strings.csv`
- Content table: `godot/game/locale/data.csv`
- Runtime: Autoload `Loc` (`godot/game/scripts/loc.gd`) → `Loc.t("key")`
- Harvest leftovers: `python3 tools/i18n_harvest.py`

## Tool adapters (optional)

If a product requires its own instruction file (`.cursor/`, `CLAUDE.md`, `.github/copilot-instructions.md`, …), that file must only **point here** — do not duplicate skill bodies, or they will drift.
