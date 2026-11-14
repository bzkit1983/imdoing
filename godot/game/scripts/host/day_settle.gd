extends RefCounted
## Closeout / settle helpers extracted from the day host.

const StateScript = preload("res://scripts/game_state.gd")


static func shared_xp_for_seats(
	seat_served: Array,
	seat_caught: Array,
	seat_cleaned: Array,
	seat_elite: Array,
	seat_n: int,
	skip_xp: int,
) -> Dictionary:
	## Returns {shared_xp, raws, raw_sum}.
	var n := maxi(1, seat_n)
	var raw_sum := 0
	var raws: Array[int] = []
	for s in n:
		var bonus := skip_xp if s == 0 else 0
		var raw := StateScript.raw_xp_for_counts(
			_seat_get(seat_served, s),
			_seat_get(seat_caught, s),
			_seat_get(seat_cleaned, s),
			_seat_get(seat_elite, s),
			bonus,
		)
		raws.append(raw)
		raw_sum += raw
	return {
		"shared_xp": int(raw_sum / n),
		"raws": raws,
		"raw_sum": raw_sum,
	}


static func _seat_get(arr: Array, seat: int) -> int:
	if seat < 0 or seat >= arr.size():
		return 0
	return int(arr[seat])


static func persist_guest_xp(shared_xp: int, host_grade: int = 0) -> Dictionary:
	## Applies shared XP + support_rating to SeatTable guest and saves selected slot.
	## Returns {guest_xp_line, guest_ups}.
	var guest_xp_line := ""
	var guest_ups := 0
	if not SeatTable.is_coop() or SeatTable.guest_stats == null:
		return {"guest_xp_line": guest_xp_line, "guest_ups": guest_ups}
	var guest_res: Dictionary = SeatTable.guest_stats.apply_xp_gain(shared_xp)
	guest_ups = int(guest_res.get("ups", 0))
	var gnote := String(guest_res.get("note", ""))
	if "support_rating" in SeatTable.guest_stats:
		SeatTable.guest_stats.support_rating = int(SeatTable.guest_stats.support_rating) + host_grade
	guest_xp_line = Loc.t("settle.guest_xp", [shared_xp, gnote])
	if host_grade != 0:
		guest_xp_line += Loc.t("settle.support_rating", [
			host_grade,
			int(SeatTable.guest_stats.support_rating) if "support_rating" in SeatTable.guest_stats else 0,
		])
	if SeatTable.guest_slot_index >= 0:
		var GuestSlots = preload("res://scripts/session/guest_slots.gd")
		var store = GuestSlots.create()
		store.set_sheet(SeatTable.guest_slot_index, SeatTable.guest_stats)
		var gerr: String = store.save_to_disk()
		if gerr != "":
			guest_xp_line += Loc.t("settle.guest_save_fail_prefix") + gerr + "）"
	return {"guest_xp_line": guest_xp_line, "guest_ups": guest_ups}


static func closeout_body(
	head: String,
	loss_label: String,
	revenue: int,
	money: int,
	spent: int,
	served: int,
	angry_left: int,
	stolen_count: int,
	stolen_value: int,
	thieves_caught: int,
	thieves_escaped: int,
	xp_line: String,
	save_line: String,
	grade_line: String = "",
) -> String:
	var body := Loc.t("settle.body", [
		head, loss_label, revenue, money, spent, served, angry_left,
		stolen_count, stolen_value, thieves_caught, thieves_escaped,
		xp_line, save_line,
	])
	if grade_line != "":
		body += "\n" + grade_line
	body += Loc.t("settle.back_hint")
	return body

## Unsold warehouse credit (F1 from demo.gd)

## Aggregate unsold pieces: shelves, floor, in-flight, player carry,
## clerk-held boxes, and guests who finished their list but have not paid.
static func collect_unsold_pieces(host) -> Dictionary:
	var out: Dictionary = {}
	DaySettle.add_pieces(out, DaySettle.collect_shelf_floor_pieces(host))
	DaySettle.add_pieces(out, DaySettle.collect_player_carry_pieces(host))
	DaySettle.add_pieces(out, DaySettle.collect_clerk_held_pieces(host))
	DaySettle.add_pieces(out, DaySettle.collect_unpaid_checkout_pieces(host))
	return out

static func add_pieces(dst: Dictionary, src: Dictionary) -> void:
	for sku_v in src.keys():
		var n := int(src[sku_v])
		if n <= 0:
			continue
		var sku := String(sku_v)
		dst[sku] = int(dst.get(sku, 0)) + n

