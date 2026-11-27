extends RefCounted
## Fight / KO controller extracted from player.gd (Tech Review F2).
## Host-bound: call bind(player) from Player._ready. State stays on the player host.

const Tuning = preload("res://scripts/tuning.gd")
const Skills = preload("res://scripts/skills.gd")

var host: CharacterBody2D = null


func bind(player: CharacterBody2D) -> void:
	host = player

func begin_fight() -> void:
	## Carry allowed; goods stay in hand for the mash window.
	## Restock/shelf targets have no is_thief — bool(Object.get null) crashes Godot 4.
	if not is_instance_valid(host.target) or not host.target.get("is_thief"):
		return
	if not host.target.has_method("is_active_thief") or not bool(host.target.call("is_active_thief")):
		return
	## A6 L — another seat already fighting this thief.
	if not host._interact_try(host.target):
		host.log_line.emit(Loc.t("log.player.thief_claimed"))
		return
	host._fighting = true
	host._fight_ko = false
	host._fight_release = true
	host.target.call("begin_fight")
	SfxBus.play("sfx_fight_grab")
	host.log_line.emit(Loc.t("log.player.thief_grab"))
	## LAN: only the catcher's machine zooms／locks the shared cam.
	if host.controls_locally() and host._shared_camera() != null:
		host._focus_camera_toward(host.target.global_position, 0.35)
		var tw = host.create_tween()
		tw.tween_property(
			host.camera, "zoom",
			Vector2(Tuning.FIGHT_ZOOM, Tuning.FIGHT_ZOOM),
			0.16,
		)

func tick_fight(delta: float) -> void:
	if host._fight_ko:
		host._tick_camera_shake(delta)
		## Net puppet KO visuals may finish while Host still owns the thief —
		## stay locked until the presentation agent is gone (despawn) or cleared.
		if host._net_ko_pending:
			if not is_instance_valid(host.target):
				host._net_ko_pending = false
				end_fight(true)
			return
		return
	if not is_instance_valid(host.target) or not bool(host.target.call("in_fight")):
		end_fight(false)
		return
	host.target.fight_left = maxf(0.0, float(host.target.fight_left) - delta)
	host.hold_progress = clampf(float(host.target.fight_hp) / 100.0, 0.0, 1.0)
	host.target.call("_refresh_labels")
	host._tick_camera_shake(delta)
	## Client vs puppet: do not locally fail the mash — Host timer / outcome is authority.
	if host._agent_is_net_puppet(host.target):
		return
	if float(host.target.fight_left) <= 0.0:
		fight_fail()

func fight_tap() -> void:
	if not is_instance_valid(host.target) or host._fight_ko:
		return
	var dmg = Tuning.hit_damage(host._str_now())
	var game = host._game()
	if game != null and game.get("state") != null and game.state.has_method("fight_damage_mult"):
		dmg *= float(game.state.fight_damage_mult())
	if host.controls_locally():
		host._shake_camera(Tuning.FIGHT_HIT_SHAKE, Tuning.FIGHT_HIT_SHAKE_SEC)
	SfxBus.play("sfx_fight_hit")
	## Puppet HP bar is feel-only; Host applies real damage from interact intents.
	if bool(host.target.call("take_hit", dmg)):
		if host._agent_is_net_puppet(host.target):
			## Keep fighting locked; Host KO → despawn ends the mash via host._net_ko_pending.
			fight_win_net_pending()
			return
		fight_win()

func fight_win_net_pending() -> void:
	## Local mash bar emptied on a presentation thief — wait for Host despawn.
	if host._fight_ko:
		return
	host._fight_ko = true
	host._net_ko_pending = true
	host.log_line.emit(Loc.t("log.player.thief_ko"))
	play_ko_sequence(host.target, "", Vector2.ZERO, false)

func fight_win() -> void:
	if host._fight_ko:
		return
	host._fight_ko = true
	var game = host._game()
	if game:
		game.record_caught(host.seat_id, "melee")
	host.log_line.emit(Loc.t("log.player.thief_ko"))
	play_ko_sequence(host.target, "ko_scatter_and_flee")


## Directional tossed box hit an active thief → Screen KO (counts as catch).

