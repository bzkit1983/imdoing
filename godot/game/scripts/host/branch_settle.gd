extends RefCounted
## Abstract branch auto-restock + settle (branchstore.md). No 3-min world sim.

const BranchRules = preload("res://scripts/session/branch_rules.gd")
const ThemeStoreSnapshot = preload("res://scripts/session/theme_store_snapshot.gd")
const RatingRules = preload("res://scripts/session/rating_rules.gd")
const EliteClerkCatalog = preload("res://scripts/session/elite_clerk_catalog.gd")
const Tuning = preload("res://scripts/tuning.gd")


## Run after HQ `state.settle(...)`, before `save_to_disk()`.
## Returns {unlocked, rows, total_revenue, total_restock, total_wage, body}.
## Networked sessions skip abstract branch settle (Prep entry already locked; full
## branch×multiplayer is #167). Host and clients stay consistent by not mutating.
static func settle_all(state) -> Dictionary:
	if SessionService.is_networked():
		return {
			"unlocked": false,
			"rows": [],
			"total_revenue": 0,
			"total_restock": 0,
			"total_wage": 0,
			"body": "",
			"skipped_networked": true,
		}
	var unlocked := BranchRules.is_unlocked(state.themes_cleared if "themes_cleared" in state else [])
	var rows: Array = []
	var total_revenue := 0
	var total_restock := 0
	var total_wage := 0
	if not unlocked:
		return {
			"unlocked": false,
			"rows": rows,
			"total_revenue": 0,
			"total_restock": 0,
			"total_wage": 0,
			"body": Loc.t("settle.branch.locked"),
		}
	## Persist live HQ shop fields into its snapshot slot first.
	ThemeStoreSnapshot.write_back_active(state)
	var candidates: Array[String] = ThemeStoreSnapshot.branch_candidate_ids(state)
	for tid in candidates:
		var row: Dictionary = settle_one(state, tid)
		rows.append(row)
		total_revenue += int(row.get("revenue", 0))
		total_restock += int(row.get("restock_spent", 0))
		total_wage += int(row.get("wage_spent", 0))
	## Re-hydrate active HQ from (possibly unchanged) snapshot so live fields stay consistent.
	var active := String(state.active_theme_id)
	if active == "" or active == BranchRules.ORIGIN_ID:
		ThemeStoreSnapshot.hydrate_into_state(state, ThemeStoreSnapshot.get_store_dict(state, BranchRules.ORIGIN_ID))
		state.active_theme_id = BranchRules.ORIGIN_ID
	else:
		ThemeStoreSnapshot.hydrate_into_state(state, ThemeStoreSnapshot.get_store_dict(state, active))
		state.active_theme_id = active
	return {
		"unlocked": true,
		"rows": rows,
		"total_revenue": total_revenue,
		"total_restock": total_restock,
		"total_wage": total_wage,
		"body": format_closeout_body(rows),
	}