static func collect_shelf_floor_pieces(host) -> Dictionary:
	var out: Dictionary = {}
	for s in host.shelves:
		if s == null or not is_instance_valid(s):
			continue
		## str() — String(null) throws in Godot 4 when Object.get misses.
		var sku := str(s.get("sku"))
		var n_v = s.get("count")
		var n := int(n_v) if n_v != null else 0
		if sku == "" or n <= 0:
			continue
		out[sku] = int(out.get(sku, 0)) + n
	if host._world == null:
		return out
	for c in host._world.get_children():
		if c == null or not is_instance_valid(c) or c.is_queued_for_deletion():
			continue
		var kind := str(c.get("kind"))
		if kind in ["universal_cannon", "shelf_cannon"]:
			for item in c.ammo:
				out[item] = int(out.get(item, 0)) + 1
			continue
		## Floor / Labels / Customers / FloatText lack kind — already using str() above.
		if kind != "drop" and kind != "drop_flight":
			continue
		var sku := str(c.get("sku"))
		var n_v = c.get("count")
		var n := int(n_v) if n_v != null else 0
		if sku == "" or n <= 0:
			continue
		out[sku] = int(out.get(sku, 0)) + n
	return out

static func collect_player_carry_pieces(host) -> Dictionary:
	var out: Dictionary = {}
	var seats: Array = host._players.duplicate()
	if seats.is_empty() and is_instance_valid(host._player):
		seats.append(host._player)
	for player in seats:
		if not is_instance_valid(player):
			continue
		for sku_v in player.inventory.items:
			var sku := str(sku_v)
			if sku != "":
				out[sku] = int(out.get(sku, 0)) + 1
	return out

static func collect_clerk_held_pieces(host) -> Dictionary:
	var out: Dictionary = {}
	if host._world != null:
		for c in host._world.get_children():
			if c == null or not is_instance_valid(c):
				continue
			if str(c.get("role")) != "restock":
				continue
			var sku := str(c.get("_box_sku"))
			var n := int(c.get("_box_n"))
			if sku == "" or n <= 0:
				continue
			out[sku] = int(out.get(sku, 0)) + n
	if host._customers == null:
		return out
	for c in host._customers.get_children():
		if c == null or not is_instance_valid(c):
			continue
		if not c.get("temp_clerk") or str(c.get("temp_role")) != "restock":
			continue
		var held := str(c.get("_temp_box_sku"))
		var pieces := int(c.get("_temp_box_n"))
		if held == "" or pieces <= 0:
			continue
		out[held] = int(out.get(held, 0)) + pieces
	return out

static func collect_unpaid_checkout_pieces(host) -> Dictionary:
	var out: Dictionary = {}
	if host._customers == null:
		return out
	for c in host._customers.get_children():
		if c == null or not is_instance_valid(c):
			continue
		if not c.has_method("unsold_checkout_cart"):
			continue
		var cart: Array = c.call("unsold_checkout_cart")
		for sku_v in cart:
			var sku := String(sku_v)
			if sku == "":
				continue
			out[sku] = int(out.get(sku, 0)) + 1
	return out

static func return_unsold_to_warehouse(host) -> void:
	var pieces := DaySettle.collect_unsold_pieces(host)
	if pieces.is_empty():
		return
	host.state.credit_unsold_pieces(pieces)
	DaySettle.clear_credited_unsold(host)
	host.sync_stock()


## Clear credited world / carry goods after warehouse credit so closeout
## does not leave orphan drops or double-count if somehow re-entered.

## Clear credited world / carry goods after warehouse credit so closeout
## does not leave orphan drops or double-count if somehow re-entered.
static func clear_credited_unsold(host) -> void:
	for s in host.shelves:
		if s == null or not is_instance_valid(s):
			continue
		if s.has_method("take_all"):
			s.call("take_all")
	var seats: Array = host._players.duplicate()
	if seats.is_empty() and is_instance_valid(host._player):
		seats.append(host._player)
	for player in seats:
		if is_instance_valid(player):
			player.inventory.clear()
	if host._customers != null:
		for c in host._customers.get_children():
			if c != null and is_instance_valid(c) and c.has_method("clear_unsold_checkout_cart"):
				c.call("clear_unsold_checkout_cart")
	if host._world == null:
		return
	var kill: Array[Node] = []
	for c in host._world.get_children():
		if c == null or not is_instance_valid(c):
			continue
		## Mixed world children: String(null) on missing kind aborts the sweep.
		var kind := str(c.get("kind"))
		if kind in ["universal_cannon", "shelf_cannon"]:
			c.ammo.clear()
			c.dismiss()
			continue
		if kind == "drop" or kind == "drop_flight":
			kill.append(c)
			continue
		if str(c.get("role")) == "restock":
			c.set("_box_n", 0)
			c.set("_box_sku", "")
	for c in kill:
		c.queue_free()
