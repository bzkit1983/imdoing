extends RefCounted
## Pack / hydrate ThemeStoreDict ↔ live GameState shop fields (branchstore.md).

const BranchRules = preload("res://scripts/session/branch_rules.gd")
const RatingRules = preload("res://scripts/session/rating_rules.gd")


## Shop-field keys mirrored into each ThemeStoreDict / origin_store.
static func shop_field_names() -> Array[String]:
	return [
		"owned",
		"placed",
		"shop_scale",
		"grid_w",
		"grid_h",
		"stock",
		"developed",
		"for_sale",
		"fish_stock",
		"fishing_taro_played",
		"clerks",
		"shop_rating",
		"rating_history",
		"last_ops_rating",
		"last_grade",
		"day_procurement",
	]


static func default_theme_store() -> Dictionary:
	return {
		"owned": {},
		"placed": [],
		"shop_scale": 1,
		"grid_w": 10,
		"grid_h": 10,
		"stock": {},
		"developed": {},
		"for_sale": {},
		"fish_stock": {},
		"fishing_taro_played": false,
		"clerks": [],
		"shop_rating": 0,
		"rating_history": [],
		"last_ops_rating": RatingRules.OPS_START,
		"last_grade": 0,
		"day_procurement": 0,
		"policy": BranchRules.POLICY_BALANCED,
		"branch_posts": BranchRules.empty_posts(),
	}


static func pack_from_state(state) -> Dictionary:
	var snap := default_theme_store()
	snap["owned"] = _dup_dict(state.owned)
	snap["placed"] = _dup_placed(state.placed)
	snap["shop_scale"] = int(state.shop_scale)
	snap["grid_w"] = int(state.grid_w)
	snap["grid_h"] = int(state.grid_h)
	snap["stock"] = _dup_dict(state.stock)
	snap["developed"] = _dup_dict(state.developed)
	snap["for_sale"] = _dup_dict(state.for_sale)
	snap["fish_stock"] = _dup_dict(state.fish_stock)
	snap["fishing_taro_played"] = bool(state.fishing_taro_played)
	snap["clerks"] = _dup_clerks(state.clerks)
	snap["shop_rating"] = int(state.shop_rating)
	snap["rating_history"] = state.rating_history.duplicate()
	snap["last_ops_rating"] = int(state.last_ops_rating)
	snap["last_grade"] = int(state.last_grade)
	snap["day_procurement"] = int(state.day_procurement)
	## Live HQ may carry transient policy/posts when it is a branch-capable store.
	if "policy" in state:
		snap["policy"] = BranchRules.normalize_policy(String(state.policy))
	else:
		snap["policy"] = BranchRules.POLICY_BALANCED
	if "branch_posts" in state:
		snap["branch_posts"] = BranchRules.normalize_posts(state.branch_posts)
	else:
		snap["branch_posts"] = BranchRules.empty_posts()
	return snap


static func hydrate_into_state(state, snap: Dictionary) -> void:
	var src := snap if not snap.is_empty() else default_theme_store()
	state.owned = _string_int_dict(src.get("owned", {}))
	state.placed = _parse_placed(src.get("placed", []))
	state.shop_scale = clampi(int(src.get("shop_scale", 1)), 1, 6)
	state.grid_w = maxi(8, int(src.get("grid_w", 10)))
	state.grid_h = maxi(8, int(src.get("grid_h", 10)))
	state.stock = _string_int_dict(src.get("stock", {}))
	state.developed = _string_bool_dict(src.get("developed", {}))
	state.for_sale = _string_bool_dict(src.get("for_sale", {}))
	state.fish_stock = _string_int_dict(src.get("fish_stock", {}))
	state.fishing_taro_played = bool(src.get("fishing_taro_played", false))
	state.clerks = _parse_clerks(src.get("clerks", []))
	state.shop_rating = maxi(0, int(src.get("shop_rating", 0)))
	state.rating_history = []
	var raw_hist = src.get("rating_history", [])
	if raw_hist is Array:
		for g in raw_hist:
			state.rating_history.append(clampi(int(g), -3, 3))
		while state.rating_history.size() > RatingRules.HISTORY_MAX:
			state.rating_history.remove_at(0)
	state.last_ops_rating = int(src.get("last_ops_rating", RatingRules.OPS_START))
	state.last_grade = clampi(int(src.get("last_grade", 0)), -3, 3)
	state.day_procurement = maxi(0, int(src.get("day_procurement", 0)))
	state.policy = BranchRules.normalize_policy(String(src.get("policy", BranchRules.POLICY_BALANCED)))
	state.branch_posts = BranchRules.normalize_posts(src.get("branch_posts", null))


