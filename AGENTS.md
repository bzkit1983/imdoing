# Agent instructions (any coding agent)

This file is the **vendor-neutral entry point** for Cursor, Claude Code, Codex, Copilot, Aider, and similar tools. Do not assume Cursor-only paths.

## Always

- Live game project: `godot/game` (Godot 4.7). Do not add features in frozen `godot/demo_*` / `godot/alpha_v0_1`.
- Design docs under `docs/systemdesign/` stay **Chinese-first**. Do not translate design markdown into other languages.
- 新小遊戲及現有小遊戲大改版，設計與評審須對照[小遊戲設計原則](docs/systemdesign/minigame-design.md)。
- Player-facing strings belong in locale CSV tables, not as hard-coded display text in `.gd` / `.tscn`.
- Growing `demo.gd`／`player.gd`／`skill_caster.gd`: follow [`docs/alpha/monolith-merge-gate.md`](docs/alpha/monolith-merge-gate.md) (new world/skill logic goes in `host/` or `player/skill_*_caster.gd`).
- After changing `godot/game/**`, `tools/test_*.py`, locale CSV, anim／props manifests, or InputMap／`project.godot`／controls: **before claiming done or suggesting push**, run `python3 tools/run_ci_static.py` and fix any FAIL (same gate as GitHub CI). Local hook bootstrap: [`docs/alpha/ci-local.md`](docs/alpha/ci-local.md).

## Skills (read when relevant)

Canonical skills live under [`agents/skills/`](agents/skills/). Index: [`agents/README.md`](agents/README.md).

| Skill | When to read |
| --- | --- |
| [`agents/skills/i18n-content/SKILL.md`](agents/skills/i18n-content/SKILL.md) | Adding or editing player-visible copy: skill names/blurbs, SKU/furniture names, events, story, HUD/menu strings — even if the task is “write the design in Chinese”. |
| [`agents/skills/playerskillvalidator/SKILL.md`](agents/skills/playerskillvalidator/SKILL.md) | Adding, updating, or fixing player skills (active／passive／ultimate), COST／loadout, skill Intent／multiplayer cast paths, or skill design conflicts — emit Validation Report before done. |
| [`agents/skills/tutorial-content/SKILL.md`](agents/skills/tutorial-content/SKILL.md) | Designing, validating, or shipping a full tutorial Lesson (pages／forced steps／triggers／`tut.*` copy／`tutorial_catalog`) — emit Validation Report before done. |
| [`agents/skills/pause-ui-chrome/SKILL.md`](agents/skills/pause-ui-chrome/SKILL.md) | **全遊戲 UI chrome 母本**（動森暖系 Cozy）；Gemini／Canva: [`imdoing-pause-ui-chrome.md`](agents/skills/pause-ui-chrome/imdoing-pause-ui-chrome.md)。Pause／HUD／Prep 色票一律對齊此檔。 |
| [`agents/skills/game-ui-ux-architect/SKILL.md`](agents/skills/game-ui-ux-architect/SKILL.md) | 遊戲 UI／UX 4 階段：資訊架構 → 線框 → 掛風格 Skill → 素材清單／生圖（唔跳步）；本專案階段 3＝`imdoing-pause-ui-chrome.md`。 |
| [`agents/skills/ops-hud-chrome/SKILL.md`](agents/skills/ops-hud-chrome/SKILL.md) | 營運 HUD；Gemini／生圖貼 [`imdoing-ops-hud-chrome.md`](agents/skills/ops-hud-chrome/imdoing-ops-hud-chrome.md)。 |
| UI 字級／間距 | [`docs/systemdesign/uitypography.md`](docs/systemdesign/uitypography.md)（Type Scale＋Spacing；色票只引用 pause-ui-chrome 母本）。 |

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
