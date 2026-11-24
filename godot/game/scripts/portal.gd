extends StaticBody2D
## Shop portal end. Paired ends share `pair_id`; only complete pairs are usable.

const Tuning = preload("res://scripts/tuning.gd")

var kind: String = "portal"
var pair_id: String = ""
var facing := Vector2.UP
var stand_offset := Vector2(0, 78)
var net_portal_id: int = -1
var partner: Node2D
var pair_tint: Color = Color("4ecdc4")

var _busy: bool = false
var _body: CanvasItem
var _pulse: float = 0.0
var _burst: CPUParticles2D


func set_facing(dir: Vector2) -> void:
	facing = dir.normalized() if dir.length_squared() > 0.01 else Vector2.UP
	stand_offset = facing * 78.0


func stand_position() -> Vector2:
	return global_position + stand_offset


func is_paired() -> bool:
	return pair_id != "" and partner != null and is_instance_valid(partner)


func can_use() -> bool:
	if not is_paired() or _busy:
		return false
	return not bool(partner.get("_busy"))


func try_begin_use() -> bool:
	if not can_use():
		return false
	_busy = true
	if partner != null and is_instance_valid(partner):
		partner.set("_busy", true)
	return true


func end_use() -> void:
	_busy = false
	if partner != null and is_instance_valid(partner):
		partner.set("_busy", false)


func play_entry_burst() -> void:
	_ensure_burst()
	_burst.global_position = global_position
	_burst.restart()


func play_exit_burst() -> void:
	_ensure_burst()
	_burst.global_position = global_position
	_burst.restart()


func _ready() -> void:
	_ensure_burst()


func _process(delta: float) -> void:
	_pulse += delta * 3.0
	if _body != null and is_instance_valid(_body):
		var glow := 0.92 + 0.08 * sin(_pulse)
		## Soft pair tint — keep cyan VOX beam readable.
		var t := 0.28
		_body.modulate = Color(
			lerpf(1.0, pair_tint.r, t) * glow,
			lerpf(1.0, pair_tint.g, t) * glow,
			lerpf(1.0, pair_tint.b, t) * glow,
			1.0
		)


func apply_pair_tint(tint: Color) -> void:
	pair_tint = tint
	_body = get_node_or_null("Body") as CanvasItem


func _ensure_burst() -> void:
	if _burst != null and is_instance_valid(_burst):
		return
	_burst = CPUParticles2D.new()
	_burst.emitting = false
	_burst.one_shot = true
	_burst.explosiveness = 0.95
	_burst.amount = 28
	_burst.lifetime = 0.45
	_burst.direction = Vector2(0, -1)
	_burst.spread = 180.0
	_burst.initial_velocity_min = 40.0
	_burst.initial_velocity_max = 120.0
	_burst.gravity = Vector2.ZERO
	_burst.scale_amount_min = 2.0
	_burst.scale_amount_max = 4.0
	_burst.color = Color(0.6, 0.95, 1.0, 0.9)
	add_child(_burst)
