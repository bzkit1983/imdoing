extends RefCounted
## Task row formatting shared by HUD task block and pause task detail list.

const TaskTracker = preload("res://scripts/session/task_tracker.gd")


static func hud_task_name(row: Dictionary) -> String:
	var label := String(row.get("name", ""))
	if label == "":
		var key := String(row.get("name_key", row.get("loc_key", "")))
		label = Loc.t(key) if key != "" else String(row.get("id", ""))
	return label


static func pause_task_name(row: Dictionary) -> String:
	var name := String(row.get("name", ""))
	if name == "":
		name = String(row.get("id", "?"))
	return name


static func row_mark(row: Dictionary) -> String:
	var st := String(row.get("status", "active"))
	var unwired := bool(row.get("unwired", false))
	return TaskTracker.status_mark(st, unwired)


static func row_progress(row: Dictionary) -> String:
	return TaskTracker.progress_text(
		String(row.get("op", ">=")),
		int(row.get("current", 0)),
		int(row.get("target", 0)),
		String(row.get("status", "active"))
	)


static func hud_status_block(rows: Array) -> String:
	if rows.is_empty():
		return ""
	var lines: PackedStringArray = PackedStringArray()
	lines.append(Loc.t("hud.tasks_header"))
	for row in rows:
		if not (row is Dictionary):
			continue
		var rd := row as Dictionary
		var st := String(rd.get("status", "active"))
		var unwired := bool(rd.get("unwired", false))
		var mark := row_mark(rd)
		var label := hud_task_name(rd)
		if unwired:
			lines.append("%s %s (%s)" % [mark, label, Loc.t("hud.tasks_unwired")])
			continue
		var prog := row_progress(rd)
		if st == "done":
			lines.append("%s %s %s %s" % [mark, label, prog, Loc.t("hud.tasks_done")])
		else:
			lines.append("%s %s %s" % [mark, label, prog])
	return "\n".join(lines)


static func pause_task_row(row: Dictionary) -> String:
	var st := String(row.get("status", "active"))
	var unwired := bool(row.get("unwired", false))
	var mark := row_mark(row)
	var name := pause_task_name(row)
	var desc := String(row.get("desc", ""))
	var prog := row_progress(row)
	if unwired:
		return Loc.t("prep.tasks.row_unwired", [mark, name])
	if desc == "":
		if st == "done":
			return Loc.t("prep.tasks.row_done_nodesc", [mark, name, prog])
		return Loc.t("prep.tasks.row_nodesc", [mark, name, prog])
	if st == "done":
		return Loc.t("prep.tasks.row_done", [mark, name, desc, prog])
	return Loc.t("prep.tasks.row", [mark, name, desc, prog])