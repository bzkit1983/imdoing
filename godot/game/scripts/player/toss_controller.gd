extends RefCounted
## Toss / drop-aim controller extracted from player.gd (Tech Review F2).
## Host-bound: call bind(player) from Player._ready. State stays on the player host.

const Tuning = preload("res://scripts/tuning.gd")
const Skills = preload("res://scripts/skills.gd")

var host: CharacterBody2D = null


func bind(player: CharacterBody2D) -> void:
	host = player

func setup_drop_aim() -> void:
	host._drop_aim_line = Line2D.new()
	host._drop_aim_line.name = "DropAimLine"
	host._drop_aim_line.width = 3.0
	host._drop_aim_line.default_color = Tuning.DROP_AIM_LINE_COLOR
	host._drop_aim_line.visible = false
	host._drop_aim_line.z_index = 6
	host.add_child(host._drop_aim_line)
	host._drop_aim_mark = Polygon2D.new()
	host._drop_aim_mark.name = "DropAimMark"
	host._drop_aim_mark.color = Tuning.DROP_AIM_MARK_COLOR
	host._drop_aim_mark.polygon = PackedVector2Array([
		Vector2(-10, 0), Vector2(0, -10), Vector2(10, 0), Vector2(0, 10),
	])
	host._drop_aim_mark.visible = false
	host._drop_aim_mark.z_index = 6
	host.add_child(host._drop_aim_mark)

## Base 5 身位; later drop-range skills can multiply this.
func drop_toss_dist() -> float:
	return Tuning.DROP_TOSS_DIST

func begin_drop_aim() -> void:
	## Entering drop prep pauses walk/run/dash until the box lands.
	host._running = false
	host._dashing = false
	host.velocity = Vector2.ZERO

func tick_cancel_hold(delta: float) -> void:
	if host._cancel_dropped:
		return
	## Direction is sampled the whole time. Aim circle and move-lock start only after the long press.
	sample_cancel_drop_dir()
	host._cancel_time += delta
	if host._cancel_time >= Tuning.DROP_HOLD_SEC:
		if not host._cancel_drop_ready:
			host._cancel_drop_ready = true
			begin_drop_aim()
			SfxBus.play("sfx_box_drop_aim")
		update_drop_aim()

func on_cancel_release() -> void:
	## Armed by long-press → toss the top segment on release.
	## Short press with a direction tosses one piece, unless this press cancelled a menu or action.
	if host._cancel_drop_ready and not host._cancel_dropped and not host._drop_flight_lock:
		host._cancel_dropped = true
		hide_drop_aim()
		discard_top_box()
	elif not host._drop_flight_lock:
		if not host._cancel_swallowed:
			toss_top_piece()
		host._cancel_drop_dir = Vector2.ZERO
		hide_drop_aim()
	## Previous piece already landed and this press did not throw another: walk again.
	## A whole-box flight keeps its own lock, so clear the piece lock here too.
	if host._piece_flights <= 0:
		host._piece_drop_lock = false
	host._cancel_time = 0.0
	host._cancel_drop_ready = false

func sample_cancel_drop_dir() -> void:
	## Direction keys retarget aim; no input keeps last aim or feet (zero).
	var v = host._move_vector() + host.stick_axis
	if v.length() >= Tuning.DROP_DIR_DEADZONE:
		host._cancel_drop_dir = v.normalized()
		host.facing = host._cancel_drop_dir

func drop_aim_dest() -> Vector2:
	return host.global_position + Tuning.drop_offset(host._cancel_drop_dir, drop_toss_dist())

func update_drop_aim() -> void:
	if host._drop_aim_line == null or host.inventory.is_empty():
		hide_drop_aim()
		return
	var dest := drop_aim_dest()
	host._drop_aim_line.visible = true
	host._drop_aim_mark.visible = true
	host._drop_aim_line.points = PackedVector2Array([Vector2.ZERO, dest - host.global_position])
	host._drop_aim_mark.position = dest - host.global_position

func hide_drop_aim() -> void:
	if host._drop_aim_line:
		host._drop_aim_line.visible = false
	if host._drop_aim_mark:
		host._drop_aim_mark.visible = false

func discard_top_box() -> void:
	if not host._round_active():
		return
	if host._stun_left > 0.0 or host._slip_left > 0.0 or host._fighting:
		return
	if host.inventory.is_empty():
		host.log_line.emit(Loc.t("log.player.hands_empty"))
		hide_drop_aim()
		return
	var run: Dictionary = host.inventory.trailing_run()
	var name := Tuning.sku_name(String(run["id"]))
	var n := int(run["count"])
	var toss = host._cancel_drop_dir
	drop_top_box(toss)
	if toss.length_squared() > 0.01:
		SfxBus.play("sfx_box_toss")
		var hint := sniper_toss_log(name, true)
		if hint != "":
			host.log_line.emit(hint)
		else:
			host.log_line.emit(
				Loc.t("log.player.toss_fly", [name, n, drop_dir_label(toss)])
			)
	else:
		SfxBus.play("sfx_box_drop_feet")
		host.log_line.emit(Loc.t("log.player.toss_feet", [name, n]))


## Direction + short cancel: throw the top piece. No aim circle.
## Stop while it flies. Another toss before it lands keeps the stop.
## When the last piece lands and cancel is up, a held direction walks again.

