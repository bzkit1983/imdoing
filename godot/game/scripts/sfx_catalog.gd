extends RefCounted
## Alpha SFX catalog — IDs match docs/systemdesign/soundeffects.md.
## Assets: res://audio/sfx/<id>.wav (procedural placeholders; replace later).

## Each entry: { "id", "priority", "path", "group" }
const ENTRIES: Array[Dictionary] = [
	{"id": "sfx_box_drop_feet", "priority": "P0", "path": "res://audio/sfx/sfx_box_drop_feet.wav", "group": "box"},
	{"id": "sfx_box_land", "priority": "P0", "path": "res://audio/sfx/sfx_box_land.wav", "group": "box"},
	{"id": "sfx_box_pickup_floor", "priority": "P0", "path": "res://audio/sfx/sfx_box_pickup_floor.wav", "group": "box"},
	{"id": "sfx_box_pull", "priority": "P0", "path": "res://audio/sfx/sfx_box_pull.wav", "group": "box"},
	{"id": "sfx_box_shelf_toss", "priority": "P0", "path": "res://audio/sfx/sfx_box_shelf_toss.wav", "group": "box"},
	{"id": "sfx_box_toss", "priority": "P0", "path": "res://audio/sfx/sfx_box_toss.wav", "group": "box"},
	{"id": "sfx_checkout_cash_pop", "priority": "P0", "path": "res://audio/sfx/sfx_checkout_cash_pop.wav", "group": "checkout"},
	{"id": "sfx_checkout_circle_done", "priority": "P0", "path": "res://audio/sfx/sfx_checkout_circle_done.wav", "group": "checkout"},
	{"id": "sfx_checkout_dir_fail", "priority": "P0", "path": "res://audio/sfx/sfx_checkout_dir_fail.wav", "group": "checkout"},
	{"id": "sfx_checkout_dir_ok", "priority": "P0", "path": "res://audio/sfx/sfx_checkout_dir_ok.wav", "group": "checkout"},
	{"id": "sfx_clean_done", "priority": "P0", "path": "res://audio/sfx/sfx_clean_done.wav", "group": "clean"},
	{"id": "sfx_clean_scrub", "priority": "P0", "path": "res://audio/sfx/sfx_clean_scrub.wav", "group": "clean"},
	{"id": "sfx_fight_fail", "priority": "P0", "path": "res://audio/sfx/sfx_fight_fail.wav", "group": "fight"},
	{"id": "sfx_fight_grab", "priority": "P0", "path": "res://audio/sfx/sfx_fight_grab.wav", "group": "fight"},
	{"id": "sfx_fight_hit", "priority": "P0", "path": "res://audio/sfx/sfx_fight_hit.wav", "group": "fight"},
	{"id": "sfx_ko_guest_dash", "priority": "P0", "path": "res://audio/sfx/sfx_ko_guest_dash.wav", "group": "ko"},
	{"id": "sfx_ko_screen", "priority": "P0", "path": "res://audio/sfx/sfx_ko_screen.wav", "group": "ko"},
	{"id": "sfx_move_dash", "priority": "P0", "path": "res://audio/sfx/sfx_move_dash.wav", "group": "move"},
	{"id": "sfx_move_slip", "priority": "P0", "path": "res://audio/sfx/sfx_move_slip.wav", "group": "move"},
	{"id": "sfx_phase_close", "priority": "P0", "path": "res://audio/sfx/sfx_phase_close.wav", "group": "phase"},
	{"id": "sfx_shelf_stock_blocked", "priority": "P0", "path": "res://audio/sfx/sfx_shelf_stock_blocked.wav", "group": "shelf"},
	{"id": "sfx_shelf_stock_done", "priority": "P0", "path": "res://audio/sfx/sfx_shelf_stock_done.wav", "group": "shelf"},
	{"id": "sfx_skill_cast", "priority": "P0", "path": "res://audio/sfx/sfx_skill_cast.wav", "group": "skill"},
	{"id": "sfx_thief_dash_out", "priority": "P0", "path": "res://audio/sfx/sfx_thief_dash_out.wav", "group": "thief"},
	{"id": "sfx_thief_escape", "priority": "P0", "path": "res://audio/sfx/sfx_thief_escape.wav", "group": "thief"},
	{"id": "sfx_ui_deny", "priority": "P0", "path": "res://audio/sfx/sfx_ui_deny.wav", "group": "ui"},
	{"id": "sfx_ult_dir_fail", "priority": "P0", "path": "res://audio/sfx/sfx_ult_dir_fail.wav", "group": "ult"},
	{"id": "sfx_ult_dir_ok", "priority": "P0", "path": "res://audio/sfx/sfx_ult_dir_ok.wav", "group": "ult"},
	{"id": "sfx_ult_fundraise", "priority": "P0", "path": "res://audio/sfx/sfx_ult_fundraise.wav", "group": "ult"},
	{"id": "sfx_ult_the_world", "priority": "P0", "path": "res://audio/sfx/sfx_ult_the_world.wav", "group": "ult"},
	{"id": "sfx_ult_yes_my_lord", "priority": "P0", "path": "res://audio/sfx/sfx_ult_yes_my_lord.wav", "group": "ult"},
	{"id": "sfx_box_drop_aim", "priority": "P1", "path": "res://audio/sfx/sfx_box_drop_aim.wav", "group": "box"},
	{"id": "sfx_box_hit_guest_ok", "priority": "P1", "path": "res://audio/sfx/sfx_box_hit_guest_ok.wav", "group": "box"},
	{"id": "sfx_box_hit_guest_reject", "priority": "P1", "path": "res://audio/sfx/sfx_box_hit_guest_reject.wav", "group": "box"},
	{"id": "sfx_box_hit_thief", "priority": "P1", "path": "res://audio/sfx/sfx_box_hit_thief.wav", "group": "box"},
	{"id": "sfx_box_pull_fail", "priority": "P1", "path": "res://audio/sfx/sfx_box_pull_fail.wav", "group": "box"},
	{"id": "sfx_box_sku_open", "priority": "P1", "path": "res://audio/sfx/sfx_box_sku_open.wav", "group": "box"},
	{"id": "sfx_checkout_clerk", "priority": "P1", "path": "res://audio/sfx/sfx_checkout_clerk.wav", "group": "checkout"},
	{"id": "sfx_checkout_enter", "priority": "P1", "path": "res://audio/sfx/sfx_checkout_enter.wav", "group": "checkout"},
	{"id": "sfx_checkout_seq_done", "priority": "P1", "path": "res://audio/sfx/sfx_checkout_seq_done.wav", "group": "checkout"},
	{"id": "sfx_clean_start", "priority": "P1", "path": "res://audio/sfx/sfx_clean_start.wav", "group": "clean"},
	{"id": "sfx_early_close_ask", "priority": "P1", "path": "res://audio/sfx/sfx_early_close_ask.wav", "group": "early"},
	{"id": "sfx_guest_angry_leave", "priority": "P1", "path": "res://audio/sfx/sfx_guest_angry_leave.wav", "group": "guest"},
	{"id": "sfx_guest_dash_land", "priority": "P1", "path": "res://audio/sfx/sfx_guest_dash_land.wav", "group": "guest"},
	{"id": "sfx_loot_inplace", "priority": "P1", "path": "res://audio/sfx/sfx_loot_inplace.wav", "group": "loot"},
	{"id": "sfx_loot_scatter", "priority": "P1", "path": "res://audio/sfx/sfx_loot_scatter.wav", "group": "loot"},
	{"id": "sfx_move_foot_run", "priority": "P1", "path": "res://audio/sfx/sfx_move_foot_run.wav", "group": "move"},
	{"id": "sfx_move_foot_walk", "priority": "P1", "path": "res://audio/sfx/sfx_move_foot_walk.wav", "group": "move"},
	{"id": "sfx_move_stun", "priority": "P1", "path": "res://audio/sfx/sfx_move_stun.wav", "group": "move"},
	{"id": "sfx_phase_open", "priority": "P1", "path": "res://audio/sfx/sfx_phase_open.wav", "group": "phase"},
	{"id": "sfx_phase_restock", "priority": "P1", "path": "res://audio/sfx/sfx_phase_restock.wav", "group": "phase"},
	{"id": "sfx_shelf_stock_instant", "priority": "P1", "path": "res://audio/sfx/sfx_shelf_stock_instant.wav", "group": "shelf"},
	{"id": "sfx_skill_cd_deny", "priority": "P1", "path": "res://audio/sfx/sfx_skill_cd_deny.wav", "group": "skill"},
	{"id": "sfx_skill_menu_open", "priority": "P1", "path": "res://audio/sfx/sfx_skill_menu_open.wav", "group": "skill"},
	{"id": "sfx_skill_soothe", "priority": "P1", "path": "res://audio/sfx/sfx_skill_soothe.wav", "group": "skill"},
	{"id": "sfx_ui_cancel", "priority": "P1", "path": "res://audio/sfx/sfx_ui_cancel.wav", "group": "ui"},
	{"id": "sfx_ui_confirm", "priority": "P1", "path": "res://audio/sfx/sfx_ui_confirm.wav", "group": "ui"},
	{"id": "sfx_ui_level_up", "priority": "P1", "path": "res://audio/sfx/sfx_ui_level_up.wav", "group": "ui"},
	{"id": "sfx_ui_move", "priority": "P1", "path": "res://audio/sfx/sfx_ui_move.wav", "group": "ui"},
	{"id": "sfx_ui_pause_close", "priority": "P1", "path": "res://audio/sfx/sfx_ui_pause_close.wav", "group": "ui"},
	{"id": "sfx_ui_pause_open", "priority": "P1", "path": "res://audio/sfx/sfx_ui_pause_open.wav", "group": "ui"},
	{"id": "sfx_ui_place", "priority": "P1", "path": "res://audio/sfx/sfx_ui_place.wav", "group": "ui"},
	{"id": "sfx_ui_purchase", "priority": "P1", "path": "res://audio/sfx/sfx_ui_purchase.wav", "group": "ui"},
	{"id": "sfx_ult_prep", "priority": "P1", "path": "res://audio/sfx/sfx_ult_prep.wav", "group": "ult"},
	{"id": "sfx_ult_the_world_end", "priority": "P1", "path": "res://audio/sfx/sfx_ult_the_world_end.wav", "group": "ult"},
	{"id": "sfx_box_sku_cancel", "priority": "P2", "path": "res://audio/sfx/sfx_box_sku_cancel.wav", "group": "box"},
	{"id": "sfx_box_sku_confirm", "priority": "P2", "path": "res://audio/sfx/sfx_box_sku_confirm.wav", "group": "box"},
	{"id": "sfx_box_sku_move", "priority": "P2", "path": "res://audio/sfx/sfx_box_sku_move.wav", "group": "box"},
	{"id": "sfx_checkout_release_reset", "priority": "P2", "path": "res://audio/sfx/sfx_checkout_release_reset.wav", "group": "checkout"},
	{"id": "sfx_clean_cancel", "priority": "P2", "path": "res://audio/sfx/sfx_clean_cancel.wav", "group": "clean"},
	{"id": "sfx_clerk_pull", "priority": "P2", "path": "res://audio/sfx/sfx_clerk_pull.wav", "group": "clerk"},
	{"id": "sfx_clerk_stock", "priority": "P2", "path": "res://audio/sfx/sfx_clerk_stock.wav", "group": "clerk"},
	{"id": "sfx_dirt_spawn", "priority": "P2", "path": "res://audio/sfx/sfx_dirt_spawn.wav", "group": "dirt"},
	{"id": "sfx_guest_enter", "priority": "P2", "path": "res://audio/sfx/sfx_guest_enter.wav", "group": "guest"},
	{"id": "sfx_guest_paid_leave", "priority": "P2", "path": "res://audio/sfx/sfx_guest_paid_leave.wav", "group": "guest"},
	{"id": "sfx_guest_queue", "priority": "P2", "path": "res://audio/sfx/sfx_guest_queue.wav", "group": "guest"},
	{"id": "sfx_guest_take", "priority": "P2", "path": "res://audio/sfx/sfx_guest_take.wav", "group": "guest"},
	{"id": "sfx_guest_think", "priority": "P2", "path": "res://audio/sfx/sfx_guest_think.wav", "group": "guest"},
	{"id": "sfx_move_crowd", "priority": "P2", "path": "res://audio/sfx/sfx_move_crowd.wav", "group": "move"},
	{"id": "sfx_move_dirt_step", "priority": "P2", "path": "res://audio/sfx/sfx_move_dirt_step.wav", "group": "move"},
	{"id": "sfx_move_overcarry", "priority": "P2", "path": "res://audio/sfx/sfx_move_overcarry.wav", "group": "move"},
	{"id": "sfx_move_stamina_empty", "priority": "P2", "path": "res://audio/sfx/sfx_move_stamina_empty.wav", "group": "move"},
	{"id": "sfx_shelf_stock_loop", "priority": "P2", "path": "res://audio/sfx/sfx_shelf_stock_loop.wav", "group": "shelf"},
	{"id": "sfx_skill_menu_cancel", "priority": "P2", "path": "res://audio/sfx/sfx_skill_menu_cancel.wav", "group": "skill"},
	{"id": "sfx_skill_menu_move", "priority": "P2", "path": "res://audio/sfx/sfx_skill_menu_move.wav", "group": "skill"},
	{"id": "sfx_thief_spawn", "priority": "P2", "path": "res://audio/sfx/sfx_thief_spawn.wav", "group": "thief"},
	{"id": "sfx_ui_pickup_item", "priority": "P2", "path": "res://audio/sfx/sfx_ui_pickup_item.wav", "group": "ui"},
	{"id": "sfx_ui_rotate", "priority": "P2", "path": "res://audio/sfx/sfx_ui_rotate.wav", "group": "ui"},
	{"id": "sfx_ui_test_skip", "priority": "P2", "path": "res://audio/sfx/sfx_ui_test_skip.wav", "group": "ui"},
	{"id": "sfx_ult_cancel", "priority": "P2", "path": "res://audio/sfx/sfx_ult_cancel.wav", "group": "ult"},
]


static func all_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for e in ENTRIES:
		ids.append(String(e["id"]))
	return ids


static func entry(id: String) -> Dictionary:
	for e in ENTRIES:
		if String(e["id"]) == id:
			return e
	return {}


static func path_for(id: String) -> String:
	var e := entry(id)
	if e.is_empty():
		return ""
	return String(e["path"])


static func by_priority(pri: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in ENTRIES:
		if String(e["priority"]) == pri:
			out.append(e)
	return out
