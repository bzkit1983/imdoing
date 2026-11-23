extends RefCounted
## Toss / drop-aim controller extracted from player.gd (Tech Review F2).
## Host-bound: call bind(player) from Player._ready. State stays on the player host.

const Tuning = preload("res://scripts/tuning.gd")
const Skills = preload("res://scripts/skills.gd")

var host: CharacterBody2D = null
var _charge_n: float = 1.0
var _aim_qty_label: Label = null


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
	_aim_qty_label = Label.new()
	_aim_qty_label.name = "DropAimQty"
	_aim_qty_label.visible = false
	_aim_qty_label.z_index = 7
	_aim_qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.add_child(_aim_qty_label)

## Base 10 身位; later drop-range skills can multiply this.
func drop_toss_dist() -> float:
	return Tuning.DROP_TOSS_DIST

func begin_drop_aim() -> void:
	## Aim locks walk until release; flight itself does not keep the lock.
	host._running = false
	host._dashing = false
	host.velocity = Vector2.ZERO
	_charge_n = 1.0
	## Default aim = current facing (no foot drop).
	ensure_toss_dir()

func ensure_toss_dir() -> Vector2:
	## Standing still still tosses along facing — never leave a zero aim dir.
	if host._cancel_drop_dir.length_squared() >= 0.01:
		return host._cancel_drop_dir.normalized()
	var face: Vector2 = host.facing
	if face.length_squared() < 0.01:
		face = Vector2.RIGHT
	host._cancel_drop_dir = face.normalized()
	return host._cancel_drop_dir

func tick_cancel_hold(delta: float) -> void:
	if host._cancel_dropped:
		return
	## Long-press flight in progress: do not re-arm aim.
	if host._drop_flight_lock:
		return
	sample_cancel_drop_dir()
	host._cancel_time += delta
	if host._cancel_time >= Tuning.DROP_HOLD_SEC:
		if not host._cancel_drop_ready:
			host._cancel_drop_ready = true
			begin_drop_aim()
			SfxBus.play("sfx_box_drop_aim")
		else:
			_tick_drop_charge(delta)
		update_drop_aim()

func _tick_drop_charge(delta: float) -> void:
	if host.inventory.is_empty():
		return
	var cap := maxi(1, host.inventory.focused_count())
	var rate := Tuning.drop_charge_per_sec(host._str_now())
	_charge_n = minf(float(cap), _charge_n + rate * delta)

func on_cancel_release() -> void:
	## Armed by long-press → toss charged focused pieces on release.
	## Short press tosses 1 (or 2 w/ hoop_ace) along aim/facing.
	ensure_toss_dir()
	## Networked Client: chrome only — Host applies toss via toss_* intent (§8.2).
	var client_predict := SessionService.is_networked() and SessionService.is_client()
	if client_predict:
		host.pending_toss_release = true
		hide_drop_aim()
		if host._piece_flights <= 0:
			host._piece_drop_lock = false
		host._cancel_time = 0.0
		host._cancel_drop_ready = false
		host._cancel_drop_dir = Vector2.ZERO
		_charge_n = 1.0
		return
	if host._cancel_drop_ready and not host._cancel_dropped and not host._drop_flight_lock:
		host._cancel_dropped = true
		hide_drop_aim()
		discard_charged_box()
	elif not host._drop_flight_lock:
		if not host._cancel_swallowed:
			toss_top_piece()
		hide_drop_aim()
	if host._piece_flights <= 0:
		host._piece_drop_lock = false
	host._cancel_time = 0.0
	host._cancel_drop_ready = false
	host._cancel_drop_dir = Vector2.ZERO
	_charge_n = 1.0


func abort_cancel_hold() -> void:
	## Leave drop-aim without tossing (e.g. LB carry-select took over).
	host._cancel_held = false
	host._cancel_time = 0.0
	host._cancel_drop_ready = false
	host._cancel_dropped = false
	host._cancel_drop_dir = Vector2.ZERO
	hide_drop_aim()
	_charge_n = 1.0


