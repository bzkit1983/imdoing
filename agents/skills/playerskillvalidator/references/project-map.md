# Project map (imdoing / godot/game)

Bindings for abstract terms in [`../SKILL.md`](../SKILL.md). Other products replace this file only.

## Design Catalog

| Kind | Path |
| --- | --- |
| Shared COST / loadout rules | [`docs/systemdesign/playerskills.md`](../../../../docs/systemdesign/playerskills.md) |
| Active | [`docs/systemdesign/playeractiveskills.md`](../../../../docs/systemdesign/playeractiveskills.md) |
| Passive | [`docs/systemdesign/playerpassiveskills.md`](../../../../docs/systemdesign/playerpassiveskills.md) |
| Ultimate | [`docs/systemdesign/playerultimateskills.md`](../../../../docs/systemdesign/playerultimateskills.md) |
| Stats / purity | [`docs/systemdesign/playerstats.md`](../../../../docs/systemdesign/playerstats.md) |
| Actions / input modes | [`docs/systemdesign/playeraction.md`](../../../../docs/systemdesign/playeraction.md), [`docs/systemdesign/control.md`](../../../../docs/systemdesign/control.md) |

## Gap Registry

- [`docs/systemdesign-gaps.md`](../../../../docs/systemdesign-gaps.md)
- Status mirror: [`docs/alpha/implementation-status.md`](../../../../docs/alpha/implementation-status.md)

## Multiplayer (Sim Authority / Intent / Seat)

- Spec: [`docs/systemdesign/multiplayer.md`](../../../../docs/systemdesign/multiplayer.md) (§12; skill Intent / M2.5)
- Session: [`godot/game/scripts/session/session_service.gd`](../../../../godot/game/scripts/session/session_service.gd)
- Seats: [`godot/game/scripts/session/seat_table.gd`](../../../../godot/game/scripts/session/seat_table.gd)
- Transport: [`godot/game/scripts/session/net_transport.gd`](../../../../godot/game/scripts/session/net_transport.gd)
- Day host / intents: [`godot/game/scripts/demo.gd`](../../../../godot/game/scripts/demo.gd) (LAN tick, Intent, agent/stock/carry/prompt)

## Code catalog and cast

| Concern | Path |
| --- | --- |
| Skill definitions / localize | [`godot/game/scripts/skills.gd`](../../../../godot/game/scripts/skills.gd) |
| Cast / hold / hotkey / CD | [`godot/game/scripts/player.gd`](../../../../godot/game/scripts/player.gd) |
| Loadout on sheet | [`godot/game/scripts/game_state.gd`](../../../../godot/game/scripts/game_state.gd) (`loadout`, save) |
| Prep UI equip | [`godot/game/scripts/prep_menu.gd`](../../../../godot/game/scripts/prep_menu.gd), [`godot/game/scripts/prep/`](../../../../godot/game/scripts/prep/) |
| Related units | [`godot/game/scripts/shadow_clone.gd`](../../../../godot/game/scripts/shadow_clone.gd), [`godot/game/scripts/universal_cannon.gd`](../../../../godot/game/scripts/universal_cannon.gd), [`godot/game/scripts/customer.gd`](../../../../godot/game/scripts/customer.gd) (Dark Side temp) |

## Timing / tuning

- [`godot/game/scripts/tuning.gd`](../../../../godot/game/scripts/tuning.gd)
- World clock vs real seconds: design notes in ultimate / multiplayer docs; verify in cast code paths above.

## Save / prep

- [`docs/systemdesign/savesystem.md`](../../../../docs/systemdesign/savesystem.md)
- [`docs/systemdesign/storepreparationphase.md`](../../../../docs/systemdesign/storepreparationphase.md)
- Runtime: `game_state.gd` save／loadout; pause/prep menus for mid-session constraints.

## i18n handoff

- Skill: [`agents/skills/i18n-content/SKILL.md`](../../i18n-content/SKILL.md)
- Content table: `godot/game/locale/data.csv` (`skill.<id>.*`)
- UI table: `godot/game/locale/strings.csv`
- Spec: [`docs/alpha/i18n.md`](../../../../docs/alpha/i18n.md)

## Environment cross-docs (axis C)

Use when the skill touches that system:

| System | Doc |
| --- | --- |
| Dirt / clean | `docs/systemdesign/cleaningsystem.md` |
| Checkout | `docs/systemdesign/cashiersystem.md` |
| Delivery / combo | `docs/systemdesign/customerdelivery.md`, `docs/systemdesign/fetchcombo.md` |
| Thief | `docs/systemdesign/thiefsystem.md` |
| Clerks | `docs/systemdesign/clerksystem.md` |
| Rating / XP | `docs/systemdesign/ratingsystem.md`, `docs/systemdesign/ecosystem.md` |
| Drops / replenish | `docs/systemdesign/replenishmentsystem.md` |

## Live vs frozen

- Live game only: `godot/game`
- Do not implement skills in `godot/demo_*` or `godot/alpha_v0_1`