static func settle_one(state, theme_id: String) -> Dictionary:
	var tid := String(theme_id)
	var snap: Dictionary = ThemeStoreSnapshot.get_store_dict(state, tid)
	var policy := BranchRules.normalize_policy(String(snap.get("policy", BranchRules.POLICY_BALANCED)))
	var posts: Dictionary = BranchRules.normalize_posts(snap.get("branch_posts", null))
	var name_key := BranchRules.store_display_key(tid)
	var base_row := {
		"theme_id": tid,
		"name_key": name_key,
		"policy": policy,
		"status": "closed",
		"restock_spent": 0,
		"wage_owed": 0,
		"wage_spent": 0,
		"revenue": 0,
		"ops_points": 0,
		"grade": 0,
		"shop_before": int(snap.get("shop_rating", 0)),
		"shop_after": int(snap.get("shop_rating", 0)),
		"reason": "",
	}
	if not BranchRules.has_manager(posts):
		base_row["reason"] = "no_manager"
		return base_row
	## Auto-restock then abstract ops. Keep owed wages distinct from the amount paid.
	var restock_spent := _auto_restock(state, snap)
	var wage_owed := _clerk_wage(snap, posts)
	var wage_spent := 0
	if wage_owed > 0:
		var pay := mini(wage_owed, int(state.money))
		state.money -= pay
		wage_spent = pay
	var stats := _post_stats(state, snap, posts)
	var manager_score := (
		float(stats["manager"]["str"])
		+ float(stats["manager"]["agi"])
		+ float(stats["manager"]["int"])
	) / 3.0
	var stock_factor := _stock_factor(snap)
	var scale_f := BranchRules.scale_factor(int(snap.get("shop_scale", 1)))
	var base_revenue := (
		float(BranchRules.BRANCH_BASE_REVENUE)
		* (1.0 + manager_score / BranchRules.MANAGER_FUND_DIV)
		* stock_factor
		* scale_f
	)
	var staff_fund := (
		float(stats["cashier"]["int"]) * BranchRules.K_INT_FUND
		+ float(stats["restock"]["str"]) * BranchRules.K_STR_FUND
	)
	var fund_mult := BranchRules.policy_fund_mult(policy)
	var revenue := maxi(0, int(round((base_revenue + staff_fund) * fund_mult)))
	state.money += revenue
	var ops_points := (
		50.0
		+ manager_score * BranchRules.K_MGR_OPS
		+ float(stats["cleaner"]["agi"]) * BranchRules.K_AGI_OPS
		+ float(stats["security"]["str"]) * BranchRules.K_STR_OPS
	)
	ops_points *= BranchRules.policy_rating_mult(policy)
	var ops_i := int(round(ops_points))
	var grade := RatingRules.grade_for_ops(ops_i)
	var shop_before := int(snap.get("shop_rating", 0))
	var shop_after := maxi(0, shop_before + grade)
	snap["shop_rating"] = shop_after
	snap["last_ops_rating"] = ops_i
	snap["last_grade"] = grade
	var hist: Array = []
	var raw_hist = snap.get("rating_history", [])
	if raw_hist is Array:
		hist = raw_hist.duplicate()
	hist.append(grade)
	while hist.size() > RatingRules.HISTORY_MAX:
		hist.remove_at(0)
	snap["rating_history"] = hist
	snap["policy"] = policy
	snap["branch_posts"] = posts
	ThemeStoreSnapshot.set_store_dict(state, tid, snap)
	return {
		"theme_id": tid,
		"name_key": name_key,
		"policy": policy,
		"status": "open",
		"restock_spent": restock_spent,
		"wage_owed": wage_owed,
		"wage_spent": wage_spent,
		"revenue": revenue,
		"ops_points": ops_i,
		"grade": grade,
		"shop_before": shop_before,
		"shop_after": shop_after,
		"reason": "",
	}


static func format_closeout_body(rows: Array) -> String:
	if rows.is_empty():
		return Loc.t("settle.branch.empty")
	var lines: PackedStringArray = []
	for row in rows:
		if not (row is Dictionary):
			continue
		var r: Dictionary = row
		var title := Loc.t(String(r.get("name_key", "branch.store.origin")))
		var policy := Loc.t(BranchRules.policy_label_key(String(r.get("policy", BranchRules.POLICY_BALANCED))))
		if String(r.get("status", "")) != "open":
			var reason := String(r.get("reason", "no_manager"))
			var reason_txt := Loc.t("settle.branch.reason.%s" % reason)
			lines.append(Loc.t("settle.branch.row_closed", [title, reason_txt, policy]))
			continue
		var grade_key := RatingRules.grade_label_key(int(r.get("grade", 0)))
		var restock_i := int(r.get("restock_spent", 0))
		var paid_i := int(r.get("wage_spent", 0))
		var owed_i := int(r.get("wage_owed", paid_i))
		var revenue_i := int(r.get("revenue", 0))
		lines.append(Loc.t("settle.branch.row_open", [
			title,
			policy,
			restock_i,
			paid_i,
			revenue_i,
			int(r.get("ops_points", 0)),
			Loc.t(grade_key),
			int(r.get("shop_before", 0)),
			int(r.get("shop_after", 0)),
		]))
		## One net line per operating store: revenue − wages paid − restock.
		## Money arg is preformatted so negatives read as `-$120`, not `$-120`.
		lines.append(Loc.t("settle.branch.net", [format_signed_money(revenue_i - paid_i - restock_i)]))
		if paid_i < owed_i:
			lines.append(Loc.t("settle.branch.partial_wage", [owed_i, paid_i]))
	return "\n".join(lines)


## `$120` / `-$120` — avoids locale `淨利 $%d` rendering `淨利 $-120`.
static func format_signed_money(amount: int) -> String:
	if amount < 0:
		return "-$%d" % absi(amount)
	return "$%d" % amount


## HUD branch panel. Empty when the system is locked (same gate demo used to inline).
static func closeout_panel_body(pack: Dictionary, state) -> String:
	if bool(pack.get("unlocked", false)):
		return String(pack.get("body", ""))
	if state != null and state.has_method("branch_system_unlocked") and state.branch_system_unlocked():
		return String(pack.get("body", ""))
	return ""


