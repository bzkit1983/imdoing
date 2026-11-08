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
	guest_xp_line = "\n訪客經驗 +%d　%s" % [shared_xp, gnote]
	if host_grade != 0:
		guest_xp_line += "\n支援別店評價 %+d　現 %d" % [
			host_grade,
			int(SeatTable.guest_stats.support_rating) if "support_rating" in SeatTable.guest_stats else 0,
		]
	if SeatTable.guest_slot_index >= 0:
		var GuestSlots = preload("res://scripts/session/guest_slots.gd")
		var store = GuestSlots.create()
		store.set_sheet(SeatTable.guest_slot_index, SeatTable.guest_stats)
		var gerr: String = store.save_to_disk()
		if gerr != "":
			guest_xp_line += "（訪客存檔失敗：" + gerr + "）"
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
	var body := "%s　%s\n營業額 $%d　入帳後資金 $%d\n進貨成本 $%d\n成功收銀 %d　生氣離開 %d\n被偷 %d 件 $%d　抓住 %d／逃走 %d\n%s\n%s" % [
		head, loss_label, revenue, money, spent, served, angry_left,
		stolen_count, stolen_value, thieves_caught, thieves_escaped,
		xp_line, save_line,
	]
	if grade_line != "":
		body += "\n" + grade_line
	body += "\n按 J／A 返回準備"
	return body
