extends RefCounted
## Cashier checkout / direction commands extracted from player.gd (#175 PR1).
## Host-bound: call bind(player) from Player._ready. State stays on the player host.

const Tuning = preload("res://scripts/tuning.gd")
const Skills = preload("res://scripts/skills.gd")
const CustomerScript = preload("res://scripts/customer.gd")

var host: CharacterBody2D = null


func bind(player: CharacterBody2D) -> void:
	host = player


func tick_cashier(_delta: float) -> void:
	if not is_instance_valid(host.target):
		return
	## A4 L — register through whole payment / cancel.
	if not host._interact_try(host.target):
		host.log_line.emit(Loc.t("log.player.register_busy"))
		host.hold_progress = 0.0
		return
	var cust = host.target.call("ready_customer")
	if cust == null:
		host._prompt.active = false
		## Still holding, but nobody to check out — unlock walk until release / next ready.
		enter_checkout_hold_idle()
		if not host._no_queue_logged:
			if host.target.call("front_customer") != null:
				host.log_line.emit(Loc.t("log.player.guest_en_route"))
			else:
				host.log_line.emit(Loc.t("log.player.no_guest_at_register"))
			host._no_queue_logged = true
		return
	host.target.operator_checkout()
	ensure_seq(cust)
	host._prompt.active = true
	host._prompt.sequence = cust.checkout_seq
	host._prompt.index = host.seq_index
	## No Loading Circle — last correct arrow (or full prefill) pays immediately.
	host.hold_progress = 0.0
	if not host.seq_done:
		host._request_prompt_broadcast()
		return
	## Boss multi-wave: finish one wave → cutscene／next wave instead of pay.
	var game_w: Node = host._game()
	if cust.get("is_boss") == true and game_w != null and game_w.has_method("boss_on_checkout_wave_done"):
		if bool(game_w.call("boss_on_checkout_wave_done", cust)):
			host.seq_index = 0
			host.seq_done = false
			cust.checkout_seq.clear()
			if cust.has_meta("checkout_seq_init"):
				cust.remove_meta("checkout_seq_init")
			host._prompt.active = true
			## Typed Array[int] — do not assign bare [].
			host._prompt.sequence.clear()
			host._prompt.index = 0
			host._request_prompt_broadcast(true)
			return
	finish_checkout(cust)


func _senior_cashier_lv_now() -> int:
	if host.buff_left("senior_cashier") <= 0.05:
		return 0
	return host._senior_cashier_lv


func ensure_seq(cust) -> void:
	if cust.checkout_seq.is_empty():
		## Client LAN: wait for Host absolute seq — never dual-randi (M2.9).
		if SessionService.is_networked() and SessionService.is_client():
			return
		var n: int = Tuning.checkout_command_count(cust.cart.size(), host._int_now())
		var game_n: Node = host._game()
		## Boss absolute wave counts (no INT reduce / later prefill).
		if cust.get("is_boss") == true and game_n != null and game_n.has_method("boss_checkout_wave_count"):
			var wave_n: int = int(game_n.call("boss_checkout_wave_count", cust))
			if wave_n > 0:
				n = wave_n
		cust.set_meta("checkout_seq_init", true)
		host.seq_index = 0
		host._checkout_had_miss = false
		var seq: Array[int] = []
		for i in n:
			seq.append(randi() % 4)
		cust.checkout_seq = seq
		host.seq_done = false
		SfxBus.play("sfx_checkout_enter")
		host.log_line.emit(Loc.t("log.player.checkout_cmds", [n, cust.cart.size()]))
		## Perfect-chain prefill: drop first N arrows (only remainder shown); keep full for miss restore.
		## Boss waves: never prefill.
		var pref: int = 0 if cust.get("is_boss") == true else mini(host._checkout_prefill_charge, seq.size())
		if cust.get("is_boss") != true:
			host._checkout_prefill_charge = 0
		else:
			host._checkout_prefill_charge = 0
		host.seq_index = 0
		if cust.has_meta("checkout_seq_full"):
			cust.remove_meta("checkout_seq_full")
		if cust.has_meta("checkout_seq_trimmed"):
			cust.remove_meta("checkout_seq_trimmed")
		if pref > 0:
			var full_copy: Array = []
			for d in seq:
				full_copy.append(int(d))
			cust.set_meta("checkout_seq_full", full_copy)
			cust.set_meta("checkout_seq_trimmed", true)
			var remain: Array[int] = []
			for i in range(pref, seq.size()):
				remain.append(int(seq[i]))
			cust.checkout_seq = remain
			if remain.is_empty():
				host.seq_done = true
				SfxBus.play("sfx_checkout_seq_done")
				host.log_line.emit(Loc.t("log.player.cmds_done"))
			else:
				host.log_line.emit(Loc.t("log.player.checkout_prefill", [pref]))
		if cust.has_method("broadcast_checkout_seq_state"):
			cust.call("broadcast_checkout_seq_state")
		## prompt_state 由 tick_cashier 在寫入 _prompt.sequence 後再廣播。
	cust.begin_paying()


