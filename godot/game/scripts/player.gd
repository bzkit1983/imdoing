extends CharacterBody2D

const Tuning = preload("res://scripts/tuning.gd")
const Skills = preload("res://scripts/skills.gd")
const InventoryScript = preload("res://scripts/inventory.gd")
const CircleScript = preload("res://scripts/loading_circle.gd")
const BoxStackScript = preload("res://scripts/box_stack.gd")
const Vox = preload("res://scripts/voxel_sprite.gd")
const PromptScript = preload("res://scripts/command_prompt.gd")
const MenuScript = preload("res://scripts/skill_menu.gd")
const UiFont = preload("res://scripts/ui_font.gd")
const FxBurst = preload("res://scripts/fx_burst.gd")
const GlowScript = preload("res://scripts/interact_glow.gd")
const SkuIcons = preload("res://scripts/sku_icons.gd")
const InteractScan = preload("res://scripts/player/interact_scan.gd")
const CustomerScript = preload("res://scripts/customer.gd")

signal stats_changed

## Last HUD right-panel fingerprint; emit stats_changed only when it changes.
var _hud_fp: String = ""
signal log_line(text: String)
signal paid(amount: int)
signal skill_cast(skill_name: String, is_ult: bool)

var inventory = InventoryScript.new()
var _cannon: Node2D
var stamina: float = Tuning.stamina_max()
var facing: Vector2 = Vector2.RIGHT
var hold_progress: float = 0.0
var blocked_mismatch: bool = false
var target: Node2D = null
var interactables: Array[Node2D] = []
var dirt_contacts: int = 0
var _dirt_areas: Array[Node] = []
var _slip_left: float = 0.0
var _stun_left: float = 0.0
var _sick_left: float = 0.0
var _last_wiggle: Vector2 = Vector2.ZERO
var _clean_hint: bool = false
var command_lock: bool = false
var seq_index: int = 0
var seq_done: bool = false
## Sticky miss for this checkout attempt (ops rating P1a vs P1b).
var _checkout_had_miss: bool = false
## Last Host checkout prompt fingerprint (M2.9 throttle).
var _net_prompt_fp: String = ""
## Cast level while `senior_cashier` buff is up (0 = inactive).
var _senior_cashier_lv: int = 0
var skill_menu_open: bool = false
var ult_prep: bool = false
var stick_axis: Vector2 = Vector2.ZERO
var clock_scale: float = 1.0
var customer_move_mult: float = 1.0
var camera: Camera2D
var stats = null
## M1 local coop seat (0 = host). Solo always 0.
var seat_id: int = 0
## Host applies remote LAN intent into these when seat is not local.
var remote_move: Vector2 = Vector2.ZERO
var remote_interact: bool = false
var remote_cancel: bool = false
var remote_dash: bool = false
## Client→Host: one-shot skill hotkey slot (−1 = none). Cleared when intent is built.
var pending_skill_hotkey: int = -1
## L-class target currently held via InteractLock (shelf/cashier/restock/…).
var _lock_node: Node = null

var _k_held: bool = false
var _k_time: float = 0.0
var _running: bool = false
var _dashing: bool = false
var _dash_dir: Vector2 = Vector2.RIGHT
var _dash_left: float = 0.0
var _regen_delay: float = 0.0
var _j_held: bool = false
## Seconds the interact button has been held this press. Short vs long splits at SKU_PICK_HOLD.
var _j_time: float = 0.0
## Long action already started (clean / stock / cashier / hand delivery) — release must not also take.
var _long_committed: bool = false
var _deliver_done: bool = false
## This dash already resolved a guest (deliver or KO).
var _dash_guest_done: bool = false
## Segment start for swept dash hit tests (set each dash physics step).
var _dash_from: Vector2 = Vector2.ZERO
## Short cancel closed a menu or an in-progress action, so it must not toss a piece.
var _cancel_swallowed: bool = false
var _pickup_used: bool = false
var _circle: Node2D
var _prompt: Node2D
var _menu: Node2D
var _body: CanvasItem
## Vox character id (SkinCatalog / stats.skin_id). Default standard player.
var _model_id: String = "player"
var _arrow: Polygon2D
var _no_queue_logged: bool = false
var _l_held: bool = false
var _l_time: float = 0.0
## Short tap left the menu up. Direction fires now; skill key again fires the center.
var _skill_latch: bool = false
## Slot that a held menu will cast on release. 0 is the center skill.
var _skill_aim: int = 0
## Second skill press already confirmed the center; ignore that press's release.
var _skill_release_ignore: bool = false
## True when this skill press came from Xbox Y (short = cast slot 0; keyboard/touch short = menu).
var _skill_from_pad: bool = false
## Staged by _unhandled_input before set_hold so touch/default stays false.
var _skill_pad_hint: bool = false
var _u_held: bool = false
var _ult_index: int = 0
## Xbox LT/RT: solo → skill 4/5 after grace; both held → ult chord.
var _lt_held: bool = false
var _rt_held: bool = false
var _lt_time: float = 0.0
var _rt_time: float = 0.0
var _both_trigger_time: float = 0.0
var _lt_fired: bool = false
var _rt_fired: bool = false
## Both triggers were down this gesture — do not cast skill 4/5 on release.
var _trigger_chord_block: bool = false
## Ult prep started via LT+RT (release both cancels; keyboard U uses _u_held alone).
var _ult_chord_active: bool = false
var _cd: Dictionary = {}
var _buffs: Dictionary = {}
var _cust_speed_q: Array[String] = []
var _cardinal_armed: bool = true
## After skill/ult/restock/checkout dir mode, ignore move until stick/keys go neutral
## so releasing the menu on a held WASD key does not start walking.
var _move_locked_until_neutral: bool = false
var _passive_checkout_pct: float = 0.0
var _restock_picking: bool = false
var _restock_hold: float = 0.0
var _restock_aborted: bool = false
var _fighting: bool = false
var _fight_release: bool = false
## After fight ends, ignore Interact until the physical key/button goes up
## so a held mash press cannot long-commit dirt/shelf/cashier.
var _interact_ignore_until_up: bool = false
## True while KO banner / knockaway plays after a fight mash win.
var _fight_ko: bool = false
## Client: mash bar emptied on a net_puppet thief; wait for Host despawn before freeing move.
var _net_ko_pending: bool = false
## Client puppet: last Host pose for walk/facing visuals (M2).
var _net_puppet_pos: Vector2 = Vector2.INF
var _net_puppet_moving: bool = false
## EliteCustomer intro ZOOM — locks player actions (~1s).
var _elite_focus_left: float = 0.0
var _shake_left: float = 0.0
var _shake_mag: float = 0.0
var _stun_pending: float = Tuning.STUN_SEC
var _cancel_held: bool = false
var _cancel_time: float = 0.0
## True once hold exceeds DROP_HOLD_SEC — release then drops (not auto).
var _cancel_drop_ready: bool = false
## True after this press has already tossed (prevents double drop).
var _cancel_dropped: bool = false
## Aim direction while holding cancel. Zero = drop at feet.
var _cancel_drop_dir: Vector2 = Vector2.ZERO
## True from toss start until the flying box lands — movement stays locked.
var _drop_flight_lock: bool = false
## Piece tosses in the air. Movement stays stopped until the latest one lands
## and the player is not already holding another short drop.
var _piece_flights: int = 0
var _piece_drop_lock: bool = false
var _drop_aim_line: Line2D
var _drop_aim_mark: Polygon2D
## 使命必達: range preview (follows player). Confirm with skill; cancel drops aim (no CD).
var _must_deliver_aim: bool = false
var _must_deliver_lv: int = 3
var _must_deliver_sid: String = ""
var _must_deliver_cd: float = 15.0
var _must_deliver_name: String = ""
var _must_deliver_ring: Line2D
var _magneto_aim: bool = false
var _magneto_lv: int = 3
var _magneto_sid: String = ""
var _magneto_cd: float = 15.0
var _magneto_name: String = ""
var _magneto_ring: Line2D
## 掃地僧 follow tornado VFX (visible while buff active).
var _monk_tornado: Node2D
## Reused halo. Parented onto the current interact target, or parked off-tree.
var _interact_glow: Node2D
var _glow_host: Node2D
## Cached game host (avoids get_first_node_in_group every physics frame).
var game: Node = null
## Dirty HUD: skip inventory.grouped() fingerprint until something relevant changes.
var _hud_dirty: bool = true
var _hud_inv_rev: int = -1
var _hud_move: String = ""
var _hud_stam: float = -999.0
var _hud_stam_max: float = -999.0
var _hud_carry: int = -1
var _hud_hold: float = -999.0
var _hud_blocked: bool = false
var _hud_target_id: int = 0
var _hud_target_detail: String = ""
var _shown_anim: String = ""
var _cast_pose_left: float = 0.0
var _deliver_pose_left: float = 0.0
var _shown_tint: Color = Color(0, 0, 0, 0)
var _menu_fp: String = ""
var _cached_clock: float = 1.0
var _cached_cust_mult: float = 1.0
var _buff_cache_valid: bool = false
var _crowd_active: bool = false
var _crowd_say: Label
var _wave_vfx_cd: float = 0.0


func controls_locally() -> bool:
	return SeatTable.seat_owned_locally(seat_id)


func is_net_puppet() -> bool:
	## Client-side copy of a seat owned by another peer (or frozen).
	return SessionService.is_lan() and SessionService.is_client() and not controls_locally()


func _agent_is_net_puppet(node: Node) -> bool:
	## World agents on client are presentation-only (M2.2); Host owns KO / loot / flee.
	return node != null and is_instance_valid(node) and node.has_method("is_net_puppet") and bool(node.call("is_net_puppet"))


func _move_vector() -> Vector2:
	## Host drives remote seats from last intent; local seats use Controls.
	if SessionService.is_lan() and SessionService.is_server() and not controls_locally():
		return remote_move
	return Controls.move_vector_for(seat_id)


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	stamina = stamina_max_now()
	_circle = CircleScript.new()
	add_child(_circle)
	_prompt = PromptScript.new()
	add_child(_prompt)
	_menu = MenuScript.new()
	add_child(_menu)
	var stack := BoxStackScript.new()
	stack.position = Vector2(0, -6)
	stack.setup(inventory)
	add_child(stack)
	if inventory.has_signal("changed"):
		inventory.changed.connect(_mark_hud_dirty)
	_setup_drop_aim()
	_setup_must_deliver_ring()
	_setup_magneto_ring()
	_setup_monk_tornado()
	_setup_crowd_say()
	_refresh_passive_checkout()


func _setup_crowd_say() -> void:
	_crowd_say = Label.new()
	_crowd_say.name = "CrowdSay"
	_crowd_say.visible = false
	_crowd_say.text = Loc.t("log.player.crowd_say")
	_crowd_say.position = Vector2(-70, -92)
	_crowd_say.z_index = 10
	UiFont.apply_label(_crowd_say, UiFont.WORLD)
	_crowd_say.add_theme_color_override("font_color", Color("fff4c2"))
	_crowd_say.add_theme_color_override("font_outline_color", Color("121212"))
	_crowd_say.add_theme_constant_override("outline_size", 6)
	add_child(_crowd_say)


func _setup_drop_aim() -> void:
	_drop_aim_line = Line2D.new()
	_drop_aim_line.name = "DropAimLine"
	_drop_aim_line.width = 3.0
	_drop_aim_line.default_color = Tuning.DROP_AIM_LINE_COLOR
	_drop_aim_line.visible = false
	_drop_aim_line.z_index = 6
	add_child(_drop_aim_line)
	_drop_aim_mark = Polygon2D.new()
	_drop_aim_mark.name = "DropAimMark"
	_drop_aim_mark.color = Tuning.DROP_AIM_MARK_COLOR
	_drop_aim_mark.polygon = PackedVector2Array([
		Vector2(-10, 0), Vector2(0, -10), Vector2(10, 0), Vector2(0, 10),
	])
	_drop_aim_mark.visible = false
	_drop_aim_mark.z_index = 6
	add_child(_drop_aim_mark)


func _setup_must_deliver_ring() -> void:
	_must_deliver_ring = Line2D.new()
	_must_deliver_ring.name = "MustDeliverRing"
	_must_deliver_ring.width = 2.0
	_must_deliver_ring.default_color = Color(0.35, 0.9, 1.0, 0.55)
	_must_deliver_ring.visible = false
	_must_deliver_ring.z_index = 5
	add_child(_must_deliver_ring)


func _setup_magneto_ring() -> void:
	_magneto_ring = Line2D.new()
	_magneto_ring.name = "MagnetoRing"
	_magneto_ring.width = 2.0
	_magneto_ring.default_color = Color(0.75, 0.45, 1.0, 0.55)
	_magneto_ring.visible = false
	_magneto_ring.z_index = 5
	add_child(_magneto_ring)


func _setup_monk_tornado() -> void:
	_monk_tornado = Node2D.new()
	_monk_tornado.name = "SweepingMonkTornado"
	_monk_tornado.visible = false
	_monk_tornado.z_index = 6
	var r := Skills.SWEEPING_MONK_RANGE
	for i in 3:
		var ring := Line2D.new()
		ring.width = 2.0 - float(i) * 0.35
		ring.default_color = Color(0.55, 0.95, 0.75, 0.45 - float(i) * 0.08)
		var pts := PackedVector2Array()
		var n := 28
		var rr := r * (0.55 + float(i) * 0.18)
		for k in n + 1:
			var a := TAU * float(k) / float(n) + float(i) * 0.7
			## Slight spiral so it reads as a tornado, not a flat circle.
			var spiral := rr * (0.85 + 0.15 * sin(a * 3.0 + float(i)))
			pts.append(Vector2(cos(a), sin(a)) * spiral)
		ring.points = pts
		_monk_tornado.add_child(ring)
	add_child(_monk_tornado)


## Base 5 身位; later drop-range skills can multiply this.
func drop_toss_dist() -> float:
	return Tuning.DROP_TOSS_DIST


func _loadout() -> Array[Dictionary]:
	if stats != null and stats.has_method("loadout"):
		return stats.loadout()
	var out: Array[Dictionary] = []
	for sk in Skills.EQUIPPED:
		out.append(Skills.localize(sk))
	return out


func _skill_at(i: int) -> Dictionary:
	var slots := _loadout()
	if i < 0 or i >= slots.size():
		return {}
	return slots[i]


func _ult_sk() -> Dictionary:
	if stats != null and stats.has_method("ult_skill"):
		return stats.ult_skill()
	return Skills.localize(Skills.ULTIMATE)


func _stat_base(which: String) -> int:
	if stats == null:
		match which:
			"agi":
				return Tuning.AGI
			"int":
				return Tuning.INT
			_:
				return Tuning.STR
	match which:
		"agi":
			return int(stats.agi_stat)
		"int":
			return int(stats.int_stat)
		_:
			return int(stats.str_stat)


func _has_flag(flag: String) -> bool:
	if stats != null and stats.has_method("has_flag") and bool(stats.has_flag(flag)):
		return true
	## 掃地僧: timed full dirt immunity (same flags as 凌波微步).
	if buff_left("sweeping_monk") > 0.05:
		match flag:
			"ignore_dirt_slow", "ignore_trash_stamina", "ignore_puddle_slip", "ignore_vomit_sick":
				return true
	return false


## Snapshot for Multiple Shadow Clone. Actives and carry/polite/global passives stay off.
func clone_snapshot() -> Dictionary:
	var move_pct := 0.0
	var restock_pct := 0.0
	var checkout_pct := 0.0
	var wave := false
	for sk in _loadout():
		if str(sk.get("kind", "")) != "passive":
			continue
		move_pct += float(sk.get("move_pct", 0.0))
		restock_pct += float(sk.get("restock_pct", 0.0))
		checkout_pct += float(sk.get("checkout_pct", 0.0))
		if bool(sk.get("ignore_dirt_slow", false)):
			wave = true
	return {
		"str": _stat_base("str"),
		"agi": _stat_base("agi"),
		"int": _stat_base("int"),
		"move_pct": move_pct,
		"restock_pct": restock_pct,
		"checkout_pct": checkout_pct,
		"wave_step": wave,
		"skin_id": appearance_skin_id(),
	}


func _refresh_passive_checkout() -> void:
	_passive_checkout_pct = 0.0
	for sk in _loadout():
		## Godot 4.7: String(null) errors — empty loadout slots omit "kind".
		if str(sk.get("kind", "")) == "passive":
			_passive_checkout_pct += float(sk.get("checkout_pct", 0.0))


func bind_visuals(body: CanvasItem, arrow: Polygon2D) -> void:
	_body = body
	_arrow = arrow
	_model_id = appearance_skin_id()


func appearance_skin_id() -> String:
	const SkinCatalog = preload("res://scripts/session/skin_catalog.gd")
	if stats != null and stats.has_method("appearance_skin_id"):
		return SkinCatalog.normalize(String(stats.appearance_skin_id()))
	if stats != null and "skin_id" in stats:
		return SkinCatalog.normalize(String(stats.skin_id))
	return SkinCatalog.DEFAULT_SKIN


func add_dirt(delta_count: int) -> void:
	dirt_contacts = maxi(0, dirt_contacts + delta_count)


func enter_dirt(area: Node) -> void:
	var was := dirt_contacts
	if area != null and not _dirt_areas.has(area):
		_dirt_areas.append(area)
	dirt_contacts = _dirt_areas.size()
	if was <= 0 and dirt_contacts > 0:
		SfxBus.play("sfx_move_dirt_step")


func exit_dirt(area: Node) -> void:
	_dirt_areas.erase(area)
	_prune_dirt_inplace()


func on_dirt() -> bool:
	## Trust enter/exit; prune only when an area exits the tree.
	return dirt_contacts > 0


func _prune_dirt_inplace() -> void:
	var i := 0
	while i < _dirt_areas.size():
		if _dirt_areas[i] == null or not is_instance_valid(_dirt_areas[i]):
			_dirt_areas.remove_at(i)
			continue
		i += 1
	dirt_contacts = _dirt_areas.size()


func _has_dirt_type(dtype: String) -> bool:
	if dirt_contacts <= 0:
		return false
	for a in _dirt_areas:
		if a != null and is_instance_valid(a) and String(a.get("dirt_type")) == dtype:
			return true
	return false


func _ability_mult() -> float:
	return Tuning.SICK_ABILITY_MULT if _sick_left > 0.0 else 1.0


func _agi_now() -> int:
	return clampi(int(round(float(_stat_base("agi")) * _ability_mult())), 1, Tuning.AGI_EFFECT_CAP)


func _str_now() -> int:
	return clampi(int(round(float(_stat_base("str")) * _ability_mult())), 1, Tuning.STR_EFFECT_CAP)


func _int_now() -> int:
	return clampi(int(round(float(_stat_base("int")) * _ability_mult())), 1, Tuning.INT_EFFECT_CAP)


func stamina_max_now() -> float:
	return Tuning.stamina_max(_str_now())


func carry_boxes() -> int:
	## Legacy display helper: piece cap / BOX_SIZE (visual boxes).
	return int(ceil(float(carry_cap()) / float(Tuning.BOX_SIZE)))


func carry_cap() -> int:
	## Piece carry limit (STR base pieces + skill carry_add in pieces).
	var n := Tuning.carry_items_from_str(_str_now())
	for sk in _loadout():
		var add := int(sk.get("carry_add", 0))
		if add == 0:
			continue
		if str(sk.get("kind", "")) == "passive" or _buffs.has(str(sk.get("id", ""))):
			n += add
	return n


func move_speed_rate() -> float:
	var rate := 1.0
	for sk in _loadout():
		var pct := float(sk.get("move_pct", 0.0))
		if pct == 0.0:
			continue
		if str(sk.get("kind", "")) == "passive" or _buffs.has(str(sk.get("id", ""))):
			rate *= 1.0 + pct
	return rate


