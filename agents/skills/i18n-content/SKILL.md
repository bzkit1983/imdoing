---
name: i18n-content
description: >-
  When adding or editing player-visible game copy (skill names/descriptions, SKU
  or furniture names, events, story lines, HUD/menu strings), sync locale CSV
  tables even if the task is Chinese-first design. Use for i18n, translation,
  Loc.t, strings.csv, data.csv, or multilingual content.
---

# i18n content (Chinese-first → locale tables)

Read this skill whenever player-facing text changes. Design docs stay Chinese; runtime uses keys + CSV.

Also read: [`docs/alpha/i18n.md`](../../../docs/alpha/i18n.md) and [`references/key-conventions.md`](references/key-conventions.md).

## Rules

1. **Design markdown stays Chinese.** Do not translate `docs/systemdesign/*.md` into English (or other locales) as the deliverable.
2. **Every player-visible string needs a stable English key** and rows in the right CSV with **`zh_TW`, `en`, `zh_CN`, and `ja`** all filled.
3. **Runtime must call `Loc.t("…")`** (or a helper that does). Do not leave new Chinese/English/Japanese display literals in `godot/game` scripts/scenes as the source of truth.
4. **Do not edit frozen demos** (`godot/demo_*`, `godot/alpha_v0_1`).

## Workflow

1. Confirm or add a stable **程式 id** on the design entry (e.g. `程式 id: \`carry_boost\``).
2. Choose the table:
   - UI chrome (menus, HUD shell, dialogs) → `godot/game/locale/strings.csv`
   - Game content (skills, SKUs, furniture, dirt, events, story, logs, moods) → `godot/game/locale/data.csv`
3. Upsert CSV rows: `key,zh_TW,en,zh_CN,ja`
   - Semantic source: `zh_TW` (consult `en` when helpful).
   - `zh_CN`: Traditional→Simplified glyphs; keep Cantonese/meme flavor where that is the design voice.
   - `ja`: Natural Japanese UI/game copy; keep `%s` / `%d` / `%.0f` / `%%` and `\n`.
   - Newlines as `\n`; fields with commas must be double-quoted.
   - No empty locale cells (except intentionally blank keys such as `hud.banner`).
4. Wire code: `Loc.t("skill.<id>.name")`, `Tuning.sku_name(id)`, `state.furniture_name(type)`, `Skills.localize(sk)`, etc.
5. If new CJK/kana glyphs appear, regenerate the font subset per [`docs/alpha/fonts-subset.md`](../../../docs/alpha/fonts-subset.md) (JP source preferred).
6. Run `python3 tools/i18n_harvest.py` and clear any new leftover literals you introduced.
7. Optional smoke: `Loc.set_locale("zh_CN")` / `"ja"` / `"en"` / `"zh_TW"`.

## Adding another locale later

Add a column to **both** CSV headers and fill every row. `Loc` loads locales from the header dynamically. Keep `zh_TW` as semantic source and fallback.

## Out of scope

- Translating internal designer notes (e.g. SFX catalog trigger labels) unless they become player-visible.

## Language switching (shipped)

Players cycle locales in **Pause → Language** and **Prep → System tools** via `PlatformServices.cycle_locale()` (`[ui] locale` in `user://settings.cfg`). Endonym labels use `locale.name.<code>` (same text in every CSV column).
