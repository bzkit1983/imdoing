extends RefCounted
## Branch-store unlock, posts, policy coeffs, settle constants (branchstore.md).

const ORIGIN_ID := "origin"

const POLICY_HIGH_PRESSURE := "high_pressure"
const POLICY_BALANCED := "balanced"
const POLICY_CUSTOMER_FIRST := "customer_first"
const POLICY_IDS: Array[String] = [
	POLICY_HIGH_PRESSURE,
	POLICY_BALANCED,
	POLICY_CUSTOMER_FIRST,
]

const POST_MANAGER := "manager"
const POST_CASHIER := "cashier"
const POST_RESTOCK := "restock"
const POST_CLEANER := "cleaner"
const POST_SECURITY := "security"
const POST_IDS: Array[String] = [
	POST_MANAGER,
	POST_CASHIER,
	POST_RESTOCK,
	POST_CLEANER,
	POST_SECURITY,
]

const CLERK_BASE_STR := 10
const CLERK_BASE_AGI := 10
const CLERK_BASE_INT := 10

const BRANCH_BASE_REVENUE := 400
const MANAGER_FUND_DIV := 50.0
const K_INT_FUND := 8.0
const K_STR_FUND := 6.0
const K_MGR_OPS := 1.5
const K_AGI_OPS := 0.8
const K_STR_OPS := 0.8
const DAILY_USAGE_PIECES := 16
const WAGE := 100

const SCALE_FACTOR := {
	1: 0.7,
	2: 0.85,
	3: 1.0,
	4: 1.1,
	5: 1.2,
	6: 1.3,
}

const POLICY_MULT := {
	POLICY_HIGH_PRESSURE: {"fund": 1.25, "rating": 0.75},
	POLICY_BALANCED: {"fund": 1.0, "rating": 1.0},
	POLICY_CUSTOMER_FIRST: {"fund": 0.75, "rating": 1.25},
}


static func is_unlocked(themes_cleared) -> bool:
	if themes_cleared is Array:
		return themes_cleared.size() >= 1
	return false


static func normalize_policy(raw: String) -> String:
	var p := String(raw).strip_edges()
	if POLICY_IDS.has(p):
		return p
	return POLICY_BALANCED


static func policy_fund_mult(policy: String) -> float:
	var row = POLICY_MULT.get(normalize_policy(policy), POLICY_MULT[POLICY_BALANCED])
	return float(row.get("fund", 1.0))


static func policy_rating_mult(policy: String) -> float:
	var row = POLICY_MULT.get(normalize_policy(policy), POLICY_MULT[POLICY_BALANCED])
	return float(row.get("rating", 1.0))


static func scale_factor(shop_scale: int) -> float:
	return float(SCALE_FACTOR.get(clampi(shop_scale, 1, 6), 1.0))


static func empty_posts() -> Dictionary:
	return {
		POST_MANAGER: null,
		POST_CASHIER: null,
		POST_RESTOCK: null,
		POST_CLEANER: null,
		POST_SECURITY: null,
	}


static func normalize_posts(raw) -> Dictionary:
	var out := empty_posts()
	if not (raw is Dictionary):
		return out
	for post in POST_IDS:
		out[post] = _normalize_post_ref(raw.get(post, null))
	return out


static func _normalize_post_ref(raw) -> Variant:
	if raw == null:
		return null
	if not (raw is Dictionary):
		return null
	var kind := String(raw.get("kind", ""))
	if kind == "elite":
		var eid := String(raw.get("id", ""))
		if eid == "":
			return null
		return {"kind": "elite", "id": eid}
	if kind == "clerk":
		return {"kind": "clerk", "id": int(raw.get("id", 0))}
	return null


static func has_manager(posts: Dictionary) -> bool:
	var m = posts.get(POST_MANAGER, null)
	return m != null and m is Dictionary


static func store_display_key(theme_id: String) -> String:
	if theme_id == ORIGIN_ID or theme_id == "":
		return "branch.store.origin"
	return "branch.store.%s" % theme_id


static func policy_label_key(policy: String) -> String:
	return "branch.policy.%s" % normalize_policy(policy)


static func post_label_key(post: String) -> String:
	return "branch.post.%s" % post
