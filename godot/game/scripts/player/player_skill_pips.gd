extends Node2D
## Overhead skill ambient: passives first (always), then active CD/buff pips.

const SkillIcons = preload("res://scripts/skill_icons.gd")
const Skills = preload("res://scripts/skills.gd")

var host: CharacterBody2D

const ICON := 20.0
const GAP := 24.0
const Y := -110.0
const GOLD := Color("f4d35e")
const CD_COL := Color("c45c26")


func setup(p_host: CharacterBody2D) -> void:
	host = p_host
	z_index = 31


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if host == null or not is_instance_valid(host):
		return
	if not host.has_method("_loadout"):
		return
	var loadout: Array = host.call("_loadout")
	if loadout == null:
		return
	var cd_map: Dictionary = {}
	if host.get("_cd") is Dictionary:
		cd_map = host.get("_cd")
	var buffs: Dictionary = {}
	if host.get("_buffs") is Dictionary:
		buffs = host.get("_buffs")
	var entries: Array = []
	## Passives first.
	for sk in loadout:
		if not (sk is Dictionary):
			continue
		if String(sk.get("kind", "")) != "passive":
			continue
		var sid := String(sk.get("id", ""))
		if sid == "":
			continue
		entries.append({"id": sid, "passive": true, "cd": 0.0, "cd_max": 0.0, "buff": false})
	## Active CD / buff next.
	for sk in loadout:
		if not (sk is Dictionary):
			continue
		if String(sk.get("kind", "")) != "active":
			continue
		var sid2 := String(sk.get("id", ""))
		if sid2 == "":
			continue
		var left := float(cd_map.get(sid2, 0.0))
		var buff_on := buffs.has(sid2) and float(buffs.get(sid2, 0.0)) > 0.05
		if left <= 0.05 and not buff_on:
			if host.has_meta("_skill_pip_cd_peak"):
				var peaks0: Dictionary = host.get_meta("_skill_pip_cd_peak")
				peaks0.erase(sid2)
			continue
		var peaks: Dictionary = {}
		if host.has_meta("_skill_pip_cd_peak"):
			peaks = host.get_meta("_skill_pip_cd_peak")
		else:
			host.set_meta("_skill_pip_cd_peak", peaks)
		var peak := maxf(float(peaks.get(sid2, left)), left)
		peaks[sid2] = peak
		entries.append({
			"id": sid2,
			"passive": false,
			"cd": left,
			"cd_max": maxf(peak, 0.01),
			"buff": buff_on,
		})
	if entries.is_empty():
		return
	var total_w := float(entries.size() - 1) * GAP
	var x0 := -total_w * 0.5
	for i in entries.size():
		var e: Dictionary = entries[i]
		var p := Vector2(x0 + float(i) * GAP, Y)
		_draw_pip(p, e)


func _draw_pip(p: Vector2, e: Dictionary) -> void:
	var sid := String(e.get("id", ""))
	var passive: bool = bool(e.get("passive", false))
	var r := Rect2(p - Vector2(ICON, ICON) * 0.5, Vector2(ICON, ICON))
	draw_rect(r, Color(0.07, 0.09, 0.1, 0.92))
	var ring := GOLD if passive or bool(e.get("buff", false)) else Color(0.55, 0.55, 0.55, 0.9)
	draw_rect(r, ring, false, 1.5)
	var tex := SkillIcons.texture(sid)
	if tex != null:
		var pad := ICON * 0.12
		draw_texture_rect(tex, Rect2(r.position + Vector2(pad, pad), r.size * 0.76), false)
	if not passive:
		var cd := float(e.get("cd", 0.0))
		var cd_max := float(e.get("cd_max", 1.0))
		if cd > 0.05 and cd_max > 0.05:
			var t := clampf(cd / cd_max, 0.0, 1.0)
			## Sweep veil: remaining fraction as arc.
			draw_arc(p, ICON * 0.55, -PI * 0.5, -PI * 0.5 + TAU * t, 24, CD_COL, 2.5, true)
