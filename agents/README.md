# Agent skills (tool-agnostic)

Skills in this tree are **repo-owned procedures** for any coding agent. Discovery starts at the repo root [`AGENTS.md`](../AGENTS.md).

## Layout

```
agents/
  README.md                 ← this file
  skills/
    <skill-id>/
      SKILL.md              ← when-to-use + mandatory workflow
      references/           ← optional long-form conventions
```

## Available skills

| id | Path | Purpose |
| --- | --- | --- |
| `i18n-content` | [`skills/i18n-content/SKILL.md`](skills/i18n-content/SKILL.md) | Chinese-first design → locale CSV (`zh_TW` + `en` + `zh_CN` + `ja`) for game content |
| `playerskillvalidator` | [`skills/playerskillvalidator/SKILL.md`](skills/playerskillvalidator/SKILL.md) | Add／update／fix player skills → mandatory conflict／gap／multiplayer／input validation report |
| `tutorial-content` | [`skills/tutorial-content/SKILL.md`](skills/tutorial-content/SKILL.md) | Design／validate／ship one full tutorial Lesson (pages＋forced steps＋catalog／locale) → Validation Report |
| `pause-ui-chrome` | [`skills/pause-ui-chrome/SKILL.md`](skills/pause-ui-chrome/SKILL.md) | **全遊戲 UI chrome 母本**；paste [`imdoing-pause-ui-chrome.md`](skills/pause-ui-chrome/imdoing-pause-ui-chrome.md) |
| `game-ui-ux-architect` | [`skills/game-ui-ux-architect/SKILL.md`](skills/game-ui-ux-architect/SKILL.md) | UI／UX 4 階段；本專案風格 Skill＝`imdoing-pause-ui-chrome.md` |
| `ops-hud-chrome` | [`skills/ops-hud-chrome/SKILL.md`](skills/ops-hud-chrome/SKILL.md) | 營運 HUD；Gemini paste [`imdoing-ops-hud-chrome.md`](skills/ops-hud-chrome/imdoing-ops-hud-chrome.md) |

Living design specs (not skills — link, don’t duplicate):

| Spec | Path |
| --- | --- |
| UI Type Scale／Spacing | [`docs/systemdesign/uitypography.md`](../docs/systemdesign/uitypography.md) |

## Conventions

- One skill = one folder + `SKILL.md`.
- Write skills in clear imperative steps; link to living specs under `docs/` instead of copying them.
- Never put the only copy of a skill under a vendor folder (`.cursor/skills`, etc.).
