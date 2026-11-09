# Locale key conventions

Columns: `key,zh_TW,en,zh_CN,ja` (all four required for new rows).

## Tables

| File | Use |
| --- | --- |
| `godot/game/locale/strings.csv` | UI shell — pause, prep chrome, HUD labels, rating grades |
| `godot/game/locale/data.csv` | Game content — skills, SKUs, furniture, dirt, dirs, skill-set defaults, events/story/logs/moods |

Keys must be unique across **both** files. Runtime merges them in `Loc`.

## Locales

| Code | Role |
| --- | --- |
| `zh_TW` | Default + semantic source + missing-translation fallback |
| `en` | English |
| `zh_CN` | Simplified Chinese (glyphs + retained flavor) |
| `ja` | Japanese UI / game copy |

In-game: Pause / Prep System tools → `PlatformServices.cycle_locale()` (`[ui] locale`).
Endonyms (same text in every column): `locale.name.zh_TW` / `.en` / `.zh_CN` / `.ja`.
Smoke: `Loc.set_locale("zh_CN")` / `"ja"` / `"en"` / `"zh_TW"`.

## Prefixes

| Prefix | Example | Notes |
| --- | --- | --- |
| `skill.<id>.name` | `skill.carry_boost.name` | Skill title |
| `skill.<id>.blurb` | `skill.carry_boost.blurb` | Short menu description |
| `sku.<id>` | `sku.can` | Sellable SKU display name |
| `furniture.<id>` | `furniture.cashier` | Furniture display name |
| `dirt.<type>` | `dirt.trash` | Dirt type label |
| `dir.<code>` | `dir.up` | Direction label |
| `skill_set.default` | `skill_set.default` | printf template with `%d` |
| `event.<id>.title` / `.body` | (Beta) | Event cards |
| `story.<id>.line.<n>` | (Beta) | Narrative lines |
| `log.player.*` / `log.demo.*` | shipped | Action / toss / skill logs |
| `mood.*` | shipped | Guest mood / status |
| `err.*` | shipped | GameState validation errors |
| `world.*` | shipped | Registers, clerks, shelves, restock points |
| `settle.*` / `phase.*` | shipped | Day settle / phase labels |
| `prep.*` `hud.*` `pause.*` `touch.*` | shipped | UI — stay in `strings.csv` |

## Design doc ↔ runtime

- Design: Chinese name + `程式 id: \`snake_case\``.
- CSV: `skill.<id>.name` / `.blurb` with `zh_TW` + `en` + `zh_CN` + `ja` in the same change.
- GDScript catalogs keep **mechanical fields + id only**; `Skills.localize()` / helpers resolve display strings.

## Formatting

- Use `Loc.t("key", [args…])` for `%` / `%d` / `%s` templates.
- Prefer English dotted paths; never use Chinese as the key.
- Preserve placeholders and `\n` across all locales.