func sample_cancel_drop_dir() -> void:
	## Direction keys retarget aim; standing still keeps / seeds facing.
	var v = host._move_vector() + host.stick_axis
	if v.length() >= Tuning.DROP_DIR_DEADZONE:
		host._cancel_drop_dir = v.normalized()
		host.facing = host._cancel_drop_dir
	else:
		ensure_toss_dir()

func toss_dir_or_facing() -> Vector2:
	return ensure_toss_dir()

func drop_aim_dest() -> Vector2:
	var dir := toss_dir_or_facing()
	var raw := host.global_position + Tuning.drop_offset(dir, drop_toss_dist())
	var game = host._game()
	if game != null and game.has_method("_clip_player_toss_path"):
		var sku: String = String(host.inventory.focused_sku())
		return game.call("_clip_player_toss_path", host.global_position, raw, sku)
	return raw

func update_drop_aim() -> void:
	if host._drop_aim_line == null or host.inventory.is_empty():
		hide_drop_aim()
		return
	var dest := drop_aim_dest()
	host._drop_aim_line.visible = true
	host._drop_aim_mark.visible = true
	host._drop_aim_line.points = PackedVector2Array([Vector2.ZERO, dest - host.global_position])
	host._drop_aim_mark.position = dest - host.global_position
	if _aim_qty_label:
		var n := maxi(1, int(floor(_charge_n)))
		_aim_qty_label.visible = true
		_aim_qty_label.text = "×%d" % n
		_aim_qty_label.position = dest - host.global_position + Vector2(-18, -28)

func hide_drop_aim() -> void:
	if host._drop_aim_line:
		host._drop_aim_line.visible = false
	if host._drop_aim_mark:
		host._drop_aim_mark.visible = false
	if _aim_qty_label:
		_aim_qty_label.visible = false

func discard_charged_box() -> void:
	if not host._round_active():
		return
	if host._stun_left > 0.0 or host._slip_left > 0.0 or host._fighting:
		return
	if host.inventory.is_empty():
		host.log_line.emit(Loc.t("log.player.hands_empty"))
		hide_drop_aim()
		return
	var run: Dictionary = host.inventory.focused_run()
	var sku_id := String(run["id"])
	var name := Tuning.sku_name(sku_id)
	var n: int = clampi(int(floor(_charge_n)), 1, int(run["count"]))
	var toss := toss_dir_or_facing()
	drop_focused_box(toss, n, false)
	## Aim unlocks walk on release — brief hitch like short toss so run cannot overtake.
	_apply_toss_move_pause(true)
	SfxBus.play("sfx_box_toss")
	var hint := sniper_toss_log(name, true)
	if hint != "":
		host.log_line.emit(hint)
	else:
		host.log_line.emit(
			Loc.t("log.player.toss_fly", [name, n, drop_dir_label(toss)])
		)


## Short cancel: throw focused piece(s) along facing / aim. No aim circle.
func toss_top_piece() -> bool:
	if not host._round_active():
		return false
	if host._stun_left > 0.0 or host._slip_left > 0.0 or host._fighting or host._drop_flight_lock:
		return false
	var dir := toss_dir_or_facing()
	if host.inventory.is_empty():
		host.log_line.emit(Loc.t("log.player.hands_empty"))
		return false
	## 投籃高手：短按一次飛出焦點最多 2 件。
	var want: int = 2 if host.buff_left("hoop_ace") > 0.05 else 1
	want = mini(want, host.inventory.focused_count())
	var sku: String = host.inventory.focused_sku()
	if sku == "" or want <= 0:
		return false
	host.inventory.remove_focused(want)
	var dist := drop_toss_dist()
	## One flight payload with count (hoop_ace 2 still one visual for same SKU).
	if want >= 2:
		launch_piece_toss(sku, dir, dist, Vector2.ZERO, true, 2)
	else:
		launch_piece_toss(sku, dir, dist, Vector2.ZERO, true, 1)
	_apply_toss_move_pause(false)
	var label := Tuning.sku_name(sku)
	var hint := sniper_toss_log(label, want > 1)
	if hint != "":
		host.log_line.emit(hint)
	elif want >= 2:
		host.log_line.emit(Loc.t("log.player.hoop_toss", [label, drop_dir_label(dir)]))
	else:
		host.log_line.emit(Loc.t("log.player.toss_one", [label, drop_dir_label(dir)]))
	return true


