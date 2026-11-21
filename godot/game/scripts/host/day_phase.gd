extends RefCounted
## Day clock / phase string helpers (shared by GameHost + demo).

const Tuning = preload("res://scripts/tuning.gd")


static func clock_hm_ampm(game_hours: float) -> Dictionary:
	## {hm: "06:00", ampm: "am"} — split so HUD can pin am/pm in a fixed slot.
	var h24 := int(floor(game_hours)) % 24
	var m := int(floor((game_hours - floorf(game_hours)) * 60.0))
	var h12 := h24 % 12
	if h12 == 0:
		h12 = 12
	var ampm := Loc.t("hud.ampm.am") if h24 < 12 else Loc.t("hud.ampm.pm")
	return {
		"hm": Loc.t("hud.clock_hm", [h12, m]),
		"ampm": ampm,
	}


static func clock_text(game_hours: float) -> String:
	var parts := clock_hm_ampm(game_hours)
	return "%s %s" % [String(parts["hm"]), String(parts["ampm"])]


static func phase_text(phase: String) -> String:
	match phase:
		"restock":
			return Loc.t("phase.restock")
		"open":
			return Loc.t("phase.ops")
		_:
			return Loc.t("demo.closeout_head")


static func advance(
	real_time: float,
	restock_sec: float = -1.0,
	open_sec: float = -1.0,
) -> Dictionary:
	## Returns {phase, game_hours, open_sfx: bool, finished: bool}.
	var rs := restock_sec if restock_sec > 0.0 else Tuning.RESTOCK_REAL_SEC
	var os := open_sec if open_sec > 0.0 else Tuning.OPEN_REAL_SEC
	if real_time < rs:
		var t := real_time / rs
		return {
			"phase": "restock",
			"game_hours": lerpf(Tuning.GAME_START_HOUR, Tuning.OPEN_HOUR, t),
			"open_sfx": false,
			"finished": false,
		}
	if real_time < rs + os:
		var t2 := (real_time - rs) / os
		return {
			"phase": "open",
			"game_hours": lerpf(Tuning.OPEN_HOUR, Tuning.CLOSE_HOUR, t2),
			"open_sfx": true,
			"finished": false,
		}
	return {
		"phase": "closed",
		"game_hours": Tuning.CLOSE_HOUR,
		"open_sfx": false,
		"finished": true,
	}
