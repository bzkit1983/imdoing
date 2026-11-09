# locale/

- **`strings.csv`** — UI string table (`key`, `zh_TW`, `en`)
- **`data.csv`** — game content table (skills, SKUs, furniture, dirt, …)
- Loaded together by Autoload `Loc` at runtime
- Both `*.csv.import` use `importer="keep"` so Web／desktop exports keep the raw CSV

See [`docs/alpha/i18n.md`](../../../docs/alpha/i18n.md) and agent skill [`agents/skills/i18n-content/SKILL.md`](../../../agents/skills/i18n-content/SKILL.md).
