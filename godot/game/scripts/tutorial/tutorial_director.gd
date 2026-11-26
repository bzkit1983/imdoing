extends Node
## Drives tutorial lessons: explain modal, forced steps, hard gates, HUD rows.

const Catalog = preload("res://scripts/tutorial/tutorial_catalog.gd")
const ModalScene = preload("res://scenes/tutorial_modal.tscn")

signal gate_changed
signal progress_changed

var state = null ## GameState
var _phase: String = "" ## prep | ops
var _prep_page: String = "" ## last prep UI page from consider_prep(page)
var _lesson: Dictionary = {}
var _step: Dictionary = {}
var _forced: bool = false
var _pages_acked: bool = false
var _step_current: int = 0
var _modal: CanvasLayer = null
var _busy_modal: bool = false
var _review_only: bool = false
var _metrics: Dictionary = {} ## metric → int (ops deltas this forced step)
var _runtime_flags: Dictionary = {} ## flag id → true (ops triggers; cleared per day／reset)
var _loadout_baseline: String = "" ## equip_skills: fingerprint at lesson start


func _ready() -> void:
	## Keep processing even if some other system pauses the tree (e.g. pause menu).
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(game_state) -> void:
	state = game_state


## Drop in-memory lesson／modal state. Call when scenario／save is wiped so
## tutorial_progress clear is not contradicted by a stale forced step.
func reset_runtime() -> void:
	close_modal_if_open()
	_phase = ""
	_prep_page = ""
	_lesson = {}
	_step = {}
	_forced = false
	_pages_acked = false
	_step_current = 0
	_metrics.clear()
	_runtime_flags.clear()
	_loadout_baseline = ""
	_busy_modal = false
	_review_only = false
	gate_changed.emit()
	progress_changed.emit()


## Call at ops day start before dirt seed so flags are re-armed by that day's spawns.
func clear_runtime_flags() -> void:
	_runtime_flags.clear()


## Raise a runtime flag for `when: "flag"` lessons. Does not clear metrics.
func notify_flag(flag: String) -> void:
	if flag == "":
		return
	_runtime_flags[flag] = true
	if _phase != "ops":
		return
	## Rating lesson: first guest → perfect-deliver tip while forced step stays active.
	if _try_rating_perfect_deliver_tip(flag):
		return
	if _busy_modal or has_forced_step():
		return
	_try_start_next("ops")


func has_forced_step() -> bool:
	return _forced and not _review_only and not _lesson.is_empty()


func is_modal_open() -> bool:
	return _modal != null and is_instance_valid(_modal) and _modal.is_open()


func close_modal_if_open() -> void:
	if _modal != null and is_instance_valid(_modal) and _modal.is_open():
		_modal.close_modal(false)
	_busy_modal = false
	_review_only = false
	_disconnect_modal_signals()


func blocks_open_day() -> bool:
	return has_forced_step() and (_phase == "prep" or String(_lesson.get("phase", "")) in ["prep", "either"])


func blocks_settle() -> bool:
	if not has_forced_step():
		return false
	## Finish-day style lessons must allow settle to complete their own step.
	if bool(_lesson.get("allow_settle", false)):
		return false
	return _phase == "ops" or String(_lesson.get("phase", "")) in ["ops", "either"]


## Prep soft-lock dict while a forced prep step is active; empty = no restrict.
func prep_restrict() -> Dictionary:
	if not has_forced_step():
		return {}
	if _phase != "prep" and String(_lesson.get("phase", "")) not in ["prep", "either"]:
		return {}
	var raw = _lesson.get("prep_restrict", {})
	return raw if raw is Dictionary else {}


func prep_hub_target_locked(hub_key: String, allow_field: String) -> bool:
	var r := prep_restrict()
	if r.is_empty():
		return false
	var allow = r.get(allow_field, [])
	if not (allow is Array) or allow.is_empty():
		return false
	return not allow.has(hub_key)


func prep_page_allowed(page: String) -> bool:
	var r := prep_restrict()
	if r.is_empty():
		return true
	var allow = r.get("pages_allow", [])
	if not (allow is Array) or allow.is_empty():
		return true
	return allow.has(page)


