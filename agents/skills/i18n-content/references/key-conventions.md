# Locale key conventions

Columns: `key,zh_TW,en` (more locale columns allowed later).

## Tables

| File | Use |
| --- | --- |
| `godot/game/locale/strings.csv` | UI shell — pause, prep chrome, HUD labels, rating grades |
| `godot/game/locale/data.csv` | Game content — skills, SKUs, furniture, dirt, dirs, skill-set defaults, future events/story/logs/moods |

Keys must be unique across **both** files. Runtime merges them in `Loc`.

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
| `log.player.*` / `log.demo.*` | shipped (wave 2) | Action / toss / skill logs |
| `mood.*` | shipped (wave 2) | Guest mood / status |
| `err.*` | shipped (wave 2) | GameState validation errors |
| `world.*` | shipped (wave 2) | Registers, clerks, shelves, restock points |
| `settle.*` / `phase.*` | shipped (wave 2) | Day settle / phase labels |
| `prep.*` `hud.*` `pause.*` `touch.*` | existing + wave 2 | UI — stay in `strings.csv` |

## Design doc ↔ runtime

- Design: Chinese name + `程式 id: \`snake_case\``.
- CSV: `skill.<id>.name` / `.blurb` from that Chinese + English translation in the same change.
- GDScript catalogs keep **mechanical fields + id only**; `Skills.localize()` / helpers resolve display strings.

## Formatting

- Use `Loc.t("key", [args…])` for `%` / `%d` / `%s` templates.
- Prefer English dotted paths; never use Chinese as the key.
