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


func clock_text() -> String:
	return DayPhase.clock_text(game_hours)


func phase_text() -> String:
	return DayPhase.phase_text(phase)