static func _auto_restock(state, snap: Dictionary) -> int:
	var spent := 0
	var developed = snap.get("developed", {})
	var for_sale = snap.get("for_sale", {})
	var stock = snap.get("stock", {})
	if not (developed is Dictionary):
		developed = {}
	if not (for_sale is Dictionary):
		for_sale = {}
	if not (stock is Dictionary):
		stock = {}
	var skus: Array = developed.keys()
	skus.sort()
	for sku_raw in skus:
		var sku := String(sku_raw)
		if not bool(developed.get(sku, false)):
			continue
		if Tuning.is_craft_only(sku):
			continue
		## Missing for_sale key ⇒ sellable (same as HQ).
		if for_sale.has(sku) and not bool(for_sale[sku]):
			continue
		var have := int(stock.get(sku, 0))
		var target := BranchRules.DAILY_USAGE_PIECES
		if have >= target:
			continue
		var need := target - have
		while need > 0 and state.money > 0:
			var chunk := mini(need, Tuning.RESTOCK_PIECES)
			chunk = maxi(1, chunk)
			var cost := Tuning.cost_for_pieces(sku, chunk)
			if cost <= 0:
				break
			if state.money < cost:
				## Buy as many pieces as affordable (no overdraft).
				var unit := Tuning.cost_for_pieces(sku, 1)
				if unit <= 0 or state.money < unit:
					break
				var max_pieces := int(state.money / unit)
				max_pieces = mini(max_pieces, need)
				if max_pieces <= 0:
					break
				cost = Tuning.cost_for_pieces(sku, max_pieces)
				state.money -= cost
				stock[sku] = have + max_pieces
				spent += cost
				have = int(stock[sku])
				need = target - have
				break
			state.money -= cost
			stock[sku] = have + chunk
			spent += cost
			have = int(stock[sku])
			need = target - have
	snap["stock"] = stock
	return spent


static func _clerk_wage(snap: Dictionary, posts: Dictionary) -> int:
	## Only regular clerks on branch posts draw wage (elites do not).
	var n := 0
	for post in BranchRules.POST_IDS:
		var ref = posts.get(post, null)
		if ref is Dictionary and String(ref.get("kind", "")) == "clerk":
			n += 1
	return n * BranchRules.WAGE


static func _stock_factor(snap: Dictionary) -> float:
	var developed = snap.get("developed", {})
	var for_sale = snap.get("for_sale", {})
	var stock = snap.get("stock", {})
	if not (developed is Dictionary):
		return 0.2
	var sale_n := 0
	var stocked_n := 0
	for sku_raw in developed.keys():
		var sku := String(sku_raw)
		if not bool(developed.get(sku, false)):
			continue
		if Tuning.is_craft_only(sku):
			continue
		if for_sale is Dictionary and for_sale.has(sku) and not bool(for_sale[sku]):
			continue
		sale_n += 1
		if int(stock.get(sku, 0)) > 0:
			stocked_n += 1
	if sale_n <= 0:
		return 0.2
	return clampf(float(stocked_n) / float(sale_n), 0.2, 1.0)


static func _post_stats(state, snap: Dictionary, posts: Dictionary) -> Dictionary:
	var out := {
		"manager": {"str": 0, "agi": 0, "int": 0},
		"cashier": {"str": 0, "agi": 0, "int": 0},
		"restock": {"str": 0, "agi": 0, "int": 0},
		"cleaner": {"str": 0, "agi": 0, "int": 0},
		"security": {"str": 0, "agi": 0, "int": 0},
	}
	for post in BranchRules.POST_IDS:
		var ref = posts.get(post, null)
		out[post] = _stats_for_ref(state, snap, ref)
	return out


static func _stats_for_ref(state, _snap: Dictionary, ref) -> Dictionary:
	if not (ref is Dictionary):
		return {"str": 0, "agi": 0, "int": 0}
	var kind := String(ref.get("kind", ""))
	if kind == "elite":
		var eid := String(ref.get("id", ""))
		var row := {}
		if state.has_method("elite_clerk_row"):
			row = state.elite_clerk_row(eid)
		if row.is_empty():
			return {"str": 0, "agi": 0, "int": 0}
		var st: Dictionary = EliteClerkCatalog.stats_at(eid, int(row.get("level", 1)))
		return {
			"str": int(st.get("str", 0)),
			"agi": int(st.get("agi", 0)),
			"int": int(st.get("int", 0)),
		}
	if kind == "clerk":
		return {
			"str": BranchRules.CLERK_BASE_STR,
			"agi": BranchRules.CLERK_BASE_AGI,
			"int": BranchRules.CLERK_BASE_INT,
		}
	return {"str": 0, "agi": 0, "int": 0}
