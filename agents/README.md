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
| `i18n-content` | [`skills/i18n-content/SKILL.md`](skills/i18n-content/SKILL.md) | Chinese-first design → locale CSV (`zh_TW` + `en`) for game content |

## Conventions

- One skill = one folder + `SKILL.md`.
- Write skills in clear imperative steps; link to living specs under `docs/` instead of copying them.
- Never put the only copy of a skill under a vendor folder (`.cursor/skills`, etc.).