## Empty = allowed. Otherwise a Loc key reason (caller formats popup).
func furniture_buy_block_reason(type: String) -> String:
	var r := prep_restrict()
	if r.is_empty():
		return ""
	var caps = r.get("furniture_owned_cap", {})
	if not (caps is Dictionary) or caps.is_empty():
		return ""
	if not caps.has(type):
		return "tut.prep.restrict.furn_denied"
	if state == null:
		return ""
	var cap := int(caps[type])
	if int(state.owned.get(type, 0)) >= cap:
		return "tut.prep.restrict.furn_cap"
	return ""


func furniture_buy_cap(type: String) -> int:
	var r := prep_restrict()
	var caps = r.get("furniture_owned_cap", {})
	if caps is Dictionary and caps.has(type):
		return int(caps[type])
	return -1


## Empty allowlist = no SKU soft-lock. Otherwise only listed skus may develop／buy.
func goods_sku_allowed(sku: String) -> bool:
	var r := prep_restrict()
	if r.is_empty():
		return true
	var allow = r.get("goods_sku_allow", [])
	if not (allow is Array) or allow.is_empty():
		return true
	return allow.has(sku)


## Empty = allowed. Otherwise a Loc key reason.
func goods_sku_block_reason(sku: String) -> String:
	if goods_sku_allowed(sku):
		return ""
	return "tut.prep.restrict.sku_denied"


func active_lesson_id() -> String:
	return String(_lesson.get("id", ""))


func active_step_id() -> String:
	return String(_step.get("id", ""))


## Call when entering prep UI or after state changes that may complete a prep step.
## Pass the current prep page so lessons with trigger.prep_page only begin there.
func consider_prep(page: String = "") -> void:
	_phase = "prep"
	if page != "":
		_prep_page = page
	if _busy_modal:
		return
	if has_forced_step() and String(_lesson.get("phase", "")) in ["prep", "either"]:
		_eval_active_step()
		return
	_try_start_next("prep")


## Call after ops day tasks are set up.
func consider_ops() -> void:
	_phase = "ops"
	_metrics.clear()
	if _busy_modal:
		return
	_try_start_next("ops")


func notify_prep_state_changed() -> void:
	if _phase != "prep":
		return
	if has_forced_step():
		_eval_active_step()


func note_metric(metric: String, delta: int = 1, filters: Dictionary = {}) -> void:
	if not has_forced_step() or _phase != "ops":
		return
	if delta == 0:
		return
	var cond: Dictionary = _step.get("condition", {})
	if String(cond.get("metric", "")) != metric:
		return
	if not _filters_match(cond.get("filters", {}), filters):
		return
	var key := metric
	_metrics[key] = int(_metrics.get(key, 0)) + delta
	_eval_active_step()
	progress_changed.emit()


func sync_metric_absolute(metric: String, value: int) -> void:
	if not has_forced_step() or _phase != "ops":
		return
	var cond: Dictionary = _step.get("condition", {})
	if String(cond.get("metric", "")) != metric:
		return
	_metrics[metric] = value
	_eval_active_step()
	progress_changed.emit()


func hud_lines() -> Array:
	if not has_forced_step() or not _pages_acked:
		return []
	var cond: Dictionary = _step.get("condition", {})
	var ops: Dictionary = _lesson.get("ops_task", {})
	var name := Loc.t(String(ops.get("name_key", "tut.task.fallback_name")))
	var desc := Loc.t(String(ops.get("desc_key", "tut.task.fallback_desc")))
	var cur := _current_for_condition(cond)
	var target := int(cond.get("target", 0))
	var op := String(cond.get("op", ">="))
	return [{
		"id": active_step_id(),
		"name": name,
		"desc": desc,
		"status": "active",
		"unwired": false,
		"op": op,
		"current": cur,
		"target": target,
		"tutorial": true,
	}]


func open_review(lesson_id: String) -> void:
	var lesson := Catalog.lesson_by_id(lesson_id)
	if lesson.is_empty():
		return
	if state != null and state.tutorial_status(lesson_id) != "done":
		return
	_review_only = true
	_busy_modal = true
	_ensure_modal()
	if not _modal.finished.is_connected(_on_review_finished):
		_modal.finished.connect(_on_review_finished)
	if not _modal.cancelled.is_connected(_on_review_finished):
		_modal.cancelled.connect(_on_review_finished)
	_modal.open_pages(lesson.get("pages", []), true)


