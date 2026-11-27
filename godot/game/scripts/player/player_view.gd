extends RefCounted
## Role status, HUD dirty-check, and body visuals extracted from player.gd (#175).
## Host-bound: call bind(player) from Player._ready. State stays on the player host.

const Tuning = preload("res://scripts/tuning.gd")
const Vox = preload("res://scripts/voxel_sprite.gd")

var host: CharacterBody2D = null


func bind(player: CharacterBody2D) -> void:
	host = player


func role_status_text() -> String:
	var bits: PackedStringArray = []
	bits.append("STR%d AGI%d INT%d" % [host._stat_base("str"), host._stat_base("agi"), host._stat_base("int")])
	if host._buffs.has("carry_boost"):
		bits.append(Loc.t("hud.status.carry", [host._buffs["carry_boost"]]))
	if host._buffs.has("move_boost"):
		bits.append(Loc.t("hud.status.move", [host._buffs["move_boost"]]))
	if host._buffs.has("instant_restock"):
		bits.append(Loc.t("hud.status.instant", [host._buffs["instant_restock"]]))
	if host._buffs.has("shelf_sniper"):
		bits.append(Loc.t("hud.status.sniper_shelf", [host._buffs["shelf_sniper"]]))
	if host._buffs.has("guest_sniper"):
		bits.append(Loc.t("hud.status.sniper_guest", [host._buffs["guest_sniper"]]))
	if host._buffs.has("thief_sniper"):
		bits.append(Loc.t("hud.status.sniper_thief", [host._buffs["thief_sniper"]]))
	if host._buffs.has("dash_deliver"):
		bits.append(Loc.t("hud.status.dash_deliver", [host._buffs["dash_deliver"]]))
	if host._buffs.has("dasher"):
		bits.append("Dasher %.0fs" % host._buffs["dasher"])
	if host._buffs.has("senior_cashier"):
		bits.append(Loc.t("hud.status.senior", [host._buffs["senior_cashier"]]))
	if host._buffs.has("checkout_rush"):
		bits.append(Loc.t("hud.status.checkout_rush", [host._buffs["checkout_rush"]]))
	if host._buffs.has("hoop_ace"):
		bits.append(Loc.t("hud.status.hoop", [host._buffs["hoop_ace"]]))
	if host._buffs.has("sweeping_monk"):
		bits.append(Loc.t("hud.status.monk", [host._buffs["sweeping_monk"]]))
	if host._sick_left > 0.0:
		bits.append(Loc.t("hud.status.sick", [host._sick_left]))
	if host._fighting:
		bits.append(Loc.t("hud.status.fighting"))
	if host._stun_left > 0.0:
		bits.append(Loc.t("hud.status.down", [host._stun_left]))
	if host._checkout_prefill_charge > 0:
		bits.append(Loc.t("hud.status.checkout_prefill", [host._checkout_prefill_charge]))
	elif host._checkout_prefill_n_equipped() > 0:
		bits.append(Loc.t("hud.status.checkout_prefill_ready", [host._checkout_prefill_n_equipped()]))
	return Loc.t("hud.status.prefix_role") + " ".join(bits)

func target_detail_fp(node: Node2D) -> String:
	if node == null or not is_instance_valid(node):
		return "-"
	var k: String = host._obj_str(node, "kind")
	var tinfo: String = "%s:%d" % [k, node.get_instance_id()]
	match k:
		"restock":
			var pick: Variant = node.call("selected_sku") if node.has_method("selected_sku") else ""
			tinfo += ":%s" % (str(pick) if pick != null else "")
		"dirt":
			var dname: Variant = node.call("type_name") if node.has_method("type_name") else ""
			tinfo += ":%s" % (str(dname) if dname != null else "")
		"universal_cannon", "shelf_cannon", "kind_cannon":
			tinfo += ":%s" % str(node.ammo)
		"drop":
			tinfo += ":%s:%d" % [host._obj_str(node, "sku"), host._obj_int(node, "count")]
		"shelf":
			var cap: int = host._obj_int(node, "capacity")
			if cap <= 0:
				cap = Tuning.SHELF_CAP
			tinfo += ":%s:%d:%d" % [host._obj_str(node, "sku"), host._obj_int(node, "count"), cap]
		"thief":
			tinfo += ":%.0f:%.1f" % [host._obj_float(node, "fight_hp"), host._obj_float(node, "fight_left")]
		"", "elite":
			tinfo += ":guest"
	return tinfo

func hud_fingerprint() -> String:
	## Assumes cheap HUD caches were refreshed by _emit_stats_if_changed.
	var inv_bits: PackedStringArray = []
	for g in host.inventory.grouped():
		inv_bits.append("%s:%d" % [String(g["id"]), int(g["count"])])
	return "%s|%.2f|%.2f|%d|%s@%d|%.2f|%s|%s" % [
		host._hud_move,
		host._hud_stam,
		host._hud_stam_max,
		host._hud_carry,
		",".join(inv_bits),
		int(host.inventory.focus_index) if host.inventory != null else -1,
		host._hud_hold,
		str(host._hud_blocked),
		host._hud_target_detail,
	]

