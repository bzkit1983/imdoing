extends CharacterBody2D

const Tuning = preload("res://scripts/act_tuning.gd")
const CircleScript = preload("res://scripts/loading_circle.gd")

signal stats_changed
signal log_line(text: String)

var agi: int = Tuning.AGI_DEFAULT
var carry_sku: String = ""
var carry_count: int = 0
var facing: Vector2 = Vector2.RIGHT
var hold_progress: float = 0.0
var blocked_mismatch: bool = false
var target: Node2D = null
var interactables: Array[Node2D] = []

var _j_held: bool = false
var _pickup_used: bool = false
var _circle: Node2D


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	_circle = CircleScript.new()
	_circle.name = "LoadingCircle"
	add_child(_circle)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		if event.physical_keycode == KEY_J:
			_j_held = event.pressed
			if not event.pressed:
				_reset_hold()
				_pickup_used = false
		elif event.pressed:
			_try_sku_hotkey(event.physical_keycode)


func _physics_process(delta: float) -> void:
	_move(delta)
	_update_target()
	_tick_action(delta)
	if _circle:
		_circle.progress = hold_progress
		_circle.blocked = blocked_mismatch
	stats_changed.emit()


func _move(delta: float) -> void:
	var axis := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	if axis.length_squared() > 1.0:
		axis = axis.normalized()
	if axis != Vector2.ZERO:
		facing = axis
		if _j_held:
			_reset_hold()
	velocity = axis * Tuning.WALK_SPEED
	move_and_slide()
	var arrow: Node = get_node_or_null("Arrow")
	if arrow:
		arrow.rotation = facing.angle() + PI / 2.0


func _update_target() -> void:
	var best: Node2D = null
	var best_score := -1.0
	for node in interactables:
		if node == null:
			continue
		var to_obj: Vector2 = node.global_position - global_position
		var dist := to_obj.length()
		if dist > Tuning.INTERACT_RANGE or dist < 0.001:
			continue
		var dot := facing.dot(to_obj.normalized())
		if dot < Tuning.FACE_DOT:
			continue
		var score := dot * 2.0 - dist / Tuning.INTERACT_RANGE
		if score > best_score:
			best_score = score
			best = node
	if target != best:
		_reset_hold()
		_pickup_used = false
	target = best


func _tick_action(delta: float) -> void:
	blocked_mismatch = false
	if target == null or not _j_held:
		if not _j_held:
			hold_progress = 0.0
		return

	var kind := String(target.get("kind"))
	if kind == "restock":
		_try_pickup()
		return

	if kind == "shelf":
		_tick_restock(delta)


func _try_pickup() -> void:
	if _pickup_used:
		return
	_pickup_used = true
	if carry_count >= Tuning.CARRY_CAP:
		log_line.emit("負重已滿，不能執貨")
		return
	var sku := String(target.get("selected_sku"))
	var add := mini(Tuning.BOX_SIZE, Tuning.CARRY_CAP - carry_count)
	if carry_count > 0 and carry_sku != sku:
		log_line.emit("本實驗室一次只帶一種貨 — 先上架再換貨")
		return
	carry_sku = sku
	carry_count += add
	log_line.emit("執貨（即時）%s +%d 件" % [sku, add])


func _tick_restock(delta: float) -> void:
	if carry_count <= 0:
		log_line.emit("空手 — 不能對貨架互動")
		_j_held = false
		return
	var shelf_sku := String(target.get("sku"))
	if shelf_sku != "" and shelf_sku != carry_sku:
		blocked_mismatch = true
		hold_progress = 0.0
		return
	if int(target.get("count")) >= Tuning.SHELF_CAP:
		log_line.emit("貨架已滿")
		_reset_hold()
		_j_held = false
		return

	var need := Tuning.restock_seconds(agi)
	hold_progress = minf(1.0, hold_progress + delta / need)
	if hold_progress >= 1.0:
		_complete_restock()
		hold_progress = 0.0


func _complete_restock() -> void:
	var placed := 0
	while carry_count > 0 and int(target.get("count")) < Tuning.SHELF_CAP:
		if String(target.get("sku")) != "" and String(target.get("sku")) != carry_sku:
			break
		target.call("add_item", carry_sku)
		carry_count -= 1
		placed += 1
	if carry_count <= 0:
		carry_sku = ""
	log_line.emit("上架完成 %s ×%d" % [String(target.get("sku")), placed])


func _reset_hold() -> void:
	if hold_progress > 0.0:
		log_line.emit("放手 — Loading Circle 重置")
	hold_progress = 0.0
	blocked_mismatch = false


func _try_sku_hotkey(code: Key) -> void:
	if target == null or String(target.get("kind")) != "restock":
		return
	match code:
		KEY_1:
			target.set("selected_sku", "罐頭")
			log_line.emit("補貨點選 罐頭")
		KEY_2:
			target.set("selected_sku", "零食")
			log_line.emit("補貨點選 零食")
		KEY_3:
			target.set("selected_sku", "杯麵")
			log_line.emit("補貨點選 杯麵")
	stats_changed.emit()