func _on_review_finished() -> void:
	_disconnect_modal_signals()
	_busy_modal = false
	_review_only = false


func _try_start_next(phase: String) -> void:
	if state == null:
		return
	if has_forced_step() or _busy_modal:
		return
	for lesson in Catalog.lessons_for_phase(phase):
		var id := String(lesson.get("id", ""))
		if id == "":
			continue
		var st: String = state.tutorial_status(id)
		if st == "done":
			continue
		if not _trigger_ok(lesson, phase):
			continue
		if st == "active":
			var row: Dictionary = state.tutorial_row(id)
			## prep_page only gates begin / unacked pages; forced step may resume anywhere.
			if not bool(row.get("pages_acked", false)) and not _prep_page_allows_start(lesson):
				continue
			_resume_lesson(lesson)
		else:
			if not _prep_page_allows_start(lesson):
				continue
			_begin_lesson(lesson)
		return


## Lessons with trigger.prep_page may only open explain pages on that prep page.
func _prep_page_allows_start(lesson: Dictionary) -> bool:
	var trig: Dictionary = lesson.get("trigger", {})
	if not trig.has("prep_page"):
		return true
	return _prep_page == String(trig.get("prep_page", ""))


func _resume_lesson(lesson: Dictionary) -> void:
	_lesson = lesson.duplicate(true)
	_metrics.clear()
	var id := active_lesson_id()
	_ensure_lesson_prereqs(id)
	_capture_equip_skills_baseline(id, false)
	var row: Dictionary = state.tutorial_row(id)
	_pages_acked = bool(row.get("pages_acked", false))
	if not _pages_acked:
		_begin_lesson(lesson)
		return
	var step_id := String(row.get("step_id", ""))
	var steps: Array = _lesson.get("steps", [])
	steps.sort_custom(func(a, b) -> bool:
		return int(a.get("order", 0)) < int(b.get("order", 0))
	)
	var found: Dictionary = {}
	for s in steps:
		if String(s.get("id", "")) == step_id:
			found = s
			break
	if found.is_empty() and not steps.is_empty():
		found = steps[0]
	if found.is_empty():
		_complete_lesson()
		return
	_activate_step(found)


## H2: skip remaining campaign from modal／offer. Marks all lessons done + persists.
func skip_campaign() -> void:
	if state == null:
		return
	close_modal_if_open()
	state.mark_tutorial_skipped()
	reset_runtime()
	progress_changed.emit()
	gate_changed.emit()


func _trigger_ok(lesson: Dictionary, phase: String) -> bool:
	if state != null and bool(state.tutorial_skipped):
		return false
	var trig: Dictionary = lesson.get("trigger", {})
	var when := String(trig.get("when", "first_unseen"))
	var requires = trig.get("requires_done", [])
	if requires is Array:
		for rid in requires:
			if state.tutorial_status(String(rid)) != "done":
				return false
	match when:
		"scenario":
			if state.scenario != int(trig.get("scenario", -1)):
				return false
			if trig.has("day_index") and phase == "ops":
				if int(state.day_index) != int(trig.get("day_index", 0)):
					return false
			return true
		"day_index":
			if phase != "ops":
				return false
			return int(state.day_index) == int(trig.get("day_index", 0))
		"flag":
			var flag_id := String(trig.get("flag", ""))
			if flag_id == "" or not bool(_runtime_flags.get(flag_id, false)):
				return false
			if trig.has("scenario") and state.scenario != int(trig.get("scenario", -1)):
				return false
			if trig.has("day_index") and phase == "ops":
				if int(state.day_index) != int(trig.get("day_index", 0)):
					return false
			return true
		_:
			## first_unseen: any unseen lesson for phase (content will tighten triggers).
			return state.tutorial_status(String(lesson.get("id", ""))) != "done"


