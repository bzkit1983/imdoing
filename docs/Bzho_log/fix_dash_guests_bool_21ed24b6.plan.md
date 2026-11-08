---
name: Fix dash guests bool
overview: Same Godot-4 Object.get → null → typed-constructor crash in `_dash_guests`. Harden the dash guest/clone scan loops with the existing null-safe helpers and a customer gate, so bool/int/float cannot explode mid-dash.
todos:
  - id: fix-dash-guests
    content: Harden _dash_guests with occupies_store gate + null-safe state/thief/stun
    status: completed
  - id: fix-dash-clone
    content: Replace bool(_vanishing) in _dash_clone with null-safe check
    status: completed
  - id: smoke-dash
    content: Confirm dash guest/clone paths no longer throw typed ctors
    status: completed
isProject: false
---

# Fix `_dash_guests` `bool()` crash

## Same class?

**Yes.** At [player.gd](godot/game/scripts/player.gd):2404:

```gdscript
if bool(c.get("is_thief")):
```

Non-customer (or property-missing) children under `_customers` → `get` returns `null` → Godot 4 `bool(null)` fails. Next lines would also explode:

- `int(c.get("state"))` (~2406)
- `float(c.get("_dash_stun_left"))` (~2409)

Same chain as earlier `customers_near` / HUD issues.

## Fix

In [`_dash_guests`](godot/game/scripts/player.gd) (~2393):

1. Skip non-customers: `if not c.has_method("occupies_store"): continue` (same gate as `demo.customers_near`).
2. Replace typed ctors with existing helpers / truthiness:
   - `if c.is_thief:` or `if _obj_str` not needed — after gate use `c.is_thief` / `c.state` direct, **or** `_obj_int` / truthy get without `bool()`.
3. Prefer direct script props after `occupies_store` gate (typed customer), mirroring `customers_near`:

```gdscript
if not c.has_method("occupies_store"):
	continue
if c.is_thief:
	continue
var st: int = c.state
if st == CustomerScript.State.LEAVE or st == CustomerScript.State.FLEE:
	continue
if float(c.get("_dash_stun_left") if c.get("_dash_stun_left") != null else 0.0) > 0.0:
	continue
```

Use `CustomerScript.State` instead of magic `7`/`9` (already preloaded on player).

## Sibling harden (same pass)

[`_dash_clone`](godot/game/scripts/player.gd) (~2429): `bool(c.get("_vanishing"))` → truthiness / null-safe (`c.get("_vanishing")` in `if`, or `_obj_int` not applicable — use `c._vanishing` if script-typed after `has_method`, else `if c.get("_vanishing"):`).

Do **not** full-repo `bool(sk.get(..., false))` Dictionary purge (defaults already safe).

## Verify

- Dash through ≥1 guest: no Error panel; KO / 衝刺交付 still works.
- Dash near leave/flee guests: skipped.
- Dash into shadow clone: vanishing skip still works.