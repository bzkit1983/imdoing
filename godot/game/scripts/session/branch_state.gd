extends RefCounted
## Branch-store mutations (assign posts, policy, stock, sale). State stays on GameState.

const BranchRules = preload("res://scripts/session/branch_rules.gd")
const ThemeStoreSnapshot = preload("res://scripts/session/theme_store_snapshot.gd")
const Tuning = preload("res://scripts/tuning.gd")


static func branch_system_unlocked(state) -> bool:
	return BranchRules.is_unlocked(state.themes_cleared)


static func elite_assignment(row: Dictionary) -> Variant:
	var raw = row.get("assignment", null)
	if raw == null:
		return null
	if not (raw is Dictionary):
		return null
	var theme_id := String(raw.get("theme_id", ""))
	var post := String(raw.get("post", ""))
	if theme_id == "" or post == "":
		return null
	return {"theme_id": theme_id, "post": post}


static func clear_elite_from_branch_posts(state, elite_id: String) -> void:
	var eid := String(elite_id)
	clear_elite_posts_in_store(state.origin_store, eid)
	if state.theme_stores is Dictionary:
		for tid in state.theme_stores.keys():
			var snap = state.theme_stores[tid]
			if snap is Dictionary:
				clear_elite_posts_in_store(snap, eid)
				state.theme_stores[tid] = snap
	## Also clear live HQ posts if mirrored.
	for post in BranchRules.POST_IDS:
		var ref = state.branch_posts.get(post, null)
		if ref is Dictionary and String(ref.get("kind", "")) == "elite" and String(ref.get("id", "")) == eid:
			state.branch_posts[post] = null


static func clear_elite_posts_in_store(snap: Dictionary, elite_id: String) -> void:
	var posts = snap.get("branch_posts", null)
	if not (posts is Dictionary):
		return
	for post in BranchRules.POST_IDS:
		var ref = posts.get(post, null)
		if ref is Dictionary and String(ref.get("kind", "")) == "elite" and String(ref.get("id", "")) == elite_id:
			posts[post] = null
	snap["branch_posts"] = posts


## Assign elite to a branch post. Clears HQ on_duty. Returns error string or "".
static func assign_elite_to_branch(state, elite_id: String, theme_id: String, post: String) -> String:
	var i := int(state._elite_index(elite_id))
	if i < 0:
		return Loc.t("err.elite_clerk_not_owned")
	var tid := String(theme_id)
	var p := String(post)
	if not BranchRules.POST_IDS.has(p):
		return Loc.t("err.branch_bad_post")
	if tid != BranchRules.ORIGIN_ID and not state.theme_stores.has(tid):
		if tid == String(state.active_theme_id):
			pass
		else:
			return Loc.t("err.branch_store_missing", [tid])
	## Clear previous assignment / posts for this elite.
	clear_elite_from_branch_posts(state, String(state.elite_clerks[i].get("id", "")))
	state.elite_clerks[i]["on_duty"] = false
	state.elite_clerks[i]["assignment"] = {"theme_id": tid, "post": p}
	set_branch_post(state, tid, p, {"kind": "elite", "id": String(state.elite_clerks[i].get("id", ""))})
	return ""


static func clear_elite_branch_assignment(state, elite_id: String) -> void:
	var i := int(state._elite_index(elite_id))
	if i < 0:
		return
	clear_elite_from_branch_posts(state, String(state.elite_clerks[i].get("id", "")))
	state.elite_clerks[i]["assignment"] = null


static func set_branch_post(state, theme_id: String, post: String, ref: Variant) -> void:
	var tid := String(theme_id)
	if tid == String(state.active_theme_id) or (tid == BranchRules.ORIGIN_ID and String(state.active_theme_id) == BranchRules.ORIGIN_ID):
		## If targeting the live HQ store, update live posts too.
		if tid == String(state.active_theme_id):
			state.branch_posts[post] = ref
	var snap: Dictionary
	if tid == BranchRules.ORIGIN_ID:
		snap = ThemeStoreSnapshot.normalize_theme_store(state.origin_store)
		var posts: Dictionary = BranchRules.normalize_posts(snap.get("branch_posts", null))
		## Vacate post if occupied by someone else.
		posts[post] = ref
		snap["branch_posts"] = posts
		state.origin_store = snap
	else:
		snap = ThemeStoreSnapshot.get_store_dict(state, tid)
		if snap.is_empty():
			return
		var posts2: Dictionary = BranchRules.normalize_posts(snap.get("branch_posts", null))
		posts2[post] = ref
		snap["branch_posts"] = posts2
		state.theme_stores[tid] = snap