func try_dir(dir: int) -> void:
	if host._restock_picking:
		if host.target != null and host._obj_str(host.target, "kind") in ["restock", "fish_tank"]:
			if dir == 0:
				host.target.call("move_pick", -1)
				SfxBus.play("sfx_box_sku_move")
			elif dir == 1:
				host.target.call("move_pick", 1)
				SfxBus.play("sfx_box_sku_move")
		return
	if host._cooked_picking:
		if host.target != null and host._obj_str(host.target, "kind") == "cooked_stall":
			## UP/DOWN cycle recipes; LEFT/RIGHT cycle fish for nigiri.
			if dir == Skills.DIR_UP:
				host.target.call("move_pick", -1)
				SfxBus.play("sfx_box_sku_move")
			elif dir == Skills.DIR_DOWN:
				host.target.call("move_pick", 1)
				SfxBus.play("sfx_box_sku_move")
			elif dir == Skills.DIR_LEFT:
				host.target.call("move_fish", -1)
				SfxBus.play("sfx_box_sku_move")
			elif dir == Skills.DIR_RIGHT:
				host.target.call("move_fish", 1)
				SfxBus.play("sfx_box_sku_move")
		return
	if host.ult_prep:
		host._try_ult_dir(dir)
		return
	if host.skill_menu_open:
		var stick := Vector2.ZERO
		match dir:
			Skills.DIR_UP:
				stick = Vector2(0, -1)
			Skills.DIR_DOWN:
				stick = Vector2(0, 1)
			Skills.DIR_LEFT:
				stick = Vector2(-1, 0)
			Skills.DIR_RIGHT:
				stick = Vector2(1, 0)
			_:
				return
		var SkillMenu = preload("res://scripts/skill_menu.gd")
		var slot_i: int = SkillMenu.aim_from_stick(stick)
		if slot_i < 0:
			return
		if host._skill_latch:
			SfxBus.play("sfx_skill_menu_move")
			host._confirm_skill(slot_i)
			return
		## Hold: the direction only previews. Release of the skill key confirms.
		host._set_skill_aim(slot_i)
		return
	if host.bag_menu_open:
		var bstick := Vector2.ZERO
		match dir:
			Skills.DIR_UP:
				bstick = Vector2(0, -1)
			Skills.DIR_DOWN:
				bstick = Vector2(0, 1)
			Skills.DIR_LEFT:
				bstick = Vector2(-1, 0)
			Skills.DIR_RIGHT:
				bstick = Vector2(1, 0)
			_:
				return
		var BagMenu = preload("res://scripts/bag_menu.gd")
		var bslot: int = BagMenu.aim_from_stick(bstick)
		if bslot < 0:
			return
		if host._bag_latch:
			SfxBus.play("sfx_skill_menu_move")
			if host._bags != null and host._bags.has_method("confirm_bag"):
				host._bags.confirm_bag(bslot)
			return
		if host._bags != null and host._bags.has_method("set_bag_aim"):
			host._bags.set_bag_aim(bslot)
		return
	if host.carry_menu_open:
		var cstick := Vector2.ZERO
		match dir:
			Skills.DIR_UP:
				cstick = Vector2(0, -1)
			Skills.DIR_DOWN:
				cstick = Vector2(0, 1)
			Skills.DIR_LEFT:
				cstick = Vector2(-1, 0)
			Skills.DIR_RIGHT:
				cstick = Vector2(1, 0)
			_:
				return
		var CarryMenu = preload("res://scripts/carry_menu.gd")
		var count: int = host.inventory.grouped().size() if host.inventory != null else 0
		var cslot: int = CarryMenu.aim_from_stick(cstick, count)
		if cslot < 0:
			return
		if host._carry_latch:
			SfxBus.play("sfx_skill_menu_move")
			if host._carries != null and host._carries.has_method("confirm_carry"):
				host._carries.confirm_carry(cslot)
			return
		if host._carries != null and host._carries.has_method("set_carry_aim"):
			host._carries.set_carry_aim(cslot)
		return
	## Prefer command_lock; also accept sticky checkout before lock flips this frame.
	if host.command_lock or (
		host._long_committed
		and host._j_held
		and not host._checkout_hold_idle
		and is_instance_valid(host.target)
		and host._obj_str(host.target, "kind") == "cashier"
	):
		try_command(dir)