func restock_seconds_now() -> float:
	## Same formula as _tick_restock (inlined there after helper returned 0 wrongly).
	var base := float(Tuning.restock_seconds(_agi_now()))
	if buff_left("instant_restock") > 0.05:
		var lv := 3
		for sk in _loadout():
			if str(sk.get("id", "")) == "instant_restock":
				lv = int(sk.get("lv", 3))
				break
		var mult := float(Skills.restock_circle_mult(lv))
		if mult <= 0.0:
			return 0.0
		return maxf(base * mult, 0.05)
	var restock_pct := 0.0
	for sk in _loadout():
		if str(sk.get("kind", "")) == "passive":
			restock_pct += float(sk.get("restock_pct", 0.0))
	if restock_pct > 0.0:
		base /= 1.0 + restock_pct
	return maxf(base, 0.05)


func checkout_seconds_now() -> float:
	_refresh_passive_checkout()
	var sec := Tuning.checkout_seconds(_int_now())
	var rate := 1.0
	if _passive_checkout_pct > 0.0:
		rate *= 1.0 + _passive_checkout_pct
	for sk in _loadout():
		## Godot 4.7: String(null) errors on empty loadout slots → default return 0 → instant checkout.
		var sid := str(sk.get("id", ""))
		if str(sk.get("kind", "")) != "active" or not _buffs.has(sid):
			continue
		if sk.has("checkout_pct"):
			rate *= 1.0 + float(sk.get("checkout_pct"))
	var out := sec / rate
	## 資深收銀員 LV3：Circle ×0.5（可與人肉數錢機等疊乘之後再砍）。
	if _senior_cashier_lv_now() >= 3:
		out *= 0.5
	return maxf(out, 0.05)


func cd_left(skill_id: String) -> float:
	return float(_cd.get(skill_id, 0.0))


func buff_left(skill_id: String) -> float:
	return float(_buffs.get(skill_id, 0.0))


## Thrown boxes / pieces home to the nearest same-SKU shelf.
func sniper_shelf_active() -> bool:
	return buff_left("shelf_sniper") > 0.0


## Thrown boxes / pieces home to the nearest guest who still wants that SKU.
func sniper_guest_active() -> bool:
	return buff_left("guest_sniper") > 0.0


## Thrown boxes / pieces home to the nearest active thief and KO them.
func sniper_thief_active() -> bool:
	return buff_left("thief_sniper") > 0.0


func store_status_text() -> String:
	var bits: PackedStringArray = []
	if _buffs.has("the_world"):
		bits.append(Loc.t("hud.status.world_stop", [_buffs["the_world"]]))
	if _buffs.has("yes_my_lord"):
		bits.append("Yes! My Lord! %.0fs" % _buffs["yes_my_lord"])
	if _buffs.has("guest_dusk"):
		bits.append(Loc.t("hud.status.dusk", [_buffs["guest_dusk"]]))
	if _buffs.has("metal_rush"):
		bits.append(Loc.t("hud.status.metal", [_buffs["metal_rush"]]))
	if bits.is_empty():
		return Loc.t("hud.scene.shop_status")
	return Loc.t("hud.status.prefix_shop") + " · ".join(bits)


func role_status_text() -> String:
	var bits: PackedStringArray = []
	bits.append("STR%d AGI%d INT%d" % [_stat_base("str"), _stat_base("agi"), _stat_base("int")])
	if _buffs.has("carry_boost"):
		bits.append(Loc.t("hud.status.carry", [_buffs["carry_boost"]]))
	if _buffs.has("move_boost"):
		bits.append(Loc.t("hud.status.move", [_buffs["move_boost"]]))
	if _buffs.has("instant_restock"):
		bits.append(Loc.t("hud.status.instant", [_buffs["instant_restock"]]))
	if _buffs.has("shelf_sniper"):
		bits.append(Loc.t("hud.status.sniper_shelf", [_buffs["shelf_sniper"]]))
	if _buffs.has("guest_sniper"):
		bits.append(Loc.t("hud.status.sniper_guest", [_buffs["guest_sniper"]]))
	if _buffs.has("thief_sniper"):
		bits.append(Loc.t("hud.status.sniper_thief", [_buffs["thief_sniper"]]))
	if _buffs.has("dash_deliver"):
		bits.append(Loc.t("hud.status.dash_deliver", [_buffs["dash_deliver"]]))
	if _buffs.has("dasher"):
		bits.append("Dasher %.0fs" % _buffs["dasher"])
	if _buffs.has("senior_cashier"):
		bits.append(Loc.t("hud.status.senior", [_buffs["senior_cashier"]]))
	if _buffs.has("hoop_ace"):
		bits.append(Loc.t("hud.status.hoop", [_buffs["hoop_ace"]]))
	if _buffs.has("sweeping_monk"):
		bits.append(Loc.t("hud.status.monk", [_buffs["sweeping_monk"]]))
	if _sick_left > 0.0:
		bits.append(Loc.t("hud.status.sick", [_sick_left]))
	if _fighting:
		bits.append(Loc.t("hud.status.fighting"))
	if _stun_left > 0.0:
		bits.append(Loc.t("hud.status.down", [_stun_left]))
	if _passive_checkout_pct > 0.0:
		bits.append(Loc.t("hud.status.checkout_pct", [(_passive_checkout_pct * 100.0)]))
	return Loc.t("hud.status.prefix_role") + " ".join(bits)


func set_hold(action: String, pressed: bool) -> void:
	## LAN Host applies intents every tick as levels — must edge-trigger.
	## Otherwise interact=false spam calls _do_short_interact every frame (auto-loot).
	match action:
		"interact":
			if _interact_ignore_until_up:
				if pressed:
					return
				_interact_ignore_until_up = false
				_j_held = false
				_j_time = 0.0
				_long_committed = false
				_deliver_done = false
				## Do not short-interact on the release that ends the latch.
				return
			if _fighting:
				## Keep `_j_held` truthful during mash so fight-end knows if the
				## physical Interact is still down (vs already released).
				if pressed:
					if not _fight_release:
						_fight_tap()
					_fight_release = true
					_j_held = true
				else:
					_fight_release = false
					_j_held = false
				return
			if pressed:
				if _j_held:
					return
				_j_held = true
				_j_time = 0.0
				_long_committed = false
				_deliver_done = false
				_restock_hold = 0.0
				_restock_aborted = false
				_pickup_used = false
				_no_queue_logged = false
			else:
				if not _j_held:
					return
				_release_interact()
				_j_held = false
				_reset_hold()
				_pickup_used = false
				_no_queue_logged = false
		"dash":
			if command_lock or skill_menu_open or ult_prep or _fighting:
				return
			if pressed:
				if _k_held:
					return
				_k_held = true
				_k_time = 0.0
			else:
				if not _k_held:
					return
				## 輕放＝衝刺；已過門檻變成奔跑的這次按鍵不再補衝（起跑不會先衝一記）。
				if not _running and _k_time < Tuning.RUN_HOLD_THRESHOLD:
					_try_dash()
				_k_held = false
				_running = false
		"skill":
			## Level intents from LAN must not re-enter press every tick (resets _l_time).
			if pressed and _l_held:
				return
			if pressed:
				_skill_from_pad = _skill_pad_hint
				_skill_pad_hint = false
			_on_skill_hold(pressed)
		"ult":
			## Keyboard U / touch RB button. Xbox pad uses LT+RT chord instead.
			## Edge-only: repeat ult=true intents must not re-fire prep.
			if pressed and _u_held:
				return
			if pressed:
				_ult_chord_active = false
			_on_ult_hold(pressed)
		"cancel":
			if pressed:
				if _cancel_held:
					return
				_cancel_held = true
				_cancel_time = 0.0
				_cancel_drop_ready = false
				_cancel_dropped = false
				_cancel_drop_dir = Vector2.ZERO
				_cancel_swallowed = false
				_sample_cancel_drop_dir()
				_cancel_input()
			else:
				if not _cancel_held:
					return
				_cancel_held = false
				_on_cancel_release()


func move_state() -> String:
	if _stun_left > 0.0:
		return Loc.t("hud.move.stun")
	if _slip_left > 0.0:
		return Loc.t("hud.move.slip")
	if _drop_flight_lock or _piece_drop_lock:
		return Loc.t("hud.move.toss")
	if _cancel_held and not _cancel_dropped:
		return Loc.t("hud.move.drop_aim")
	if ult_prep:
		return Loc.t("hud.move.ult_cmd")
	if _must_deliver_aim:
		return Loc.t("hud.move.must_deliver")
	if _magneto_aim:
		return Loc.t("hud.move.magneto")
	if skill_menu_open:
		return Loc.t("hud.move.skill_menu")
	if _restock_picking:
		return Loc.t("hud.move.pick_sku")
	if _cleaning():
		return Loc.t("hud.move.clean")
	if _fighting:
		return Loc.t("hud.move.fight")
	if command_lock:
		return Loc.t("hud.move.checkout_cmd")
	if _dashing:
		return "DASH"
	if _running and velocity.length() > 8.0:
		return "RUN"
	if velocity.length() > 8.0:
		return "WALK"
	return "IDLE"


func speed_mult() -> float:
	var m := Tuning.agi_mult(_agi_now())
	m *= move_speed_rate()
	var n := inventory.count()
	var cap := carry_cap()
	if n > cap:
		m *= Tuning.OVERWEIGHT_OVER_CAP_MULT
	if on_dirt() and not _has_flag("ignore_dirt_slow"):
		m *= Tuning.DIRT_MULT
	if _crowd_near():
		m *= Tuning.CROWD_SPEED_MULT
	return clampf(m, 0.0, Tuning.SPEED_MAX_MULT)


func _crowd_near() -> bool:
	var g := _game()
	if g == null or not g.has_method("customers_near"):
		## Fallback: scan game customers group / thieves list.
		return _crowd_near_fallback()
	return g.call("customers_near", global_position, Tuning.CROWD_RADIUS_SQ) == true


func _crowd_near_fallback() -> bool:
	var g := _game()
	if g == null or g.get("_customers") == null:
		return false
	var rsq := Tuning.CROWD_RADIUS_SQ
	var n := 0
	for c in g._customers.get_children():
		if c == null or not is_instance_valid(c):
			continue
		if not c.has_method("occupies_store"):
			continue
		if c.temp_clerk:
			continue
		## Match demo.customers_near: leave / flee / temp job do not block the aisle.
		var st: int = c.state
		if st == CustomerScript.State.LEAVE or st == CustomerScript.State.FLEE or st == CustomerScript.State.TEMP:
			continue
		if global_position.distance_squared_to(c.global_position) <= rsq:
			n += 1
			if n >= 2:
				return true
	return false


func _sync_crowd_say() -> void:
	## Hide during dash so「唔該借借」is not mistaken for a failed 衝刺交付.
	var on := (not _dashing) and _crowd_near()
	if on and not _crowd_active:
		SfxBus.play("sfx_move_crowd")
	_crowd_active = on
	if _crowd_say:
		_crowd_say.visible = on


func _shelving() -> bool:
	return _long_committed and _j_held and is_instance_valid(target) and _obj_str(target, "kind") == "shelf"


func _cleaning() -> bool:
	return _long_committed and _j_held and is_instance_valid(target) and _obj_str(target, "kind") == "dirt"


func _in_dir_mode() -> bool:
	if ult_prep or skill_menu_open or _restock_picking or _l_held or _u_held:
		return true
	if _j_held and is_instance_valid(target):
		var kind := _obj_str(target, "kind")
		if kind == "cashier" or kind == "restock":
			return true
	elif _j_held and target != null:
		target = null
	return command_lock


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if not controls_locally():
		return
	if not Controls.event_for_seat(event, seat_id):
		return
	# Early-close dialog and closeout own confirm / cancel.
	if _asking_early():
		return
	if not _round_active() and (event.is_action(Controls.INTERACT) or event.is_action(Controls.CANCEL)):
		return
	# Discrete directions only here; analog stick uses _poll_stick_cardinal.
	if _in_dir_mode() and event.is_pressed() and (
		event is InputEventKey or event is InputEventJoypadButton
	):
		var dir := Controls.dir_from_event(event)
		if dir >= 0:
			_try_dir(dir)
			get_viewport().set_input_as_handled()
			return
	for action in Controls.HOLD_ACTIONS:
		if event.is_action(action) and (event is InputEventKey or event is InputEventJoypadButton):
			if action == Controls.SKILL and event.is_pressed():
				_skill_pad_hint = event is InputEventJoypadButton
			set_hold(action, event.is_pressed())
			get_viewport().set_input_as_handled()
			return
	if event.is_pressed() and (event is InputEventKey or event is InputEventJoypadButton):
		_handle_hotkey_actions(event)


func _begin_drop_aim() -> void:
	## Entering drop prep pauses walk/run/dash until the box lands.
	_running = false
	_dashing = false
	velocity = Vector2.ZERO


func _tick_cancel_hold(delta: float) -> void:
	if _cancel_dropped:
		return
	## Direction is sampled the whole time. Aim circle and move-lock start only after the long press.
	_sample_cancel_drop_dir()
	_cancel_time += delta
	if _cancel_time >= Tuning.DROP_HOLD_SEC:
		if not _cancel_drop_ready:
			_cancel_drop_ready = true
			_begin_drop_aim()
			SfxBus.play("sfx_box_drop_aim")
		_update_drop_aim()


func _on_cancel_release() -> void:
	## Armed by long-press → toss the top segment on release.
	## Short press with a direction tosses one piece, unless this press cancelled a menu or action.
	if _cancel_drop_ready and not _cancel_dropped and not _drop_flight_lock:
		_cancel_dropped = true
		_hide_drop_aim()
		_discard_top_box()
	elif not _drop_flight_lock:
		if not _cancel_swallowed:
			_toss_top_piece()
		_cancel_drop_dir = Vector2.ZERO
		_hide_drop_aim()
	## Previous piece already landed and this press did not throw another: walk again.
	## A whole-box flight keeps its own lock, so clear the piece lock here too.
	if _piece_flights <= 0:
		_piece_drop_lock = false
	_cancel_time = 0.0
	_cancel_drop_ready = false


func _sample_cancel_drop_dir() -> void:
	## Direction keys retarget aim; no input keeps last aim or feet (zero).
	var v := _move_vector() + stick_axis
	if v.length() >= Tuning.DROP_DIR_DEADZONE:
		_cancel_drop_dir = v.normalized()
		facing = _cancel_drop_dir


func _drop_aim_dest() -> Vector2:
	return global_position + Tuning.drop_offset(_cancel_drop_dir, drop_toss_dist())


func _update_drop_aim() -> void:
	if _drop_aim_line == null or inventory.is_empty():
		_hide_drop_aim()
		return
	var dest := _drop_aim_dest()
	_drop_aim_line.visible = true
	_drop_aim_mark.visible = true
	_drop_aim_line.points = PackedVector2Array([Vector2.ZERO, dest - global_position])
	_drop_aim_mark.position = dest - global_position


func _hide_drop_aim() -> void:
	if _drop_aim_line:
		_drop_aim_line.visible = false
	if _drop_aim_mark:
		_drop_aim_mark.visible = false


func _game() -> Node:
	if game != null and is_instance_valid(game):
		return game
	game = get_tree().get_first_node_in_group("game")
	return game


func _round_active() -> bool:
	var g := _game()
	if g == null:
		return true
	var phase := String(g.get("phase"))
	return phase == "restock" or phase == "open"


func _asking_early() -> bool:
	var g := _game()
	return g != null and g.has_method("asking_early_close") and bool(g.asking_early_close())


func _mark_hud_dirty() -> void:
	_hud_dirty = true


func _discard_top_box() -> void:
	if not _round_active():
		return
	if _stun_left > 0.0 or _slip_left > 0.0 or _fighting:
		return
	if inventory.is_empty():
		log_line.emit(Loc.t("log.player.hands_empty"))
		_hide_drop_aim()
		return
	var run: Dictionary = inventory.trailing_run()
	var name := Tuning.sku_name(String(run["id"]))
	var n := int(run["count"])
	var toss := _cancel_drop_dir
	_drop_top_box(toss)
	if toss.length_squared() > 0.01:
		SfxBus.play("sfx_box_toss")
		var hint := _sniper_toss_log(name, true)
		if hint != "":
			log_line.emit(hint)
		else:
			log_line.emit(
				Loc.t("log.player.toss_fly", [name, n, _drop_dir_label(toss)])
			)
	else:
		SfxBus.play("sfx_box_drop_feet")
		log_line.emit(Loc.t("log.player.toss_feet", [name, n]))


## Direction + short cancel: throw the top piece. No aim circle.
## Stop while it flies. Another toss before it lands keeps the stop.
## When the last piece lands and cancel is up, a held direction walks again.
func _toss_top_piece() -> bool:
	if not _round_active():
		return false
	if _stun_left > 0.0 or _slip_left > 0.0 or _fighting or _drop_flight_lock:
		return false
	if _cancel_drop_dir.length_squared() < 0.01:
		return false
	if inventory.is_empty():
		log_line.emit(Loc.t("log.player.hands_empty"))
		return false
	## 投籃高手：短按方向一次飛出最上 2 件（可不同 SKU）；只有 1 件則 1。
	var want := 2 if buff_left("hoop_ace") > 0.05 else 1
	var tossed: PackedStringArray = []
	for _i in want:
		if inventory.is_empty():
			break
		var run: Dictionary = inventory.trailing_run()
		var sku := String(run["id"])
		inventory.remove_trailing(1)
		tossed.append(sku)
	if tossed.is_empty():
		return false
	var dir := _cancel_drop_dir
	var dist := drop_toss_dist()
	_launch_piece_toss(String(tossed[0]), dir, dist, Vector2.ZERO)
	if tossed.size() >= 2:
		## Delay + lateral land offset so the second box reads as a separate toss.
		var sku2 := String(tossed[1])
		var nudge := _hoop_ace_side_nudge(dir)
		_piece_flights += 1
		_piece_drop_lock = true
		_running = false
		_dashing = false
		velocity = Vector2.ZERO
		get_tree().create_timer(Tuning.HOOP_ACE_SECOND_DELAY_SEC).timeout.connect(
			func() -> void:
				if not is_instance_valid(self):
					return
				if not _round_active():
					_on_piece_drop_landed()
					return
				_launch_piece_toss(sku2, dir, dist, nudge, false)
		)
	var names: PackedStringArray = []
	for s in tossed:
		names.append(Tuning.sku_name(String(s)))
	var label := "、".join(names)
	var hint := _sniper_toss_log(label, false)
	if hint != "":
		log_line.emit(hint)
	elif tossed.size() >= 2:
		log_line.emit(Loc.t("log.player.hoop_toss", [label, _drop_dir_label(dir)]))
	else:
		log_line.emit(Loc.t("log.player.toss_one", [label, _drop_dir_label(dir)]))
	return true


func _hoop_ace_side_nudge(dir: Vector2) -> Vector2:
	if dir.length_squared() < 0.0001:
		return Vector2(Tuning.HOOP_ACE_SIDE_OFFSET, 0.0)
	var forward := dir.normalized()
	## Perpendicular to toss (screen-right of throw direction).
	return Vector2(-forward.y, forward.x) * Tuning.HOOP_ACE_SIDE_OFFSET


func _launch_piece_toss(
	sku: String,
	dir: Vector2,
	dist: float,
	land_nudge: Vector2 = Vector2.ZERO,
	count_flight: bool = true,
) -> void:
	var host := _game()
	if host == null or not host.has_method("spawn_dropped_box"):
		if not count_flight:
			_on_piece_drop_landed()
		return
	if count_flight:
		_piece_flights += 1
	_piece_drop_lock = true
	_running = false
	_dashing = false
	velocity = Vector2.ZERO
	host.call(
		"spawn_dropped_box",
		global_position,
		sku,
		1,
		dir,
		dist,
		Callable(self, "_on_piece_drop_landed"),
		land_nudge,
	)
	SfxBus.play("sfx_box_toss")


