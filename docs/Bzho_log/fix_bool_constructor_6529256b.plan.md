---
name: Fix bool constructor
overview: Fix the Godot 4 crash from calling `bool()` on `Object.get()` results that can be `null`, starting with the `customers_near` / crowd path and the same `temp_clerk` anti-pattern elsewhere in `godot/game`.
todos:
  - id: fix-crowd-path
    content: Fix bool() in demo.customers_near + player._crowd_near / _crowd_near_fallback
    status: completed
  - id: fix-temp-clerk-siblings
    content: Replace bool(...get("temp_clerk")) (and same-line sibling gets) in demo/player/customer/fundraise/dark_side
    status: completed
  - id: smoke-check
    content: Confirm crowd path logic still skips temp_clerk and needs ≥2 nearby customers
    status: completed
isProject: false
---

# Fix `bool()` crash in crowd / temp_clerk checks

## Cause

Godot 4 `bool()` only accepts `bool` / `int` / `float`. At [godot/game/scripts/demo.gd](godot/game/scripts/demo.gd):822:

```gdscript
if bool(c.get("temp_clerk")):
```

`Object.get()` returns `null` when the property is missing → runtime error `Nonexistent 'bool' constructor`. Call chain: `player._physics_process` → `_tick_move` → `speed_mult` → `_crowd_near` → `demo.customers_near`.

## Approach

Replace unsafe `bool(node.get(...))` with GDScript truthiness / `== true` (null is falsy). No new helper; keep changes local and readable.

- `if bool(c.get("temp_clerk")):` → `if c.get("temp_clerk"):`
- `if not bool(c.get("temp_clerk")):` → `if not c.get("temp_clerk"):`
- `return bool(g.call("customers_near", ...))` → `return g.call("customers_near", ...) == true`

## Files / sites

**Crash path (must):**
- [godot/game/scripts/demo.gd](godot/game/scripts/demo.gd) `customers_near` (~822)
- [godot/game/scripts/player.gd](godot/game/scripts/player.gd) `_crowd_near` (~729), `_crowd_near_fallback` (~741)

**Same `temp_clerk` anti-pattern (same bug class):**
- [godot/game/scripts/demo.gd](godot/game/scripts/demo.gd) ~712, ~751, ~985
- [godot/game/scripts/player.gd](godot/game/scripts/player.gd) ~1983, ~2291, ~2353
- [godot/game/scripts/customer.gd](godot/game/scripts/customer.gd) ~1362
- [godot/game/scripts/fundraise.gd](godot/game/scripts/fundraise.gd) ~37 (also drop `bool()` on sibling `is_thief` on that line)
- [godot/game/scripts/dark_side.gd](godot/game/scripts/dark_side.gd) ~27 (also drop `bool()` on sibling `is_thief` / `is_elite` on that line)

Out of scope: repo-wide `bool()` cleanup (`Dictionary.get(..., false)`, typed method returns). Those are usually safe; this pass stays on the reported crash + identical `temp_clerk` Object.get pattern.

## Verify

- Walk near ≥2 customers so `_crowd_near` → `customers_near` runs; no Error panel spam.
- Crowd slow +「唔該借借」still apply only when ≥2 non-temp-clerk customers are in radius.