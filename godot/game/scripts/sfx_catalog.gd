extends RefCounted
## Alpha SFX catalog — IDs match docs/systemdesign/soundeffects.md.
## Assets: res://audio/sfx/<id>.wav (procedural placeholders; replace later).
## `trigger` = mapped gameplay action / effect (from soundeffects.md).

## Each entry: { "id", "priority", "path", "group", "trigger" }
const ENTRIES: Array[Dictionary] = [
	{"id": "sfx_box_drop_feet", "priority": "P0", "path": "res://audio/sfx/sfx_box_drop_feet.wav", "group": "box", "trigger": "無方向掉腳邊"},
	{"id": "sfx_box_land", "priority": "P0", "path": "res://audio/sfx/sfx_box_land.wav", "group": "box", "trigger": "飛箱落地（地／剩貨）"},
	{"id": "sfx_box_pickup_floor", "priority": "P0", "path": "res://audio/sfx/sfx_box_pickup_floor.wav", "group": "box", "trigger": "撿起地上貨箱"},
	{"id": "sfx_box_pull", "priority": "P0", "path": "res://audio/sfx/sfx_box_pull.wav", "group": "box", "trigger": "補貨點輕放執貨成功（即時）"},
	{"id": "sfx_box_shelf_toss", "priority": "P0", "path": "res://audio/sfx/sfx_box_shelf_toss.wav", "group": "box", "trigger": "丟掉軌道命中可接受貨架並補架"},
	{"id": "sfx_box_toss", "priority": "P0", "path": "res://audio/sfx/sfx_box_toss.wav", "group": "box", "trigger": "放手丟出（有方向飛出）"},
	{"id": "sfx_checkout_cash_pop", "priority": "P0", "path": "res://audio/sfx/sfx_checkout_cash_pop.wav", "group": "checkout", "trigger": "完成後彈出 $ 圖示"},
	{"id": "sfx_checkout_circle_done", "priority": "P0", "path": "res://audio/sfx/sfx_checkout_circle_done.wav", "group": "checkout", "trigger": "Circle 填滿、完成收銀"},
	{"id": "sfx_checkout_dir_fail", "priority": "P0", "path": "res://audio/sfx/sfx_checkout_dir_fail.wav", "group": "checkout", "trigger": "方向錯誤（整串重置）"},
	{"id": "sfx_checkout_dir_ok", "priority": "P0", "path": "res://audio/sfx/sfx_checkout_dir_ok.wav", "group": "checkout", "trigger": "單一方向指令正確"},
	{"id": "sfx_clean_done", "priority": "P0", "path": "res://audio/sfx/sfx_clean_done.wav", "group": "clean", "trigger": "清潔計滿、污物消失"},
	{"id": "sfx_clean_scrub", "priority": "P0", "path": "res://audio/sfx/sfx_clean_scrub.wav", "group": "clean", "trigger": "搖桿有效推進清潔計（可節奏點）"},
	{"id": "sfx_fight_fail", "priority": "P0", "path": "res://audio/sfx/sfx_fight_fail.wav", "group": "fight", "trigger": "5 秒內未打倒：玩家被撞開倒地"},
	{"id": "sfx_fight_grab", "priority": "P0", "path": "res://audio/sfx/sfx_fight_grab.wav", "group": "fight", "trigger": "空手長按抓住小偷進打擊"},
	{"id": "sfx_fight_hit", "priority": "P0", "path": "res://audio/sfx/sfx_fight_hit.wav", "group": "fight", "trigger": "連按行動扣血（每有效一下）"},
	{"id": "sfx_ko_guest_dash", "priority": "P0", "path": "res://audio/sfx/sfx_ko_guest_dash.wav", "group": "ko", "trigger": "衝刺撞一般客人 Screen KO（原地落地）"},
	{"id": "sfx_ko_screen", "priority": "P0", "path": "res://audio/sfx/sfx_ko_screen.wav", "group": "ko", "trigger": "Screen KO（近身打倒／丟掉砸中小偷）"},
	{"id": "sfx_move_dash", "priority": "P0", "path": "res://audio/sfx/sfx_move_dash.wav", "group": "move", "trigger": "衝刺出手"},
	{"id": "sfx_move_slip", "priority": "P0", "path": "res://audio/sfx/sfx_move_slip.wav", "group": "move", "trigger": "水漬上奔跑／衝刺滑倒"},
	{"id": "sfx_phase_close", "priority": "P0", "path": "res://audio/sfx/sfx_phase_close.wav", "group": "phase", "trigger": "關店結算畫面出現"},
	{"id": "sfx_shelf_stock_blocked", "priority": "P0", "path": "res://audio/sfx/sfx_shelf_stock_blocked.wav", "group": "shelf", "trigger": "SKU 不符／貨架已滿（叉）"},
	{"id": "sfx_shelf_stock_done", "priority": "P0", "path": "res://audio/sfx/sfx_shelf_stock_done.wav", "group": "shelf", "trigger": "近身上架完成一箱／一段"},
	{"id": "sfx_skill_cast", "priority": "P0", "path": "res://audio/sfx/sfx_skill_cast.wav", "group": "skill", "trigger": "主動技能施放成功（通用層）"},
	{"id": "sfx_thief_dash_out", "priority": "P0", "path": "res://audio/sfx/sfx_thief_dash_out.wav", "group": "thief", "trigger": "衝刺撞飛小偷離場"},
	{"id": "sfx_thief_escape", "priority": "P0", "path": "res://audio/sfx/sfx_thief_escape.wav", "group": "thief", "trigger": "小偷持贓走到出口：橫幅「你已經被偷了！」"},
	{"id": "sfx_ui_deny", "priority": "P0", "path": "res://audio/sfx/sfx_ui_deny.wav", "group": "ui", "trigger": "不能執行（開店條件不足、買不起等）"},
	{"id": "sfx_ult_dir_fail", "priority": "P0", "path": "res://audio/sfx/sfx_ult_dir_fail.wav", "group": "ult", "trigger": "奧義指令錯誤重置"},
	{"id": "sfx_ult_dir_ok", "priority": "P0", "path": "res://audio/sfx/sfx_ult_dir_ok.wav", "group": "ult", "trigger": "奧義方向指令正確"},
	{"id": "sfx_ult_fundraise", "priority": "P0", "path": "res://audio/sfx/sfx_ult_fundraise.wav", "group": "ult", "trigger": "全體集資發動／批次入帳"},
	{"id": "sfx_ult_the_world", "priority": "P0", "path": "res://audio/sfx/sfx_ult_the_world.wav", "group": "ult", "trigger": "The World! 發動"},
	{"id": "sfx_ult_yes_my_lord", "priority": "P0", "path": "res://audio/sfx/sfx_ult_yes_my_lord.wav", "group": "ult", "trigger": "Yes! My Lord! 發動"},
	{"id": "sfx_box_drop_aim", "priority": "P1", "path": "res://audio/sfx/sfx_box_drop_aim.wav", "group": "box", "trigger": "長按取消達丟掉瞄準門檻"},
	{"id": "sfx_box_hit_guest_ok", "priority": "P1", "path": "res://audio/sfx/sfx_box_hit_guest_ok.wav", "group": "box", "trigger": "丟掉砸中客人且 SKU 在清單"},
	{"id": "sfx_box_hit_guest_reject", "priority": "P1", "path": "res://audio/sfx/sfx_box_hit_guest_reject.wav", "group": "box", "trigger": "丟掉砸中客人且 SKU 不在清單"},
	{"id": "sfx_box_hit_thief", "priority": "P1", "path": "res://audio/sfx/sfx_box_hit_thief.wav", "group": "box", "trigger": "飛箱命中小偷（可與 KO 疊或作前導）"},
	{"id": "sfx_box_pull_fail", "priority": "P1", "path": "res://audio/sfx/sfx_box_pull_fail.wav", "group": "box", "trigger": "補貨點空／負重已滿"},
	{"id": "sfx_box_sku_open", "priority": "P1", "path": "res://audio/sfx/sfx_box_sku_open.wav", "group": "box", "trigger": "補貨點長按打開 SKU 清單"},
	{"id": "sfx_checkout_clerk", "priority": "P1", "path": "res://audio/sfx/sfx_checkout_clerk.wav", "group": "checkout", "trigger": "店員自動收銀完成（可共用完成鈴變體）"},
	{"id": "sfx_checkout_enter", "priority": "P1", "path": "res://audio/sfx/sfx_checkout_enter.wav", "group": "checkout", "trigger": "進入收銀指令模式（隊首就緒）"},
	{"id": "sfx_checkout_seq_done", "priority": "P1", "path": "res://audio/sfx/sfx_checkout_seq_done.wav", "group": "checkout", "trigger": "指令串全部正確 → Circle 出現"},
	{"id": "sfx_clean_start", "priority": "P1", "path": "res://audio/sfx/sfx_clean_start.wav", "group": "clean", "trigger": "開始對污物填清潔計"},
	{"id": "sfx_early_close_ask", "priority": "P1", "path": "res://audio/sfx/sfx_early_close_ask.wav", "group": "early", "trigger": "提早關店詢問彈出"},
	{"id": "sfx_guest_angry_leave", "priority": "P1", "path": "res://audio/sfx/sfx_guest_angry_leave.wav", "group": "guest", "trigger": "不滿滿 100 生氣離開"},
	{"id": "sfx_guest_dash_land", "priority": "P1", "path": "res://audio/sfx/sfx_guest_dash_land.wav", "group": "guest", "trigger": "被衝刺撞飛後落地暈 2 秒"},
	{"id": "sfx_loot_inplace", "priority": "P1", "path": "res://audio/sfx/sfx_loot_inplace.wav", "group": "loot", "trigger": "丟掉砸中：贓物原地掉落"},
	{"id": "sfx_loot_scatter", "priority": "P1", "path": "res://audio/sfx/sfx_loot_scatter.wav", "group": "loot", "trigger": "贓物近／遠散落飛行"},
	{"id": "sfx_move_foot_run", "priority": "P1", "path": "res://audio/sfx/sfx_move_foot_run.wav", "group": "move", "trigger": "奔跑步伐（較密／較重）"},
	{"id": "sfx_move_foot_walk", "priority": "P1", "path": "res://audio/sfx/sfx_move_foot_walk.wav", "group": "move", "trigger": "走路步伐循環（可跟動畫幀）"},
	{"id": "sfx_move_stun", "priority": "P1", "path": "res://audio/sfx/sfx_move_stun.wav", "group": "move", "trigger": "滑倒後暈眩／打擊失敗倒地"},
	{"id": "sfx_phase_open", "priority": "P1", "path": "res://audio/sfx/sfx_phase_open.wav", "group": "phase", "trigger": "補貨結束→營運時段"},
	{"id": "sfx_phase_restock", "priority": "P1", "path": "res://audio/sfx/sfx_phase_restock.wav", "group": "phase", "trigger": "進入補貨時段（日開始）"},
	{"id": "sfx_shelf_stock_instant", "priority": "P1", "path": "res://audio/sfx/sfx_shelf_stock_instant.wav", "group": "shelf", "trigger": "瞬間補貨 LV3 略過 Circle 完成"},
	{"id": "sfx_skill_cd_deny", "priority": "P1", "path": "res://audio/sfx/sfx_skill_cd_deny.wav", "group": "skill", "trigger": "CD 中／不能施放"},
	{"id": "sfx_skill_menu_open", "priority": "P1", "path": "res://audio/sfx/sfx_skill_menu_open.wav", "group": "skill", "trigger": "長按技能開選單"},
	{"id": "sfx_skill_soothe", "priority": "P1", "path": "res://audio/sfx/sfx_skill_soothe.wav", "group": "skill", "trigger": "安撫生效"},
	{"id": "sfx_ui_cancel", "priority": "P1", "path": "res://audio/sfx/sfx_ui_cancel.wav", "group": "ui", "trigger": "選單取消／返回"},
	{"id": "sfx_ui_confirm", "priority": "P1", "path": "res://audio/sfx/sfx_ui_confirm.wav", "group": "ui", "trigger": "選單確定"},
	{"id": "sfx_ui_level_up", "priority": "P1", "path": "res://audio/sfx/sfx_ui_level_up.wav", "group": "ui", "trigger": "結算升級（若有）"},
	{"id": "sfx_ui_move", "priority": "P1", "path": "res://audio/sfx/sfx_ui_move.wav", "group": "ui", "trigger": "選單游標移動"},
	{"id": "sfx_ui_pause_close", "priority": "P1", "path": "res://audio/sfx/sfx_ui_pause_close.wav", "group": "ui", "trigger": "暫停繼續"},
	{"id": "sfx_ui_pause_open", "priority": "P1", "path": "res://audio/sfx/sfx_ui_pause_open.wav", "group": "ui", "trigger": "暫停選單開啟"},
	{"id": "sfx_ui_place", "priority": "P1", "path": "res://audio/sfx/sfx_ui_place.wav", "group": "ui", "trigger": "店舖設計放置成功"},
	{"id": "sfx_ui_purchase", "priority": "P1", "path": "res://audio/sfx/sfx_ui_purchase.wav", "group": "ui", "trigger": "採購／購入傢俬／開發成功扣款"},
	{"id": "sfx_ult_prep", "priority": "P1", "path": "res://audio/sfx/sfx_ult_prep.wav", "group": "ult", "trigger": "長按奧義進入指令準備"},
	{"id": "sfx_ult_the_world_end", "priority": "P1", "path": "res://audio/sfx/sfx_ult_the_world_end.wav", "group": "ult", "trigger": "The World! 結束恢復流速"},
	{"id": "sfx_box_sku_cancel", "priority": "P2", "path": "res://audio/sfx/sfx_box_sku_cancel.wav", "group": "box", "trigger": "取消選貨"},
	{"id": "sfx_box_sku_confirm", "priority": "P2", "path": "res://audio/sfx/sfx_box_sku_confirm.wav", "group": "box", "trigger": "放手確認 SKU"},
	{"id": "sfx_box_sku_move", "priority": "P2", "path": "res://audio/sfx/sfx_box_sku_move.wav", "group": "box", "trigger": "清單上／下改選"},
	{"id": "sfx_checkout_release_reset", "priority": "P2", "path": "res://audio/sfx/sfx_checkout_release_reset.wav", "group": "checkout", "trigger": "收銀中放手重置指令"},
	{"id": "sfx_clean_cancel", "priority": "P2", "path": "res://audio/sfx/sfx_clean_cancel.wav", "group": "clean", "trigger": "清潔中放手重置"},
	{"id": "sfx_clerk_pull", "priority": "P2", "path": "res://audio/sfx/sfx_clerk_pull.wav", "group": "clerk", "trigger": "補貨店員取箱（可共用 `sfx_box_pull` 降音量）"},
	{"id": "sfx_clerk_stock", "priority": "P2", "path": "res://audio/sfx/sfx_clerk_stock.wav", "group": "clerk", "trigger": "補貨店員上架完成"},
	{"id": "sfx_dirt_spawn", "priority": "P2", "path": "res://audio/sfx/sfx_dirt_spawn.wav", "group": "dirt", "trigger": "污物生成（可極淡）"},
	{"id": "sfx_guest_enter", "priority": "P2", "path": "res://audio/sfx/sfx_guest_enter.wav", "group": "guest", "trigger": "一般客人進店"},
	{"id": "sfx_guest_paid_leave", "priority": "P2", "path": "res://audio/sfx/sfx_guest_paid_leave.wav", "group": "guest", "trigger": "付完款離開"},
	{"id": "sfx_guest_queue", "priority": "P2", "path": "res://audio/sfx/sfx_guest_queue.wav", "group": "guest", "trigger": "加入收銀排隊（可選）"},
	{"id": "sfx_guest_take", "priority": "P2", "path": "res://audio/sfx/sfx_guest_take.wav", "group": "guest", "trigger": "客人貨架取貨完成（逗留後）"},
	{"id": "sfx_guest_think", "priority": "P2", "path": "res://audio/sfx/sfx_guest_think.wav", "group": "guest", "trigger": "找不到貨、短暫思考"},
	{"id": "sfx_move_crowd", "priority": "P2", "path": "res://audio/sfx/sfx_move_crowd.wav", "group": "move", "trigger": "進入擁擠（3 身位內多人）"},
	{"id": "sfx_move_dirt_step", "priority": "P2", "path": "res://audio/sfx/sfx_move_dirt_step.wav", "group": "move", "trigger": "踩上污物（可與腳步疊極輕）"},
	{"id": "sfx_move_overcarry", "priority": "P2", "path": "res://audio/sfx/sfx_move_overcarry.wav", "group": "move", "trigger": "超重移動開始／持續層（可極輕）"},
	{"id": "sfx_move_stamina_empty", "priority": "P2", "path": "res://audio/sfx/sfx_move_stamina_empty.wav", "group": "move", "trigger": "氣力見底無法再跑／衝"},
	{"id": "sfx_shelf_stock_loop", "priority": "P2", "path": "res://audio/sfx/sfx_shelf_stock_loop.wav", "group": "shelf", "trigger": "近身上架 Circle 進行中（可極短循環或無聲＋完成音）"},
	{"id": "sfx_skill_menu_cancel", "priority": "P2", "path": "res://audio/sfx/sfx_skill_menu_cancel.wav", "group": "skill", "trigger": "放手取消選單"},
	{"id": "sfx_skill_menu_move", "priority": "P2", "path": "res://audio/sfx/sfx_skill_menu_move.wav", "group": "skill", "trigger": "選單方向改選"},
	{"id": "sfx_thief_spawn", "priority": "P2", "path": "res://audio/sfx/sfx_thief_spawn.wav", "group": "thief", "trigger": "小偷進店（可選）"},
	{"id": "sfx_ui_pickup_item", "priority": "P2", "path": "res://audio/sfx/sfx_ui_pickup_item.wav", "group": "ui", "trigger": "店舖設計收回傢俬"},
	{"id": "sfx_ui_rotate", "priority": "P2", "path": "res://audio/sfx/sfx_ui_rotate.wav", "group": "ui", "trigger": "店舖設計轉向"},
	{"id": "sfx_ui_test_skip", "priority": "P2", "path": "res://audio/sfx/sfx_ui_test_skip.wav", "group": "ui", "trigger": "測試「馬上完成營運」等（測試版）"},
	{"id": "sfx_ult_cancel", "priority": "P2", "path": "res://audio/sfx/sfx_ult_cancel.wav", "group": "ult", "trigger": "奧義蓄力放手取消"},
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


static func trigger_for(id: String) -> String:
	var e := entry(id)
	if e.is_empty():
		return ""
	return String(e.get("trigger", ""))


static func by_priority(pri: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in ENTRIES:
		if String(e["priority"]) == pri:
			out.append(e)
	return out