func _sniper_toss_log(sku_name: String, whole_run: bool) -> String:
	var unit := Loc.t("log.player.unit_run") if whole_run else Loc.t("log.player.unit_one")
	if sniper_thief_active():
		return Loc.t("log.player.sniper_toss_thief", [sku_name, unit])
	if sniper_guest_active():
		return Loc.t("log.player.sniper_toss_guest", [sku_name, unit])
	if sniper_shelf_active():
		return Loc.t("log.player.sniper_toss_shelf", [sku_name, unit])
	return ""


func _on_piece_drop_landed() -> void:
	_piece_flights = maxi(0, _piece_flights - 1)
	if _piece_flights > 0:
		return
	## Still holding cancel for another short drop: stay stopped until that press ends.
	if _cancel_held and not _cancel_swallowed and not _cancel_drop_ready:
		return
	_piece_drop_lock = false


func _drop_dir_label(dir: Vector2) -> String:
	if absf(dir.x) > absf(dir.y):
		return Loc.t("dir.right") if dir.x > 0.0 else Loc.t("dir.left")
	return Loc.t("dir.down") if dir.y > 0.0 else Loc.t("dir.up")


func _cancel_input() -> void:
	var used := _fighting or _stun_left > 0.0 or _slip_left > 0.0 or _long_committed or command_lock
	if _restock_picking:
		_abort_restock_pick()
		_restock_aborted = true
		_j_held = false
		log_line.emit(Loc.t("log.player.cancel_pick"))
		used = true
	if _must_deliver_aim:
		_cancel_must_deliver_aim()
		used = true
	if _magneto_aim:
		_cancel_magneto_aim()
		used = true
	if skill_menu_open or _l_held or _skill_latch:
		_close_skill_menu()
		SfxBus.play("sfx_skill_menu_cancel")
		log_line.emit(Loc.t("log.player.cancel_skill_menu"))
		used = true
	if ult_prep:
		_on_ult_hold(false)
		used = true
	if _j_held:
		set_hold("interact", false)
		used = true
	if used:
		_cancel_swallowed = true


func _physics_process(delta: float) -> void:
	if is_net_puppet():
		## Presentation only — Host already wrote facing／position; still refresh Vox.
		velocity = Vector2.ZERO
		if _net_puppet_pos == Vector2.INF:
			_net_puppet_moving = false
		else:
			_net_puppet_moving = global_position.distance_squared_to(_net_puppet_pos) > 2.25
		_net_puppet_pos = global_position
		_sync_interact_glow()
		_update_visuals()
		return
	if SeatTable.is_frozen(seat_id):
		velocity = Vector2.ZERO
		_sync_interact_glow()
		_update_visuals()
		return
	if _asking_early():
		velocity = Vector2.ZERO
		_sync_interact_glow()
		return
	if _elite_focus_left > 0.0:
		_elite_focus_left = maxf(0.0, _elite_focus_left - delta)
		velocity = Vector2.ZERO
		_tick_buffs(delta)
		_tick_status(delta)
		_tick_camera_shake(delta)
		_sync_interact_glow()
		return
	_tick_buffs(delta)
	_tick_status(delta)
	if _cast_pose_left > 0.0:
		_cast_pose_left = maxf(0.0, _cast_pose_left - delta)
	if _deliver_pose_left > 0.0:
		_deliver_pose_left = maxf(0.0, _deliver_pose_left - delta)
	command_lock = _long_committed and _j_held and is_instance_valid(target) and _obj_str(target, "kind") == "cashier" and not skill_menu_open and not ult_prep
	if not command_lock and not ult_prep:
		_prompt.active = false
	if _k_held and not _cancel_held and not _drop_flight_lock and not _piece_drop_lock and not command_lock and not skill_menu_open and not ult_prep and not _fighting and _stun_left <= 0.0 and _slip_left <= 0.0:
		_k_time += delta
		if _k_time >= Tuning.RUN_HOLD_THRESHOLD:
			_running = _dasher_active() or stamina > 1.0
	if _cancel_held:
		_tick_cancel_hold(delta)
	## Long-press aim, a flying box, or a piece still in the air: freeze locomotion.
	if (_cancel_drop_ready or _drop_flight_lock or _piece_drop_lock) and _slip_left <= 0.0:
		_running = false
		_dashing = false
		velocity = Vector2.ZERO
	if _l_held and _sick_left <= 0.0 and _stun_left <= 0.0:
		_l_time += delta
		if not skill_menu_open and _l_time >= Skills.HOLD_MENU_SEC:
			_open_skill_menu(false)
		if skill_menu_open and not _skill_latch:
			_sync_hold_aim()
	## Pad LT/RT only on locally owned seats; remote seats get skill/ult via Intent (M2.5).
	if controls_locally() and _round_active() and not _asking_early():
		_tick_triggers(delta)
	## Skill / ult / checkout dir modes: hard-stop so held WASD cannot coast.
	if _in_dir_mode() or _move_locked_until_neutral:
		_running = false
		if not _dashing and _slip_left <= 0.0:
			velocity = Vector2.ZERO
	if _fighting:
		velocity = Vector2.ZERO
	elif _slip_left > 0.0:
		_tick_slip(delta)
	elif _dashing:
		_tick_dash(delta)
	else:
		_tick_move(delta)
	_poll_stick_cardinal()
	_regen(delta)
	_update_target()
	_tick_action(delta)
	_tick_sweeping_monk(delta)
	_sync_interact_glow()
	if _circle:
		## Clean uses dirt StickHint (blue meter + stick), not the yellow hold Circle.
		if _cleaning():
			_circle.progress = 0.0
			_circle.blocked = false
		else:
			_circle.progress = hold_progress
			_circle.blocked = blocked_mismatch
	if _menu:
		## Host／他機 seat：邏輯可開選單瞄準，但不畫 radial（避免殘留 P2 選單）。
		_menu.open = skill_menu_open and controls_locally()
		if skill_menu_open and controls_locally():
			var mfp := "%s|%s" % [str(_cd), str(_loadout())]
			if mfp != _menu_fp:
				_menu_fp = mfp
				_menu.set_slots(_loadout(), _cd)
	_sync_crowd_say()
	_update_visuals()
	_emit_stats_if_changed()


func _obj_str(node: Object, prop: String) -> String:
	var v = node.get(prop)
	return str(v) if v != null else ""


func _obj_int(node: Object, prop: String) -> int:
	var v = node.get(prop)
	return int(v) if v != null else 0


func _obj_float(node: Object, prop: String) -> float:
	var v = node.get(prop)
	return float(v) if v != null else 0.0


func _target_detail_fp(node: Node2D) -> String:
	if node == null or not is_instance_valid(node):
		return "-"
	var k := _obj_str(node, "kind")
	var tinfo := "%s:%d" % [k, node.get_instance_id()]
	match k:
		"restock":
			var pick = node.call("selected_sku") if node.has_method("selected_sku") else ""
			tinfo += ":%s" % (str(pick) if pick != null else "")
		"dirt":
			var dname = node.call("type_name") if node.has_method("type_name") else ""
			tinfo += ":%s" % (str(dname) if dname != null else "")
		"universal_cannon":
			tinfo += ":%s" % str(node.ammo)
		"drop":
			tinfo += ":%s:%d" % [_obj_str(node, "sku"), _obj_int(node, "count")]
		"shelf":
			var cap := _obj_int(node, "capacity")
			if cap <= 0:
				cap = Tuning.SHELF_CAP
			tinfo += ":%s:%d:%d" % [_obj_str(node, "sku"), _obj_int(node, "count"), cap]
		"thief":
			tinfo += ":%.0f:%.1f" % [_obj_float(node, "fight_hp"), _obj_float(node, "fight_left")]
		"", "elite":
			tinfo += ":guest"
	return tinfo


func _hud_fingerprint() -> String:
	## Assumes cheap HUD caches were refreshed by _emit_stats_if_changed.
	var inv_bits: PackedStringArray = []
	for g in inventory.grouped():
		inv_bits.append("%s:%d" % [String(g["id"]), int(g["count"])])
	return "%s|%.2f|%.2f|%d|%s|%.2f|%s|%s" % [
		_hud_move,
		_hud_stam,
		_hud_stam_max,
		_hud_carry,
		",".join(inv_bits),
		_hud_hold,
		str(_hud_blocked),
		_hud_target_detail,
	]


func _emit_stats_if_changed() -> void:
	## Cheap dirty gate — avoid inventory.grouped() / string join when nothing changed.
	var inv_rev: int = int(inventory.revision) if inventory != null else 0
	var move := move_state()
	var stam := snappedf(stamina, 0.25)
	var stam_max := snappedf(stamina_max_now(), 0.25)
	var carry := int(carry_cap())
	var hold := snappedf(hold_progress, 0.01)
	var tid: int = target.get_instance_id() if is_instance_valid(target) else 0
	var need := _hud_dirty
	if inv_rev != _hud_inv_rev:
		need = true
	elif move != _hud_move:
		need = true
	elif not is_equal_approx(stam, _hud_stam):
		need = true
	elif not is_equal_approx(stam_max, _hud_stam_max):
		need = true
	elif carry != _hud_carry:
		need = true
	elif not is_equal_approx(hold, _hud_hold):
		need = true
	elif blocked_mismatch != _hud_blocked:
		need = true
	elif tid != _hud_target_id:
		need = true
	elif tid != 0:
		var detail := _target_detail_fp(target)
		if detail != _hud_target_detail:
			need = true
			_hud_target_detail = detail
	if not need:
		return
	_hud_inv_rev = inv_rev
	_hud_move = move
	_hud_stam = stam
	_hud_stam_max = stam_max
	_hud_carry = carry
	_hud_hold = hold
	_hud_blocked = blocked_mismatch
	_hud_target_id = tid
	_hud_target_detail = _target_detail_fp(target) if tid != 0 else "-"
	_hud_dirty = false
	var fp := _hud_fingerprint()
	if fp == _hud_fp:
		return
	_hud_fp = fp
	stats_changed.emit()


func _enqueue_cust_speed(skill_id: String) -> void:
	if not _cust_speed_q.has(skill_id):
		_cust_speed_q.append(skill_id)
		_buff_cache_valid = false


func _customer_move_kind(skill_id: String) -> String:
	var ult_id := String(_ult_sk().get("id", ""))
	if ult_id != "" and skill_id == ult_id:
		var scale := float(_ult_sk().get("clock_scale", 0.0))
		if scale <= 0.001:
			return "stop"
		if scale < 1.0:
			return "slow"
		return ""
	for sk in _loadout():
		if String(sk.get("id")) != skill_id:
			continue
		var pct := float(sk.get("customer_move_pct", 0.0))
		if pct > 0.0:
			return "fast"
		if pct < 0.0:
			return "slow"
	return ""


func _customer_move_mult_now() -> float:
	var kinds: PackedStringArray = []
	for id in _cust_speed_q:
		if not _buffs.has(id):
			continue
		var k := _customer_move_kind(id)
		if k != "" and not kinds.has(k):
			kinds.append(k)
	if kinds.has("stop"):
		return 1.0
	var mixed := kinds.has("fast") and kinds.has("slow")
	if mixed:
		for id in _cust_speed_q:
			if not _buffs.has(id):
				continue
			var k := _customer_move_kind(id)
			if k == "fast":
				return 1.0 + _cust_move_pct(id)
			if k == "slow":
				return 1.0
		return 1.0
	var m := 1.0
	for id in _cust_speed_q:
		if not _buffs.has(id):
			continue
		if _customer_move_kind(id) != "fast":
			continue
		m *= 1.0 + _cust_move_pct(id)
	return m


func _world_clock_now() -> float:
	if not _buffs.has("the_world"):
		return 1.0
	var scale := float(_ult_sk().get("clock_scale", 0.0))
	if scale <= 0.001:
		return 0.0
	var has_fast := false
	var has_slow := false
	for id in _cust_speed_q:
		if not _buffs.has(id):
			continue
		var k := _customer_move_kind(id)
		if k == "fast":
			has_fast = true
		elif k == "slow":
			has_slow = true
	if has_fast and has_slow:
		for id in _cust_speed_q:
			if not _buffs.has(id):
				continue
			var k := _customer_move_kind(id)
			if k == "fast":
				return 1.0
			if k == "slow":
				return scale
	return scale


func _cust_move_pct(skill_id: String) -> float:
	if skill_id == "the_world":
		return 0.0
	for sk in _loadout():
		if String(sk.get("id")) == skill_id:
			return float(sk.get("customer_move_pct", 0.0))
	return 0.0


func _tick_buffs(delta: float) -> void:
	var gone: Array[String] = []
	for id in _buffs.keys():
		_buffs[id] = float(_buffs[id]) - delta
		if float(_buffs[id]) <= 0.0:
			gone.append(String(id))
	var changed := not gone.is_empty()
	for id in gone:
		if id == "the_world":
			SfxBus.play("sfx_ult_the_world_end")
		if id == "senior_cashier":
			_senior_cashier_lv = 0
		if id == "sweeping_monk":
			_sync_monk_tornado(false)
		_buffs.erase(id)
	for id in _cd.keys():
		_cd[id] = maxf(0.0, float(_cd[id]) - delta)
	var keep_q: Array[String] = []
	for id in _cust_speed_q:
		if _buffs.has(id):
			keep_q.append(id)
	if keep_q.size() != _cust_speed_q.size():
		changed = true
	_cust_speed_q = keep_q
	if changed or not _buff_cache_valid:
		_cached_clock = _world_clock_now()
		_cached_cust_mult = _customer_move_mult_now()
		_buff_cache_valid = true
	clock_scale = _cached_clock
	customer_move_mult = _cached_cust_mult


func _wiggle_axis() -> Vector2:
	var v := _move_vector() + stick_axis
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v


func _move_axis() -> Vector2:
	## Long-press aim, box flight, or a piece still in the air: no locomotion.
	## After the last piece lands, a direction that is still held walks again.
	if _cancel_drop_ready or _drop_flight_lock or _piece_drop_lock:
		return Vector2.ZERO
	if _elite_focus_left > 0.0:
		return Vector2.ZERO
	if _stun_left > 0.0 or _slip_left > 0.0 or _fighting or _shelving() or _cleaning():
		return Vector2.ZERO
	if _in_dir_mode():
		## Arm latch: skill menu / ult / checkout / restock pick consume move_* .
		_move_locked_until_neutral = true
		return Vector2.ZERO
	var v := _move_vector() + stick_axis
	if _move_locked_until_neutral:
		if v.length() < Controls.MOVE_DEADZONE:
			_move_locked_until_neutral = false
		else:
			return Vector2.ZERO
	if v.length() < Controls.MOVE_DEADZONE:
		return Vector2.ZERO
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v


func _poll_stick_cardinal() -> void:
	# Analog only (touch stick / left stick). Discrete move_* taps are handled in _input.
	# Host remote seats: use intent remote_move (M2.5) — no local stick on this machine.
	if not _in_dir_mode():
		_cardinal_armed = true
		return
	var v: Vector2
	if SessionService.is_lan() and SessionService.is_server() and not controls_locally():
		v = remote_move
	else:
		v = stick_axis + _joy_stick_vector()
	if v.length() < 0.42:
		_cardinal_armed = true
		return
	if not _cardinal_armed:
		return
	_cardinal_armed = false
	var dir := 0
	if absf(v.x) > absf(v.y):
		dir = 3 if v.x > 0.0 else 2
	else:
		dir = 1 if v.y > 0.0 else 0
	_try_dir(dir)


func _joy_stick_vector() -> Vector2:
	var v := Controls.stick_vector_for(seat_id)
	if v.length() < Controls.MOVE_DEADZONE:
		return Vector2.ZERO
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v


func _tick_move(delta: float) -> void:
	var axis := _move_axis()
	if axis != Vector2.ZERO:
		facing = axis
		if _j_held and not command_lock and not _shelving() and not _cleaning():
			_reset_hold()
	if _can_slip():
		_begin_slip()
		return
	var want_run := _running and axis != Vector2.ZERO
	var free_stam := _dasher_active()
	if want_run and not free_stam:
		if stamina <= 0.0:
			want_run = false
			_running = false
		else:
			stamina = maxf(0.0, stamina - Tuning.RUN_STAMINA_PER_SEC * delta)
			_regen_delay = Tuning.STAMINA_REGEN_DELAY
	var walk := Tuning.WALK_SPEED * Tuning.PLAYER_MOVE_MULT * speed_mult()
	var target_speed := walk * (Tuning.RUN_SPEED_MULT if want_run else 1.0)
	var speed_cap := Tuning.WALK_SPEED * Tuning.PLAYER_MOVE_MULT * Tuning.SPEED_MAX_MULT
	target_speed = clampf(target_speed, Tuning.SPEED_FLOOR, speed_cap)
	if axis == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, walk * 8.0 * delta)
	else:
		velocity = axis * target_speed
		if velocity.length() > 8.0:
			SfxBus.play_foot(want_run)
			if inventory.count() > carry_cap():
				SfxBus.play_overcarry()
	move_and_slide()


func _dasher_active() -> bool:
	return buff_left("dasher") > 0.05


## Stick/keys for dash aim. Ignores post-skill move-lock so LT skill → dash still aims at the stick.
func _dash_dir_input() -> Vector2:
	var v := _move_vector() + stick_axis
	if v.length() < Controls.MOVE_DEADZONE:
		return Vector2.ZERO
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v


func _try_dash() -> void:
	if _dashing or _fighting or _stun_left > 0.0 or _slip_left > 0.0:
		return
	_dash_guest_done = false
	var free_stam := _dasher_active()
	if not free_stam and stamina < Tuning.DASH_STAMINA_COST:
		SfxBus.play("sfx_move_stamina_empty")
		return
	var dir := _dash_dir_input()
	if dir == Vector2.ZERO:
		dir = facing
	## Skill cast locks move until stick neutral; dash must still use held aim and then unlock walk.
	_move_locked_until_neutral = false
	_dashing = true
	_dash_dir = dir.normalized()
	facing = _dash_dir
	_dash_from = global_position
	_dash_left = Tuning.DASH_TIME
	if not free_stam:
		stamina = maxf(0.0, stamina - Tuning.DASH_STAMINA_COST)
		_regen_delay = Tuning.STAMINA_REGEN_DELAY
	SfxBus.play("sfx_move_dash")
	_reset_hold()


func _tick_dash(delta: float) -> void:
	_dash_from = global_position
	_dash_left -= delta
	var speed := Tuning.DASH_DISTANCE / Tuning.DASH_TIME
	velocity = _dash_dir * speed
	move_and_slide()
	_try_dash_thief()
	if _can_slip():
		_dashing = false
		_begin_slip()
		return
	if _dash_left <= 0.0:
		_dashing = false
		velocity *= 0.35


## True if `pos` is within dash hit range of the current dash segment (_dash_from → global_position).
func _dash_segment_hits(pos: Vector2) -> bool:
	var a := _dash_from
	var b := global_position
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.0001:
		return a.distance_squared_to(pos) <= Tuning.DASH_HIT_RANGE_SQ
	var t := clampf((pos - a).dot(ab) / len_sq, 0.0, 1.0)
	return (a + ab * t).distance_squared_to(pos) <= Tuning.DASH_HIT_RANGE_SQ


func _can_slip() -> bool:
	if _slip_left > 0.0 or _stun_left > 0.0:
		return false
	if _has_flag("ignore_puddle_slip"):
		return false
	if not _has_dirt_type(Tuning.DIRT_PUDDLE):
		return false
	return _dashing or _running


func _begin_slip() -> void:
	_dashing = false
	_running = false
	_slip_left = Tuning.SLIP_TIME
	_stun_pending = Tuning.STUN_SEC
	_reset_hold()
	## Slip dump: no aim lock — player is already sliding.
	_drop_top_box(Vector2.ZERO, false)
	_spawn_fx("skid", global_position + Vector2(0, 8))
	SfxBus.play("sfx_move_slip")
	log_line.emit(Loc.t("log.player.slip"))


