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
| [`agents/skills/playerskillvalidator/SKILL.md`](agents/skills/playerskillvalidator/SKILL.md) | Adding, updating, or fixing player skills (active／passive／ultimate), COST／loadout, skill Intent／multiplayer cast paths, or skill design conflicts — emit Validation Report before done. |
| [`agents/skills/tutorial-content/SKILL.md`](agents/skills/tutorial-content/SKILL.md) | Designing, validating, or shipping a full tutorial Lesson (pages／forced steps／triggers／`tut.*` copy／`tutorial_catalog`) — emit Validation Report before done. |
| [`agents/skills/pause-ui-chrome/SKILL.md`](agents/skills/pause-ui-chrome/SKILL.md) | Pause menu chrome／asset pack — 動森暖系 Cozy（雙層 cream 面板、全膠囊 1.5D bevel、Focus 整顆暖金）；Gemini-ready: [`imdoing-pause-ui-chrome.md`](agents/skills/pause-ui-chrome/imdoing-pause-ui-chrome.md). |
| UI 字級／間距 | 改選單／HUD／標題字大細或 spacing 時讀 [`docs/systemdesign/uitypography.md`](docs/systemdesign/uitypography.md)（Type Scale＋Spacing；Pause 色見 pause-ui-chrome）。 |

## i18n quick pointers

- Spec: [`docs/alpha/i18n.md`](docs/alpha/i18n.md)
- UI table: `godot/game/locale/strings.csv`
- Content table: `godot/game/locale/data.csv`
- Columns: `key,zh_TW,en,zh_CN,ja` (all four required for new player-facing rows)
- Runtime: Autoload `Loc` (`godot/game/scripts/loc.gd`) → `Loc.t("key")`
- Locales: `zh_TW` (default/fallback), `en`, `zh_CN`, `ja` — in-game via Pause / Prep System language pick menu (`PlatformServices.set_locale`, `[ui] locale`); smoke with `Loc.set_locale("…")`
- Harvest leftovers: `python3 tools/i18n_harvest.py`

## Tool adapters (optional)

If a product requires its own instruction file (`.cursor/`, `CLAUDE.md`, `.github/copilot-instructions.md`, …), that file must only **point here** — do not duplicate skill bodies, or they will drift.
