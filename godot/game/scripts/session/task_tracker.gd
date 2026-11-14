extends RefCounted
## Per-seat ops task bag for one shop run (tasksystem.md).

const TaskCatalog = preload("res://scripts/session/task_catalog.gd")

signal changed

## seat -> Array[Dictionary] runtime rows:
## { task, current, status: active|done|failed|unwired, started_day }
var bags: Dictionary = {}
var day_index: int = 0
## Snapshot metrics evaluated at settle (sales_revenue, ops_rating, …).
var _settle_metrics: Dictionary = {}


func reset_seats(seat_count: int) -> void:
	for s in range(maxi(1, seat_count)):
		var key := str(s)
		if not bags.has(key):
			bags[key] = []


func clear_day_tasks() -> void:
	## Drop finished day-scope rows; keep accumulate active/unwired.
	for key in bags.keys():
		var kept: Array = []
		for row in bags[key]:
			if not (row is Dictionary):
				continue
			var st := String(row.get("status", "active"))
			var scope: Dictionary = (row.get("task", {}) as Dictionary).get("scope", {})
			var stype := String(scope.get("type", "day"))
			if stype == "day" and (st == "done" or st == "failed"):
				continue
			if stype == "day" and st == "active":
				## Fresh day bag replaces prior day actives.
				continue
			kept.append(row)
		bags[key] = kept


func load_from_save(saved: Dictionary) -> void:
	bags.clear()
	for key in saved.keys():
		var arr: Array = []
		var raw = saved[key]
		if raw is Array:
			for row in raw:
				if row is Dictionary:
					arr.append((row as Dictionary).duplicate(true))
		bags[str(key)] = arr


func to_save() -> Dictionary:
	var out := {}
	for key in bags.keys():
		var arr: Array = []
		for row in bags[key]:
			if row is Dictionary:
				arr.append((row as Dictionary).duplicate(true))
		out[str(key)] = arr
	return out


func attach_pack(pack: Dictionary, seat_indices: Array, started_day: int) -> void:
	var tasks = pack.get("tasks", [])
	if not (tasks is Array):
		return
	for seat in seat_indices:
		var key := str(int(seat))
		if not bags.has(key):
			bags[key] = []
		var bag: Array = bags[key]
		for t in tasks:
			if not (t is Dictionary):
				continue
			var task: Dictionary = (t as Dictionary).duplicate(true)
			var id := String(task.get("id", ""))
			if id != "" and _bag_has_id(bag, id):
				continue
			var metric := String(task.get("metric", ""))
			var status := "active"
			if not TaskCatalog.is_wired(metric):
				status = "unwired"
			bag.append({
				"task": task,
				"current": 0,
				"status": status,
				"started_day": started_day,
			})
		bags[key] = bag
	changed.emit()


func _bag_has_id(bag: Array, id: String) -> bool:
	for row in bag:
		if row is Dictionary and String((row.get("task", {}) as Dictionary).get("id", "")) == id:
			return true
	return false


func note_metric(seat: int, metric: String, delta: int = 1, filters: Dictionary = {}) -> void:
	if delta == 0:
		return
	var key := str(seat)
	if not bags.has(key):
		return
	var bag: Array = bags[key]
	var dirty := false
	for row in bag:
		if not (row is Dictionary):
			continue
		var st := String(row.get("status", "active"))
		if st != "active":
			continue
		var task: Dictionary = row.get("task", {})
		if String(task.get("metric", "")) != metric:
			continue
		if not _filters_match(task.get("filters", {}), filters):
			continue
		var op := String(task.get("op", ">="))
		var cur := int(row.get("current", 0)) + delta
		row["current"] = cur
		dirty = true
		_eval_row(row, op)
	if dirty:
		changed.emit()


func set_metric_absolute(seat: int, metric: String, value: int, filters: Dictionary = {}) -> void:
	var key := str(seat)
	if not bags.has(key):
		return
	var bag: Array = bags[key]
	var dirty := false
	for row in bag:
		if not (row is Dictionary):
			continue
		if String(row.get("status", "active")) != "active":
			continue
		var task: Dictionary = row.get("task", {})
		if String(task.get("metric", "")) != metric:
			continue
		if not _filters_match(task.get("filters", {}), filters):
			continue
		row["current"] = value
		dirty = true
		_eval_row(row, String(task.get("op", ">=")))
	if dirty:
		changed.emit()


func sync_absolute_for_all_seats(metric: String, value: int) -> void:
	for key in bags.keys():
		set_metric_absolute(int(key), metric, value)


func _filters_match(need: Variant, have: Dictionary) -> bool:
	if need == null or not (need is Dictionary):
		return true
	var n: Dictionary = need
	if n.is_empty():
		return true
	for k in n.keys():
		if not have.has(k):
			## Task has a filter the event didn't supply — only match if we don't care.
			## For shelve_count_sku, caller must pass sku.
			return false
		if str(have[k]) != str(n[k]):
			return false
	return true


func _eval_row(row: Dictionary, op: String) -> void:
	var task: Dictionary = row.get("task", {})
	var cur := int(row.get("current", 0))
	var target = task.get("target", 0)
	var tnum := int(target) if typeof(target) != TYPE_STRING else int(target)
	match op:
		">=":
			if cur >= tnum:
				row["status"] = "done"
		">":
			if cur > tnum:
				row["status"] = "done"
		"==":
			if cur == tnum:
				row["status"] = "done"
		"<":
			## Cap: fail when current reaches/exceeds target (impossible to stay below).
			if cur >= tnum:
				row["status"] = "failed"
		"<=":
			if cur > tnum:
				row["status"] = "failed"
		_:
			pass