func _begin_lesson(lesson: Dictionary) -> void:
	_lesson = lesson.duplicate(true)
	_step = {}
	_forced = false
	_pages_acked = false
	_step_current = 0
	_metrics.clear()
	var id := active_lesson_id()
	_ensure_lesson_prereqs(id)
	state.set_tutorial_row(id, {
		"status": "active",
		"step_id": "",
		"pages_acked": false,
	})
	_capture_equip_skills_baseline(id, true)
	_busy_modal = true
	_ensure_modal()
	_disconnect_modal_signals()
	if not _modal.finished.is_connected(_on_pages_finished):
		_modal.finished.connect(_on_pages_finished)
	if not _modal.skip_requested.is_connected(_on_skip_requested):
		_modal.skip_requested.connect(_on_skip_requested)
	_modal.open_pages(_lesson.get("pages", []), false)
	gate_changed.emit()
	progress_changed.emit()


func _on_skip_requested() -> void:
	_disconnect_modal_signals()
	_busy_modal = false
	skip_campaign()
	## Persist immediately so a crash mid-prep still honors skip.
	if state != null and state.has_method("save_to_disk"):
		state.save_to_disk()


func _on_pages_finished() -> void:
	_disconnect_modal_signals()
	_busy_modal = false
	_pages_acked = true
	var id := active_lesson_id()
	var row: Dictionary = state.tutorial_row(id)
	row["status"] = "active"
	row["pages_acked"] = true
	state.set_tutorial_row(id, row)
	_enter_first_step()


func _enter_first_step() -> void:
	var steps: Array = _lesson.get("steps", [])
	if steps.is_empty():
		_complete_lesson()
		return
	steps.sort_custom(func(a, b) -> bool:
		return int(a.get("order", 0)) < int(b.get("order", 0))
	)
	_activate_step(steps[0])


func _activate_step(step: Dictionary) -> void:
	_step = step.duplicate(true)
	_forced = true
	_metrics.clear()
	var id := active_lesson_id()
	var row: Dictionary = state.tutorial_row(id)
	row["status"] = "active"
	row["step_id"] = String(_step.get("id", ""))
	row["pages_acked"] = true
	state.set_tutorial_row(id, row)
	_maybe_attach_rating_practice_pack(id)
	## Prep may already satisfy (e.g. furniture placed before reading).
	_eval_active_step()
	## Guest may have entered during explain pages — tip once forced step is live.
	if bool(_runtime_flags.get("guest_present", false)):
		_try_rating_perfect_deliver_tip("guest_present")
	gate_changed.emit()
	progress_changed.emit()


## tut.ops.rating: soft-attach OP-TUT-001 for HUD practice (not task_test_mode).
func _maybe_attach_rating_practice_pack(id: String) -> void:
	if id != "tut.ops.rating":
		return
	var host := get_parent()
	if host != null and host.has_method("attach_tutorial_practice_pack"):
		host.attach_tutorial_practice_pack("OP-TUT-001")


## During tut.ops.rating forced step: one-shot perfect-deliver tip on first guest.
func _try_rating_perfect_deliver_tip(flag: String) -> bool:
	if flag != "guest_present":
		return false
	if active_lesson_id() != "tut.ops.rating":
		return false
	if not has_forced_step() or _busy_modal or _review_only:
		return false
	if state == null:
		return false
	var row: Dictionary = state.tutorial_row("tut.ops.rating")
	if bool(row.get("perfect_deliver_tip_acked", false)):
		return false
	var tip_pages = _lesson.get("perfect_deliver_pages", [])
	if not (tip_pages is Array) or tip_pages.is_empty():
		return false
	_show_perfect_deliver_tip(tip_pages)
	return true


func _show_perfect_deliver_tip(pages: Array) -> void:
	_busy_modal = true
	_ensure_modal()
	_disconnect_modal_signals()
	if not _modal.finished.is_connected(_on_perfect_deliver_tip_acked):
		_modal.finished.connect(_on_perfect_deliver_tip_acked)
	if not _modal.cancelled.is_connected(_on_perfect_deliver_tip_acked):
		_modal.cancelled.connect(_on_perfect_deliver_tip_acked)
	## review=true → last button is「關閉」; does not complete the lesson.
	_modal.open_pages(pages, true)