func emit_stats_if_changed() -> void:
	## Cheap dirty gate — avoid inventory.grouped() / string join when nothing changed.
	var inv_rev: int = int(host.inventory.revision) if host.inventory != null else 0
	var move: String = host.move_state()
	var stam: float = snappedf(host.stamina, 0.25)
	var stam_max: float = snappedf(host.stamina_max_now(), 0.25)
	var carry: int = int(host.carry_cap())
	var hold: float = snappedf(host.hold_progress, 0.01)
	var tid: int = host.target.get_instance_id() if is_instance_valid(host.target) else 0
	var need: bool = host._hud_dirty
	if inv_rev != host._hud_inv_rev:
		need = true
	elif move != host._hud_move:
		need = true
	elif not is_equal_approx(stam, host._hud_stam):
		need = true
	elif not is_equal_approx(stam_max, host._hud_stam_max):
		need = true
	elif carry != host._hud_carry:
		need = true
	elif not is_equal_approx(hold, host._hud_hold):
		need = true
	elif host.blocked_mismatch != host._hud_blocked:
		need = true
	elif tid != host._hud_target_id:
		need = true
	elif tid != 0:
		var detail: String = target_detail_fp(host.target)
		if detail != host._hud_target_detail:
			need = true
			host._hud_target_detail = detail
	if not need:
		return
	host._hud_inv_rev = inv_rev
	host._hud_move = move
	host._hud_stam = stam
	host._hud_stam_max = stam_max
	host._hud_carry = carry
	host._hud_hold = hold
	host._hud_blocked = host.blocked_mismatch
	host._hud_target_id = tid
	host._hud_target_detail = target_detail_fp(host.target) if tid != 0 else "-"
	host._hud_dirty = false
	var fp: String = hud_fingerprint()
	if fp == host._hud_fp:
		return
	host._hud_fp = fp
	host.stats_changed.emit()

func visual_anim() -> String:
	var mid: String = host._model_id if host._model_id != "" else host.appearance_skin_id()
	if host._stun_left > 0.0:
		return "down"
	if host._slip_left > 0.0:
		return "slip"
	if host._cast_pose_left > 0.0 and Vox.has_anim(mid, "cast"):
		return "cast"
	if host._deliver_pose_left > 0.0 and Vox.has_anim(mid, "deliver"):
		return "deliver"
	if host._fighting:
		return "fight"
	if host._cleaning():
		return "clean"
	if host.command_lock:
		return "checkout"
	if host._shelving():
		return "restock"
	if host._dashing:
		return "dash"
	var moving: bool = host.velocity.length() > 8.0
	## Puppets zero velocity — walk from Host pose delta instead.
	if host.is_net_puppet():
		moving = host._net_puppet_moving
	if host._running and moving and not host.is_net_puppet():
		return "run"
	if moving:
		if not host.inventory.is_empty() and Vox.has_anim(mid, "walk_carry"):
			return "walk_carry"
		return "walk"
	return "idle"

func update_visuals() -> void:
	if host._arrow:
		## Tip is authored toward +Y (south); rotate so tip matches facing.
		host._arrow.rotation = host.facing.angle() - PI / 2.0
	if host._body == null:
		return
	host._model_id = host.appearance_skin_id()
	var anim: String = visual_anim()
	var prev_face: int = int(host._body.get_meta("vox_anim_facing", -1)) if host._body is AnimatedSprite2D else -1
	var face_k: int = Vox.k_from_facing_stable(host.facing, prev_face) if host._body is AnimatedSprite2D else Vox.k_from_facing(host.facing)
	var anim_key: String = "%s_%s_%d_%.2f" % [host._model_id, anim, face_k, 1.25 if host._running else 1.0]
	if host._body is AnimatedSprite2D:
		if anim_key != host._shown_anim:
			host._shown_anim = anim_key
			var spd: float = 1.25 if host._running else 1.0
			Vox.play_anim(host._body as AnimatedSprite2D, host._model_id, anim, host.facing, spd)
	elif host._body is Sprite2D:
		Vox.apply(host._body as Sprite2D, host._model_id, face_k)
	var status: Color = Color.WHITE
	if host.ult_prep:
		status = Color(1.0, 0.45, 0.4)
	elif host.skill_menu_open:
		status = Color(0.65, 0.9, 1.0)
	elif host.command_lock:
		status = Color(1.0, 0.9, 0.55)
	elif host._dashing:
		status = Color(1.0, 0.92, 0.45)
	elif host._running:
		status = Color(0.7, 1.0, 0.85)
	elif host._fighting:
		status = Color(1.0, 0.45, 0.4)
	elif host._stun_left > 0.0:
		status = Color(0.85, 0.7, 1.0)
	elif host.on_dirt():
		status = Color(0.75, 0.62, 0.45)
	var appear: Color = appearance_tint()
	var tint: Color = Color(appear.r * status.r, appear.g * status.g, appear.b * status.b, 1.0)
	if tint != host._shown_tint:
		host._shown_tint = tint
		host._body.modulate = tint

func appearance_tint() -> Color:
	if host.stats == null:
		return Color.WHITE
	if host.stats.has_method("appearance_tint"):
		return host.stats.appearance_tint()
	if "tint" in host.stats:
		const CharacterSheet = preload("res://scripts/session/character_sheet.gd")
		return CharacterSheet.tint_color(int(host.stats.tint))
	return Color.WHITE