## Directional tossed box hit an active thief → Screen KO (counts as catch).
func apply_toss_ko(thief: Node, knock_dir: Vector2) -> void:
	if thief == null or not is_instance_valid(thief):
		return
	if not thief.has_method("is_active_thief") or not bool(thief.call("is_active_thief")):
		return
	if not thief.has_method("ko_box_hit_and_flee"):
		return
	## Client presentation thief: Host resolves box KO + loot; local seat only plays VFX.
	if host._agent_is_net_puppet(thief):
		var end_fight_net = host._fighting and host.target == thief
		if end_fight_net:
			host._fight_ko = true
			host._net_ko_pending = true
		host.log_line.emit(Loc.t("log.player.thief_box_ko"))
		SfxBus.play("sfx_box_hit_thief")
		play_ko_sequence(thief, "", knock_dir.normalized() if knock_dir.length_squared() > 0.01 else Vector2.ZERO, false)
		return
	var game = host._game()
	if game:
		game.record_caught(host.seat_id, "box")
	host.log_line.emit(Loc.t("log.player.thief_box_ko"))
	SfxBus.play("sfx_box_hit_thief")
	## If this toss finishes an ongoing grab fight, clear fight state after the KO.
	var end_fight = host._fighting and host.target == thief
	if end_fight:
		host._fight_ko = true
	var dir := knock_dir
	if dir.length_squared() < 0.01:
		dir = (thief as Node2D).global_position - host.global_position
	if dir.length_squared() < 0.01:
		dir = host.facing
	play_ko_sequence(thief, "ko_box_hit_and_flee", dir.normalized(), end_fight)

func play_ko_sequence(
	thief: Node,
	flee_method: String = "ko_scatter_and_flee",
	knock_override: Vector2 = Vector2.ZERO,
	end_fight: bool = true
) -> void:
	var local_cam = host.controls_locally()
	if local_cam:
		host._shake_camera(Tuning.FIGHT_KO_SHAKE, 0.22)
	SfxBus.play("sfx_ko_screen")
	if local_cam and host._shared_camera() != null:
		if is_instance_valid(thief):
			host._focus_camera_toward((thief as Node2D).global_position, 0.35)
		var punch = host.create_tween()
		punch.tween_property(
			host.camera, "zoom",
			Vector2(Tuning.FIGHT_KO_ZOOM, Tuning.FIGHT_KO_ZOOM),
			0.07,
		)
	var game = host._game()
	if game:
		game.play_ko_banner()
	await host.get_tree().create_timer(0.18).timeout
	## Empty flee_method = presentation-only (net puppet); Host scatters / despawns.
	if flee_method != "" and is_instance_valid(thief) and thief.has_method(flee_method):
		var knock: Vector2 = knock_override
		if knock.length_squared() < 0.01:
			knock = (thief as Node2D).global_position - host.global_position
		if knock.length_squared() < 0.01:
			knock = host.facing
		thief.call(flee_method, knock.normalized())
	await host.get_tree().create_timer(Tuning.FIGHT_KO_FLASH_SEC * 0.55).timeout
	if end_fight:
		end_fight(true)
	elif local_cam and host.camera and not host._net_ko_pending:
		## Toss KO outside a fight: restore shop framing after the punch-in.
		host.restore_base_camera()

func fight_fail() -> void:
	if host._fight_ko:
		return
	if is_instance_valid(host.target):
		var away = host.global_position - host.target.global_position
		if away.length_squared() < 0.01:
			away = -host.facing
		host.facing = away.normalized()
		## Never drive puppet escape — Host owns leave / stolen host.stats.
		if not host._agent_is_net_puppet(host.target) and host.target.has_method("escape_with_loot"):
			host.target.call("escape_with_loot")
	apply_fight_fail_player()


## Client: Host broadcast fight_clear(caught=false) — mirror slip/stun without mutating puppet.

## Client: Host broadcast fight_clear(caught=false) — mirror slip/stun without mutating puppet.
func apply_net_fight_fail() -> void:
	if not host._fighting and not host._net_ko_pending and not host._fight_ko:
		return
	if is_instance_valid(host.target):
		var away = host.global_position - host.target.global_position
		if away.length_squared() < 0.01:
			away = -host.facing
		host.facing = away.normalized()
	apply_fight_fail_player()


## Client presentation: Host absolute checkout arrows／hold (M2.9). Works on puppets.