static func normalize_theme_store(raw) -> Dictionary:
	var base := default_theme_store()
	if not (raw is Dictionary):
		return base
	base["owned"] = _string_int_dict(raw.get("owned", {}))
	base["placed"] = _parse_placed(raw.get("placed", []))
	base["shop_scale"] = clampi(int(raw.get("shop_scale", 1)), 1, 6)
	base["grid_w"] = maxi(8, int(raw.get("grid_w", 10)))
	base["grid_h"] = maxi(8, int(raw.get("grid_h", 10)))
	base["stock"] = _string_int_dict(raw.get("stock", {}))
	base["developed"] = _string_bool_dict(raw.get("developed", {}))
	base["for_sale"] = _string_bool_dict(raw.get("for_sale", {}))
	base["fish_stock"] = _string_int_dict(raw.get("fish_stock", {}))
	base["fishing_taro_played"] = bool(raw.get("fishing_taro_played", false))
	base["clerks"] = _parse_clerks(raw.get("clerks", []))
	base["shop_rating"] = maxi(0, int(raw.get("shop_rating", 0)))
	base["rating_history"] = []
	var raw_hist = raw.get("rating_history", [])
	if raw_hist is Array:
		for g in raw_hist:
			base["rating_history"].append(clampi(int(g), -3, 3))
	base["last_ops_rating"] = int(raw.get("last_ops_rating", RatingRules.OPS_START))
	base["last_grade"] = clampi(int(raw.get("last_grade", 0)), -3, 3)
	base["day_procurement"] = maxi(0, int(raw.get("day_procurement", 0)))
	base["policy"] = BranchRules.normalize_policy(String(raw.get("policy", BranchRules.POLICY_BALANCED)))
	base["branch_posts"] = BranchRules.normalize_posts(raw.get("branch_posts", null))
	return base


static func write_back_active(state) -> void:
	var tid := String(state.active_theme_id) if "active_theme_id" in state else BranchRules.ORIGIN_ID
	if tid == "" or tid == BranchRules.ORIGIN_ID:
		state.origin_store = pack_from_state(state)
		state.active_theme_id = BranchRules.ORIGIN_ID
	else:
		if not (state.theme_stores is Dictionary):
			state.theme_stores = {}
		state.theme_stores[tid] = pack_from_state(state)


static func switch_active(state, theme_id: String) -> String:
	var target := String(theme_id)
	if target == "":
		target = BranchRules.ORIGIN_ID
	write_back_active(state)
	if target == BranchRules.ORIGIN_ID:
		var origin = state.origin_store if "origin_store" in state else {}
		if not (origin is Dictionary) or origin.is_empty():
			return Loc.t("err.branch_store_missing", [target])
		hydrate_into_state(state, origin)
		state.active_theme_id = BranchRules.ORIGIN_ID
		return ""
	var stores = state.theme_stores if "theme_stores" in state else {}
	if not (stores is Dictionary) or not stores.has(target):
		return Loc.t("err.branch_store_missing", [target])
	hydrate_into_state(state, stores[target])
	state.active_theme_id = target
	return ""


static func branch_candidate_ids(state) -> Array[String]:
	var out: Array[String] = []
	var active := String(state.active_theme_id) if "active_theme_id" in state else BranchRules.ORIGIN_ID
	if active == "":
		active = BranchRules.ORIGIN_ID
	var origin = state.origin_store if "origin_store" in state else {}
	if origin is Dictionary and not origin.is_empty() and active != BranchRules.ORIGIN_ID:
		out.append(BranchRules.ORIGIN_ID)
	var stores = state.theme_stores if "theme_stores" in state else {}
	if stores is Dictionary:
		var keys: Array = stores.keys()
		keys.sort()
		for k in keys:
			var tid := String(k)
			if tid == "" or tid == active:
				continue
			out.append(tid)
	return out


static func get_store_dict(state, theme_id: String) -> Dictionary:
	var tid := String(theme_id)
	if tid == "" or tid == BranchRules.ORIGIN_ID:
		var origin = state.origin_store if "origin_store" in state else {}
		return normalize_theme_store(origin if origin is Dictionary else {})
	var stores = state.theme_stores if "theme_stores" in state else {}
	if stores is Dictionary and stores.has(tid):
		return normalize_theme_store(stores[tid])
	return {}


static func set_store_dict(state, theme_id: String, snap: Dictionary) -> void:
	var tid := String(theme_id)
	var norm := normalize_theme_store(snap)
	if tid == "" or tid == BranchRules.ORIGIN_ID:
		state.origin_store = norm
	else:
		if not (state.theme_stores is Dictionary):
			state.theme_stores = {}
		state.theme_stores[tid] = norm


static func _dup_dict(d: Dictionary) -> Dictionary:
	return d.duplicate(true)


static func _dup_placed(placed) -> Array:
	var out: Array = []
	if not (placed is Array):
		return out
	for it in placed:
		if it is Dictionary:
			out.append((it as Dictionary).duplicate(true))
	return out


static func _dup_clerks(clerks) -> Array:
	var out: Array = []
	if not (clerks is Array):
		return out
	for c in clerks:
		if c is Dictionary:
			out.append({
				"role": String(c.get("role", "restock")),
				"register": int(c.get("register", 0)),
			})
	return out


static func _parse_placed(raw) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not (raw is Array):
		return out
	for it in raw:
		if not (it is Dictionary):
			continue
		out.append((it as Dictionary).duplicate(true))
	return out


static func _parse_clerks(raw) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not (raw is Array):
		return out
	for c in raw:
		if not (c is Dictionary):
			continue
		var role := String(c.get("role", "restock"))
		if role != "cashier" and role != "restock" and role != "security" and role != "cleaner":
			role = "restock"
		out.append({"role": role, "register": maxi(0, int(c.get("register", 0)))})
	return out


static func _string_int_dict(raw) -> Dictionary:
	var out: Dictionary = {}
	if not (raw is Dictionary):
		return out
	for k in raw.keys():
		out[String(k)] = int(raw[k])
	return out


static func _string_bool_dict(raw) -> Dictionary:
	var out: Dictionary = {}
	if not (raw is Dictionary):
		return out
	for k in raw.keys():
		out[String(k)] = bool(raw[k])
	return out
