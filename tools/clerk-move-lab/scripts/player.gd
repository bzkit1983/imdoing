extends CharacterBody2D

const MoveTuning = preload("res://scripts/move_tuning.gd")

signal state_changed(state_name: String)
signal stats_changed

var carry_items: int = 0
var stamina: float = MoveTuning.stamina_max()
var on_dirt: bool = false

var _k_held: bool = false
var _k_time: float = 0.0
var _running: bool = false
var _dashing: bool = false
var _dash_dir: Vector2 = Vector2.DOWN
var _dash_left: float = 0.0
var _regen_delay: float = 0.0
var _facing: Vector2 = Vector2.DOWN
var _last_state: String = ""

@onready var _body: Polygon2D = $Body
@onready var _arrow: Polygon2D = $Arrow


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	stamina = MoveTuning.stamina_max()
	_emit_state("WALK")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical_keycode == KEY_K and not event.echo:
		if event.pressed:
			_k_held = true
			_k_time = 0.0
		else:
			if _k_held and not _running and _k_time < MoveTuning.RUN_HOLD_THRESHOLD:
				_try_dash()
			_k_held = false
			_running = false


func _physics_process(delta: float) -> void:
	if _k_held:
		_k_time += delta
		if _k_time >= MoveTuning.RUN_HOLD_THRESHOLD:
			_running = stamina > 1.0

	if _dashing:
		_tick_dash(delta)
	else:
		_tick_move(delta)

	_regen(delta)
	_update_visuals()
	stats_changed.emit()


func current_speed() -> float:
	return velocity.length()


func current_state() -> String:
	if _dashing:
		return "DASH"
	if _running and current_speed() > 8.0:
		return "RUN"
	if current_speed() > 8.0:
		return "WALK"
	return "IDLE"


func speed_mult() -> float:
	var m := MoveTuning.agi_mult()
	if carry_items > MoveTuning.CARRY_CAP_ITEMS:
		m *= MoveTuning.OVERWEIGHT_OVER_CAP_MULT
	elif carry_items >= MoveTuning.CARRY_CAP_ITEMS:
		m *= MoveTuning.OVERWEIGHT_AT_CAP_MULT
	if on_dirt:
		m *= MoveTuning.DIRT_MULT
	return clampf(m, 0.0, MoveTuning.SPEED_MAX_MULT)


func _move_axis() -> Vector2:
	var v := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v


func _tick_move(delta: float) -> void:
	var axis := _move_axis()
	if axis != Vector2.ZERO:
		_facing = axis

	var want_run := _running and axis != Vector2.ZERO
	if want_run:
		if stamina <= 0.0:
			want_run = false
			_running = false
		else:
			stamina = maxf(0.0, stamina - MoveTuning.RUN_STAMINA_PER_SEC * delta)
			_regen_delay = MoveTuning.STAMINA_REGEN_DELAY

	var walk := MoveTuning.WALK_SPEED * speed_mult()
	var target := walk * (MoveTuning.RUN_SPEED_MULT if want_run else 1.0)
	target = clampf(target, MoveTuning.SPEED_FLOOR, MoveTuning.WALK_SPEED * MoveTuning.SPEED_MAX_MULT)

	if axis == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, walk * 8.0 * delta)
	else:
		velocity = axis * target

	move_and_slide()
	_emit_state(current_state())


func _try_dash() -> void:
	if _dashing:
		return
	if stamina < MoveTuning.DASH_STAMINA_COST:
		return
	var dir := _move_axis()
	if dir == Vector2.ZERO:
		dir = _facing
	_dashing = true
	_dash_dir = dir.normalized()
	_dash_left = MoveTuning.DASH_TIME
	stamina = maxf(0.0, stamina - MoveTuning.DASH_STAMINA_COST)
	_regen_delay = MoveTuning.STAMINA_REGEN_DELAY
	_emit_state("DASH")


func _tick_dash(delta: float) -> void:
	_dash_left -= delta
	var speed := MoveTuning.DASH_DISTANCE / MoveTuning.DASH_TIME
	speed = minf(speed, MoveTuning.WALK_SPEED * MoveTuning.SPEED_MAX_MULT)
	velocity = _dash_dir * speed
	move_and_slide()
	if _dash_left <= 0.0:
		_dashing = false
		velocity *= 0.35
		_emit_state(current_state())


func _regen(delta: float) -> void:
	if _dashing or (_running and _move_axis() != Vector2.ZERO):
		return
	if _regen_delay > 0.0:
		_regen_delay -= delta
		return
	stamina = minf(MoveTuning.stamina_max(), stamina + MoveTuning.STAMINA_REGEN_PER_SEC * delta)


func _emit_state(state_name: String) -> void:
	if state_name == _last_state:
		return
	_last_state = state_name
	state_changed.emit(state_name)


func _update_visuals() -> void:
	var angle := _facing.angle() + PI / 2.0
	_arrow.rotation = angle
	if _dashing:
		_body.color = Color("f4d35e")
	elif _running:
		_body.color = Color("2a9d8f")
	elif on_dirt:
		_body.color = Color("6b4f3a")
	else:
		_body.color = Color("2a6b4a")