## Brief foot plant so walk/run cannot overtake the flying box.
## Short toss: only when already moving. Charged toss: always (aim just unlocked move).
func _apply_toss_move_pause(force: bool) -> void:
	if not force:
		var move_in: Vector2 = host._move_vector() + host.stick_axis
		var was_moving: bool = (
			move_in.length() >= Controls.MOVE_DEADZONE
			or host.velocity.length_squared() > 36.0
		)
		if not was_moving:
			return
	host._toss_move_pause_left = Tuning.DROP_TOSS_MOVE_PAUSE_SEC
	host._running = false
	host._dashing = false
	host.velocity = Vector2.ZERO

func hoop_ace_side_nudge(dir: Vector2) -> Vector2:
	if dir.length_squared() < 0.0001:
		return Vector2(Tuning.HOOP_ACE_SIDE_OFFSET, 0.0)
	var forward := dir.normalized()
	return Vector2(-forward.y, forward.x) * Tuning.HOOP_ACE_SIDE_OFFSET

func launch_piece_toss(
	sku: String,
	dir: Vector2,
	dist: float,
	land_nudge: Vector2 = Vector2.ZERO,
	count_flight: bool = true,
	piece_n: int = 1,
) -> void:
	var game = host._game()
	if game == null:
		if not count_flight:
			on_piece_drop_landed()
		return
	if count_flight:
		host._piece_flights += 1
	## Flight does not lock locomotion — player can walk while the box flies.
	host._piece_drop_lock = false
	host._drop_flight_lock = false
	game.spawn_dropped_box(host.global_position,
		sku,
		maxi(1, piece_n),
		dir,
		dist,
		Callable(host, "_on_piece_drop_landed"),
		land_nudge,
		host,
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
	host._piece_drop_lock = false

func drop_dir_label(dir: Vector2) -> String:
	if absf(dir.x) > absf(dir.y):
		return Loc.t("dir.right") if dir.x > 0.0 else Loc.t("dir.left")
	return Loc.t("dir.down") if dir.y > 0.0 else Loc.t("dir.up")

func drop_focused_box(toss_dir: Vector2, n: int, lock_until_land: bool = false) -> void:
	if host.inventory.is_empty():
		return
	var run: Dictionary = host.inventory.focused_run()
	n = clampi(n, 1, int(run["count"]))
	host.inventory.remove_focused(n)
	var game = host._game()
	if game:
		var landed := Callable()
		if lock_until_land:
			host._drop_flight_lock = true
			host._running = false
			host._dashing = false
			host.velocity = Vector2.ZERO
			landed = Callable(host, "_on_drop_flight_done")
		else:
			## Unlock on release: clear aim lock; do not wait for land.
			host._drop_flight_lock = false
		game.spawn_dropped_box(host.global_position,
			String(run["id"]),
			n,
			toss_dir,
			drop_toss_dist(),
			landed,
			Vector2.ZERO,
			host,
		)

## Legacy name used by older call sites.
func drop_top_box(toss_dir: Vector2 = Vector2.ZERO, lock_until_land: bool = false) -> void:
	var dir := toss_dir
	if dir.length_squared() < 0.01:
		dir = toss_dir_or_facing()
	var n: int = host.inventory.focused_count()
	drop_focused_box(dir, n, lock_until_land)


func discard_top_box() -> void:
	## Legacy alias — long-press release now uses charged discard.
	discard_charged_box()

func on_drop_flight_done() -> void:
	host._drop_flight_lock = false
	host._cancel_drop_dir = Vector2.ZERO
	hide_drop_aim()