func _tick_slip(delta: float) -> void:
	_slip_left -= delta
	var dist := Tuning.SLIP_BODY_LENGTHS * Tuning.BODY_LENGTH
	var dir := facing
	if dir.length_squared() < 0.01:
		dir = Vector2.RIGHT
	velocity = dir.normalized() * (dist / Tuning.SLIP_TIME)
	move_and_slide()
	if _slip_left <= 0.0:
		velocity = Vector2.ZERO
		_stun_left = _stun_pending
		SfxBus.play("sfx_move_stun")


func _drop_top_box(toss_dir: Vector2 = Vector2.ZERO, lock_until_land: bool = true) -> void:
	if inventory.is_empty():
		return
	var run: Dictionary = inventory.trailing_run()
	var n := int(run["count"])
	inventory.remove_trailing(n)
	var game := _game()
	if game and game.has_method("spawn_dropped_box"):
		var landed := Callable()
		if lock_until_land:
			_drop_flight_lock = true
			_running = false
			_dashing = false
			velocity = Vector2.ZERO
			landed = Callable(self, "_on_drop_flight_done")
		game.call(
			"spawn_dropped_box",
			global_position,
			String(run["id"]),
			n,
			toss_dir,
			drop_toss_dist(),
			landed,
		)


func _on_drop_flight_done() -> void:
	_drop_flight_lock = false
	_cancel_drop_dir = Vector2.ZERO
	_hide_drop_aim()


func _tick_status(delta: float) -> void:
	if _stun_left > 0.0:
		_stun_left = maxf(0.0, _stun_left - delta)
		velocity = Vector2.ZERO
	if _sick_left > 0.0:
		_sick_left = maxf(0.0, _sick_left - delta)
	if _has_dirt_type(Tuning.DIRT_VOMIT) and not _has_flag("ignore_vomit_sick"):
		if _sick_left <= 0.0:
			log_line.emit(Loc.t("log.player.vomit"))
		_sick_left = Tuning.SICK_SEC
	if _has_dirt_type(Tuning.DIRT_TRASH) and not _has_flag("ignore_trash_stamina"):
		stamina = maxf(0.0, stamina - Tuning.TRASH_STAMINA_PER_SEC * delta)
		_regen_delay = Tuning.STAMINA_REGEN_DELAY
	if _wave_vfx_cd > 0.0:
		_wave_vfx_cd = maxf(0.0, _wave_vfx_cd - delta)


func _regen(delta: float) -> void:
	if _dashing or _slip_left > 0.0 or (_running and _move_axis() != Vector2.ZERO) or (_has_dirt_type(Tuning.DIRT_TRASH) and not _has_flag("ignore_trash_stamina")):
		return
	if _regen_delay > 0.0:
		_regen_delay -= delta
		return
	stamina = minf(stamina_max_now(), stamina + Tuning.STAMINA_REGEN_PER_SEC * delta)


func _kind_of(node: Object) -> StringName:
	return InteractScan.kind_of(node)


## Facing and range test. Returns distance, or -1 when this node is not a valid interact target.
func _interact_dist(node: Node2D) -> float:
	return InteractScan.interact_dist(self, node, facing, _dirt_areas)


func _nearest_kind(kind: String) -> Node2D:
	return InteractScan.nearest_kind(self, interactables, kind, facing, _dirt_areas)


func _nearest_active_thief() -> Node2D:
	return InteractScan.nearest_active_thief(self, interactables, facing, _dirt_areas)


func _nearest_stocked_shelf() -> Node2D:
	return InteractScan.nearest_stocked_shelf(self, interactables, facing, _dirt_areas)


func _store_open() -> bool:
	var g := _game()
	return g != null and String(g.get("phase")) == "open"


func _faced_guests() -> Array:
	var found: Array = []
	var g := _game()
	if g == null:
		return found
	var custs = g.get("_customers")
	if custs == null:
		return found
	for c in custs.get_children():
		if c == null or not is_instance_valid(c):
			continue
		if not c.has_method("can_receive_delivery") or not bool(c.call("can_receive_delivery")):
			continue
		if _interact_dist(c) < 0.0:
			continue
		found.append(c)
	found.sort_custom(func(a, b) -> bool:
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)
	return found


## Long-press target when no thief is in range. Restock ticks from the first frame; the others wait out the tap.
## Order (after thief): dirt → guest → stockable shelf → other shelf / cashier / …
func _long_kind() -> String:
	if _usable_cannon() != null:
		return "universal_cannon"
	## 掃地僧 aura blocks manual clean (skill clears dirt instead).
	if _nearest_kind("dirt") != null and buff_left("sweeping_monk") <= 0.05:
		return "dirt"
	if _store_open() and not inventory.is_empty() and not _faced_guests().is_empty():
		return "guest"
	if not inventory.is_empty():
		var stock_shelf := _nearest_kind("shelf")
		if stock_shelf != null and _shelf_can_take_carried(stock_shelf):
			return "shelf"
	if _nearest_kind("shelf") != null:
		return "shelf"
	if _nearest_kind("cashier") != null:
		return "cashier"
	if _nearest_kind("restock") != null:
		return "restock"
	if _nearest_kind("drop") != null:
		return "drop"
	return ""


func _shelf_can_take_carried(shelf: Node2D) -> bool:
	if shelf == null or not shelf.has_method("can_accept") or inventory.is_empty():
		return false
	var run: Dictionary = inventory.trailing_run()
	return bool(shelf.call("can_accept", String(run["id"])))


func _preview_target() -> Node2D:
	var cannon := _usable_cannon()
	if cannon != null:
		return cannon
	var thief := _nearest_active_thief()
	if thief != null:
		return thief
	var stocked := _nearest_stocked_shelf()
	if stocked != null:
		return stocked
	var restock := _nearest_kind("restock")
	if restock != null:
		return restock
	var drop := _nearest_kind("drop")
	if drop != null:
		return drop
	match _long_kind():
		"dirt":
			return _nearest_kind("dirt")
		"guest":
			var guests := _faced_guests()
			return guests[0] if not guests.is_empty() else null
		"shelf":
			return _nearest_kind("shelf")
		"cashier":
			return _nearest_kind("cashier")
	return null


func _release_interact() -> void:
	if _restock_aborted:
		_restock_aborted = false
		_restock_picking = false
		_restock_hold = 0.0
		return
	if _fighting or _long_committed or _deliver_done or _restock_picking:
		if _restock_picking and target != null and _obj_str(target, "kind") == "restock":
			var sku := String(target.call("commit_pick"))
			SfxBus.play("sfx_box_sku_confirm")
			log_line.emit(Loc.t("log.player.restock_set", [Tuning.sku_name(sku)]))
		_restock_picking = false
		_restock_hold = 0.0
		return
	_do_short_interact()
	_restock_picking = false
	_restock_hold = 0.0


## Tap: thief (already grabbed), else one piece off a stocked shelf, else a restock box, else a floor box.
func _do_short_interact() -> void:
	var cannon := _usable_cannon()
	if cannon != null:
		if _interact_try(cannon):
			if not cannon.retrieve_to(self):
				log_line.emit(Loc.t("cannon.take_failed"))
			_interact_release(cannon)
		return
	if _nearest_active_thief() != null:
		return
	var shelf := _nearest_stocked_shelf()
	if shelf != null:
		_take_shelf_piece(shelf)
		return
	var restock := _nearest_kind("restock")
	if restock != null:
		target = restock
		_pickup_used = false
		_try_pickup()
		return
	var drop := _nearest_kind("drop")
	if drop != null:
		target = drop
		_pickup_used = false
		_tick_drop()
		return
	if _store_open() and not inventory.is_empty() and not _faced_guests().is_empty():
		log_line.emit(Loc.t("log.player.hold_deliver_hint"))


func _take_shelf_piece(shelf: Node2D) -> void:
	if inventory.count() >= carry_cap():
		SfxBus.play("sfx_box_pull_fail")
		log_line.emit(Loc.t("log.player.carry_need", [inventory.count(), carry_cap()]))
		return
	var sku := _obj_str(shelf, "sku")
	if sku == "" or not shelf.has_method("take_n"):
		return
	var taken := int(shelf.call("take_n", 1))
	if taken <= 0:
		return
	inventory.add_one(sku)
	_spawn_fx("suck", shelf.global_position)
	SfxBus.play("sfx_box_pull")
	log_line.emit(Loc.t("log.player.take_shelf", [Tuning.sku_name(sku)]))


func _guest_wants_carried(guest: Node) -> bool:
	if guest == null or not is_instance_valid(guest):
		return false
	for s in guest.shopping:
		if inventory.count_of(String(s)) > 0:
			return true
	return false


func _give_guest(guest: Node) -> int:
	if guest == null or not guest.has_method("accept_toss_box"):
		return 0
	var before := 0
	if guest.get("shopping") != null:
		before = int((guest.shopping as Array).size())
	var given := 0
	var seen := {}
	var wants: Array[String] = []
	for s in guest.shopping:
		var sku := String(s)
		if seen.has(sku):
			continue
		seen[sku] = true
		wants.append(sku)
	for sku in wants:
		if guest.has_method("can_receive_delivery") and not bool(guest.call("can_receive_delivery")):
			break
		var need := 0
		for s in guest.shopping:
			if String(s) == sku:
				need += 1
		var n := mini(need, inventory.count_of(sku))
		if n <= 0:
			continue
		var taken := int(guest.call("accept_toss_box", sku, n))
		if taken > 0:
			inventory.remove_sku(sku, taken)
			given += taken
	## COMBO: cleared remaining list (≥3) in this burst.
	if given > 0 and before >= 3 and guest.shopping.is_empty():
		guest.set_meta("combo_cleared_n", before)
	return given


func _begin_must_deliver_aim(sk: Dictionary) -> void:
	_must_deliver_aim = true
	_must_deliver_lv = int(sk.get("lv", 3))
	_must_deliver_sid = String(sk.get("id"))
	_must_deliver_cd = float(sk.get("cd", Skills.ACTIVE_CD))
	_must_deliver_name = String(sk.get("name"))
	_rebuild_must_deliver_ring(Skills.must_deliver_range(_must_deliver_lv))
	if _must_deliver_ring:
		_must_deliver_ring.visible = true
	SfxBus.play("sfx_skill_cast")
	log_line.emit(Loc.t("log.player.aim_preview", [_must_deliver_name]))


func _cancel_must_deliver_aim() -> void:
	if not _must_deliver_aim:
		return
	_must_deliver_aim = false
	if _must_deliver_ring:
		_must_deliver_ring.visible = false
	SfxBus.play("sfx_skill_menu_cancel")
	log_line.emit(Loc.t("log.player.cancel_named", [_must_deliver_name]))


func _rebuild_must_deliver_ring(radius: float) -> void:
	if _must_deliver_ring == null:
		return
	var pts := PackedVector2Array()
	var n := 48
	for i in n + 1:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	_must_deliver_ring.points = pts


func _finish_must_deliver_aim() -> void:
	if not _must_deliver_aim:
		return
	var lv := _must_deliver_lv
	var sid := _must_deliver_sid
	var name := _must_deliver_name
	var cd_base := _must_deliver_cd
	if not _cast_must_deliver(lv):
		_must_deliver_aim = false
		if _must_deliver_ring:
			_must_deliver_ring.visible = false
		return
	_must_deliver_aim = false
	if _must_deliver_ring:
		_must_deliver_ring.visible = false
	_cd[sid] = Tuning.cd_seconds(cd_base, _int_now())
	_buffs.erase(sid)
	_buff_cache_valid = false
	SfxBus.play("sfx_skill_cast")
	log_line.emit(Loc.t("log.player.cast", [name, lv]))
	_begin_cast_pose(false)
	skill_cast.emit(name, false)
	_play_zoom(false)


## Complete-first fill for guests in range. False = fail (no CD).
func _cast_must_deliver(lv: int) -> bool:
	if inventory.is_empty():
		log_line.emit(Loc.t("log.player.must_fail_empty"))
		return false
	if not _store_open():
		log_line.emit(Loc.t("log.player.must_fail_guest"))
		return false
	var radius := Skills.must_deliver_range(lv)
	var max_n := Skills.must_deliver_max_guests(lv)
	var guests := _must_deliver_guests(radius)
	if guests.is_empty():
		log_line.emit(Loc.t("log.player.must_fail_guest"))
		return false
	var ordered := _must_deliver_order_guests(guests, inventory.items)
	var counts := _must_deliver_count_map(inventory.items)
	var plan: Array = []
	for g in ordered:
		if plan.size() >= max_n:
			break
		var pieces := _must_deliver_match_pieces(g.shopping, counts)
		if pieces.is_empty():
			continue
		plan.append({"guest": g, "pieces": pieces})
	if plan.is_empty():
		log_line.emit(Loc.t("log.player.must_fail_match"))
		return false
	var total := 0
	var vfx: Array = []
	var touched: Array = []
	for entry in plan:
		var guest: Node = entry["guest"]
		var pieces: Array = entry["pieces"]
		if guest == null or not is_instance_valid(guest) or not guest.has_method("accept_must_deliver"):
			continue
		## D3 L — skill delivery target.
		if not _interact_try(guest):
			continue
		touched.append(guest)
		var before := int((guest.shopping as Array).size()) if guest.get("shopping") != null else 0
		for sku in pieces:
			inventory.remove_sku(String(sku), 1)
		var taken := int(guest.call("accept_must_deliver", pieces))
		if taken <= 0:
			for sku in pieces:
				inventory.add_one(String(sku))
			continue
		total += taken
		if before >= 3 and guest.shopping.is_empty():
			guest.set_meta("combo_cleared_n", before)
		var shown: Array = []
		for j in taken:
			shown.append(String(pieces[j]))
		vfx.append({"pos": guest.global_position, "skus": shown})
	for g in touched:
		_interact_release(g)
	if total <= 0:
		log_line.emit(Loc.t("log.player.must_fail_match"))
		return false
	_play_must_deliver_vfx(vfx)
	log_line.emit(Loc.t("log.player.must_n", [total]))
	_deliver_pose_left = 0.4
	_note_delivery_combo(touched, total)
	return true


func _must_deliver_guests(radius: float) -> Array:
	var found: Array = []
	var g := _game()
	if g == null:
		return found
	var custs = g.get("_customers")
	if custs == null:
		return found
	var r2 := radius * radius
	for c in custs.get_children():
		if c == null or not is_instance_valid(c):
			continue
		if c.get("temp_clerk"):
			continue
		if not c.has_method("can_receive_delivery") or not bool(c.call("can_receive_delivery")):
			continue
		if global_position.distance_squared_to(c.global_position) > r2:
			continue
		found.append(c)
	found.sort_custom(func(a, b) -> bool:
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)
	return found


func _must_deliver_count_map(items: Array) -> Dictionary:
	var counts := {}
	for s in items:
		var sku := String(s)
		counts[sku] = int(counts.get(sku, 0)) + 1
	return counts


func _must_deliver_can_complete(shopping: Array, sim: Dictionary) -> bool:
	if shopping.is_empty():
		return false
	var need := {}
	for s in shopping:
		var sku := String(s)
		need[sku] = int(need.get(sku, 0)) + 1
	for sku in need:
		if int(sim.get(sku, 0)) < int(need[sku]):
			return false
	return true


func _must_deliver_deduct_shopping(shopping: Array, sim: Dictionary) -> void:
	for s in shopping:
		var sku := String(s)
		sim[sku] = int(sim.get(sku, 0)) - 1


## Completable guests first (near→far with inventory reservation), then partials near→far.
func _must_deliver_order_guests(guests: Array, inv_items: Array) -> Array:
	var sim := _must_deliver_count_map(inv_items)
	var completable: Array = []
	var rest: Array = []
	for g in guests:
		var shopping: Array = g.shopping if g != null else []
		if _must_deliver_can_complete(shopping, sim):
			_must_deliver_deduct_shopping(shopping, sim)
			completable.append(g)
		else:
			rest.append(g)
	return completable + rest


## Match shopping needs against counts (mutates counts). Any inventory order.
func _must_deliver_match_pieces(shopping: Array, counts: Dictionary) -> Array[String]:
	var pieces: Array[String] = []
	for s in shopping:
		var sku := String(s)
		if int(counts.get(sku, 0)) <= 0:
			continue
		pieces.append(sku)
		counts[sku] = int(counts.get(sku, 0)) - 1
	return pieces