## Direction + short cancel: throw the top piece. No aim circle.
## Stop while it flies. Another toss before it lands keeps the stop.
## When the last piece lands and cancel is up, a held direction walks again.
func toss_top_piece() -> bool:
	if not host._round_active():
		return false
	if host._stun_left > 0.0 or host._slip_left > 0.0 or host._fighting or host._drop_flight_lock:
		return false
	if host._cancel_drop_dir.length_squared() < 0.01:
		return false
	if host.inventory.is_empty():
		host.log_line.emit(Loc.t("log.player.hands_empty"))
		return false
	## 投籃高手：短按方向一次飛出最上 2 件（可不同 SKU）；只有 1 件則 1。
	var want = 2 if host.buff_left("hoop_ace") > 0.05 else 1
	var tossed: PackedStringArray = []
	for _i in want:
		if host.inventory.is_empty():
			break
		var run: Dictionary = host.inventory.trailing_run()
		var sku := String(run["id"])
		host.inventory.remove_trailing(1)
		tossed.append(sku)
	if tossed.is_empty():
		return false
	var dir = host._cancel_drop_dir
	var dist := drop_toss_dist()
	launch_piece_toss(String(tossed[0]), dir, dist, Vector2.ZERO)
	if tossed.size() >= 2:
		## Delay + lateral land offset so the second box reads as a separate toss.
		var sku2 := String(tossed[1])
		var nudge := hoop_ace_side_nudge(dir)
		host._piece_flights += 1
		host._piece_drop_lock = true
		host._running = false
		host._dashing = false
		host.velocity = Vector2.ZERO
		host.get_tree().create_timer(Tuning.HOOP_ACE_SECOND_DELAY_SEC).timeout.connect(
			func() -> void:
				if not is_instance_valid(host):
					return
				if not host._round_active():
					on_piece_drop_landed()
					return
				launch_piece_toss(sku2, dir, dist, nudge, false)
		)
	var names: PackedStringArray = []
	for s in tossed:
		names.append(Tuning.sku_name(String(s)))
	var label := "、".join(names)
	var hint := sniper_toss_log(label, false)
	if hint != "":
		host.log_line.emit(hint)
	elif tossed.size() >= 2:
		host.log_line.emit(Loc.t("log.player.hoop_toss", [label, drop_dir_label(dir)]))
	else:
		host.log_line.emit(Loc.t("log.player.toss_one", [label, drop_dir_label(dir)]))
	return true

func hoop_ace_side_nudge(dir: Vector2) -> Vector2:
	if dir.length_squared() < 0.0001:
		return Vector2(Tuning.HOOP_ACE_SIDE_OFFSET, 0.0)
	var forward := dir.normalized()
	## Perpendicular to toss (screen-right of throw direction).
	return Vector2(-forward.y, forward.x) * Tuning.HOOP_ACE_SIDE_OFFSET

func launch_piece_toss(
	sku: String,
	dir: Vector2,
	dist: float,
	land_nudge: Vector2 = Vector2.ZERO,
	count_flight: bool = true
) -> void:
	var game = host._game()
	if game == null or not game.has_method("spawn_dropped_box"):
		if not count_flight:
			on_piece_drop_landed()
		return
	if count_flight:
		host._piece_flights += 1
	host._piece_drop_lock = true
	host._running = false
	host._dashing = false
	host.velocity = Vector2.ZERO
	game.call(
		"spawn_dropped_box",
		host.global_position,
		sku,
		1,
		dir,
		dist,
		Callable(host, "_on_piece_drop_landed"),
		land_nudge,
	)
	SfxBus.play("sfx_box_toss")

func sniper_toss_log(sku_name: String, whole_run: bool) -> String:
	var unit := Loc.t("log.player.unit_run") if whole_run else Loc.t("log.player.unit_one")
	if host.sniper_thief_active():
		return Loc.t("log.player.sniper_toss_thief", [sku_name, unit])
	if host.sniper_guest_active():
		return Loc.t("log.player.sniper_toss_guest", [sku_name, unit])
	if host.sniper_shelf_active():
		return Loc.t("log.player.sniper_toss_shelf", [sku_name, unit])
	return ""

func on_piece_drop_landed() -> void:
	host._piece_flights = maxi(0, host._piece_flights - 1)
	if host._piece_flights > 0:
		return
	## Still holding cancel for another short drop: stay stopped until that press ends.
	if host._cancel_held and not host._cancel_swallowed and not host._cancel_drop_ready:
		return
	host._piece_drop_lock = false

func drop_dir_label(dir: Vector2) -> String:
	if absf(dir.x) > absf(dir.y):
		return Loc.t("dir.right") if dir.x > 0.0 else Loc.t("dir.left")
	return Loc.t("dir.down") if dir.y > 0.0 else Loc.t("dir.up")

func drop_top_box(toss_dir: Vector2 = Vector2.ZERO, lock_until_land: bool = true) -> void:
	if host.inventory.is_empty():
		return
	var run: Dictionary = host.inventory.trailing_run()
	var n := int(run["count"])
	host.inventory.remove_trailing(n)
	var game = host._game()
	if game and game.has_method("spawn_dropped_box"):
		var landed := Callable()
		if lock_until_land:
			host._drop_flight_lock = true
			host._running = false
			host._dashing = false
			host.velocity = Vector2.ZERO
			landed = Callable(host, "_on_drop_flight_done")
		game.call(
			"spawn_dropped_box",
			host.global_position,
			String(run["id"]),
			n,
			toss_dir,
			drop_toss_dist(),
			landed,
		)

func on_drop_flight_done() -> void:
	host._drop_flight_lock = false
	host._cancel_drop_dir = Vector2.ZERO
	hide_drop_aim()

