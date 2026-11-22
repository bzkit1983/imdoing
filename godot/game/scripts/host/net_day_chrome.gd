extends RefCounted
## Day HUD / clock / skill-CD net chrome peeled from demo.gd (§8.1 Host authority).

var host: Node


func bind(day_host: Node) -> void:
	host = day_host


func connect_session() -> void:
	if not SessionService.day_hud_state_received.is_connected(on_day_hud_state_received):
		SessionService.day_hud_state_received.connect(on_day_hud_state_received)
	if not SessionService.day_clock_state_received.is_connected(on_day_clock_state_received):
		SessionService.day_clock_state_received.connect(on_day_clock_state_received)
	if not SessionService.skill_cd_state_received.is_connected(on_skill_cd_state_received):
		SessionService.skill_cd_state_received.connect(on_skill_cd_state_received)


func broadcast_day_hud_state() -> void:
	if not SessionService.is_networked() or not SessionService.is_server() or not SessionService.day_started:
		return
	SessionService.broadcast_day_hud_state({
		"ops_rating": host.ops_rating,
		"revenue": host.revenue,
		"stolen_value": host.stolen_value,
		"stolen_count": host.stolen_count,
		"served": host.served,
		"angry_left": host.angry_left,
		"thieves_caught": host.thieves_caught,
		"thieves_escaped": host.thieves_escaped,
	})


func on_day_hud_state_received(payload: Dictionary) -> void:
	if not SessionService.is_client():
		return
	if host._world == null or not is_instance_valid(host._world):
		host._pending_day_hud_states.append(payload.duplicate(true))
		return
	apply_day_hud_state_payload(payload)


func flush_pending_day_hud_states() -> void:
	if host._pending_day_hud_states.is_empty():
		return
	var queued: Array = host._pending_day_hud_states.duplicate(true)
	host._pending_day_hud_states.clear()
	for payload in queued:
		if payload is Dictionary:
			apply_day_hud_state_payload(payload)