func _play_must_deliver_vfx(deliveries: Array) -> void:
	if deliveries.is_empty():
		return
	var parent: Node = get_parent()
	var g := _game()
	if g != null:
		var world = g.get("_world")
		if world != null:
			parent = world
	var gather := global_position + Vector2(0.0, -72.0)
	var i := 0
	for d in deliveries:
		var dest_base: Vector2 = d.get("pos", global_position)
		var skus: Array = d.get("skus", [])
		for sku_v in skus:
			var sku := String(sku_v)
			var spr: Sprite2D = SkuIcons.make_sprite(sku, 20.0)
			spr.z_index = 12
			parent.add_child(spr)
			spr.global_position = global_position + Vector2(randf_range(-10.0, 10.0), -18.0)
			var gather_pt := gather + Vector2(randf_range(-22.0, 22.0), randf_range(-12.0, 12.0))
			var land := dest_base + Vector2(randf_range(-8.0, 8.0), -44.0)
			var tw := spr.create_tween()
			tw.tween_interval(0.02 * float(i))
			tw.tween_property(spr, "global_position", gather_pt, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_interval(0.1)
			tw.tween_property(spr, "global_position", land, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(spr.queue_free)
			i += 1


## Instant door summon. False = 0 guests (no CD).
func _cast_summon_guest(lv: int) -> bool:
	var want := Skills.summon_guest_count(lv)
	var game := _game()
	if game == null or not game.has_method("cast_summon_guest"):
		log_line.emit(Loc.t("log.player.summon_fail"))
		return false
	var n := int(game.call("cast_summon_guest", want))
	if n <= 0:
		log_line.emit(Loc.t("log.player.summon_fail_phase"))
		return false
	log_line.emit(Loc.t("log.player.summon_n", [n]))
	return true


func _begin_magneto_aim(sk: Dictionary) -> void:
	if inventory.count() >= carry_cap():
		log_line.emit(Loc.t("log.player.magneto_full"))
		return
	if _must_deliver_aim:
		_cancel_must_deliver_aim()
	_magneto_aim = true
	_magneto_lv = int(sk.get("lv", 3))
	_magneto_sid = String(sk.get("id"))
	_magneto_cd = float(sk.get("cd", Skills.ACTIVE_CD))
	_magneto_name = String(sk.get("name"))
	_rebuild_magneto_ring(Skills.magneto_range(_magneto_lv))
	if _magneto_ring:
		_magneto_ring.visible = true
	SfxBus.play("sfx_skill_cast")
	log_line.emit(Loc.t("log.player.aim_preview", [_magneto_name]))


func _cancel_magneto_aim() -> void:
	if not _magneto_aim:
		return
	_magneto_aim = false
	if _magneto_ring:
		_magneto_ring.visible = false
	SfxBus.play("sfx_skill_menu_cancel")
	log_line.emit(Loc.t("log.player.cancel_named", [_magneto_name]))


func _rebuild_magneto_ring(radius: float) -> void:
	if _magneto_ring == null:
		return
	var pts := PackedVector2Array()
	var n := 48
	for i in n + 1:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	_magneto_ring.points = pts


func _finish_magneto_aim() -> void:
	if not _magneto_aim:
		return
	var lv := _magneto_lv
	var sid := _magneto_sid
	var name := _magneto_name
	var cd_base := _magneto_cd
	## Full carry: abort without CD (preview shouldn't have started, but re-check).
	if inventory.count() >= carry_cap():
		_magneto_aim = false
		if _magneto_ring:
			_magneto_ring.visible = false
		log_line.emit(Loc.t("log.player.magneto_full"))
		return
	_cast_magneto(lv)
	_magneto_aim = false
	if _magneto_ring:
		_magneto_ring.visible = false
	## Empty absorb still starts CD.
	_cd[sid] = Tuning.cd_seconds(cd_base, _int_now())
	_buffs.erase(sid)
	_buff_cache_valid = false
	SfxBus.play("sfx_skill_cast")
	log_line.emit(Loc.t("log.player.cast", [name, lv]))
	_begin_cast_pose(false)
	skill_cast.emit(name, false)
	_play_zoom(false)


## Absorb landed drops in radius until carry_cap. Always "succeeds" for CD (0 pieces ok).
func _cast_magneto(lv: int) -> void:
	var range_px := Skills.magneto_range(lv)
	var range_sq := range_px * range_px
	var piles: Array = []
	for node in interactables:
		if node == null or not is_instance_valid(node):
			continue
		if _obj_str(node, "kind") != "drop":
			continue
		if _obj_int(node, "count") <= 0:
			continue
		if global_position.distance_squared_to(node.global_position) > range_sq:
			continue
		piles.append(node)
	piles.sort_custom(func(a, b) -> bool:
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)
	var flights: Array = []
	var locked_piles: Array = []
	for pile in piles:
		if not is_instance_valid(pile):
			continue
		var room := carry_cap() - inventory.count()
		if room <= 0:
			break
		if not pile.has_method("take_count"):
			continue
		## D4 L — magneto floor pile.
		if not _interact_try(pile):
			continue
		locked_piles.append(pile)
		var sku := _obj_str(pile, "sku")
		var at: Vector2 = pile.global_position
		var got := int(pile.call("take_count", room))
		if got <= 0:
			continue
		for _i in got:
			inventory.add_one(sku)
			flights.append({"sku": sku, "from": at})
		_spawn_fx("suck", at)
	for pile in locked_piles:
		_interact_release(pile)
	_spawn_fx("suck", global_position)
	_play_magneto_vfx(flights)
	var taken_total := flights.size()
	var game := _game()
	if game != null and game.has_method("play_skill_banner"):
		game.call("play_skill_banner", Loc.t("log.player.magneto_n", [taken_total]))
	log_line.emit(Loc.t("log.player.magneto_n", [taken_total]))


## One-by-one fly from pile toward player (visual only; inventory already updated).
func _play_magneto_vfx(flights: Array) -> void:
	if flights.is_empty():
		return
	var parent: Node = get_parent()
	var g := _game()
	if g != null:
		var world = g.get("_world")
		if world != null:
			parent = world
	var i := 0
	for f in flights:
		var sku := String(f.get("sku", ""))
		var from: Vector2 = f["from"] as Vector2 if f.has("from") else global_position
		var spr: Sprite2D = SkuIcons.make_sprite(sku, 18.0)
		spr.z_index = 12
		parent.add_child(spr)
		spr.global_position = from + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
		## Capture landing target each tween start so it tracks a walking player.
		var delay := 0.035 * float(i)
		var dur := 0.22
		var tw := spr.create_tween()
		tw.tween_interval(delay)
		tw.tween_callback(func() -> void:
			if not is_instance_valid(spr):
				return
			var land := global_position + Vector2(randf_range(-10.0, 10.0), -20.0)
			var fly := spr.create_tween()
			fly.tween_property(spr, "global_position", land, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			fly.tween_property(spr, "scale", Vector2(0.35, 0.35), dur * 0.85)
			fly.tween_callback(spr.queue_free)
		)
		i += 1
		## Soft cap so huge pulls stay readable.
		if i >= 48:
			break


## Instant harvest_chives on aimed cashier queue. False = fail (no CD).
func _cast_self_checkout(level: int) -> bool:
	var host := _game()
	var count := 0
	if host != null:
		for reg in host.get("cashiers"):
			if is_instance_valid(reg) and global_position.distance_squared_to(reg.global_position) <= pow(5.0 * Tuning.BODY_LENGTH, 2):
				reg.activate_self_checkout(host, level, seat_id)
				count += 1
	if count == 0:
		log_line.emit(Loc.t("self_checkout.no_register"))
	else:
		var ring_script = preload("res://scripts/self_checkout_ring.gd")
		ring_script.spawn(host, global_position)
	return count > 0


func _cast_harvest_chives(lv: int) -> bool:
	var reg: Node2D = null
	if is_instance_valid(target) and _obj_str(target, "kind") == "cashier":
		reg = target
	else:
		reg = _nearest_kind("cashier")
	if reg == null or _interact_dist(reg) < 0.0:
		log_line.emit(Loc.t("log.player.chives_aim"))
		return false
	## D4 L — harvest register.
	if not _interact_try(reg):
		log_line.emit(Loc.t("log.player.chives_busy"))
		return false
	var want := Skills.harvest_chives_count(lv)
	var game := _game()
	if game == null or not game.has_method("cast_harvest_chives"):
		_interact_release(reg)
		log_line.emit(Loc.t("log.player.chives_fail"))
		return false
	var n := int(game.call("cast_harvest_chives", reg, want))
	_interact_release(reg)
	if n <= 0:
		log_line.emit(Loc.t("log.player.chives_empty"))
		return false
	return true


## Instant force_sell into nearest hand-deliverable guest cart. False = fail (no CD).
func _cast_force_sell(lv: int) -> bool:
	if inventory.is_empty():
		log_line.emit(Loc.t("log.player.force_empty"))
		return false
	var guest: Node = null
	for g in _faced_guests():
		if g == null or not is_instance_valid(g):
			continue
		if g.get("temp_clerk"):
			continue
		guest = g
		break
	if guest == null or not guest.has_method("accept_force_sell"):
		log_line.emit(Loc.t("log.player.force_no_guest"))
		return false
	## D3 L — force_sell guest.
	if not _interact_try(guest):
		log_line.emit(Loc.t("log.player.force_busy"))
		return false
	var before := int((guest.shopping as Array).size()) if guest.get("shopping") != null else 0
	var n := mini(Skills.force_sell_count(lv), inventory.count())
	var pieces: Array[String] = inventory.pop_trailing(n)
	if pieces.is_empty():
		_interact_release(guest)
		log_line.emit(Loc.t("log.player.force_empty"))
		return false
	var taken := int(guest.call("accept_force_sell", pieces))
	if taken <= 0:
		for sku in pieces:
			inventory.add_one(String(sku))
		_interact_release(guest)
		log_line.emit(Loc.t("log.player.force_no_guest"))
		return false
	if before >= 3 and guest.shopping.is_empty():
		guest.set_meta("combo_cleared_n", before)
	_interact_release(guest)
	log_line.emit(Loc.t("log.player.force_n", [taken]))
	_deliver_pose_left = 0.4
	_note_delivery_combo([guest], taken)
	return true


## Nearest guest first. `penalize_miss` adds +15 on the nearest guest when nothing matched.
func _hand_deliver(guests: Array, penalize_miss: bool) -> int:
	var total := 0
	var nearest: Node = null
	var locked: Array = []
	for guest in guests:
		if guest == null or not is_instance_valid(guest):
			continue
		if not guest.has_method("can_receive_delivery") or not bool(guest.call("can_receive_delivery")):
			continue
		## A7 L — hand delivery target.
		if not _interact_try(guest):
			continue
		locked.append(guest)
		if nearest == null:
			nearest = guest
		total += _give_guest(guest)
	if total > 0:
		SfxBus.play("sfx_box_hit_guest_ok")
		log_line.emit(Loc.t("log.player.deliver_n", [total]))
		_deliver_pose_left = 0.4
		_note_delivery_combo(guests, total)
		for g in locked:
			_interact_release(g)
		return total
	if penalize_miss and nearest != null and nearest.has_method("apply_toss_reject"):
		nearest.call("apply_toss_reject", "")
		SfxBus.play("sfx_box_hit_guest_reject")
		if nearest.get("temp_clerk"):
			log_line.emit(Loc.t("log.player.wrong_temp"))
		else:
			log_line.emit(Loc.t("log.player.wrong_dissat"))
	var game := _game()
	if game != null and game.has_method("combo_break_personal"):
		game.call("combo_break_personal", seat_id)
	for g in locked:
		_interact_release(g)
	return 0


func _dash_guests() -> Array:
	var found: Array = []
	var g := _game()
	if g == null:
		return found
	var custs = g.get("_customers")
	if custs == null:
		return found
	for c in custs.get_children():
		if c == null or not is_instance_valid(c):
			continue
		## Non-customer children: Object.get null → bool()/int()/float() constructors explode.
		if not c.has_method("occupies_store"):
			continue
		if c.is_thief:
			continue
		var st: int = c.state
		if st == CustomerScript.State.LEAVE or st == CustomerScript.State.FLEE:
			continue
		if _obj_float(c, "_dash_stun_left") > 0.0:
			continue
		if not _dash_segment_hits(c.global_position):
			continue
		found.append(c)
	found.sort_custom(func(a, b) -> bool:
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)
	return found


func _dash_clone() -> Node:
	var g := _game()
	if g == null or not g.has_method("shadow_clones"):
		return null
	var best: Node = null
	var best_d_sq := Tuning.DASH_HIT_RANGE_SQ
	for c in g.call("shadow_clones"):
		if c == null or not is_instance_valid(c):
			continue
		if c.get("_vanishing"):
			continue
		if _obj_float(c, "_dash_stun_left") > 0.0:
			continue
		if not _dash_segment_hits(c.global_position):
			continue
		var d_sq := global_position.distance_squared_to(c.global_position)
		if d_sq <= best_d_sq:
			best_d_sq = d_sq
			best = c
	return best


## Warm halo on the one object the interact button would actually use.
func _sync_interact_glow() -> void:
	var host := _glow_host_now()
	if host != null and host == _glow_host and is_instance_valid(_interact_glow) and _interact_glow.get_parent() == host:
		return
	_detach_interact_glow()
	if host == null:
		return
	if _interact_glow == null or not is_instance_valid(_interact_glow):
		_interact_glow = GlowScript.new()
		_interact_glow.name = "InteractGlow"
	_interact_glow.call("set_span", _glow_span(host))
	host.add_child(_interact_glow)
	_glow_host = host


func _detach_interact_glow() -> void:
	_glow_host = null
	if _interact_glow == null or not is_instance_valid(_interact_glow):
		_interact_glow = null
		return
	var parent := _interact_glow.get_parent()
	if parent != null:
		parent.remove_child(_interact_glow)


func _glow_host_now() -> Node2D:
	if not _round_active() or _asking_early():
		return null
	if skill_menu_open or ult_prep or _stun_left > 0.0 or _slip_left > 0.0 or _elite_focus_left > 0.0:
		return null
	if _cancel_drop_ready:
		return null
	if not is_instance_valid(target):
		return null
	if not _interact_available(target):
		return null
	return target


## True when pressing interact would start a real action on this node.
func _interact_available(node: Node2D) -> bool:
	var kind := _obj_str(node, "kind")
	if kind == "universal_cannon":
		return node.available_for(self)
	if kind == "thief":
		## Carry allowed; goods stay in hand during the fight.
		return node.has_method("is_active_thief") and bool(node.call("is_active_thief"))
	if kind == "shelf":
		return _shelf_interactable(node)
	if kind == "restock":
		return _restock_interactable(node)
	if kind == "drop":
		var n := _obj_int(node, "count")
		return n > 0 and inventory.count() + n <= carry_cap()
	if kind == "dirt":
		## Carry allowed; goods stay in hand while cleaning.
		return true
	if kind == "cashier":
		return node.has_method("ready_customer") and node.call("ready_customer") != null
	if kind == "elite" or kind == "":
		if not _store_open() or inventory.is_empty():
			return false
		if not node.has_method("can_receive_delivery"):
			return false
		return bool(node.call("can_receive_delivery"))
	return false


func _shelf_interactable(node: Node2D) -> bool:
	if _obj_int(node, "count") > 0 and inventory.count() < carry_cap():
		return true
	if inventory.is_empty() or not node.has_method("can_accept"):
		return false
	var run: Dictionary = inventory.trailing_run()
	return bool(node.call("can_accept", String(run["id"])))


func _restock_interactable(node: Node2D) -> bool:
	if not node.has_method("skus"):
		return false
	var raw = node.call("skus")
	if not (raw is Array):
		return false
	return not (raw as Array).is_empty()


## Same halo shape as the first fit, pulled in a little so it sits closer to the body.
const GLOW_SPAN_SCALE := 0.85


func _glow_span(node: Node2D) -> Vector2:
	var kind := _obj_str(node, "kind")
	var span := Vector2(150.0, 150.0)
	if kind == "shelf" or kind == "cashier" or kind == "restock":
		span = Vector2(240.0, 150.0)
		for child in node.get_children():
			if child is CollisionShape2D and child.shape is RectangleShape2D:
				var sz: Vector2 = (child.shape as RectangleShape2D).size
				span = Vector2(maxf(sz.x, 64.0) * 1.85, maxf(sz.y, 48.0) * 2.15)
				break
	elif kind == "dirt":
		span = Vector2(168.0, 140.0)
	elif kind == "drop":
		span = Vector2(120.0, 120.0)
	return span * GLOW_SPAN_SCALE


func _update_target() -> void:
	if _fighting:
		return
	## Aim / flight / slip / held interact: keep the action target (no full rescan).
	if _j_held or _cancel_drop_ready or _drop_flight_lock or _slip_left > 0.0:
		return
	var best := _preview_target()
	if target != best:
		if _restock_picking and target != null and _obj_str(target, "kind") == "restock":
			target.call("abort_pick")
		_restock_picking = false
		_restock_hold = 0.0
		_reset_hold()
		_pickup_used = false
		_hud_dirty = true
	target = best


func _tick_action(delta: float) -> void:
	blocked_mismatch = false
	if _fighting:
		_tick_fight(delta)
		return
	if _stun_left > 0.0 or _slip_left > 0.0:
		if is_instance_valid(target) and _obj_str(target, "kind") == "dirt":
			target.call("set_cleaning", false, Vector2.ZERO, 0.0, seat_id)
		return
	if not _j_held:
		hold_progress = 0.0
		_clear_clean_hint()
		return
	_j_time += delta
	var cannon := _usable_cannon()
	if is_instance_valid(_lock_node) and _obj_str(_lock_node, "kind") == "universal_cannon" and _lock_node != cannon:
		_interact_release_held()
		hold_progress = 0.0
		_pickup_used = false
	if cannon != null:
		target = cannon
		if not _interact_try(cannon):
			hold_progress = 0.0
			return
		if _j_time >= Tuning.SKU_PICK_HOLD:
			_long_committed = true
			_tick_cannon(delta)
		return
	var thief := _nearest_active_thief()
	if thief != null:
		target = thief
		_begin_fight()
		return
	var long_kind := _long_kind()
	if long_kind == "restock":
		target = _nearest_kind("restock")
		_tick_sku_pick(delta)
		return
	if _j_time < Tuning.SKU_PICK_HOLD:
		return
	match long_kind:
		"dirt":
			_long_committed = true
			target = _nearest_kind("dirt")
			_tick_clean(delta)
		"guest":
			_long_committed = true
			var guests := _faced_guests()
			if not guests.is_empty():
				target = guests[0]
			if not _deliver_done:
				_deliver_done = true
				_hand_deliver(guests, true)
		"shelf":
			_long_committed = true
			target = _nearest_kind("shelf")
			_tick_restock(delta)
		"cashier":
			_long_committed = true
			target = _nearest_kind("cashier")
			_tick_cashier(delta)


func _begin_fight() -> void:
	## Carry allowed; goods stay in hand for the mash window.
	## Restock/shelf targets have no is_thief — bool(Object.get null) crashes Godot 4.
	if not is_instance_valid(target) or not target.get("is_thief"):
		return
	if not target.has_method("is_active_thief") or not bool(target.call("is_active_thief")):
		return
	## A6 L — another seat already fighting this thief.
	if not _interact_try(target):
		log_line.emit(Loc.t("log.player.thief_claimed"))
		return
	_fighting = true
	_fight_ko = false
	_fight_release = true
	target.call("begin_fight")
	SfxBus.play("sfx_fight_grab")
	log_line.emit(Loc.t("log.player.thief_grab"))
	## LAN: only the catcher's machine zooms／locks the shared cam.
	if controls_locally() and _shared_camera() != null:
		_focus_camera_toward(target.global_position, 0.35)
		var tw := create_tween()
		tw.tween_property(
			camera, "zoom",
			Vector2(Tuning.FIGHT_ZOOM, Tuning.FIGHT_ZOOM),
			0.16,
		)


func _tick_fight(delta: float) -> void:
	if _fight_ko:
		_tick_camera_shake(delta)
		## Net puppet KO visuals may finish while Host still owns the thief —
		## stay locked until the presentation agent is gone (despawn) or cleared.
		if _net_ko_pending:
			if not is_instance_valid(target):
				_net_ko_pending = false
				_end_fight(true)
			return
		return
	if not is_instance_valid(target) or not bool(target.call("in_fight")):
		_end_fight(false)
		return
	target.fight_left = maxf(0.0, float(target.fight_left) - delta)
	hold_progress = clampf(float(target.fight_hp) / 100.0, 0.0, 1.0)
	target.call("_refresh_labels")
	_tick_camera_shake(delta)
	## Client vs puppet: do not locally fail the mash — Host timer / outcome is authority.
	if _agent_is_net_puppet(target):
		return
	if float(target.fight_left) <= 0.0:
		_fight_fail()


func _fight_tap() -> void:
	if not is_instance_valid(target) or _fight_ko:
		return
	var dmg := Tuning.hit_damage(_str_now())
	if controls_locally():
		_shake_camera(Tuning.FIGHT_HIT_SHAKE, Tuning.FIGHT_HIT_SHAKE_SEC)
	SfxBus.play("sfx_fight_hit")
	## Puppet HP bar is feel-only; Host applies real damage from interact intents.
	if bool(target.call("take_hit", dmg)):
		if _agent_is_net_puppet(target):
			## Keep fighting locked; Host KO → despawn ends the mash via _net_ko_pending.
			_fight_win_net_pending()
			return
		_fight_win()


func _fight_win_net_pending() -> void:
	## Local mash bar emptied on a presentation thief — wait for Host despawn.
	if _fight_ko:
		return
	_fight_ko = true
	_net_ko_pending = true
	log_line.emit(Loc.t("log.player.thief_ko"))
	_play_ko_sequence(target, "", Vector2.ZERO, false)


func _fight_win() -> void:
	if _fight_ko:
		return
	_fight_ko = true
	var game := _game()
	if game and game.has_method("record_caught"):
		game.call("record_caught", seat_id)
	log_line.emit(Loc.t("log.player.thief_ko"))
	_play_ko_sequence(target, "ko_scatter_and_flee")


## Directional tossed box hit an active thief → Screen KO (counts as catch).
func apply_toss_ko(thief: Node, knock_dir: Vector2) -> void:
	if thief == null or not is_instance_valid(thief):
		return
	if not thief.has_method("is_active_thief") or not bool(thief.call("is_active_thief")):
		return
	if not thief.has_method("ko_box_hit_and_flee"):
		return
	## Client presentation thief: Host resolves box KO + loot; local seat only plays VFX.
	if _agent_is_net_puppet(thief):
		var end_fight_net := _fighting and target == thief
		if end_fight_net:
			_fight_ko = true
			_net_ko_pending = true
		log_line.emit(Loc.t("log.player.thief_box_ko"))
		SfxBus.play("sfx_box_hit_thief")
		_play_ko_sequence(thief, "", knock_dir.normalized() if knock_dir.length_squared() > 0.01 else Vector2.ZERO, false)
		return
	var game := _game()
	if game and game.has_method("record_caught"):
		game.call("record_caught", seat_id)
	log_line.emit(Loc.t("log.player.thief_box_ko"))
	SfxBus.play("sfx_box_hit_thief")
	## If this toss finishes an ongoing grab fight, clear fight state after the KO.
	var end_fight := _fighting and target == thief
	if end_fight:
		_fight_ko = true
	var dir := knock_dir
	if dir.length_squared() < 0.01:
		dir = (thief as Node2D).global_position - global_position
	if dir.length_squared() < 0.01:
		dir = facing
	_play_ko_sequence(thief, "ko_box_hit_and_flee", dir.normalized(), end_fight)


func _play_ko_sequence(
	thief: Node,
	flee_method: String = "ko_scatter_and_flee",
	knock_override: Vector2 = Vector2.ZERO,
	end_fight: bool = true,
) -> void:
	var local_cam := controls_locally()
	if local_cam:
		_shake_camera(Tuning.FIGHT_KO_SHAKE, 0.22)
	SfxBus.play("sfx_ko_screen")
	if local_cam and _shared_camera() != null:
		if is_instance_valid(thief):
			_focus_camera_toward((thief as Node2D).global_position, 0.35)
		var punch := create_tween()
		punch.tween_property(
			camera, "zoom",
			Vector2(Tuning.FIGHT_KO_ZOOM, Tuning.FIGHT_KO_ZOOM),
			0.07,
		)
	var game := _game()
	if game and game.has_method("play_ko_banner"):
		game.call("play_ko_banner")
	await get_tree().create_timer(0.18).timeout
	## Empty flee_method = presentation-only (net puppet); Host scatters / despawns.
	if flee_method != "" and is_instance_valid(thief) and thief.has_method(flee_method):
		var knock: Vector2 = knock_override
		if knock.length_squared() < 0.01:
			knock = (thief as Node2D).global_position - global_position
		if knock.length_squared() < 0.01:
			knock = facing
		thief.call(flee_method, knock.normalized())
	await get_tree().create_timer(Tuning.FIGHT_KO_FLASH_SEC * 0.55).timeout
	if end_fight:
		_end_fight(true)
	elif local_cam and camera and not _net_ko_pending:
		## Toss KO outside a fight: restore shop framing after the punch-in.
		restore_base_camera()


func _fight_fail() -> void:
	if _fight_ko:
		return
	if is_instance_valid(target):
		var away := global_position - target.global_position
		if away.length_squared() < 0.01:
			away = -facing
		facing = away.normalized()
		## Never drive puppet escape — Host owns leave / stolen stats.
		if not _agent_is_net_puppet(target) and target.has_method("escape_with_loot"):
			target.call("escape_with_loot")
	_apply_fight_fail_player()


## Client: Host broadcast fight_clear(caught=false) — mirror slip/stun without mutating puppet.
func apply_net_fight_fail() -> void:
	if not _fighting and not _net_ko_pending and not _fight_ko:
		return
	if is_instance_valid(target):
		var away := global_position - target.global_position
		if away.length_squared() < 0.01:
			away = -facing
		facing = away.normalized()
	_apply_fight_fail_player()


## Client presentation: Host absolute checkout arrows／hold (M2.9). Works on puppets.
func apply_net_checkout_prompt(on: bool, seq: Array, idx: int, fail: int, done: bool, hold: float) -> void:
	## Do not clobber ultimate direction chrome.
	if ult_prep:
		return
	var bits: PackedStringArray = []
	for v in seq:
		bits.append(str(int(v)))
	var fp := "%d|%d|%d|%d|%d|%s" % [
		1 if on else 0,
		idx,
		fail,
		1 if done else 0,
		int(round(clampf(hold, 0.0, 1.0) * 100.0)),
		"|".join(bits),
	]
	if fp == _net_prompt_fp:
		return
	_net_prompt_fp = fp
	seq_index = idx
	seq_done = done
	hold_progress = clampf(hold, 0.0, 1.0)
	if _prompt:
		_prompt.sequence.clear()
		for v in seq:
			_prompt.sequence.append(int(v))
		_prompt.index = idx
		_prompt.fail_at = fail
		_prompt.active = on
	if _circle != null and not _cleaning():
		_circle.progress = hold_progress
		_circle.blocked = false


func prompt_net_row() -> Dictionary:
	var dirs: Array = []
	if _prompt != null:
		for d in _prompt.sequence:
			dirs.append(int(d))
	var on := false
	var fail := -1
	if _prompt != null and not ult_prep:
		on = bool(_prompt.active)
		fail = int(_prompt.fail_at)
	return {
		"seat": seat_id,
		"on": on,
		"seq": dirs,
		"idx": seq_index,
		"fail": fail,
		"done": seq_done,
		"hold": hold_progress,
	}


func _prompt_state_fp() -> String:
	var bits: PackedStringArray = []
	if _prompt != null:
		for d in _prompt.sequence:
			bits.append(str(int(d)))
	var on := _prompt != null and not ult_prep and bool(_prompt.active)
	var fail := int(_prompt.fail_at) if _prompt != null else -1
	return "%d|%d|%d|%d|%d|%s" % [
		1 if on else 0,
		seq_index,
		fail,
		1 if seq_done else 0,
		int(round(hold_progress * 100.0)),
		"|".join(bits),
	]


func _request_prompt_broadcast(force: bool = false) -> void:
	## Host absolute checkout chrome for clients (M2.9).
	if SessionService.is_lan() and SessionService.is_client():
		return
	if not SessionService.is_lan() or not SessionService.is_server():
		return
	var fp := _prompt_state_fp()
	if not force and fp == _net_prompt_fp:
		return
	_net_prompt_fp = fp
	var game := _game()
	if game != null and game.has_method("_broadcast_seat_prompt"):
		game.call("_broadcast_seat_prompt", seat_id)


func _apply_fight_fail_player() -> void:
	log_line.emit(Loc.t("log.player.thief_fail"))
	SfxBus.play("sfx_fight_fail")
	SfxBus.play("sfx_move_stun")
	_end_fight(false)
	_dashing = false
	_running = false
	_slip_left = Tuning.SLIP_TIME
	_stun_pending = Tuning.FIGHT_DOWN_SEC
	var g := _game()
	if g != null and g.has_method("note_fight_fail"):
		g.call("note_fight_fail", self)


func _end_fight(_won: bool) -> void:
	if is_instance_valid(target):
		_interact_release(target)
	_fighting = false
	_fight_release = false
	_fight_ko = false
	_net_ko_pending = false
	_shake_left = 0.0
	hold_progress = 0.0
	## Mash updates `_j_held` above; if still down through KO, latch until up
	## so `_tick_action` cannot long-commit nearby dirt/shelf/cashier.
	var still_held := _j_held
	_j_held = false
	_j_time = 0.0
	_long_committed = false
	_deliver_done = false
	_interact_ignore_until_up = still_held
	_clear_clean_hint()
	if controls_locally():
		restore_base_camera()
	var game := _game()
	if game != null and game.has_method("notify_camera_priority_idle"):
		game.call("notify_camera_priority_idle")


func camera_priority_busy() -> bool:
	## Fight / KO framing beats EliteCustomer intro zoom.
	## Remote seats must not lock another peer's shared camera (LAN).
	if not controls_locally():
		return false
	return _fighting or _fight_ko


func base_camera_zoom() -> float:
	match PlatformServices.get_camera_view():
		PlatformServices.CAMERA_VIEW_FAR:
			return Tuning.CAMERA_ZOOM_FAR
		PlatformServices.CAMERA_VIEW_OVERVIEW:
			var game := _game()
			if game != null and game.has_method("overview_camera_zoom"):
				return float(game.call("overview_camera_zoom"))
			return Tuning.CAMERA_ZOOM_FAR
		_:
			return Tuning.CAMERA_ZOOM


## Restore zoom / follow from PlatformServices camera_view (after fight, skill, elite).
func restore_base_camera() -> void:
	if camera == null:
		return
	if not controls_locally():
		return
	var z := base_camera_zoom()
	camera.offset = Vector2.ZERO
	var game := _game()
	if PlatformServices.get_camera_view() == PlatformServices.CAMERA_VIEW_OVERVIEW:
		camera.top_level = true
		if game != null and game.has_method("shop_camera_center"):
			camera.global_position = game.call("shop_camera_center") as Vector2
		camera.zoom = Vector2(z, z)
	elif game != null and game.has_method("is_local_coop") and bool(game.call("is_local_coop")):
		## Coop follow: world-space midpoint (demo keeps it each frame).
		camera.top_level = true
		if game.has_method("coop_camera_midpoint"):
			camera.global_position = game.call("coop_camera_midpoint") as Vector2
		camera.zoom = Vector2(z, z)
	else:
		camera.top_level = false
		camera.position = Vector2.ZERO
		camera.zoom = Vector2(z, z)


## Leave overview lock so temporary fight / elite framing can offset from the player.
func _prepare_camera_for_local_focus() -> void:
	if camera == null:
		return
	if camera.top_level:
		camera.top_level = false
		camera.position = Vector2.ZERO


## Frame toward a world point. Shared cam (parent ≠ this seat) must use top_level
## global_position — local offset would be relative to seat0 and land in the wrong place.
func _focus_camera_toward(focus_global: Vector2, blend: float) -> void:
	## Non-local seats must not steal another peer's camera (LAN thief／elite framing).
	if not controls_locally():
		return
	var cam := _shared_camera()
	if cam == null:
		return
	camera = cam
	var want := global_position.lerp(focus_global, blend)
	if cam.get_parent() != self:
		cam.top_level = true
		cam.global_position = want
	else:
		_prepare_camera_for_local_focus()
		cam.position = (focus_global - global_position) * blend


func play_elite_focus(target_node: Node, sec: float = Tuning.ELITE_ZOOM_SEC) -> void:
	if target_node == null or not is_instance_valid(target_node):
		await get_tree().create_timer(sec).timeout
		return
	if _shared_camera() == null:
		await get_tree().create_timer(sec).timeout
		return
	_elite_focus_left = maxf(_elite_focus_left, sec)
	_focus_camera_toward((target_node as Node2D).global_position, 0.55)
	var base_z := base_camera_zoom()
	var punch_z := base_z * 1.35
	var tw := create_tween()
	tw.tween_property(camera, "zoom", Vector2(punch_z, punch_z), 0.18)
	await get_tree().create_timer(sec).timeout
	if camera:
		restore_base_camera()
	_elite_focus_left = 0.0


func _shake_camera(mag: float, dur: float) -> void:
	if not controls_locally():
		return
	_shake_mag = mag
	_shake_left = maxf(_shake_left, dur)


func _tick_camera_shake(delta: float) -> void:
	if not controls_locally() or camera == null:
		return
	if _shake_left <= 0.0:
		camera.offset = Vector2.ZERO
		return
	_shake_left = maxf(0.0, _shake_left - delta)
	var falloff := clampf(_shake_left / maxf(Tuning.FIGHT_HIT_SHAKE_SEC, 0.01), 0.0, 1.0)
	var m := _shake_mag * (0.35 + 0.65 * falloff)
	camera.offset = Vector2(randf_range(-m, m), randf_range(-m, m))


func _try_dash_thief() -> void:
	_try_dash_hits()


func _try_dash_hits() -> void:
	var g := _game()
	if g == null:
		return
	_try_wave_dirt_vfx()
	## Thieves first (caught).
	if g.has_method("thieves"):
		for t in g.call("thieves"):
			if t == null or not is_instance_valid(t):
				continue
			if not bool(t.call("is_active_thief")):
				continue
			if not _dash_segment_hits(t.global_position):
				continue
			## Presentation thief: Host resolves dash KO from intents; local VFX only.
			if _agent_is_net_puppet(t):
				SfxBus.play("sfx_thief_dash_out")
				log_line.emit(Loc.t("log.player.thief_dash"))
				if _fighting and target == t:
					_fight_ko = true
					_net_ko_pending = true
					_play_ko_sequence(t, "", _dash_dir, false)
				return
			t.call("dash_knock_away", _dash_dir)
			if g.has_method("record_caught"):
				g.call("record_caught", seat_id)
			SfxBus.play("sfx_thief_dash_out")
			log_line.emit(Loc.t("log.player.thief_dash"))
			if _fighting:
				_end_fight(false)
			return
	## One guest resolution per dash. 衝刺交付: prefer guests who want carried goods (near→far), not only nearest.
	## Clones are after guests so 衝刺交付 never hands goods to a clone.
	if not _dash_guest_done:
		var guests := _dash_guests()
		if not guests.is_empty():
			if buff_left("dash_deliver") > 0.0:
				var deliver_targets: Array = []
				for guest in guests:
					if guest == null or not is_instance_valid(guest):
						continue
					if not guest.has_method("can_receive_delivery") or not bool(guest.call("can_receive_delivery")):
						continue
					if not _guest_wants_carried(guest):
						continue
					deliver_targets.append(guest)
				if not deliver_targets.is_empty():
					var gave := _hand_deliver(deliver_targets, false)
					if gave > 0:
						_dash_guest_done = true
						log_line.emit(Loc.t("log.player.dash_deliver", [gave]))
						return
			var nearest: Node = guests[0]
			_dash_guest_done = true
			var add := 0.0 if _has_flag("polite_dash") else Tuning.DASH_GUEST_DISSAT
			if g.has_method("play_ko_banner"):
				g.call("play_ko_banner")
			if nearest.has_method("dash_knock_guest"):
				nearest.call("dash_knock_guest", add)
			if add > 0.0 and g.has_method("note_dash_guest"):
				g.call("note_dash_guest", self)
			SfxBus.play("sfx_ko_guest_dash")
			log_line.emit(Loc.t("log.player.dash_guest") if add > 0.0 else Loc.t("log.player.dash_polite"))
			return
	if _dash_guest_done:
		return
	var clone := _dash_clone()
	if clone == null:
		return
	_dash_guest_done = true
	if g.has_method("play_ko_banner"):
		g.call("play_ko_banner")
	if clone.has_method("dash_knock"):
		clone.call("dash_knock")
	SfxBus.play("sfx_ko_guest_dash")
	log_line.emit(Loc.t("log.player.dash_clone"))


func _try_wave_dirt_vfx() -> void:
	if not _has_flag("ignore_dirt_slow") or _wave_vfx_cd > 0.0:
		return
	if not on_dirt():
		return
	_wave_vfx_cd = 0.2
	var ring := Polygon2D.new()
	ring.color = Color(0.45, 0.95, 1.0, 0.55)
	ring.polygon = PackedVector2Array([
		Vector2(-18, 0), Vector2(0, -12), Vector2(18, 0), Vector2(0, 12),
	])
	ring.z_index = 9
	add_child(ring)
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector2(2.2, 2.2), 0.22)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.22)
	tw.tween_callback(ring.queue_free)


func _tick_sku_pick(delta: float) -> void:
	_restock_hold += delta
	if _restock_picking or _restock_hold < Tuning.SKU_PICK_HOLD:
		return
	## A3 L — restock point pick menu.
	if not is_instance_valid(target) or not _interact_try(target):
		log_line.emit(Loc.t("log.player.restock_busy"))
		_j_held = false
		_restock_hold = 0.0
		return
	_restock_picking = true
	target.call("begin_pick")
	SfxBus.play("sfx_box_sku_open")
	log_line.emit(Loc.t("log.player.sku_list_hint"))


func _abort_restock_pick() -> void:
	if target != null and _obj_str(target, "kind") == "restock":
		target.call("abort_pick")
		SfxBus.play("sfx_box_sku_cancel")
		_interact_release(target)
	_restock_picking = false
	_restock_hold = 0.0


func _try_pickup() -> void:
	if _pickup_used:
		return
	_pickup_used = true
	if not inventory.can_take_pieces(1, carry_cap()):
		SfxBus.play("sfx_box_pull_fail")
		log_line.emit(Loc.t("log.player.carry_need", [inventory.count(), carry_cap()]))
		return
	if not bool(target.call("take_box")):
		SfxBus.play("sfx_box_pull_fail")
		log_line.emit(Loc.t("log.player.restock_empty", [Tuning.sku_name(String(target.call("selected_sku")))]))
		return
	var sku := String(target.call("selected_sku"))
	inventory.take_pieces(sku, 1)
	_spawn_fx("suck", target.global_position)
	SfxBus.play("sfx_box_pull")
	log_line.emit(Loc.t("log.player.pull_instant", [Tuning.sku_name(sku)]))


func _tick_restock(delta: float) -> void:
	if inventory.is_empty():
		log_line.emit(Loc.t("log.player.empty_hands_shelf"))
		_j_held = false
		return
	var run: Dictionary = inventory.trailing_run()
	var sku := String(run["id"])
	if not is_instance_valid(target) or not target.has_method("can_accept"):
		hold_progress = 0.0
		return
	## A2 L — shelf stocking Circle.
	if not _interact_try(target):
		log_line.emit(Loc.t("log.player.shelf_busy"))
		hold_progress = 0.0
		return
	if not bool(target.call("can_accept", sku)):
		if _obj_int(target, "count") >= _obj_int(target, "capacity"):
			SfxBus.play("sfx_shelf_stock_blocked")
			log_line.emit(Loc.t("log.player.shelf_full"))
			_j_held = false
			_reset_hold()
			return
		if not blocked_mismatch:
			SfxBus.play("sfx_shelf_stock_blocked")
		blocked_mismatch = true
		hold_progress = 0.0
		return
	## Duration: AGI baseline only. Instant ONLY while 瞬間補貨 buff is active.
	## Equipped loadout always includes instant_restock with restock_circle_mult=0 —
	## never multiply that in when the buff is off.
	var dur := float(Tuning.restock_seconds(_agi_now()))
	if buff_left("instant_restock") > 0.05:
		var lv := 3
		for sk in _loadout():
			if str(sk.get("id", "")) == "instant_restock":
				lv = int(sk.get("lv", 3))
				break
		var mult := float(Skills.restock_circle_mult(lv))
		if mult <= 0.0:
			dur = 0.0
		else:
			dur *= mult
	else:
		var restock_pct := 0.0
		for sk in _loadout():
			## Godot 4.7: String(null) throws — empty slots have no "kind".
			if str(sk.get("kind", "")) == "passive":
				restock_pct += float(sk.get("restock_pct", 0.0))
		if restock_pct > 0.0:
			dur /= 1.0 + restock_pct
		dur = maxf(dur, 0.05)
	if dur <= 0.001:
		hold_progress = 1.0
	else:
		hold_progress = minf(1.0, hold_progress + delta / dur)
		if hold_progress < 1.0:
			SfxBus.play_stock_loop()
	if hold_progress >= 1.0:
		var placed := int(target.call("add_items", sku, int(run["count"])))
		inventory.remove_trailing(placed)
		_spawn_fx("spray", target.global_position + Vector2(0, -20))
		if dur <= 0.001:
			SfxBus.play("sfx_shelf_stock_instant")
		else:
			SfxBus.play("sfx_shelf_stock_done")
		log_line.emit(Loc.t("log.player.shelve", [Tuning.sku_name(sku), placed]))
		hold_progress = 0.0
		_interact_release(target)


func _abort_manual_clean_for_monk() -> void:
	if _cleaning() or _clean_hint:
		_clear_clean_hint()
		_long_committed = false
		hold_progress = 0.0
		log_line.emit(Loc.t("log.player.monk_no_manual"))


func _activate_sweeping_monk() -> void:
	_abort_manual_clean_for_monk()
	## Timed immunity: drop lingering vomit debuff while aura is up.
	_sick_left = 0.0
	_sync_monk_tornado(true)
	## Immediate pulse; ongoing clears happen in _tick_sweeping_monk.
	_clear_dirt_in_monk_range()
	var game := _game()
	if game != null and game.has_method("play_skill_banner"):
		game.call("play_skill_banner", Loc.t("log.player.monk_banner"))


func _sync_monk_tornado(force_on: bool = false) -> void:
	if _monk_tornado == null:
		return
	var on := force_on or buff_left("sweeping_monk") > 0.05
	_monk_tornado.visible = on


func _tick_sweeping_monk(delta: float) -> void:
	if buff_left("sweeping_monk") <= 0.05:
		_sync_monk_tornado(false)
		return
	_sync_monk_tornado(true)
	if _monk_tornado != null:
		_monk_tornado.rotation += delta * 7.5
	_clear_dirt_in_monk_range()


func _clear_dirt_in_monk_range() -> void:
	var g := _game()
	if g == null:
		return
	var dirts = g.get("_dirts")
	if dirts == null:
		return
	var rsq := Skills.SWEEPING_MONK_RANGE_SQ
	var hit: Array = []
	for d in dirts:
		if d == null or not is_instance_valid(d):
			continue
		## Skip nodes already queued for free this frame (avoid double note_clean).
		if d.is_queued_for_deletion():
			continue
		if global_position.distance_squared_to(d.global_position) > rsq:
			continue
		hit.append(d)
	for d in hit:
		if d == null or not is_instance_valid(d) or d.is_queued_for_deletion():
			continue
		var at: Vector2 = d.global_position
		var name := String(d.call("type_name")) if d.has_method("type_name") else Loc.t("dirt.generic")
		if is_instance_valid(target) and target == d:
			target = null
			_long_committed = false
			hold_progress = 0.0
			_clear_clean_hint()
		d.queue_free()
		_spawn_fx("clean_spark", at)
		SfxBus.play("sfx_clean_done")
		if g.has_method("note_clean"):
			g.note_clean()
		log_line.emit(Loc.t("log.player.monk_clear", [name]))


func _tick_clean(_delta: float) -> void:
	if buff_left("sweeping_monk") > 0.05:
		_abort_manual_clean_for_monk()
		return
	if not is_instance_valid(target) or _obj_str(target, "kind") != "dirt":
		return
	## Another seat already owns this dirt's clean cycle — do not wipe / steal it.
	if target.has_method("is_clean_locked_by_other") and bool(target.call("is_clean_locked_by_other", seat_id)):
		return
	## Carry allowed; goods stay in hand while scrubbing.
	var axis := _wiggle_axis()
	if not _clean_hint:
		_last_wiggle = axis
	var travel := (axis - _last_wiggle).length()
	_last_wiggle = axis
	var needed := Tuning.CLEAN_WIGGLE_PER_SEC * Tuning.clean_seconds(_agi_now())
	if needed <= 0.001:
		hold_progress = 1.0
	else:
		var before := hold_progress
		hold_progress = minf(1.0, hold_progress + travel / needed)
		if hold_progress > before:
			SfxBus.play_scrub()
	if not _clean_hint:
		_clean_hint = true
		SfxBus.play("sfx_clean_start")
		log_line.emit(Loc.t("log.player.clean_hint", [String(target.call("type_name"))]))
	if not bool(target.call("set_cleaning", true, axis, hold_progress * 100.0, seat_id)):
		## Lost the race to another seat this frame.
		_clean_hint = false
		_last_wiggle = Vector2.ZERO
		return
	if hold_progress >= 1.0:
		var name := String(target.call("type_name"))
		var spark_at := target.global_position
		target.queue_free()
		target = null
		hold_progress = 0.0
		_clean_hint = false
		_last_wiggle = Vector2.ZERO
		_spawn_fx("clean_spark", spark_at)
		SfxBus.play("sfx_clean_done")
		var game := _game()
		if game and game.has_method("note_clean"):
			game.note_clean(seat_id)
		log_line.emit(Loc.t("log.player.clean_done", [name]))


func _tick_drop() -> void:
	if _pickup_used:
		return
	_pickup_used = true
	if not is_instance_valid(target):
		return
	## A8 L — floor drop pile.
	if not _interact_try(target):
		log_line.emit(Loc.t("log.player.drop_busy"))
		return
	var n := _obj_int(target, "count")
	var sku := _obj_str(target, "sku")
	if n <= 0:
		_interact_release(target)
		return
	if inventory.count() + n > carry_cap():
		log_line.emit(Loc.t("log.player.drop_carry"))
		_interact_release(target)
		return
	var taken := int(target.call("take_all"))
	for i in taken:
		inventory.add_one(sku)
	SfxBus.play("sfx_box_pickup_floor")
	log_line.emit(Loc.t("log.player.pickup", [Tuning.sku_name(sku), taken]))
	_interact_release(target)


func _clear_clean_hint() -> void:
	## Only release dirt THIS seat was cleaning. Never blanket-clear contacts —
	## in coop that wiped the other player's loading cycle when they walked on.
	var was := _clean_hint
	if was:
		SfxBus.play("sfx_clean_cancel")
	_clean_hint = false
	_last_wiggle = Vector2.ZERO
	if was and is_instance_valid(target) and _obj_str(target, "kind") == "dirt":
		target.call("set_cleaning", false, Vector2.ZERO, hold_progress * 100.0, seat_id)


func _tick_cashier(delta: float) -> void:
	if not is_instance_valid(target):
		return
	## A4 L — register through whole payment / cancel.
	if not _interact_try(target):
		log_line.emit(Loc.t("log.player.register_busy"))
		hold_progress = 0.0
		return
	var cust = target.call("ready_customer")
	if cust == null:
		_prompt.active = false
		if not _no_queue_logged:
			if target.call("front_customer") != null:
				log_line.emit(Loc.t("log.player.guest_en_route"))
			else:
				log_line.emit(Loc.t("log.player.no_guest_at_register"))
			_no_queue_logged = true
		return
	target.operator_checkout()
	_ensure_seq(cust)
	_prompt.active = true
	_prompt.sequence = cust.checkout_seq
	_prompt.index = seq_index
	if not seq_done:
		_request_prompt_broadcast()
		return
	var csec := checkout_seconds_now()
	hold_progress = minf(1.0, hold_progress + delta / csec)
	if hold_progress >= 1.0:
		_finish_checkout(cust)
	else:
		_request_prompt_broadcast()


func _senior_cashier_lv_now() -> int:
	if buff_left("senior_cashier") <= 0.05:
		return 0
	return _senior_cashier_lv


func _ensure_seq(cust) -> void:
	if cust.checkout_seq.is_empty():
		## LV3 skip leaves seq empty but marks init so we do not re-roll each frame.
		if cust.has_meta("checkout_seq_init") and bool(cust.get_meta("checkout_seq_init")):
			seq_done = true
			cust.begin_paying()
			return
		## Client LAN: wait for Host absolute seq — never dual-randi (M2.9).
		if SessionService.is_lan() and SessionService.is_client():
			return
		var n := Tuning.command_count(cust.cart.size())
		n = Skills.senior_cashier_command_count(n, _senior_cashier_lv_now())
		cust.set_meta("checkout_seq_init", true)
		seq_index = 0
		_checkout_had_miss = false
		if n <= 0:
			cust.checkout_seq = []
			seq_done = true
			SfxBus.play("sfx_checkout_enter")
			SfxBus.play("sfx_checkout_seq_done")
			log_line.emit(Loc.t("log.player.senior_skip", [cust.cart.size()]))
		else:
			var seq: Array[int] = []
			for i in n:
				seq.append(randi() % 4)
			cust.checkout_seq = seq
			seq_done = false
			SfxBus.play("sfx_checkout_enter")
			log_line.emit(Loc.t("log.player.checkout_cmds", [n, cust.cart.size()]))
		if cust.has_method("broadcast_checkout_seq_state"):
			cust.call("broadcast_checkout_seq_state")
		## prompt_state 由 _tick_cashier 在寫入 _prompt.sequence 後再廣播。
	cust.begin_paying()

func _try_dir(dir: int) -> void:
	if _restock_picking:
		if target != null and _obj_str(target, "kind") == "restock":
			if dir == 0:
				target.call("move_pick", -1)
				SfxBus.play("sfx_box_sku_move")
			elif dir == 1:
				target.call("move_pick", 1)
				SfxBus.play("sfx_box_sku_move")
		return
	if ult_prep:
		_try_ult_dir(dir)
		return
	if skill_menu_open:
		var slot_i: int = int(Skills.DIR_TO_SLOT.get(dir, -1))
		if slot_i < 0:
			return
		if _skill_latch:
			SfxBus.play("sfx_skill_menu_move")
			_confirm_skill(slot_i)
			return
		## Hold: the direction only previews. Release of the skill key confirms.
		_set_skill_aim(slot_i)
		return
	if command_lock:
		_try_command(dir)


func _try_command(dir: int) -> void:
	var cust = target.call("ready_customer") if target else null
	if cust == null or seq_done:
		return
	var seq: Array = cust.checkout_seq
	if seq.is_empty() or seq_index >= seq.size():
		return
	if dir == int(seq[seq_index]):
		_prompt.fail_at = -1
		seq_index += 1
		SfxBus.play("sfx_checkout_dir_ok")
		if seq_index >= seq.size():
			seq_done = true
			SfxBus.play("sfx_checkout_seq_done")
			log_line.emit(Loc.t("log.player.cmds_done"))
	else:
		_checkout_had_miss = true
		_prompt.fail_at = seq_index
		seq_index = 0
		SfxBus.play("sfx_checkout_dir_fail")
		log_line.emit(Loc.t("log.player.cmds_fail"))
	if _prompt:
		_prompt.index = seq_index
	_request_prompt_broadcast(true)


func _finish_checkout(cust) -> void:
	var amount: int = int(cust.call("payout_total")) if cust.has_method("payout_total") else int(cust.call("cart_total"))
	var from_elite: bool = cust.get("is_elite") == true
	var perfect := not _checkout_had_miss
	## paid signal → demo._on_paid; pass elite via game helper when connected.
	var game := _game()
	if game != null and game.has_method("_on_paid"):
		game.call("_on_paid", amount, from_elite, seat_id, self, perfect)
	else:
		paid.emit(amount)
	_checkout_had_miss = false
	SfxBus.play("sfx_checkout_circle_done")
	if from_elite:
		log_line.emit(Loc.t("log.player.elite_pay", [amount]))
	else:
		log_line.emit(Loc.t("log.player.pay_done", [amount]))
	_spawn_dollar()
	cust.finish_paid()
	if target:
		target.dequeue(cust)
		_interact_release(target)
	seq_index = 0
	seq_done = false
	hold_progress = 0.0
	_prompt.active = false
	_prompt.fail_at = -1
	_request_prompt_broadcast(true)


func _spawn_dollar() -> void:
	SfxBus.play("sfx_checkout_cash_pop")
	var lab := Label.new()
	lab.text = "$"
	lab.position = Vector2(-6, -90)
	UiFont.apply_label(lab, UiFont.TITLE)
	lab.add_theme_color_override("font_color", Color("e8c36a"))
	add_child(lab)
	var tw := create_tween()
	tw.tween_property(lab, "position:y", -130.0, 0.55)
	tw.parallel().tween_property(lab, "modulate:a", 0.0, 0.55)
	tw.tween_callback(lab.queue_free)


func _on_skill_hold(pressed: bool) -> void:
	if pressed:
		if _sick_left > 0.0 or _stun_left > 0.0 or _fighting:
			log_line.emit(Loc.t("log.player.cant_skill"))
			return
		## Second skill press confirms range preview skills.
		if _must_deliver_aim:
			_finish_must_deliver_aim()
			_skill_release_ignore = true
			return
		if _magneto_aim:
			_finish_magneto_aim()
			_skill_release_ignore = true
			return
		if _skill_latch:
			_confirm_skill(0)
			_skill_release_ignore = true
			return
		_l_held = true
		_l_time = 0.0
		_skill_aim = 0
		return
	if _skill_release_ignore:
		_skill_release_ignore = false
		_l_held = false
		return
	## Cancel already dropped the hold, or this release is not ours.
	if not _l_held:
		return
	if skill_menu_open:
		if not _skill_latch:
			_sync_hold_aim()
		_confirm_skill(_skill_aim)
		return
	var short := _l_time < Skills.HOLD_MENU_SEC
	var from_pad := _skill_from_pad
	_l_held = false
	_skill_from_pad = false
	if short:
		## Remote LAN seat on Host: short release must not leave a latch menu nobody can close.
		if not controls_locally():
			return
		if from_pad:
			_confirm_skill(0)
		else:
			_open_skill_menu(true)


func _open_skill_menu(latch: bool) -> void:
	skill_menu_open = true
	_skill_latch = latch
	_skill_aim = 0
	_move_locked_until_neutral = true
	_running = false
	velocity = Vector2.ZERO
	if _menu:
		## Only the piloting machine draws the radial; Host still tracks aim for remote seats.
		_menu.open = controls_locally()
		if controls_locally():
			_menu.call("set_slots", _loadout(), _cd)
			if _menu.has_method("set_aim"):
				_menu.call("set_aim", 0)
	_menu_fp = "%s|%s" % [str(_cd), str(_loadout())]
	## A stick already pushed for walking must not count as the tap-menu choice.
	if latch and (stick_axis.length() >= 0.42 or _joy_stick_vector().length() >= 0.42):
		_cardinal_armed = false
	if controls_locally():
		SfxBus.play("sfx_skill_menu_open")
		if latch:
			log_line.emit(Loc.t("log.player.skill_menu_tap"))
		else:
			log_line.emit(Loc.t("log.player.skill_menu_hold"))


func _sync_hold_aim() -> void:
	_set_skill_aim(_skill_aim_slot())


func _skill_aim_slot() -> int:
	var v := _move_vector() + stick_axis
	if v.length() < 0.42:
		return 0
	var dir := Skills.DIR_DOWN if v.y > 0.0 else Skills.DIR_UP
	if absf(v.x) > absf(v.y):
		dir = Skills.DIR_RIGHT if v.x > 0.0 else Skills.DIR_LEFT
	return int(Skills.DIR_TO_SLOT.get(dir, 0))


func _set_skill_aim(slot: int) -> void:
	slot = clampi(slot, 0, 4)
	if slot == _skill_aim:
		if _menu and _menu.has_method("set_aim"):
			_menu.call("set_aim", slot)
		return
	_skill_aim = slot
	if _menu and _menu.has_method("set_aim"):
		_menu.call("set_aim", slot)
	SfxBus.play("sfx_skill_menu_move")


func _confirm_skill(slot: int) -> void:
	_close_skill_menu()
	_cast_slot(slot)
	_move_locked_until_neutral = true
	velocity = Vector2.ZERO


func _try_skill_hotkey(slot: int) -> void:
	if _sick_left > 0.0 or _stun_left > 0.0 or _fighting:
		log_line.emit(Loc.t("log.player.cant_skill"))
		return
	if ult_prep or _elite_focus_left > 0.0:
		return
	if _must_deliver_aim:
		_finish_must_deliver_aim()
		return
	if _magneto_aim:
		_finish_magneto_aim()
		return
	## Queue for Host sim when this seat is piloted on a LAN client.
	if controls_locally() and SessionService.is_lan() and SessionService.is_client():
		pending_skill_hotkey = clampi(slot, 0, 4)
	_confirm_skill(slot)


func take_pending_skill_hotkey() -> int:
	var slot := pending_skill_hotkey
	pending_skill_hotkey = -1
	return slot


## TouchPad / external callers: slot 0–4 = skills 1–5 (0 = center; 1–4 = LB/RB/LT/RT).
func cast_skill_hotkey(slot: int) -> void:
	_try_skill_hotkey(slot)


func _tick_triggers(delta: float) -> void:
	var tr := Controls.trigger_values_for(seat_id)
	var lt := tr.x >= Controls.TRIGGER_DEADZONE
	var rt := tr.y >= Controls.TRIGGER_DEADZONE
	if lt and not _lt_held:
		_lt_held = true
		_lt_time = 0.0
		_lt_fired = false
	if rt and not _rt_held:
		_rt_held = true
		_rt_time = 0.0
		_rt_fired = false
	if lt:
		_lt_time += delta
	if rt:
		_rt_time += delta
	if lt and rt:
		_trigger_chord_block = true
		_both_trigger_time += delta
		if not _ult_chord_active and not ult_prep and _both_trigger_time >= Skills.HOLD_MENU_SEC:
			_on_ult_hold(true)
			if ult_prep:
				_ult_chord_active = true
				_lt_fired = true
				_rt_fired = true
	else:
		_both_trigger_time = 0.0
	## Solo LT/RT → skill 4/5 after grace (skipped if the other trigger joined).
	if lt and not rt and not _trigger_chord_block and not _lt_fired and not ult_prep:
		if _lt_time >= Controls.TRIGGER_SKILL_GRACE:
			_lt_fired = true
			_try_skill_hotkey(3)
	if rt and not lt and not _trigger_chord_block and not _rt_fired and not ult_prep:
		if _rt_time >= Controls.TRIGGER_SKILL_GRACE:
			_rt_fired = true
			_try_skill_hotkey(4)
	if not lt and _lt_held:
		_lt_held = false
	if not rt and _rt_held:
		_rt_held = false
	if not lt and not rt:
		if _ult_chord_active:
			_on_ult_hold(false)
			_ult_chord_active = false
		_trigger_chord_block = false
		_both_trigger_time = 0.0
		_lt_fired = false
		_rt_fired = false


func _close_skill_menu() -> void:
	_l_held = false
	_l_time = 0.0
	_skill_latch = false
	_skill_aim = 0
	skill_menu_open = false
	if _menu:
		_menu.open = false
		if _menu.has_method("set_aim"):
			_menu.call("set_aim", 0)


func _on_ult_hold(pressed: bool) -> void:
	if pressed:
		if _sick_left > 0.0 or _stun_left > 0.0 or _fighting:
			log_line.emit(Loc.t("log.player.cant_ult"))
			return
		var ult := _ult_sk()
		if ult.is_empty() or String(ult.get("id", "")) == "":
			log_line.emit(Loc.t("log.player.no_ult"))
			return
		if bool(ult.get("unimplemented", false)):
			log_line.emit(Loc.t("log.player.demo_no_cd", [String(ult.get("name"))]))
			return
		var ult_id := String(ult.get("id"))
		if cd_left(ult_id) > 0.05:
			SfxBus.play("sfx_skill_cd_deny")
			log_line.emit(Loc.t("log.player.ult_cd", [cd_left(ult_id)]))
			return
		_u_held = true
		ult_prep = true
		_ult_index = 0
		SfxBus.play("sfx_ult_prep")
		_prompt.active = true
		var seq: Array[int] = []
		for d in ult.get("seq", []):
			seq.append(int(d))
		_prompt.sequence = seq
		_prompt.index = 0
		_prompt.fail_at = -1
		log_line.emit(Loc.t("log.player.ult_prep", [String(_ult_sk().get("name"))]))
		return
	if ult_prep:
		SfxBus.play("sfx_ult_cancel")
		log_line.emit(Loc.t("log.player.ult_cancel"))
	_u_held = false
	ult_prep = false
	if not command_lock:
		_prompt.active = false
		_prompt.fail_at = -1


func _try_ult_dir(dir: int) -> void:
	var seq: Array = _ult_sk().get("seq", [])
	if seq.is_empty() or _ult_index < 0 or _ult_index >= seq.size():
		return
	if dir == int(seq[_ult_index]):
		_prompt.fail_at = -1
		_ult_index += 1
		_prompt.index = _ult_index
		SfxBus.play("sfx_ult_dir_ok")
		if _ult_index >= seq.size():
			_cast_ultimate()
			_u_held = false
			ult_prep = false
			_ult_chord_active = false
	else:
		_prompt.fail_at = _ult_index
		_ult_index = 0
		_prompt.index = 0
		SfxBus.play("sfx_ult_dir_fail")
		log_line.emit(Loc.t("log.player.ult_cmds_fail"))


func _cast_slot(i: int) -> void:
	if _sick_left > 0.0 or _stun_left > 0.0 or _fighting:
		log_line.emit(Loc.t("log.player.cant_skill"))
		return
	var sk: Dictionary = _skill_at(i)
	if sk.is_empty():
		return
	if bool(sk.get("unimplemented", false)):
		log_line.emit(Loc.t("log.player.demo_no_cd", [String(sk.get("name"))]))
		return
	if str(sk.get("kind", "")) != "active":
		log_line.emit(Loc.t("log.player.passive", [String(sk.get("name"))]))
		return
	var sid := String(sk.get("id"))
	if cd_left(sid) > 0.05:
		SfxBus.play("sfx_skill_cd_deny")
		log_line.emit(Loc.t("log.player.skill_cd", [String(sk.get("name")), cd_left(sid)]))
		return
	if bool(sk.get("universal_cannon", false)):
		if not _round_active():
			return
		_cancel_must_deliver_aim()
		_cancel_magneto_aim()
		if is_instance_valid(_cannon) and not _cannon.dismissed:
			_cannon.dismiss()
			_cannon = null
			_cd[sid] = Tuning.cd_seconds(60.0, _int_now())
			log_line.emit(Loc.t("cannon.cancelled"))
		else:
			var host := _game()
			if host == null or not host.has_method("deploy_universal_cannon"):
				return
			_cannon = host.deploy_universal_cannon(global_position, int(sk.get("lv", 3)), seat_id)
			if _cannon == null:
				return
			log_line.emit(Loc.t("cannon.deployed"))
		SfxBus.play("sfx_skill_cast")
		_begin_cast_pose(false)
		skill_cast.emit(Loc.t("cannon.name"), false)
		return
	if bool(sk.get("self_checkout", false)):
		if not _cast_self_checkout(int(sk.get("lv", 3))):
			return
		_cancel_must_deliver_aim()
		_cancel_magneto_aim()
		_cd[sid] = Tuning.cd_seconds(30.0, _int_now())
		SfxBus.play("sfx_skill_cast")
		_begin_cast_pose(false)
		skill_cast.emit(Loc.t("self_checkout.active"), false)
		_play_zoom(false)
		return
	## Instant force_sell: empty hands / no target must not start CD.
	if bool(sk.get("force_sell", false)):
		if _must_deliver_aim:
			_cancel_must_deliver_aim()
		if _magneto_aim:
			_cancel_magneto_aim()
		if not _cast_force_sell(int(sk.get("lv", 3))):
			return
		_cd[sid] = Tuning.cd_seconds(float(sk.get("cd", Skills.ACTIVE_CD)), _int_now())
		_buffs.erase(sid)
		_buff_cache_valid = false
		SfxBus.play("sfx_skill_cast")
		log_line.emit(Loc.t("log.player.cast", [String(sk.get("name")), int(sk.get("lv", 3))]))
		_begin_cast_pose(false)
		skill_cast.emit(String(sk.get("name")), false)
		_play_zoom(false)
		return
	## Instant harvest_chives: must aim a cashier with QUEUE/PAYING; 0 must not start CD.
	if bool(sk.get("harvest_chives", false)):
		if _must_deliver_aim:
			_cancel_must_deliver_aim()
		if _magneto_aim:
			_cancel_magneto_aim()
		if not _cast_harvest_chives(int(sk.get("lv", 3))):
			return
		_cd[sid] = Tuning.cd_seconds(float(sk.get("cd", Skills.ACTIVE_CD)), _int_now())
		_buffs.erase(sid)
		_buff_cache_valid = false
		SfxBus.play("sfx_skill_cast")
		log_line.emit(Loc.t("log.player.cast", [String(sk.get("name")), int(sk.get("lv", 3))]))
		_begin_cast_pose(false)
		skill_cast.emit(String(sk.get("name")), false)
		_play_zoom(false)
		return
	## Instant summon_guest: 0 spawned must not start CD.
	if bool(sk.get("summon_guest", false)):
		if _must_deliver_aim:
			_cancel_must_deliver_aim()
		if _magneto_aim:
			_cancel_magneto_aim()
		if not _cast_summon_guest(int(sk.get("lv", 3))):
			return
		_cd[sid] = Tuning.cd_seconds(float(sk.get("cd", Skills.ACTIVE_CD)), _int_now())
		_buffs.erase(sid)
		_buff_cache_valid = false
		SfxBus.play("sfx_skill_cast")
		log_line.emit(Loc.t("log.player.cast", [String(sk.get("name")), int(sk.get("lv", 3))]))
		_begin_cast_pose(false)
		skill_cast.emit(String(sk.get("name")), false)
		_play_zoom(false)
		return
	## 攝石人: first cast = range preview (no CD); confirm via skill press while aiming.
	if bool(sk.get("magneto", false)):
		if _magneto_aim:
			_finish_magneto_aim()
			return
		_begin_magneto_aim(sk)
		return
	## 使命必達: first cast = range preview (no CD); confirm is via skill press while aiming.
	if bool(sk.get("must_deliver", false)):
		if _must_deliver_aim:
			_finish_must_deliver_aim()
			return
		if _magneto_aim:
			_cancel_magneto_aim()
		_begin_must_deliver_aim(sk)
		return
	if _must_deliver_aim:
		_cancel_must_deliver_aim()
	if _magneto_aim:
		_cancel_magneto_aim()
	_cd[sid] = Tuning.cd_seconds(float(sk.get("cd", Skills.ACTIVE_CD)), _int_now())
	## 衝刺交付: the armed window is the cooldown itself, and INT does not shorten this 5s.
	## Dark Side / Multiple Shadow Clone: CD still eats INT, but each body keeps its own 30s.
	## Recast must not refresh people already working (clones despawn then respawn).
	if bool(sk.get("dash_deliver", false)):
		var window := float(sk.get("cd", 5.0))
		_cd[sid] = window
		_buffs[sid] = window
	elif bool(sk.get("dasher", false)):
		_buffs[sid] = Skills.dasher_seconds(int(sk.get("lv", 3)))
	elif bool(sk.get("hoop_ace", false)):
		_buffs[sid] = Skills.hoop_ace_seconds(int(sk.get("lv", 3)))
	elif bool(sk.get("senior_cashier", false)):
		_senior_cashier_lv = int(sk.get("lv", 3))
		_buffs[sid] = Skills.senior_cashier_seconds(_senior_cashier_lv)
	elif bool(sk.get("sweeping_monk", false)):
		_buffs[sid] = Skills.sweeping_monk_seconds(int(sk.get("lv", 3)))
	elif bool(sk.get("dark_side", false)) or bool(sk.get("shadow_clone", false)):
		_buffs.erase(sid)
	else:
		_buffs[sid] = float(sk.get("duration", Skills.ACTIVE_DURATION))
	_buff_cache_valid = false
	if sk.has("customer_move_pct"):
		_enqueue_cust_speed(sid)
	if sk.has("soothe_keep"):
		var game := _game()
		if game and game.has_method("soothe_all"):
			game.soothe_all(float(sk.get("soothe_keep")))
		SfxBus.play("sfx_skill_soothe")
	else:
		if bool(sk.get("dark_side", false)):
			var host := _game()
			if host and host.has_method("cast_dark_side"):
				host.call("cast_dark_side", int(sk.get("lv", 3)))
		elif bool(sk.get("shadow_clone", false)):
			var clone_host := _game()
			if clone_host and clone_host.has_method("cast_shadow_clone"):
				clone_host.call("cast_shadow_clone", int(sk.get("lv", 3)))
		elif bool(sk.get("sweeping_monk", false)):
			_activate_sweeping_monk()
			SfxBus.play("sfx_skill_sweeping_monk")
		else:
			SfxBus.play("sfx_skill_cast")
	log_line.emit(Loc.t("log.player.cast", [String(sk.get("name")), int(sk.get("lv", 3))]))
	_begin_cast_pose(false)
	skill_cast.emit(String(sk.get("name")), false)
	_play_zoom(false)


func release_checkout() -> void:
	seq_index = 0
	seq_done = false
	_checkout_had_miss = false
	hold_progress = 0.0
	_j_held = false
	_long_committed = false
	if _prompt and not ult_prep:
		_prompt.active = false
		_prompt.fail_at = -1
	## Drop InteractLock so a forced KO interrupt cannot leave the register stuck.
	if target != null and _obj_str(target, "kind") == "cashier":
		_interact_release(target)
	_interact_release_held()
	_request_prompt_broadcast(true)


func _lord_seconds(lv: int) -> float:
	match lv:
		1:
			return 3.0
		2:
			return 5.0
		_:
			return 10.0


func _cast_ultimate() -> void:
	var sk: Dictionary = _ult_sk()
	if sk.is_empty() or String(sk.get("id", "")) == "":
		log_line.emit(Loc.t("log.player.no_ult"))
		_prompt.active = false
		return
	if bool(sk.get("unimplemented", false)):
		log_line.emit(Loc.t("log.player.demo_missing", [String(sk.get("name"))]))
		_prompt.active = false
		return
	var sid := String(sk.get("id"))
	var lv := int(sk.get("lv", 3))
	_cd[sid] = Tuning.cd_seconds(float(sk.get("cd", Skills.ULT_CD)), _int_now())
	_buff_cache_valid = false
	var game := _game()
	if sid == "fundraise":
		if game and game.has_method("cast_fundraise"):
			game.call("cast_fundraise", lv)
		SfxBus.play("sfx_ult_fundraise")
		log_line.emit(Loc.t("log.player.ult_fundraise", [lv]))
		_begin_cast_pose(true)
		skill_cast.emit(String(sk.get("name")), true)
		_play_zoom(true)
		_prompt.active = false
		return
	if sid == "close_gate":
		if game and game.has_method("cast_close_gate"):
			game.call("cast_close_gate")
		SfxBus.play("sfx_ult_close_gate")
		log_line.emit(Loc.t("log.player.ult_close_gate"))
		_begin_cast_pose(true)
		skill_cast.emit(String(sk.get("name")), true)
		_play_zoom(true)
		_prompt.active = false
		return
	if sid == "guest_dusk":
		var dusk_ok := false
		if game and game.has_method("cast_guest_dusk"):
			dusk_ok = bool(game.call("cast_guest_dusk"))
		if dusk_ok:
			_buffs[sid] = Skills.GUEST_DUSK_DURATION
			log_line.emit(Loc.t("log.player.ult_dusk", [Skills.GUEST_DUSK_COUNT]))
		else:
			_buffs.erase(sid)
			log_line.emit(Loc.t("log.player.ult_dusk_closed"))
		_buff_cache_valid = false
		SfxBus.play("sfx_ult_guest_dusk")
		_begin_cast_pose(true)
		_spawn_fx("combo", global_position + Vector2(0, -36))
		skill_cast.emit(String(sk.get("name")), true)
		_play_zoom(true)
		_prompt.active = false
		return
	if sid == "yes_my_lord":
		_buffs[sid] = _lord_seconds(lv)
		_buff_cache_valid = false
		SfxBus.play("sfx_ult_yes_my_lord")
		log_line.emit(Loc.t("log.player.ult_lord", [lv, _lord_seconds(lv)]))
		_begin_cast_pose(true)
		_spawn_fx("combo", global_position + Vector2(0, -36))
		skill_cast.emit(String(sk.get("name")), true)
		_play_zoom(true)
		_prompt.active = false
		return
	_buffs[sid] = float(sk.get("duration", Skills.ULT_DURATION))
	_buff_cache_valid = false
	_enqueue_cust_speed(sid)
	SfxBus.play("sfx_ult_the_world")
	log_line.emit(Loc.t("log.player.ult_world", [String(sk.get("name")), lv]))
	_begin_cast_pose(true)
	_spawn_fx("timestop", global_position + Vector2(0, -40))
	skill_cast.emit(String(sk.get("name")), true)
	_play_zoom(true)
	_prompt.active = false


func _begin_cast_pose(ult: bool) -> void:
	_cast_pose_left = 0.55 if ult else 0.35


func _spawn_fx(fx_id: String, at: Vector2) -> void:
	var host: Node = _game()
	if host == null:
		host = get_parent()
	FxBurst.spawn(host, fx_id, at)


func _shared_camera() -> Camera2D:
	if camera != null and is_instance_valid(camera):
		return camera
	var game := _game()
	if game != null:
		var host = game.get("_player")
		if host != null and host.get("camera") != null:
			return host.camera as Camera2D
	return null


func _play_zoom(ult: bool) -> void:
	if not controls_locally():
		return
	var cam := _shared_camera()
	if cam == null:
		return
	## Keep local ref so restore_base_camera / shake also work for seat1+.
	camera = cam
	var base := base_camera_zoom()
	var z := base * (1.28 if ult else 1.12)
	var tw := create_tween()
	tw.tween_property(cam, "zoom", Vector2(z, z), 0.18)
	tw.tween_interval(0.22 if ult else 0.12)
	tw.tween_callback(restore_base_camera)


func _reset_hold() -> void:
	if hold_progress > 0.0 or seq_index > 0:
		SfxBus.play("sfx_checkout_release_reset")
		log_line.emit(Loc.t("log.player.cmd_reset"))
	_clear_clean_hint()
	hold_progress = 0.0
	blocked_mismatch = false
	seq_index = 0
	seq_done = false
	_checkout_had_miss = false
	if _prompt and not ult_prep:
		_prompt.active = false
		_prompt.fail_at = -1
	if not is_instance_valid(target):
		target = null
	elif _obj_str(target, "kind") == "cashier":
		var cust = target.call("front_customer")
		if cust:
			cust.cancel_pay()
		_interact_release(target)
	elif _obj_str(target, "kind") == "shelf":
		_interact_release(target)
	_interact_release_held()
	_request_prompt_broadcast(true)


func _interact_try(node: Object) -> bool:
	var il := get_node_or_null("/root/InteractLock")
	if il == null:
		_lock_node = node as Node
		return true
	if not bool(il.try_acquire(node, seat_id)):
		return false
	_lock_node = node as Node
	return true


func _interact_release(node: Object) -> void:
	var il := get_node_or_null("/root/InteractLock")
	if il:
		il.release(node, seat_id)
	if _lock_node == node:
		_lock_node = null


func _interact_release_held() -> void:
	if _lock_node != null and is_instance_valid(_lock_node):
		_interact_release(_lock_node)
	_lock_node = null


func _note_delivery_combo(guests: Array, _pieces: int) -> void:
	## Qualifying COMBO: cleared remaining list with ≥3 pieces on a guest this burst.
	var game := _game()
	if game == null or not game.has_method("combo_note_qualify"):
		return
	var qualified := false
	for guest in guests:
		if guest == null or not is_instance_valid(guest):
			continue
		if not guest.has_meta("combo_cleared_n"):
			continue
		var n := int(guest.get_meta("combo_cleared_n"))
		guest.remove_meta("combo_cleared_n")
		if n >= 3:
			qualified = true
			if guest.has_method("apply_combo_bonus"):
				guest.call("apply_combo_bonus")
	if qualified:
		game.call("combo_note_qualify", seat_id)
	elif game.has_method("combo_break_personal"):
		game.call("combo_break_personal", seat_id)


func _handle_hotkey_actions(event: InputEvent) -> void:
	if event.is_action_pressed(Controls.SKILL_2):
		_try_skill_hotkey(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(Controls.SKILL_3):
		_try_skill_hotkey(2)
		get_viewport().set_input_as_handled()
		return
	if target == null or _obj_str(target, "kind") != "restock":
		return
	if event.is_action_pressed(Controls.RESTOCK_PREV):
		target.call("cycle", -1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(Controls.RESTOCK_NEXT):
		target.call("cycle", 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(Controls.RESTOCK_SLOT_1):
		target.call("set_highlight", 0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(Controls.RESTOCK_SLOT_2):
		target.call("set_highlight", 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(Controls.RESTOCK_SLOT_3):
		target.call("set_highlight", 2)
		get_viewport().set_input_as_handled()


func _visual_anim() -> String:
	var mid := _model_id if _model_id != "" else appearance_skin_id()
	if _stun_left > 0.0:
		return "down"
	if _slip_left > 0.0:
		return "slip"
	if _cast_pose_left > 0.0 and Vox.has_anim(mid, "cast"):
		return "cast"
	if _deliver_pose_left > 0.0 and Vox.has_anim(mid, "deliver"):
		return "deliver"
	if _fighting:
		return "fight"
	if _cleaning():
		return "clean"
	if command_lock:
		return "checkout"
	if _shelving():
		return "restock"
	if _dashing:
		return "dash"
	var moving := velocity.length() > 8.0
	## Puppets zero velocity — walk from Host pose delta instead.
	if is_net_puppet():
		moving = _net_puppet_moving
	if _running and moving and not is_net_puppet():
		return "run"
	if moving:
		if not inventory.is_empty() and Vox.has_anim(mid, "walk_carry"):
			return "walk_carry"
		return "walk"
	return "idle"


func _update_visuals() -> void:
	if _arrow:
		## Tip is authored toward +Y (south); rotate so tip matches facing.
		_arrow.rotation = facing.angle() - PI / 2.0
	if _body == null:
		return
	_model_id = appearance_skin_id()
	var anim := _visual_anim()
	var prev_face := int(_body.get_meta("vox_anim_facing", -1)) if _body is AnimatedSprite2D else -1
	var face_k := Vox.k_from_facing_stable(facing, prev_face) if _body is AnimatedSprite2D else Vox.k_from_facing(facing)
	var anim_key := "%s_%s_%d_%.2f" % [_model_id, anim, face_k, 1.25 if _running else 1.0]
	if _body is AnimatedSprite2D:
		if anim_key != _shown_anim:
			_shown_anim = anim_key
			var spd := 1.25 if _running else 1.0
			Vox.play_anim(_body as AnimatedSprite2D, _model_id, anim, facing, spd)
	elif _body is Sprite2D:
		Vox.apply(_body as Sprite2D, _model_id, face_k)
	var status := Color.WHITE
	if ult_prep:
		status = Color(1.0, 0.45, 0.4)
	elif skill_menu_open:
		status = Color(0.65, 0.9, 1.0)
	elif command_lock:
		status = Color(1.0, 0.9, 0.55)
	elif _dashing:
		status = Color(1.0, 0.92, 0.45)
	elif _running:
		status = Color(0.7, 1.0, 0.85)
	elif _fighting:
		status = Color(1.0, 0.45, 0.4)
	elif _stun_left > 0.0:
		status = Color(0.85, 0.7, 1.0)
	elif on_dirt():
		status = Color(0.75, 0.62, 0.45)
	var appear := _appearance_tint()
	var tint := Color(appear.r * status.r, appear.g * status.g, appear.b * status.b, 1.0)
	if tint != _shown_tint:
		_shown_tint = tint
		_body.modulate = tint


func _appearance_tint() -> Color:
	if stats == null:
		return Color.WHITE
	if stats.has_method("appearance_tint"):
		return stats.appearance_tint()
	if "tint" in stats:
		const CharacterSheet = preload("res://scripts/session/character_sheet.gd")
		return CharacterSheet.tint_color(int(stats.tint))
	return Color.WHITE


func _usable_cannon() -> Node2D:
	var best: Node2D
	var best_d := INF
	for node in interactables:
		if not is_instance_valid(node) or _obj_str(node, "kind") != "universal_cannon":
			continue
		if not node.available_for(self):
			continue
		var d := _interact_dist(node)
		if d >= 0.0 and d < best_d:
			best = node
			best_d = d
	return best


func _tick_cannon(delta: float) -> void:
	if _pickup_used or not is_instance_valid(target):
		return
	if inventory.is_empty() or target.ammo.size() >= target.capacity():
		hold_progress = 0.0
		return
	var seconds := maxf(0.05, Tuning.restock_seconds(_agi_now()))
	hold_progress = minf(1.0, hold_progress + delta / seconds)
	if hold_progress >= 1.0:
		var loaded: int = target.load_from(self)
		_pickup_used = true
		hold_progress = 0.0
		log_line.emit(Loc.t("cannon.loaded", [loaded]))
		SfxBus.play("sfx_shelf_stock_done")
