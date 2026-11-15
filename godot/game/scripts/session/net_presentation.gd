extends RefCounted
## Client presentation buffer for remote poses (§8.4).
## Host samples are pushed with timestamps; render samples at now - INTERP_DELAY.

const NET_HZ := 30.0
const NET_DT := 1.0 / NET_HZ
const AGENT_HZ := 15.0
const AGENT_DT := 1.0 / AGENT_HZ
## Render behind latest sample to absorb jitter (seconds).
const INTERP_DELAY := 0.09
## Snap instead of lerp across teleports / large corrections.
const TELEPORT_PX := 128.0
const TELEPORT_PX_SQ := TELEPORT_PX * TELEPORT_PX
## Owned-seat soft reconcile bands (pixels).
const OWNED_IGNORE_PX := 4.0
const OWNED_BLEND_PX := 48.0
const OWNED_IGNORE_PX_SQ := OWNED_IGNORE_PX * OWNED_IGNORE_PX
const OWNED_BLEND_PX_SQ := OWNED_BLEND_PX * OWNED_BLEND_PX
## Host: clear sticky remote_move after this many empty net ticks.
const INTENT_STALE_TICKS := 3
## Soft blend rate toward Host pose (fraction per second, clamped per frame).
const OWNED_BLEND_RATE := 12.0

## key → {t0, p0, f0, t1, p1, f1}  (t1 is newest)
var _buf: Dictionary = {}


func clear() -> void:
	_buf.clear()


func push_sample(key: String, t: float, pos: Vector2, facing: Vector2) -> void:
	if key.is_empty():
		return
	if not _buf.has(key):
		_buf[key] = {
			"t0": t, "p0": pos, "f0": facing,
			"t1": t, "p1": pos, "f1": facing,
		}
		return
	var s: Dictionary = _buf[key]
	## Ignore out-of-order / duplicate timestamps.
	if t < float(s.get("t1", 0.0)) - 0.0001:
		return
	s["t0"] = float(s.get("t1", t))
	s["p0"] = s.get("p1", pos)
	s["f0"] = s.get("f1", facing)
	s["t1"] = t
	s["p1"] = pos
	s["f1"] = facing


## Returns {ok, pos, facing, hard}. hard=true means caller should snap.
func sample(key: String, render_t: float) -> Dictionary:
	if not _buf.has(key):
		return {"ok": false, "pos": Vector2.ZERO, "facing": Vector2.RIGHT, "hard": true}
	var s: Dictionary = _buf[key]
	var t0 := float(s.get("t0", 0.0))
	var t1 := float(s.get("t1", 0.0))
	var p0: Vector2 = s.get("p0", Vector2.ZERO)
	var p1: Vector2 = s.get("p1", Vector2.ZERO)
	var f0: Vector2 = s.get("f0", Vector2.RIGHT)
	var f1: Vector2 = s.get("f1", Vector2.RIGHT)
	var target_t := render_t - INTERP_DELAY
	if t1 <= t0 + 0.00001:
		return {"ok": true, "pos": p1, "facing": f1, "hard": false}
	if p0.distance_squared_to(p1) >= TELEPORT_PX_SQ:
		return {"ok": true, "pos": p1, "facing": f1, "hard": true}
	if target_t <= t0:
		return {"ok": true, "pos": p0, "facing": f0, "hard": false}
	if target_t >= t1:
		return {"ok": true, "pos": p1, "facing": f1, "hard": false}
	var u := (target_t - t0) / (t1 - t0)
	u = clampf(u, 0.0, 1.0)
	return {
		"ok": true,
		"pos": p0.lerp(p1, u),
		"facing": f0.lerp(f1, u).normalized() if f0.length_squared() > 0.0001 and f1.length_squared() > 0.0001 else f1,
		"hard": false,
	}


## Owned-seat correction toward Host pose. Returns new position (always applies facing separately).
## in_combat → hard snap. Small error → keep current. Mid → blend. Large → hard.
func reconcile_owned(current: Vector2, host_pos: Vector2, delta: float, in_combat: bool) -> Vector2:
	var d2 := current.distance_squared_to(host_pos)
	if in_combat or d2 >= OWNED_BLEND_PX_SQ:
		return host_pos
	if d2 <= OWNED_IGNORE_PX_SQ:
		return current
	var a := clampf(OWNED_BLEND_RATE * delta, 0.0, 1.0)
	return current.lerp(host_pos, a)


static func seat_key(seat_id: int) -> String:
	return "seat:%d" % seat_id


static func agent_key(agent_id: int) -> String:
	return "agent:%d" % agent_id