func apply_fight_fail_player() -> void:
	host.log_line.emit(Loc.t("log.player.thief_fail"))
	SfxBus.play("sfx_fight_fail")
	SfxBus.play("sfx_move_stun")
	end_fight(false)
	host._dashing = false
	host._running = false
	host._slip_left = Tuning.SLIP_TIME
	host._stun_pending = Tuning.FIGHT_DOWN_SEC
	var g = host._game()
	if g != null:
		g.note_fight_fail(host)

func end_fight(_won: bool) -> void:
	if is_instance_valid(host.target):
		host._interact_release(host.target)
	host._fighting = false
	host._fight_release = false
	host._fight_ko = false
	host._net_ko_pending = false
	host._shake_left = 0.0
	host.hold_progress = 0.0
	## Mash updates `host._j_held` above; if still down through KO, latch until up
	## so `host._tick_action` cannot long-commit nearby dirt/shelf/cashier.
	var still_held = host._j_held
	host._j_held = false
	host._j_time = 0.0
	host._long_committed = false
	host._deliver_done = false
	host._interact_ignore_until_up = still_held
	host._clear_clean_hint()
	if host.controls_locally():
		host.restore_base_camera()
	var game = host._game()
	if game != null:
		game.notify_camera_priority_idle()


func try_dash_hits() -> void:
	var g: Node = host._game()
	if g == null:
		return
	host._try_wave_dirt_vfx()
	## Thieves first (caught).
	if g:
		for t in g.thieves():
			if t == null or not is_instance_valid(t):
				continue
			if not bool(t.call("is_active_thief")):
				continue
			if not host._dash_segment_hits(t.global_position):
				continue
			## Presentation thief: Host resolves dash KO from intents; local VFX only.
			if host._agent_is_net_puppet(t):
				SfxBus.play("sfx_thief_dash_out")
				host.log_line.emit(Loc.t("log.player.thief_dash"))
				if host._fighting and host.target == t:
					host._fight_ko = true
					host._net_ko_pending = true
					host._play_ko_sequence(t, "", host._dash_dir, false)
				return
			t.call("dash_knock_away", host._dash_dir)
			if g:
				g.record_caught(host.seat_id, "dash")
			SfxBus.play("sfx_thief_dash_out")
			host.log_line.emit(Loc.t("log.player.thief_dash"))
			if host._fighting:
				host._end_fight(false)
			return
	## One guest resolution per dash. 衝刺交付: prefer guests who want carried goods (near→far), not only nearest.
	## Clones are after guests so 衝刺交付 never hands goods to a clone.
	if not host._dash_guest_done:
		var guests: Array = host._dash_guests()
		if not guests.is_empty():
			if host.buff_left("dash_deliver") > 0.0:
				var deliver_targets: Array = []
				for guest in guests:
					if guest == null or not is_instance_valid(guest):
						continue
					if not guest.has_method("can_receive_delivery") or not bool(guest.call("can_receive_delivery")):
						continue
					if not host._guest_wants_carried(guest):
						continue
					deliver_targets.append(guest)
				if not deliver_targets.is_empty():
					var gave: int = host._hand_deliver(deliver_targets, false)
					if gave > 0:
						host._dash_guest_done = true
						host.log_line.emit(Loc.t("log.player.dash_deliver", [gave]))
						return
			var nearest: Node = guests[0]
			host._dash_guest_done = true
			var add: float = 0.0 if host._has_flag("polite_dash") else Tuning.DASH_GUEST_DISSAT
			if g:
				g.play_ko_banner()
			if nearest.has_method("dash_knock_guest"):
				nearest.call("dash_knock_guest", add)
			if add > 0.0:
				g.note_dash_guest(host)
			SfxBus.play("sfx_ko_guest_dash")
			host.log_line.emit(Loc.t("log.player.dash_guest") if add > 0.0 else Loc.t("log.player.dash_polite"))
			return
	if host._dash_guest_done:
		return
	var clone: Node = host._dash_clone()
	if clone == null:
		return
	host._dash_guest_done = true
	if g:
		g.play_ko_banner()
	if clone.has_method("dash_knock"):
		clone.call("dash_knock")
	SfxBus.play("sfx_ko_guest_dash")
	host.log_line.emit(Loc.t("log.player.dash_clone"))