func settle_day(
	current_day_index: int,
	settle_metrics: Dictionary = {},
) -> void:
	## Apply absolute day-end metrics (revenue, grade, shop_rating, ops_rating, shop_money).
	_settle_metrics = settle_metrics.duplicate(true)
	for key in bags.keys():
		var seat := int(key)
		for m in settle_metrics.keys():
			set_metric_absolute(seat, String(m), int(settle_metrics[m]))
	for key in bags.keys():
		var bag: Array = bags[key]
		for row in bag:
			if not (row is Dictionary):
				continue
			var st := String(row.get("status", "active"))
			if st != "active":
				continue
			var task: Dictionary = row.get("task", {})
			var metric := String(task.get("metric", ""))
			if not TaskCatalog.is_wired(metric):
				row["status"] = "unwired"
				continue
			var scope: Dictionary = task.get("scope", {})
			var stype := String(scope.get("type", "day"))
			var op := String(task.get("op", ">="))
			var cur := int(row.get("current", 0))
			var target := int(task.get("target", 0))
			var started := int(row.get("started_day", current_day_index))
			## Day-scope floor fail on close.
			if stype == "day":
				if _floor_met(op, cur, target):
					row["status"] = "done"
				elif _is_floor_op(op):
					row["status"] = "failed"
				## Cap still active and under target → success for "<".
				elif op == "<" or op == "<=":
					row["status"] = "done"
				continue
			## Accumulate: expire after max_days inclusive of started_day.
			if stype == "accumulate":
				var max_days := int(scope.get("max_days", 0))
				var days_elapsed := current_day_index - started + 1
				var window_over := max_days > 0 and days_elapsed >= max_days
				if _floor_met(op, cur, target):
					row["status"] = "done"
				elif window_over:
					if _is_floor_op(op):
						row["status"] = "failed"
					elif op == "<" or op == "<=":
						row["status"] = "done" if _cap_ok(op, cur, target) else "failed"
	changed.emit()


func _is_floor_op(op: String) -> bool:
	return op == ">=" or op == ">" or op == "=="


func _floor_met(op: String, cur: int, target: int) -> bool:
	match op:
		">=":
			return cur >= target
		">":
			return cur > target
		"==":
			return cur == target
		_:
			return false


func _cap_ok(op: String, cur: int, target: int) -> bool:
	if op == "<":
		return cur < target
	if op == "<=":
		return cur <= target
	return false


func hud_lines(seat: int, max_lines: int = 8) -> Array[Dictionary]:
	## Each: {id, text_key, current, target, status, unwired}
	var out: Array[Dictionary] = []
	var key := str(seat)
	if not bags.has(key):
		return out
	for row in bags[key]:
		if not (row is Dictionary):
			continue
		var task: Dictionary = row.get("task", {})
		var st := String(row.get("status", "active"))
		out.append({
			"id": String(task.get("id", "")),
			"loc_key": String(task.get("loc_key", "")),
			"current": int(row.get("current", 0)),
			"target": int(task.get("target", 0)),
			"op": String(task.get("op", ">=")),
			"status": st,
			"unwired": st == "unwired" or not TaskCatalog.is_wired(String(task.get("metric", ""))),
			"metric": String(task.get("metric", "")),
		})
		if out.size() >= max_lines:
			break
	return out


## Floor ops (>= / > / ==): show (current/target). Cap ops: same fraction vs limit.
static func progress_text(op: String, cur: int, tgt: int, status: String = "") -> String:
	var denom := maxi(tgt, 0)
	var numer := cur
	match op:
		">=", "==":
			if status == "done":
				numer = denom
			else:
				numer = clampi(cur, 0, denom)
		">":
			## Need strictly more than tgt → treat need as tgt+1.
			denom = maxi(tgt + 1, 1)
			if status == "done":
				numer = denom
			else:
				numer = clampi(cur, 0, denom)
		"<", "<=":
			numer = maxi(cur, 0)
		_:
			numer = clampi(cur, 0, denom) if denom > 0 else maxi(cur, 0)
	return "(%d/%d)" % [numer, denom]


static func status_mark(status: String, unwired: bool = false) -> String:
	if status == "done":
		return "✓"
	if status == "failed":
		return "✗"
	if unwired or status == "unwired":
		return "?"
	return "·"


func closeout_lines(seat: int = 0) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for row_info in hud_lines(seat, 32):
		var st := String(row_info.get("status", ""))
		var unwired := bool(row_info.get("unwired", false))
		var mark := status_mark(st, unwired)
		var key := String(row_info.get("loc_key", ""))
		var label := Loc.t(key) if key != "" else String(row_info.get("id", ""))
		var cur := int(row_info.get("current", 0))
		var tgt := int(row_info.get("target", 0))
		var op := String(row_info.get("op", ">="))
		var prog := progress_text(op, cur, tgt, st)
		if st == "done":
			lines.append("%s %s %s %s" % [mark, label, prog, Loc.t("hud.tasks_done")])
		else:
			lines.append("%s %s %s" % [mark, label, prog])
	return lines


func active_count(seat: int = 0) -> int:
	var n := 0
	for row_info in hud_lines(seat, 64):
		if String(row_info.get("status", "")) == "active":
			n += 1
	return n
