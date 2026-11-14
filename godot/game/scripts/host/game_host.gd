extends Node2D
## Day-host contract for the living shop loop.
## `demo.gd` extends this so player/customer/HUD can rely on a stable surface
## instead of ad-hoc `has_method` discovery. M2 Session should call these too.
##
## Required overrides live in demo; defaults here are safe no-ops for probes.

const DayPhase = preload("res://scripts/host/day_phase.gd")

signal host_phase_changed(phase: String)

## prep | restock | open | closed
var phase: String = "prep"
var game_hours: float = 0.0
## Left-HUD dirty counter (guest/revenue/combo/phase).
var hud_rev: int = 0


func bump_hud() -> void:
	hud_rev += 1


func is_game_host() -> bool:
	return true


# --- Counts / lists (demo maintains) -----------------------------------------

func guest_count() -> int:
	return 0


func thief_count() -> int:
	return 0


func thieves() -> Array[Node2D]:
	return []


func shadow_clones() -> Array:
	return []


# --- Path / world ------------------------------------------------------------

func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	return PackedVector2Array([to])


func world_delta(delta: float) -> float:
	return delta


func customer_move_mult() -> float:
	return 1.0


# --- Combo / economy ---------------------------------------------------------

func combo_note_qualify(_seat: int) -> void:
	pass


func combo_break_personal(_seat: int) -> void:
	pass


func combo_personal(_seat: int) -> int:
	return 0


func combo_team() -> int:
	return 0


func record_caught(_seat: int = 0, _method: String = "any") -> void:
	pass


func combo_note_perfect(_seat: int) -> void:
	pass


func note_shelve(_seat: int, _sku: String, _n: int) -> void:
	pass


func note_deliver(_seat: int, _mode: String, _n: int = 1, _perfect: bool = false) -> void:
	pass


func note_skill_cast(_seat: int, _skill_id: String, _is_ult: bool) -> void:
	pass


func task_hud_lines(_seat: int = 0) -> Array:
	return []


func record_stolen(_items: Array) -> void:
	pass


func note_clean(_seat: int = 0) -> void:
	pass


func _on_paid(
	_amount: int,
	_from_elite: bool = false,
	_seat: int = 0,
	_actor: Node2D = null,
	_perfect: bool = true,
) -> void:
	pass


func note_angry_leave(_actor: Node2D = null) -> void:
	pass


func note_wrong_deliver(_actor: Node2D = null) -> void:
	pass


func note_dash_guest(_actor: Node2D = null) -> void:
	pass


func note_fight_fail(_actor: Node2D = null) -> void:
	pass


# --- Spawns / skills (world effects) -----------------------------------------

func spawn_dropped_box(
	_pos: Vector2,
	_sku: String,
	_n: int,
	_toss_dir: Vector2 = Vector2.ZERO,
	_toss_dist: float = -1.0,
	_on_landed: Callable = Callable(),
	_land_nudge: Vector2 = Vector2.ZERO,
) -> void:
	pass


func cast_fundraise(_level: int) -> void:
	pass


func cast_close_gate() -> void:
	pass


func cast_three_volley() -> void:
	pass


func cast_guest_dusk() -> bool:
	return false


func cast_summon_guest(_n: int) -> int:
	return 0


func cast_harvest_chives(_reg: Node, _max_n: int) -> int:
	return 0


func soothe_all(_keep: float) -> void:
	pass


func play_skill_banner(_text: String) -> void:
	pass


func play_ko_banner() -> void:
	pass


# --- Camera / coop -----------------------------------------------------------

func asking_early_close() -> bool:
	return false


func is_local_coop() -> bool:
	return false


func notify_camera_priority_idle() -> void:
	pass


func overview_camera_zoom() -> float:
	return 1.0


func shop_camera_center() -> Vector2:
	return Vector2.ZERO


func coop_camera_midpoint() -> Vector2:
	return Vector2.ZERO


func customers_near(_pos: Vector2, _radius_sq: float) -> bool:
	return false


func customers_in_radius(_origin: Vector2, _radius_sq: float) -> Array:
	return []


func clock_text() -> String:
	return DayPhase.clock_text(game_hours)


func phase_text() -> String:
	return DayPhase.phase_text(phase)


# --- Shop geometry / shelves (F3 hot-path contract) ---------------------------

func shelf_stand(_shelf: Node2D) -> Vector2:
	return Vector2.ZERO


func find_shelf(_sku: String) -> Node2D:
	return null


func shelf_has(_shelf: Node2D, _sku: String) -> bool:
	return false


func take_from_shelf(_shelf: Node2D, _sku: String) -> bool:
	return false


func nearest_shelf(_origin: Vector2) -> Node2D:
	return null


func nearest_stocked_shelf(_from: Vector2) -> Node2D:
	return null


func random_shelf_stand() -> Vector2:
	return Vector2.ZERO


func exit_pos() -> Vector2:
	return Vector2.ZERO


func door_pos() -> Vector2:
	return Vector2.ZERO


func inside_pos() -> Vector2:
	return Vector2.ZERO


func restock_for(_cat: String) -> Node2D:
	return null


func restock_holds(_except: Node) -> Dictionary:
	return {}


func sync_stock() -> void:
	pass


func sellable() -> Array[String]:
	return []


# --- Guests / checkout / pause -----------------------------------------------

func play_is_easy() -> bool:
	return false


func yes_my_lord_on() -> bool:
	return false


func pick_register(_cust: Node) -> Node2D:
	return null


func seat_locks_register(_reg: Node) -> bool:
	return false


func release_player_checkout(_guest = null) -> void:
	pass


func queue_dissat_blocked() -> bool:
	return false


func note_customer_occupy_changed(_c: Node, _occupies: bool) -> void:
	pass


func note_thief_active_changed() -> void:
	pass


func customer_list_bounds() -> Vector2i:
	return Vector2i.ZERO


func can_open_pause() -> bool:
	return true


func request_pause() -> void:
	pass


func skip_operate() -> void:
	pass


func _broadcast_seat_prompt(_seat_id: int) -> void:
	pass


# --- Loot / dirt / extra skill world effects ---------------------------------

func spawn_loot_inplace(_origin: Vector2, _piles: Array) -> void:
	pass


func spawn_loot_scatter(
	_origin: Vector2,
	_piles: Array,
	_min_r: float,
	_max_r: float,
) -> void:
	pass


func spawn_dirt_at(_at: Vector2, _dtype: String) -> bool:
	return false


func show_stolen_banner() -> void:
	pass


func cast_dark_side(_level: int) -> void:
	pass


func cast_shadow_clone(_level: int) -> void:
	pass


func deploy_calm_zone(_at: Vector2, _level: int, _seat: int) -> Node2D:
	return null


func deploy_universal_cannon(_at: Vector2, _level: int, _seat: int) -> Node2D:
	return null


func deploy_shelf_cannon(_at: Vector2, _level: int, _seat: int) -> Node2D:
	return null