func _on_perfect_deliver_tip_acked() -> void:
	_disconnect_modal_signals()
	_busy_modal = false
	if state != null and active_lesson_id() == "tut.ops.rating":
		var row: Dictionary = state.tutorial_row("tut.ops.rating")
		row["perfect_deliver_tip_acked"] = true
		row["status"] = "active"
		row["pages_acked"] = true
		row["step_id"] = String(_step.get("id", ""))
		state.set_tutorial_row("tut.ops.rating", row)
	gate_changed.emit()
	progress_changed.emit()


func _eval_active_step() -> void:
	if not _forced or _step.is_empty():
		return
	var cond: Dictionary = _step.get("condition", {})
	if not _condition_met(cond):
		return
	_advance_after_step()


func _advance_after_step() -> void:
	var next_id := String(_step.get("next", ""))
	if next_id == "":
		_complete_lesson()
		return
	var steps: Array = _lesson.get("steps", [])
	for s in steps:
		if String(s.get("id", "")) == next_id:
			_activate_step(s)
			return
	_complete_lesson()


func _complete_lesson() -> void:
	var id := active_lesson_id()
	var complete_pages = _lesson.get("complete_pages", [])
	if id != "" and state != null:
		state.mark_tutorial_done(id)
		var err: String = state.save_to_disk()
		if err != "":
			push_warning("tutorial save failed: %s" % err)
	_lesson = {}
	_step = {}
	_forced = false
	_pages_acked = false
	_metrics.clear()
	_loadout_baseline = ""
	gate_changed.emit()
	progress_changed.emit()
	## After shelve, allow dirt so clean can trigger on dirt_present.
	if id == "tut.ops.shelve":
		var host := get_parent()
		if host != null and host.has_method("seed_dirt_if_tutorial_allows"):
			host.call_deferred("seed_dirt_if_tutorial_allows")
	## After checkout, seed a thief so catch lesson can arm on thief_present.
	if id == "tut.ops.checkout":
		var host2 := get_parent()
		if host2 != null and host2.has_method("seed_thief_for_tutorial"):
			host2.call_deferred("seed_thief_for_tutorial")
	## Celebration modal before chaining the next lesson.
	_show_complete_modal(complete_pages if complete_pages is Array else [])


func _show_complete_modal(pages: Array) -> void:
	var show_pages: Array = pages.duplicate() if not pages.is_empty() else [{
		"title_key": "tut.complete.title",
		"body_key": "tut.complete.body",
		"image_path": "",
	}]
	_busy_modal = true
	_ensure_modal()
	_disconnect_modal_signals()
	if not _modal.finished.is_connected(_on_complete_acked):
		_modal.finished.connect(_on_complete_acked)
	if not _modal.cancelled.is_connected(_on_complete_acked):
		_modal.cancelled.connect(_on_complete_acked)
	## review=true → last button is「關閉」.
	_modal.open_pages(show_pages, true)


func _on_complete_acked() -> void:
	_disconnect_modal_signals()
	_busy_modal = false
	## Chain next lesson in same phase if any.
	if _phase == "prep":
		call_deferred("consider_prep")
	elif _phase == "ops":
		call_deferred("consider_ops")


## Prep chains that auto top-up cash so a purchase／develop can complete.
const PURCHASE_SUBSIDY_LESSONS := [
	"tut.prep.develop_goods",
	"tut.prep.buy_new_goods",
	"tut.prep.buy_new_furn",
	"tut.prep.buy_cashier",
]


func purchase_subsidy_active() -> bool:
	if not has_forced_step():
		return false
	return active_lesson_id() in PURCHASE_SUBSIDY_LESSONS


## If subsidy is active and cash is short, grant the difference. Returns amount granted.
func subsidize_for_cost(cost: int) -> int:
	if not purchase_subsidy_active() or state == null:
		return 0
	cost = maxi(0, cost)
	if state.money >= cost:
		return 0
	if state.has_method("ensure_min_money"):
		return int(state.ensure_min_money(cost))
	var granted := cost - int(state.money)
	state.money = cost
	return granted