func apply_day_hud_state_payload(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	if payload.has("ops_rating"):
		host.ops_rating = int(payload["ops_rating"])
	if payload.has("revenue"):
		host.revenue = int(payload["revenue"])
	if payload.has("stolen_value"):
		host.stolen_value = int(payload["stolen_value"])
	if payload.has("stolen_count"):
		host.stolen_count = int(payload["stolen_count"])
	if payload.has("served"):
		host.served = int(payload["served"])
	if payload.has("angry_left"):
		host.angry_left = int(payload["angry_left"])
	if payload.has("thieves_caught"):
		host.thieves_caught = int(payload["thieves_caught"])
	if payload.has("thieves_escaped"):
		host.thieves_escaped = int(payload["thieves_escaped"])
	if host._tasks != null:
		host._tasks.sync_absolute_for_all_seats("ops_rating", host.ops_rating)
		host._tasks.sync_absolute_for_all_seats("sales_revenue", host.revenue)
		host._tasks.sync_absolute_for_all_seats("angry_leave", host.angry_left)
	host.bump_hud()


func day_clock_payload() -> Dictionary:
	return {
		"real_time": host.real_time,
		"game_hours": host.game_hours,
		"phase": host.phase,
		"early_open": host._early_open,
		"early_closed": host._early_closed,
		"closing": host.phase == "closed" or host._settled,
	}


func broadcast_day_clock_state(force: bool = false) -> void:
	if not SessionService.is_networked() or not SessionService.is_server() or not SessionService.day_started:
		return
	var payload := day_clock_payload()
	var fp := "%s|%.2f|%s|%s" % [
		String(payload["phase"]),
		float(payload["real_time"]),
		str(bool(payload["early_open"])),
		str(bool(payload["early_closed"])),
	]
	if not force and fp == host._day_clock_net_fp:
		return
	host._day_clock_net_fp = fp
	SessionService.broadcast_day_clock_state(payload)


func maybe_broadcast_day_clock(delta: float) -> void:
	if not SessionService.is_networked() or not SessionService.is_server() or not SessionService.day_started:
		return
	host._day_clock_accum += delta
	if host._day_clock_accum < 0.25:
		return
	host._day_clock_accum = 0.0
	broadcast_day_clock_state(false)


func on_day_clock_state_received(payload: Dictionary) -> void:
	if not SessionService.is_client():
		return
	if host._world == null or not is_instance_valid(host._world):
		host._pending_day_clock_states.append(payload.duplicate(true))
		return
	apply_day_clock_state_payload(payload)


func flush_pending_day_clock_states() -> void:
	if host._pending_day_clock_states.is_empty():
		return
	var queued: Array = host._pending_day_clock_states.duplicate(true)
	host._pending_day_clock_states.clear()
	for payload in queued:
		if payload is Dictionary:
			apply_day_clock_state_payload(payload)


func apply_day_clock_state_payload(payload: Dictionary) -> void:
	if payload.is_empty() or not SessionService.is_client():
		return
	var prev_phase: String = String(host.phase)
	if payload.has("real_time"):
		host.real_time = float(payload["real_time"])
	if payload.has("game_hours"):
		host.game_hours = float(payload["game_hours"])
	if payload.has("phase"):
		host.phase = String(payload["phase"])
	if payload.has("early_closed"):
		host._early_closed = bool(payload["early_closed"])
	## Mirror Host early-close chrome: show/hide local dialog without confirming.
	var want_early := bool(payload.get("early_open", false))
	if want_early and not host._early_open:
		host._show_early_dialog()
	elif not want_early and host._early_open:
		host._hide_early_dialog()
	if String(host.phase) != prev_phase:
		host.host_phase_changed.emit(host.phase)
	host.bump_hud()


func skill_cd_net_fingerprint() -> String:
	var bits: PackedStringArray = []
	for p in host._players:
		if p == null or not is_instance_valid(p) or not p.has_method("skill_cd_fp"):
			continue
		bits.append(String(p.call("skill_cd_fp")))
	bits.sort()
	return "|".join(bits)


func maybe_broadcast_skill_cds() -> void:
	if not SessionService.is_networked() or not SessionService.is_server() or not SessionService.day_started:
		return
	var fp := skill_cd_net_fingerprint()
	if fp == host._skill_cd_net_fp:
		return
	host._skill_cd_net_fp = fp
	dump_all_skill_cds()


func dump_all_skill_cds() -> void:
	if not SessionService.is_networked() or not SessionService.is_server() or not SessionService.day_started:
		return
	var rows: Array = []
	for p in host._players:
		if p == null or not is_instance_valid(p) or not p.has_method("skill_cd_net_row"):
			continue
		rows.append(p.call("skill_cd_net_row"))
	if rows.is_empty():
		return
	host._skill_cd_net_fp = skill_cd_net_fingerprint()
	SessionService.broadcast_skill_cd_state({"seats": rows})


func on_skill_cd_state_received(payload: Dictionary) -> void:
	if not SessionService.is_client():
		return
	if host._world == null or not is_instance_valid(host._world):
		host._pending_skill_cd_states.append(payload.duplicate(true))
		return
	apply_skill_cd_state_payload(payload)


func flush_pending_skill_cd_states() -> void:
	if host._pending_skill_cd_states.is_empty():
		return
	var queued: Array = host._pending_skill_cd_states.duplicate(true)
	host._pending_skill_cd_states.clear()
	for payload in queued:
		if payload is Dictionary:
			apply_skill_cd_state_payload(payload)


func apply_skill_cd_state_payload(payload: Dictionary) -> void:
	var rows = payload.get("seats", [])
	if not (rows is Array):
		return
	for row in rows:
		if not (row is Dictionary):
			continue
		var sid := int(row.get("seat", -1))
		if sid < 0:
			continue
		var p = host._player_for_seat(sid)
		if p == null or not p.has_method("apply_net_skill_cd"):
			continue
		p.call("apply_net_skill_cd", row)
	host.bump_hud()
