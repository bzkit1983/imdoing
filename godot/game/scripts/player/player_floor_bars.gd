extends Node2D
## Under-foot stamina + skill CD bars (non-overlapping slots).

const Tuning = preload("res://scripts/tuning.gd")

var host: CharacterBody2D
var _show_stam: bool = false
var _stam_force_until: float = 0.0
var _cd_ids: Array[String] = []
var _cd_left: Array[float] = []
var _cd_max: Array[float] = []
var _cd_peak: Dictionary = {} ## id → peak remaining seen this cycle

const BAR_W := 56.0
const BAR_H := 6.0
const GAP := 4.0
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
	_sync_cds()
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


func _sync_cds() -> void:
	_cd_ids.clear()
	_cd_left.clear()
	_cd_max.clear()
	var cd_map: Dictionary = host.get("_cd") if host.get("_cd") != null else {}
	var live: Dictionary = {}
	for sid in cd_map.keys():
		var id := String(sid)
		var left := float(cd_map[sid])
		if left <= 0.05:
			_cd_peak.erase(id)
			continue
		live[id] = true
		var peak := float(_cd_peak.get(id, left))
		peak = maxf(peak, left)
		_cd_peak[id] = peak
		_cd_ids.append(id)
		_cd_left.append(left)
		_cd_max.append(peak)
	## Drop peaks for ids no longer cooling.
	for id in _cd_peak.keys():
		if not live.has(id):
			_cd_peak.erase(id)


func _draw() -> void:
	var y := Y0
	if _show_stam and host != null:
		var mx := 1.0
		if host.has_method("stamina_max_now"):
			mx = maxf(float(host.call("stamina_max_now")), 1.0)
		var st := float(host.get("stamina"))
		var t := clampf(st / mx, 0.0, 1.0)
		var low := t < 0.35
		_draw_bar(y, t, Color("3d9e5f") if not low else Color("e09a3e"))
		y += BAR_H + GAP
	for i in _cd_ids.size():
		var t := clampf(_cd_left[i] / maxf(_cd_max[i], 0.01), 0.0, 1.0)
		## Remaining CD as emptying bar.
		_draw_bar(y, t, Color("c45c26"))
		y += BAR_H + GAP


func _draw_bar(y: float, fill: float, col: Color) -> void:
	var origin := Vector2(-BAR_W * 0.5, y)
	draw_rect(Rect2(origin, Vector2(BAR_W, BAR_H)), Color(0.08, 0.08, 0.08, 0.85))
	draw_rect(Rect2(origin, Vector2(BAR_W * fill, BAR_H)), col)