func try_command(dir: int) -> void:
	var cust = host.target.call("ready_customer") if host.target else null
	if cust == null or host.seq_done:
		return
	var seq: Array = cust.checkout_seq
	if seq.is_empty() or host.seq_index >= seq.size():
		return
	if dir == int(seq[host.seq_index]):
		host._prompt.fail_at = -1
		host.seq_index += 1
		SfxBus.play("sfx_checkout_dir_ok")
		if host.seq_index >= seq.size():
			host.seq_done = true
			SfxBus.play("sfx_checkout_seq_done")
			host.log_line.emit(Loc.t("log.player.cmds_done"))
	else:
		host._checkout_had_miss = true
		## Prefill miss: restore full arrow string so trimmed cmds reappear; chain ends (no Perfect).
		if cust.has_meta("checkout_seq_trimmed") and bool(cust.get_meta("checkout_seq_trimmed")):
			var full = cust.get_meta("checkout_seq_full")
			if full is Array and full.size() > cust.checkout_seq.size():
				var restored: Array[int] = []
				for d in full:
					restored.append(int(d))
				cust.checkout_seq = restored
				if cust.has_method("broadcast_checkout_seq_state"):
					cust.call("broadcast_checkout_seq_state")
			cust.set_meta("checkout_seq_trimmed", false)
		host._prompt.fail_at = 0
		host.seq_index = 0
		SfxBus.play("sfx_checkout_dir_fail")
		host.log_line.emit(Loc.t("log.player.cmds_fail"))
	if host._prompt:
		host._prompt.sequence = cust.checkout_seq
		host._prompt.index = host.seq_index
	host._request_prompt_broadcast(true)


