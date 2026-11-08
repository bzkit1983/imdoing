---
name: Fix HUD freed target
overview: Fix the HUD crash when player.target is freed, harden shared keyboard/VJ hold paths against freed targets, and close TouchPad stick-ghost + crowd-fallback mismatches. Hybrid InputMode / restock double-pickup changes are deferred.
todos:
  - id: fix-hud-target
    content: Guard freed player.target in hud._refresh_pane before typed use
    status: completed
  - id: fix-player-target-guards
    content: Add is_instance_valid(+clear) in _in_dir_mode and _reset_hold
    status: completed
  - id: fix-touchpad-stick-zero
    content: Emit stick_changed(ZERO) on TouchPad _rebuild
    status: completed
  - id: align-crowd-fallback
    content: Mirror LEAVE/FLEE/TEMP skips in _crowd_near_fallback
    status: completed
  - id: smoke-kb-vj
    content: Sanity-check HUD, stick rebuild, crowd fallback, freed-target guards
    status: completed
isProject: false
---

# Fix HUD freed target + keyboard/VJ control hardening

## Reported bug

[`hud.gd`](godot/game/scripts/hud.gd) `_refresh_pane` line ~542:

```gdscript
var t: Node = p.get("target")
```

When the interact target was `queue_free`’d but `player.target` still holds the ref, assigning that Variant into a typed `Node` throws **Trying to assign invalid previously freed instance**.

## Fix 1 — HUD (must)

In [`godot/game/scripts/hud.gd`](godot/game/scripts/hud.gd) `_refresh_pane`:

- Read target without forcing a typed assign from a possibly-freed Variant.
- Treat invalid targets as none; show `hud.target_none`.

```gdscript
var t = p.get("target")
if t == null or not is_instance_valid(t):
	target_l.text = Loc.t("hud.target_none")
else:
	# existing kind branches…
```

## Fix 2 — Shared keyboard/VJ paths (freed `target`)

- [`player.gd`](godot/game/scripts/player.gd) `_in_dir_mode` (~773): `is_instance_valid(target)` before `get("kind")`; clear if invalid.
- [`player.gd`](godot/game/scripts/player.gd) `_reset_hold` (~3906): same before cashier/shelf cleanup.

## Fix 3 — VJ stick ghost after rebuild

[`touch_pad.gd`](godot/game/scripts/touch_pad.gd) `_rebuild` (~58): after a real rebuild starts, `stick_changed.emit(Vector2.ZERO)`.

## Fix 4 — Crowd fallback align

[`player.gd`](godot/game/scripts/player.gd) `_crowd_near_fallback`: skip LEAVE/FLEE/TEMP like `demo.customers_near`.

## Deferred (do not change now)

User asked to hold off:

- VJ 顯示跟偏好設定、唔因按鍵盤收埋（hybrid mouse 長按 + WASD 清潔）
- 程式清 hold 當取消、唔當短按取貨；同埋只清一次（補貨點 WASD 離開 +2 件）

These stay known issues; revisit later.

## Out of scope

- Coop multi-seat VJ routing
- Repo-wide `bool(get())` purge
- Deferred hybrid InputMode / restock abort work above

## Verify

- Target despawns while HUD refreshing — no freed-instance error; target line shows none.
- Keyboard move/dash/run/interact still work; VJ on + resize — stick recenters.
- ≥2 active guests crowd slow; LEAVE/FLEE not counted.