## Lesson-start seeds so unlock／budget gates match the teachable surface.
func _ensure_lesson_prereqs(id: String) -> void:
	if state == null:
		return
	## allocate_stats: LV2 (+ unspent) so spend-all is teachable.
	if id == "tut.prep.allocate_stats":
		if state.has_method("ensure_min_level"):
			state.ensure_min_level(2)
		return
	## develop_goods: content gates for snack／drink／凍櫃家具；資金不足則補到 $3000.
	if id == "tut.prep.develop_goods":
		if state.has_method("unlock_sku"):
			state.unlock_sku("snack")
			state.unlock_sku("drink")
		if state.has_method("unlock_furniture"):
			state.unlock_furniture("shelf_frozen_4")
			state.unlock_furniture("restock_frozen")
		if state.has_method("ensure_min_money"):
			state.ensure_min_money(3000)
		return
	## buy_new_furn: ensure dry＋frozen 4-slot lines are purchasable.
	if id == "tut.prep.buy_new_furn":
		if state.has_method("unlock_furniture"):
			state.unlock_furniture("cashier")
			state.unlock_furniture("restock_dry")
			state.unlock_furniture("shelf_dry_4")
			state.unlock_furniture("shelf_frozen_4")
			state.unlock_furniture("restock_frozen")
		if state.has_method("ensure_min_money"):
			state.ensure_min_money(2000)
		return
	## buy_cashier: scale 2 so HIRE_CAP allows 1 clerk；cash for second cashier.
	if id == "tut.prep.buy_cashier":
		if state.has_method("ensure_min_shop_scale"):
			state.ensure_min_shop_scale(2)
		if state.has_method("ensure_min_money"):
			state.ensure_min_money(1000)


## tut.prep.equip_skills: snapshot loadout so any edit can complete the step.
func _capture_equip_skills_baseline(id: String, force: bool) -> void:
	if id != "tut.prep.equip_skills":
		return
	if state == null:
		return
	if not force:
		var row: Dictionary = state.tutorial_row(id)
		var saved := String(row.get("loadout_baseline", ""))
		if saved != "":
			_loadout_baseline = saved
			return
	_loadout_baseline = _skill_loadout_fingerprint()
	var row2: Dictionary = state.tutorial_row(id)
	row2["loadout_baseline"] = _loadout_baseline
	state.set_tutorial_row(id, row2)


func _skill_loadout_fingerprint() -> String:
	if state == null:
		return ""
	var sets_out: Array = []
	var raw_sets = state.skill_sets
	if raw_sets is Array:
		for pack in raw_sets:
			if not (pack is Dictionary):
				continue
			var p: Dictionary = pack
			var slots_out: Array = []
			var slots = p.get("slots", [])
			if slots is Array:
				for s in slots:
					slots_out.append(String(s))
			var levels_out: Dictionary = {}
			var levels = p.get("levels", {})
			if levels is Dictionary:
				var keys: Array = levels.keys()
				keys.sort()
				for k in keys:
					levels_out[String(k)] = int(levels[k])
			sets_out.append({
				"name": String(p.get("name", "")),
				"slots": slots_out,
				"ult_id": String(p.get("ult_id", "")),
				"levels": levels_out,
			})
	return JSON.stringify({
		"index": int(state.skill_set_index),
		"sets": sets_out,
	})


func _condition_met(cond: Dictionary) -> bool:
	var cur := _current_for_condition(cond)
	var target := int(cond.get("target", 0))
	var op := String(cond.get("op", ">="))
	return _cmp(cur, op, target)