func finish_checkout(cust) -> void:
	## Host authority — Client waits for prompt／agent state (M2.9).
	if not host._world_authority():
		return
	var reg = host.target
	## Peek dual target before primary leaves the queue (index 1 = next in line).
	## Boss: no senior dual-pay.
	var dual_guest = null if cust.get("is_boss") == true else peek_senior_dual_guest(reg, cust)
	var base: int = int(cust.call("payout_total")) if cust.has_method("payout_total") else int(cust.call("cart_total"))
	var from_elite: bool = cust.get("is_elite") == true
	var perfect: bool = not host._checkout_had_miss
	## Grade hook for future rhythm FX (Good/Great/Perfect visuals).
	host._last_checkout_grade = "perfect" if perfect else "ok"
	var amount: int = Tuning.checkout_revenue_amount(base, host._int_now(), perfect, host._checkout_rush_bonus_now())
	## paid signal → demo._on_paid; pass elite via game helper when connected.
	var game: Node = host._game()
	if game != null:
		game._on_paid(amount, from_elite, host.seat_id, host, perfect, cust, true)
	else:
		host.paid.emit(amount)
	host._checkout_had_miss = false
	SfxBus.play("sfx_checkout_circle_done")
	if from_elite:
		host.log_line.emit(Loc.t("log.player.elite_pay", [amount]))
	else:
		host.log_line.emit(Loc.t("log.player.pay_done", [amount]))
	host._spawn_dollar()
	cust.finish_paid()
	if game != null and cust.get("is_boss") == true and game.has_method("boss_on_paid"):
		game.call("boss_on_paid", cust)
	if reg and is_instance_valid(reg) and reg.has_method("dequeue"):
		reg.dequeue(cust)
	## Perfect-chain: arm next-guest prefill (one layer; non-Perfect clears).
	if perfect:
		host._checkout_prefill_charge = host._checkout_prefill_n_equipped()
	else:
		host._checkout_prefill_charge = 0
	## Senior dual-pay: settle the guest captured before primary left.
	try_senior_dual_checkout(reg, dual_guest)
	if reg:
		host._interact_release(reg)
	host.seq_index = 0
	host.seq_done = false
	host.hold_progress = 0.0
	host._prompt.active = false
	host._prompt.fail_at = -1
	host._request_prompt_broadcast(true)
	## Chain into the next ready guest while still holding; otherwise idle-walk.
	if reg != null and is_instance_valid(reg) and host._cashier_has_ready(reg):
		host._checkout_hold_idle = false
		host._no_queue_logged = false
	else:
		enter_checkout_hold_idle()


func enter_checkout_hold_idle() -> void:
	host._checkout_hold_idle = true
	host._long_committed = false
	if is_instance_valid(host.target) and host._obj_str(host.target, "kind") == "cashier":
		host._interact_release(host.target)
	if host._prompt and not host.ult_prep:
		host._prompt.active = false
		host._prompt.fail_at = -1


## Next QUEUE／PAYING guest behind `primary` at this register (not TO_CASHIER).
func peek_senior_dual_guest(reg, primary) -> Node:
	if reg == null or not is_instance_valid(reg):
		return null
	var q = reg.get("queue")
	if q == null or not (q is Array) or q.size() < 2:
		return null
	var nxt = q[1]
	if nxt == null or not is_instance_valid(nxt) or nxt == primary:
		return null
	var st := int(nxt.get("state"))
	if st != CustomerScript.State.QUEUE and st != CustomerScript.State.PAYING:
		return null
	return nxt


## While senior_cashier is up, optionally pay the peeked dual guest (no Perfect).
func try_senior_dual_checkout(reg, nxt) -> void:
	var lv := _senior_cashier_lv_now()
	if lv <= 0:
		return
	if SessionService.is_networked() and SessionService.is_client():
		return
	if nxt == null or not is_instance_valid(nxt):
		return
	var st := int(nxt.get("state"))
	if st == CustomerScript.State.LEAVE or st == CustomerScript.State.FLEE:
		return
	if st != CustomerScript.State.QUEUE and st != CustomerScript.State.PAYING:
		return
	var proc := Skills.senior_cashier_dual_proc(lv)
	if proc < 1.0 and randf() > proc:
		return
	var base: int = int(nxt.call("payout_total")) if nxt.has_method("payout_total") else int(nxt.call("cart_total"))
	var from_elite: bool = nxt.get("is_elite") == true
	## Dual guest: INT + rush money OK; never Perfect ×1.05 / perfect rating.
	var amount: int = Tuning.checkout_revenue_amount(base, host._int_now(), false, host._checkout_rush_bonus_now())
	var game: Node = host._game()
	if game != null:
		game._on_paid(amount, from_elite, host.seat_id, host, false, nxt, true)
	else:
		host.paid.emit(amount)
	SfxBus.play("sfx_checkout_cash_pop2")
	host.log_line.emit(Loc.t("log.player.senior_dual", [amount]))
	host._spawn_dollar()
	if nxt.has_method("finish_paid"):
		nxt.finish_paid()
	if reg != null and is_instance_valid(reg) and reg.has_method("dequeue"):
		reg.dequeue(nxt)
