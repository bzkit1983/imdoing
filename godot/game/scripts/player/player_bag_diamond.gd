extends Node2D
## Ambient ops-bag preview: diamond of 4 wells (up/right/down/left).
## TasksPanel-style Flat wells; show when bag has ≥1 item; linger after last use.

const OpsItems = preload("res://scripts/ops_items.gd")
const OpsItemIcons = preload("res://scripts/ops_item_icons.gd")

var host: CharacterBody2D
var _linger_until: float = 0.0

const WELL := 16.0
const ARM := 18.0
## Hip / side offset (left of clerk); kept tight to the body.
const ORIGIN := Vector2(-30.0, 4.0)
## up, right, down, left — matches bag slot indices 0–3.
const _OFF: Array[Vector2] = [
	Vector2(0.0, -ARM),
	Vector2(ARM, 0.0),
	Vector2(0.0, ARM),
	Vector2(-ARM, 0.0),
]

const BG := Color(0.07, 0.09, 0.1, 0.94)
const BORDER := Color(0.42, 0.78, 0.68, 0.9)
const GHOST := Color(0.35, 0.4, 0.42, 0.35)
const GHOST_BORDER := Color(0.42, 0.78, 0.68, 0.35)


func setup(p_host: CharacterBody2D) -> void:
	host = p_host
	z_index = 28
	position = Vector2.ZERO


func pulse_empty() -> void:
	## Call when last item used so diamond lingers then hides.
	_linger_until = Time.get_ticks_msec() / 1000.0 + 1.2


func _process(_delta: float) -> void:
	queue_redraw()


func _bag_ids() -> Array[String]:
	if host == null or not is_instance_valid(host):
		return OpsItems.empty_bag()
	if host.has_method("ops_bag_ids"):
		var raw: Variant = host.call("ops_bag_ids")
		if raw is Array:
			var out: Array[String] = []
			for i in mini(4, (raw as Array).size()):
				out.append(String((raw as Array)[i]))
			while out.size() < 4:
				out.append("")
			return out
	var bag: Variant = host.get("ops_bag")
	if bag is Array:
		var out2: Array[String] = []
		for i in mini(4, (bag as Array).size()):
			out2.append(String((bag as Array)[i]))
		while out2.size() < 4:
			out2.append("")
		return out2
	return OpsItems.empty_bag()


func _filled_count(ids: Array[String]) -> int:
	var n := 0
	for id in ids:
		if String(id) != "":
			n += 1
	return n


func _draw() -> void:
	if host == null or not is_instance_valid(host):
		return
	var ids := _bag_ids()
	var filled := _filled_count(ids)
	var now := Time.get_ticks_msec() / 1000.0
	if filled <= 0 and now > _linger_until:
		return
	for i in 4:
		var id := String(ids[i]) if i < ids.size() else ""
		var p := ORIGIN + _OFF[i]
		var empty := id == ""
		var bg := GHOST if empty else BG
		var border := GHOST_BORDER if empty else BORDER
		var r := Rect2(p - Vector2(WELL, WELL) * 0.5, Vector2(WELL, WELL))
		draw_rect(r, bg)
		draw_rect(r, border, false, 2.0)
		if not empty:
			var tex := OpsItemIcons.texture(id)
			if tex != null:
				var pad := WELL * 0.15
				draw_texture_rect(tex, Rect2(r.position + Vector2(pad, pad), r.size * 0.7), false)
