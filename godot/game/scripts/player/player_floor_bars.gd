extends Node2D
## Under-foot stamina bar (skill CD lives on the skill radial).

var host: CharacterBody2D
var _show_stam: bool = false
var _stam_force_until: float = 0.0

const BAR_W := 56.0
const BAR_H := 6.0
const Y0 := 28.0


func setup(p_host: CharacterBody2D) -> void:
	host = p_host
	z_index = 25
	position = Vector2.ZERO


func note_dash() -> void:
	_show_stam = true
	_stam_force_until = Time.get_ticks_msec() / 1000.0 + 0.35


func _process(_delta: float) -> void:
	if host == null or not is_instance_valid(host):
		return
	_sync_stam()
	queue_redraw()


func _sync_stam() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var mx := 1.0
	if host.has_method("stamina_max_now"):
		mx = maxf(float(host.call("stamina_max_now")), 1.0)
	var st := float(host.get("stamina"))
	var ratio := st / mx
	if now < _stam_force_until or ratio < 0.995:
		_show_stam = true
	elif ratio >= 0.999 and not bool(host.get("_running")) and not bool(host.get("_dashing")):
		_show_stam = false


func _draw() -> void:
	if not _show_stam or host == null:
		return
	var mx := 1.0
	if host.has_method("stamina_max_now"):
		mx = maxf(float(host.call("stamina_max_now")), 1.0)
	var st := float(host.get("stamina"))
	var t := clampf(st / mx, 0.0, 1.0)
	var low := t < 0.35
	_draw_bar(Y0, t, Color("3d9e5f") if not low else Color("e09a3e"))


func _draw_bar(y: float, fill: float, col: Color) -> void:
	var origin := Vector2(-BAR_W * 0.5, y)
	draw_rect(Rect2(origin, Vector2(BAR_W, BAR_H)), Color(0.08, 0.08, 0.08, 0.85))
	draw_rect(Rect2(origin, Vector2(BAR_W * fill, BAR_H)), col)
