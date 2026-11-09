# Locale (living line)

- **UI:** `strings.csv` — menus, HUD chrome, pause, settings shells
- **Content:** `data.csv` — skills, SKUs, furniture, dirt, dirs, skill-group defaults; also `log.*` / `mood.*` / `err.*` / `world.*` / settle copy
- Columns: `key`, `zh_TW`, `en`, `zh_CN`, `ja` (all four required for new rows)
- Runtime: Autoload `Loc` merges both CSVs at boot (`scripts/loc.gd`)
- Default locale: `zh_TW`. Switch with `Loc.set_locale("en")` / `"zh_CN"` / `"ja"` (smoke / future Steam).
- Keys must be unique across both files.
- Keep `*.csv.import` as `importer="keep"` so Web/desktop exports still ship the raw tables.
- Design docs stay Chinese-first; sync player-facing names via [`agents/skills/i18n-content`](../../../agents/skills/i18n-content/SKILL.md).
- Docs: [`docs/alpha/i18n.md`](../../../docs/alpha/i18n.md)