## Assign a regular clerk index from that store's clerks[] to a branch post.
static func assign_clerk_to_branch(state, theme_id: String, post: String, clerk_index: int) -> String:
	var tid := String(theme_id)
	var p := String(post)
	if not BranchRules.POST_IDS.has(p):
		return Loc.t("err.branch_bad_post")
	var snap: Dictionary = ThemeStoreSnapshot.get_store_dict(state, tid)
	if snap.is_empty() and tid != String(state.active_theme_id):
		return Loc.t("err.branch_store_missing", [tid])
	if tid == String(state.active_theme_id):
		snap = ThemeStoreSnapshot.pack_from_state(state)
	var clerks_arr = snap.get("clerks", [])
	if not (clerks_arr is Array) or clerk_index < 0 or clerk_index >= clerks_arr.size():
		return Loc.t("err.branch_bad_clerk")
	## Clear this clerk from other posts in the same store.
	var posts: Dictionary = BranchRules.normalize_posts(snap.get("branch_posts", null))
	for op in BranchRules.POST_IDS:
		var pref = posts.get(op, null)
		if pref is Dictionary and String(pref.get("kind", "")) == "clerk" and int(pref.get("id", -1)) == clerk_index:
			posts[op] = null
	posts[p] = {"kind": "clerk", "id": clerk_index}
	snap["branch_posts"] = posts
	ThemeStoreSnapshot.set_store_dict(state, tid, snap)
	if tid == String(state.active_theme_id):
		state.branch_posts = posts
	return ""


static func set_branch_policy(state, theme_id: String, new_policy: String) -> void:
	var tid := String(theme_id)
	var p := BranchRules.normalize_policy(new_policy)
	if tid == String(state.active_theme_id):
		state.policy = p
	var snap: Dictionary = ThemeStoreSnapshot.get_store_dict(state, tid)
	if snap.is_empty() and tid != String(state.active_theme_id):
		return
	if tid == String(state.active_theme_id):
		snap = ThemeStoreSnapshot.pack_from_state(state)
	snap["policy"] = p
	ThemeStoreSnapshot.set_store_dict(state, tid, snap)


static func buy_branch_stock(state, theme_id: String, sku: String, pieces: int) -> String:
	var tid := String(theme_id)
	if tid == String(state.active_theme_id):
		return state.buy_stock(sku, pieces)
	var snap: Dictionary = ThemeStoreSnapshot.get_store_dict(state, tid)
	if snap.is_empty():
		return Loc.t("err.branch_store_missing", [tid])
	var developed = snap.get("developed", {})
	var for_sale = snap.get("for_sale", {})
	var stock = snap.get("stock", {})
	if not (developed is Dictionary) or not bool(developed.get(sku, false)):
		return Loc.t("err.not_developed")
	if Tuning.is_craft_only(sku):
		return Loc.t("err.craft_only")
	if for_sale is Dictionary and for_sale.has(sku) and not bool(for_sale[sku]):
		return Loc.t("err.not_for_sale")
	pieces = clampi(pieces, 1, Tuning.RESTOCK_PIECES)
	var cost := Tuning.cost_for_pieces(sku, pieces)
	if state.money < cost:
		return Loc.t("err.funds")
	state.money -= cost
	if not (stock is Dictionary):
		stock = {}
	stock[sku] = int(stock.get(sku, 0)) + pieces
	snap["stock"] = stock
	ThemeStoreSnapshot.set_store_dict(state, tid, snap)
	return ""


static func set_branch_for_sale(state, theme_id: String, sku: String, on: bool) -> String:
	var tid := String(theme_id)
	if tid == String(state.active_theme_id):
		state.for_sale[sku] = on
		state._ensure_one_for_sale()
		return ""
	var snap: Dictionary = ThemeStoreSnapshot.get_store_dict(state, tid)
	if snap.is_empty():
		return Loc.t("err.branch_store_missing", [tid])
	var developed = snap.get("developed", {})
	var fs = snap.get("for_sale", {})
	if not (developed is Dictionary) or not bool(developed.get(sku, false)):
		return Loc.t("err.not_developed")
	if not (fs is Dictionary):
		fs = {}
	fs[sku] = on
	## Keep at least one sellable.
	var any_on := false
	for s in developed.keys():
		var sid := String(s)
		if not bool(developed[s]):
			continue
		if Tuning.is_craft_only(sid):
			continue
		if not fs.has(sid) or bool(fs[sid]):
			any_on = true
			break
	if not any_on:
		fs[sku] = true
	snap["for_sale"] = fs
	ThemeStoreSnapshot.set_store_dict(state, tid, snap)
	return ""