func _current_for_condition(cond: Dictionary) -> int:
	var metric := String(cond.get("metric", ""))
	match metric:
		"placed_count":
			if state == null:
				return 0
			return state.placed.size()
		"owned_furniture_kinds":
			if state == null:
				return 0
			return state.owned.size()
		"cashier_count":
			if state == null or not state.has_method("cashier_count"):
				return 0
			return int(state.cashier_count())
		"clerk_count":
			if state == null:
				return 0
			return state.clerks.size()
		"open_ready":
			## 1 when GameState.open_blockers() is empty (can start the day).
			if state == null or not state.has_method("open_blockers"):
				return 0
			var blocks: PackedStringArray = state.open_blockers()
			return 1 if blocks.is_empty() else 0
		"stock_pieces":
			## Warehouse pieces for filters.sku (prep buy lessons).
			if state == null:
				return 0
			var filters = cond.get("filters", {})
			var sku := ""
			if filters is Dictionary:
				sku = String(filters.get("sku", ""))
			if sku == "":
				return 0
			return int(state.stock.get(sku, 0))
		"unspent":
			if state == null:
				return 0
			return int(state.unspent)
		"loadout_changed":
			## 1 when skill_sets／skill_set_index differ from lesson-start fingerprint.
			if state == null or _loadout_baseline == "":
				return 0
			return 1 if _skill_loadout_fingerprint() != _loadout_baseline else 0
		"developed_has":
			## 1 when filters.sku is in state.developed.
			if state == null:
				return 0
			var dev_filters = cond.get("filters", {})
			var dev_sku := ""
			if dev_filters is Dictionary:
				dev_sku = String(dev_filters.get("sku", ""))
			if dev_sku == "":
				return 0
			return 1 if state.developed.has(dev_sku) else 0
		"owned_qty":
			## Owned furniture count for filters.type.
			if state == null:
				return 0
			var own_filters = cond.get("filters", {})
			var own_type := ""
			if own_filters is Dictionary:
				own_type = String(own_filters.get("type", ""))
			if own_type == "":
				return 0
			return int(state.owned.get(own_type, 0))
		"unplaced_qty":
			## Owned−placed for filters.type, or sum of all owned types when no filter.
			if state == null or not state.has_method("unplaced"):
				return 0
			var up_filters = cond.get("filters", {})
			var up_type := ""
			if up_filters is Dictionary:
				up_type = String(up_filters.get("type", ""))
			if up_type != "":
				return int(state.unplaced(up_type))
			var total_up := 0
			for t in state.owned.keys():
				total_up += int(state.unplaced(String(t)))
			return total_up
		"restock_defaults_distinct":
			## 1 when every placed restock has a non-empty default_sku and all are unique.
			if state == null or not state.has_method("is_restock_type"):
				return 0
			var seen_defs: Dictionary = {}
			var any_restock := false
			for it in state.placed:
				if not (it is Dictionary):
					continue
				var rt := String(it.get("type", ""))
				if not state.is_restock_type(rt):
					continue
				any_restock = true
				var def := String(it.get("default_sku", ""))
				if def == "" or seen_defs.has(def):
					return 0
				seen_defs[def] = true
			return 1 if any_restock else 0
		_:
			return int(_metrics.get(metric, 0))


func _cmp(cur: int, op: String, target: int) -> bool:
	match op:
		">":
			return cur > target
		">=":
			return cur >= target
		"==":
			return cur == target
		"<":
			return cur < target
		"<=":
			return cur <= target
		_:
			return cur >= target


func _filters_match(need, have: Dictionary) -> bool:
	if need == null or not (need is Dictionary):
		return true
	var req: Dictionary = need
	if req.is_empty():
		return true
	for k in req.keys():
		if not have.has(k):
			return false
		if str(have[k]) != str(req[k]):
			return false
	return true


func _ensure_modal() -> void:
	if _modal != null and is_instance_valid(_modal):
		return
	_modal = ModalScene.instantiate()
	add_child(_modal)


func _disconnect_modal_signals() -> void:
	if _modal == null or not is_instance_valid(_modal):
		return
	if _modal.finished.is_connected(_on_pages_finished):
		_modal.finished.disconnect(_on_pages_finished)
	if _modal.finished.is_connected(_on_review_finished):
		_modal.finished.disconnect(_on_review_finished)
	if _modal.cancelled.is_connected(_on_review_finished):
		_modal.cancelled.disconnect(_on_review_finished)
	if _modal.finished.is_connected(_on_complete_acked):
		_modal.finished.disconnect(_on_complete_acked)
	if _modal.cancelled.is_connected(_on_complete_acked):
		_modal.cancelled.disconnect(_on_complete_acked)
	if _modal.finished.is_connected(_on_perfect_deliver_tip_acked):
		_modal.finished.disconnect(_on_perfect_deliver_tip_acked)
	if _modal.cancelled.is_connected(_on_perfect_deliver_tip_acked):
		_modal.cancelled.disconnect(_on_perfect_deliver_tip_acked)
	if _modal.skip_requested.is_connected(_on_skip_requested):
		_modal.skip_requested.disconnect(_on_skip_requested)
