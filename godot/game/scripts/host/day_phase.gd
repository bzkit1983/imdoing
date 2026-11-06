extends RefCounted
## Day clock / phase string helpers (shared by GameHost + demo).

const Tuning = preload("res://scripts/tuning.gd")


static func clock_text(game_hours: float) -> String:
	var h := int(floor(game_hours)) % 24
	var m := int(floor((game_hours - floorf(game_hours)) * 60.0))
	return "%02d:%02d" % [h, m]


static func phase_text(phase: String) -> String:
	match phase:
		"restock":
			return "補貨時段  06:00–08:00  無客人"
		"open":
			return "營運時段  08:00–22:00"
		_:
			return "關店結算"


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
