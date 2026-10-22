# Runtime performance audit — `godot/game/scripts`

- **Tip audited:** `origin/main` @ `19261b595861d6ccd7fffc3dec86724d9278fbab` (v1.0 living line; Align design docs with toss restock and box-hit KO. #40)
- **Date:** 2026-10-22
- **Scope:** Hot paths in `player.gd`, `customer.gd`, `demo.gd`, `pathfinder.gd`, `hud.gd`, `voxel_sprite.gd`, `loc.gd` (plus closely coupled `box_stack.gd` / `cashier.gd` / `clerk.gd` / `drop_flight.gd` / `inventory.gd`)
- **Floor:** Switch 1 as performance target (see `docs/alpha/tech-review-v0.1.md` §3)
- **Scale today:** guest cap 10–15 (`game_state.guest_cap`), thief cap 2, dirt cap 6; path grid ~1.2k–4.5k cells depending on shop LV

This is a read-only findings list. Suggested fixes are directional; none are applied here.

---

## Already optimized (do not re-litigate)

| Optimization | Evidence | Effect |
| --- | --- | --- |
| **Dirty HUD (right panel)** | `player._hud_fingerprint` / `_emit_stats_if_changed` (`player.gd` 650–689); `hud._right_dirty` + `_mark_right_dirty` (`hud.gd` 11, 44, 60–61, 185–189) | Right-panel `ItemList` / labels only rebuild when fingerprint changes, not every frame. |
| **Dirty HUD (left panel writes)** | `hud._left_fp` gate before assigning label text (`hud.gd` 155–182) | Label node writes skipped when clock/guests/etc. unchanged. **Note:** computation before the gate is still every frame — see finding H1. |
| **Customer / thief label dirty sync** | `_shown_*` caches + `_sync_labels` (`customer.gd` 43–52, 712–770) | Label `.text` / bar size / anim only written when values change. |
| **Shelf SKU index** | `_shelves_by_sku` + `stock_sku_changed` (`demo.gd` 33–34, 590–668; `shelf.gd` signal) | `find_shelf(sku)` is O(list for that SKU) with lazy invalid prune, not O(all shelves). |
| **CJK font subset** | `NotoSansTC-Game.otf` ≈170KB; `docs/alpha/fonts-subset.md`; `ui_font.gd` preloads subset face | Avoids shipping full ~5.5MB NotoSansTC at runtime. |
| **SpriteFrames cache** | `voxel_sprite._frames_cache` (`voxel_sprite.gd` 11, 112–148) | Character `AnimatedSprite2D` frames built once per `char_id`, shared across instances. |
| **Voxel apply short-circuit** | `Vox.apply` meta `vox_id`/`vox_k` (`voxel_sprite.gd` 72–74) | Static sprite re-apply no-ops when id+facing unchanged. |
| **Path stuck / goal hysteresis** | Customer/clerk repath only if path empty or goal moved >18px (`customer.gd` 383–386; `clerk.gd` 246–249) | Avoids A* every physics tick while walking a stable goal. |

Tech-review §3 still lists **path throttle + object pools** as open P1 work; the items below are the concrete gaps on the current tip.

---

## Findings

### 1. Interactable scan uses sqrt + string kind every physics frame

| | |
| --- | --- |
| **Severity** | **P1** |
| **Where** | `player.gd:_update_target` (999–1033), called from `_physics_process` (637) |
| **Why it costs** | Per physics frame, O(N) over `interactables` (shelves + restocks + cashiers + dirts + thieves + dropped boxes). Each candidate: `Vector2.length()` (sqrt), `normalized()`, up to **3×** `String(node.get("kind"))` allocations, plus facing dot. N grows with drops/dirt; typical ~15–40. |
| **Suggested fix** | Cache `kind` as a typed property / int enum on interactables; use `distance_squared_to` + compare against `INTERACT_RANGE²`; early-out with a coarse spatialize (grid buckets or “near player” list updated on move cell change). Skip full scan while `_fighting` already returns early — extend that to aim/slip if target freeze is OK. |
| **Risk** | Targeting feel (facing cone, dirt/thief/cashier specials). Regress interact priority when many drops overlap. |

```999:1025:godot/game/scripts/player.gd
func _update_target() -> void:
	if _fighting:
		return
	var best: Node2D = null
	var best_score := -1.0
	for node in interactables:
		# ...
		var dist := to_obj.length()
		# ...
		var dot := facing.dot(to_obj.normalized())
		if String(node.get("kind")) == "dirt" and _dirt_areas.has(node):
```

---

### 2. HUD fingerprint rebuilds inventory groups every physics frame

| | |
| --- | --- |
| **Severity** | **P1** |
| **Where** | `player.gd:_hud_fingerprint` (650–681) → `_emit_stats_if_changed` (684–689) every `_physics_process` (647) |
| **Why it costs** | Always allocates: `inventory.grouped()` builds `Array[Dictionary]` O(items) (`inventory.gd` 44–51); `PackedStringArray` + `%` format string every frame. Emit is gated, but **alloc+scan is not**. Carry can be dozens of SKU slots (boxes × `BOX_SIZE`). |
| **Suggested fix** | Dirty fingerprint only when inventory/target/stamina/hold/move-state change (signals or int revision counters). Or compute a cheap numeric hash (counts + target instance_id) without string join. |
| **Risk** | Missed HUD updates if a mutation path forgets to bump dirty. |

---

### 3. Left HUD still does O(C) guest/thief scans every process frame

| | |
| --- | --- |
| **Severity** | **P1** |
| **Where** | `hud.gd:_sync_left` (155–182) via `_process` (91–93); `demo.guest_count` (697–705); `demo.thief_count` → `thieves()` (708–724) |
| **Why it costs** | Fingerprint **write** is cached, but every frame still: `guest_count()` walks all customers with `has_method`/`call`; `thief_count()` allocates a new `Array[Node2D]` via `thieves()` then walks again; `_skill_cd_text()` rebuilds loadout strings. Cost ≈ O(C) + alloc/frame even when UI text is unchanged. |
| **Suggested fix** | Maintain running `guest_n` / `thief_n` on spawn/exit/state change; cache skill CD text with 0.25s snap or dirty from player CD ticks; move left sync behind the same dirty bit as right, or only rebuild fingerprint inputs when counters change. |
| **Risk** | Counter drift if despawn/state paths miss increments. |

```155:171:godot/game/scripts/hud.gd
func _sync_left() -> void:
	# ...
	var guests_n := int(game.guest_count())
	var thieves_n := int(game.call("thief_count"))
	# ...
	var skills_txt := _skill_cd_text()
	var fp := "%s|%s|%d|%d|%d|%d|%s|%s|%s|%.2f" % [
```

```716:724:godot/game/scripts/demo.gd
func thieves() -> Array[Node2D]:
	var out: Array[Node2D] = []
	if _customers == null:
		return out
	for c in _customers.get_children():
		if bool(c.get("is_thief")):
			out.append(c)
	return out
```

---

### 4. `thieves()` allocates a fresh array on every caller

| | |
| --- | --- |
| **Severity** | **P1** |
| **Where** | `demo.thieves` (716–724); callers: `thief_count` (HUD every frame), `_thief_for_toss` (1135–1148), `player._try_dash_thief` (1229–1240) |
| **Why it costs** | O(C) scan + heap `Array` alloc per call. Dash path also does `get_first_node_in_group("game")` + `call("thieves")` duck dispatch every dash physics tick. |
| **Suggested fix** | Keep `_thieves: Array[Node2D]` updated on spawn/`tree_exiting` (same pattern as `_add_interactable`). Dash/toss iterate the maintained list. |
| **Risk** | Stale refs if exit disconnect missed (mitigate with `is_instance_valid`). |

---

### 5. Customer `_sync_labels` rebuilds shopping string every physics frame

| | |
| --- | --- |
| **Severity** | **P1** |
| **Where** | `customer.gd:_physics_process` ends with `_sync_labels()` (233); `_list_label_text` (697–709) |
| **Why it costs** | Per customer × per physics frame: allocate `PackedStringArray`, `Tuning.sku_name` per shopping/cart SKU, `"、".join(...)`, then compare to `_shown_list`. Dirty write works; **string build always runs**. At 15 guests × ~4–8 SKUs this is steady GC pressure (tech-review’s original Switch concern). |
| **Suggested fix** | Rebuild list text only when `shopping`/`cart`/`raided` change (revision int). Mood/bar already cheap once list is skipped. |
| **Risk** | Stale list if a mutation forgets bump; keep bump next to `cart.append` / `shopping.remove_at`. |

---

### 6. Customer pathfinding storms on seek / queue / leave

| | |
| --- | --- |
| **Severity** | **P1** (tech-review open item) |
| **Where** | `customer._follow_to` (379–413); `pathfinder.find_path` / `_open_cell` (`pathfinder.gd` 27–77); seek calls `find_shelf` every tick (249) |
| **Why it costs** | A* `get_point_path` on up to ~1k–4k cell grids; each endpoint `_open_cell` can ring-search O(rad²) up to rad 13 (~700 cell tests) when standing on solid. Stuck >0.35s clears route → repath. Many customers seeking/leaving simultaneously = multi-A* same frame. `find_shelf` is indexed but still invoked every seek frame. |
| **Suggested fix** | Path request throttle / shared budget (e.g. max 2–3 A* per frame, queue rest); cache last path by `(cell_from, cell_to)`; only re-`find_shelf` when shelf empties or timer; prefer `distance_squared` in follow loops. |
| **Risk** | Guests hesitate or stack if throttle too aggressive; door leave timing. |

```60:77:godot/game/scripts/pathfinder.gd
func _open_cell(p: Vector2) -> Vector2i:
	var id := _world_to_cell(p)
	if _is_open(id):
		return id
	# ring search rad 1..13
	for rad in range(1, 14):
		for dx in range(-rad, rad + 1):
			for dy in range(-rad, rad + 1):
```

---

### 7. Queue tick re-enqueues and linear-finds every frame

| | |
| --- | --- |
| **Severity** | **P2** (borderline P1 under many cashiers/queues) |
| **Where** | `customer._tick_queue` (353–368) |
| **Why it costs** | Every queued customer every frame: `reg.enqueue(self)` (idempotent but `customer in queue` is O(Q)), `queue.find(self)` O(Q), then `_follow_to` (possible A*). |
| **Suggested fix** | Cache queue index; update on enqueue/dequeue only; follow slot without re-find. |
| **Risk** | Wrong slot if queue mutates without notifying — centralize in `cashier.dequeue`/`enqueue`. |

```353:363:godot/game/scripts/customer.gd
func _tick_queue(delta: float, td: float) -> void:
	# ...
	reg.enqueue(self)
	var idx: int = int(reg.queue.find(self))
	# ...
	var slot: Vector2 = reg.slot_position(idx)
	if _follow_to(slot, delta):
```

---

### 8. Per-frame dirt prune + `on_dirt()` from move and visuals

| | |
| --- | --- |
| **Severity** | **P2** |
| **Where** | `customer.on_dirt` (83–90) every physics when on dirt path (182); `player._prune_dirt` / `_has_dirt_type` (208–220); `player._update_visuals` → `on_dirt()` (1739); `speed_mult` → `on_dirt()` (434) |
| **Why it costs** | Rebuilds `Array[Node]` keep-list frequently; player can prune multiple times per physics frame (status, regen, move, visuals). Dirt count is small (cap 6) so absolute cost is modest, but it’s pure waste alloc. |
| **Suggested fix** | Prune only on `exit_dirt` / `tree_exiting`; cache `on_dirt` bool; single `_dirt_flags` bitset for trash/puddle/vomit. |
| **Risk** | Freed Area2D left in list if disconnect missed — keep `is_instance_valid` on use. |

---

### 9. Player buff / world-clock recomputes loadout every frame

| | |
| --- | --- |
| **Severity** | **P2** |
| **Where** | `_tick_buffs` (784–800) → `_world_clock_now` / `_customer_move_mult_now` (716–773); `_customer_move_kind` / `_cust_move_pct` rescan `_loadout()`; `game_state.loadout` allocates new `Array[Dictionary]` (547–554) |
| **Why it costs** | Nested loops over buff queue × loadout slots × string compares every physics frame, even with empty buffs (still calls `_world_clock_now`). `_loadout()` allocates when `stats` is set. |
| **Suggested fix** | Cache `clock_scale` / `customer_move_mult` when buffs/CD/loadout change; cache loadout array until slots change. |
| **Risk** | Stale mult if buff apply path skips cache invalidate. |

---

### 10. `get_first_node_in_group("game")` on hot / semi-hot paths

| | |
| --- | --- |
| **Severity** | **P2** |
| **Where** | `player._asking_early` (552–554) **every** `_physics_process` (601); also `_try_dash_thief`, drop, fight, skills (many sites) |
| **Why it costs** | Group lookup + method checks every physics frame for early-close; dash adds another lookup. Should be a cached `game` ref from spawn (`customer` already stores `_game`). |
| **Suggested fix** | `var game: Node` set in `demo._make_player` / `_begin_day`; null on clear. |
| **Risk** | Stale after world rebuild if not cleared in `_clear_world`. |

---

### 11. Floor is one Sprite2D per cell

| | |
| --- | --- |
| **Severity** | **P1** (memory / draw on LV3; load hitch on day start) |
| **Where** | `demo._floor` (818–829) |
| **Why it costs** | O(grid_w × grid_h) nodes: 100 @ 10×10, **400 @ 20×20** LV3. Each `Vox.sprite("floor_tile")` + child under y-sorted world. Day start hitch + ongoing 2D transform/canvas item cost. |
| **Suggested fix** | Single tiled `TextureRect` / `Sprite2D` with region repeat, `TileMap`, or MultiMesh; or one mesh. |
| **Risk** | Visual/y-sort differences vs per-tile sprites; art pipeline change. |

```818:829:godot/game/scripts/demo.gd
func _floor() -> void:
	var step := StateScript.CELL
	var x := 0.0
	while x < FLOOR_SIZE.x - 0.5:
		var y := 0.0
		while y < FLOOR_SIZE.y - 0.5:
			var tile := Vox.sprite("floor_tile", 0)
			# ...
			_world.add_child(tile)
```

---

### 12. Toss landing shelf scan ignores SKU index

| | |
| --- | --- |
| **Severity** | **P2** (event-driven; rare) |
| **Where** | `demo._shelf_for_toss` (1161–1177); `_thief_for_toss` uses `thieves()` (1135–1148) |
| **Why it costs** | O(shelves) with `can_accept` `call` + string sku get. Fine at current shelf counts; inconsistent with indexed `find_shelf`. Thief hit also pays `thieves()` alloc (finding 4). |
| **Suggested fix** | Candidate shelves = `_shelves_by_sku.get(sku, [])` plus empty shelves of matching category (maintain `_empty_by_cat` or scan empties only); thief list = maintained array. |
| **Risk** | Wrong shelf if index lags `add_items` (signal already maintains index). |

---

### 13. Dirt spawn rejection loop is O(attempts × obstacles)

| | |
| --- | --- |
| **Severity** | **P2** |
| **Where** | `demo._try_spawn_dirt` / `_blocked_rect` (958–986), timer from `_process` (584–587) |
| **Why it costs** | Up to 28 attempts × (all furniture rects + all dirts). Occasional, not per-frame continuous. |
| **Suggested fix** | Free-cell grid / spatial hash; fewer attempts with backoff. |
| **Risk** | Spawn bias if grid coarse. |

---

### 14. `box_stack` redraws every process frame

| | |
| --- | --- |
| **Severity** | **P1** |
| **Where** | `box_stack.gd` 13–14, 17–24 |
| **Why it costs** | Unconditional `queue_redraw()` every frame; `_draw` calls `inventory.boxes()` (allocates run dictionaries) and `Vox.texture` every redraw even when inventory unchanged. |
| **Suggested fix** | Redraw only on inventory mutation (signal/revision); cache box runs. |
| **Risk** | Missed redraw if take/remove paths don’t notify. |

```13:24:godot/game/scripts/box_stack.gd
func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	# ...
	var boxes: Array = inventory.boxes()
```

---

### 15. Cashier label rewritten every process frame

| | |
| --- | --- |
| **Severity** | **P2** |
| **Where** | `cashier.gd:_process` (52–55) |
| **Why it costs** | Format string + Label.text assign every frame per register even when queue size unchanged. |
| **Suggested fix** | Update on enqueue/dequeue only (mirror customer dirty labels). |
| **Risk** | None if all queue mutations go through enqueue/dequeue. |

---

### 16. Drop flight reallocates trail points every frame

| | |
| --- | --- |
| **Severity** | **P2** |
| **Where** | `drop_flight.gd:_process` (36–44) |
| **Why it costs** | New `PackedVector2Array` per flight per frame; short-lived (toss / loot scatter). Spikes when KO scatters many piles. |
| **Suggested fix** | Mutate existing `PackedVector2Array` in place (`set` two points); pool flight nodes (tech-review object-pool P1). |
| **Risk** | Low. |

---

### 17. Clerk restock job search is O(shelves × SKUs) when idle

| | |
| --- | --- |
| **Severity** | **P2** |
| **Where** | `clerk._find_job` / `_skus_on_shelves` / `_reserved_by_others` (`clerk.gd` 137–219) |
| **Why it costs** | While seeking a job (not every frame once pathing), rescans all shelves + sibling clerks. Fine for 1–2 clerks; scales poorly if hire cap rises. |
| **Suggested fix** | Reuse `_shelves_by_sku` / empty-shelf lists; throttle job search to 2–4 Hz. |
| **Risk** | Two clerks pick same shelf without reservation — reservation already exists, keep it. |

---

### 18. Loc / UI font — not hot-path critical

| | |
| --- | --- |
| **Severity** | **P2** (loc) / **already OK** (font) |
| **Where** | `loc.t` (84–88); `ui_font.apply_label`; HUD uses Loc when left fp changes |
| **Why it costs** | `Loc.t` is O(1) dict lookup + optional `%` — fine. CSV parse only at reload. Font subset already addresses Switch memory. Viewport `size_changed` → full `_apply_cjk_fonts` tree walk (`hud.gd` 43, 64–79) can hitch on rotate/resize. |
| **Suggested fix** | Debounce font re-apply; avoid Loc in per-frame fingerprint construction (prefer raw numbers in fp, Loc only on write). |
| **Risk** | Low. |

---

### 19. Player visuals / skill menu touch every physics frame

| | |
| --- | --- |
| **Severity** | **P2** |
| **Where** | `_update_visuals` (1712–1741); skill menu `set_slots(_loadout(), _cd)` when open (642–645) |
| **Why it costs** | `Vox.play_anim` mostly no-ops when anim key stable (customer caches `shown_anim`; player does not — relies on `spr.animation != key`). Tint always assigned. Open skill menu rebuilds slots from loadout each frame. |
| **Suggested fix** | Same shown-anim/tint cache as customer; set_slots only when loadout/CD display changes. |
| **Risk** | Anim stickiness if cache key wrong. |

---

### 20. Duck-typed `call`/`has_method` on game host

| | |
| --- | --- |
| **Severity** | **P2** (maintainability + micro cost) |
| **Where** | Widespread in `customer.gd` / `clerk.gd` / `player.gd` (`_game.call("find_path"…)`, `world_delta`, etc.) |
| **Why it costs** | Per-call method name lookup vs typed API; adds up across all AI bodies. Tech-review already flags God-object / duck typing. |
| **Suggested fix** | Typed `GameSession` facade or direct property access for hot helpers (`find_path`, `world_delta`, `customer_move_mult`). |
| **Risk** | Refactor blast radius across scripts. |

---

## Priority summary

| Sev | Count | Themes |
| --- | --- | --- |
| **P0** | **0 new** | Prior P0s (dirty HUD writes, SKU index, font subset) are done on this tip. |
| **P1** | **7** | Interactable scan; HUD fingerprint/left compute; `thieves()` alloc; customer list string rebuild; path storms; per-cell floor; box_stack redraw. |
| **P2** | **13** | Queue re-find; dirt prune; buff/loadout; group lookup; toss shelf scan; dirt spawn; cashier label; drop trail; clerk jobs; Loc resize; player visual/menu; duck calls. |

**Highest leverage next (Switch floor):** (1) stop left-HUD / `thieves()` / fingerprint **alloc before dirty gate**, (2) path request budget, (3) floor tiling, (4) box_stack dirty redraw, (5) customer list-text dirty build.

---

## Evidence map (quick)

| Area | File lines (approx.) |
| --- | --- |
| Player physics hub | `player.gd` 600–647 |
| Interactables | `player.gd` 999–1033; `demo.gd` 1004–1014 |
| Customer AI + labels | `customer.gd` 170–233, 379–413, 697–770 |
| Spawn / thieves / shelf index / toss | `demo.gd` 557–724, 792–815, 1017–1177 |
| Pathfinder | `pathfinder.gd` entire |
| HUD dirty | `hud.gd` 91–99, 155–258 |
| Frames cache | `voxel_sprite.gd` 11, 112–148 |
| Font subset | `ui_font.gd` 7; `docs/alpha/fonts-subset.md` |
