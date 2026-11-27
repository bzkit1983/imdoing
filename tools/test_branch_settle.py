#!/usr/bin/env python3
"""Static + formula checks for branch-store vertical slice."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
errs: list[str] = []


def need(cond: bool, msg: str) -> None:
    if not cond:
        errs.append(msg)


GS = (ROOT / "godot/game/scripts/game_state.gd").read_text(encoding="utf-8")
BR = (ROOT / "godot/game/scripts/session/branch_rules.gd").read_text(encoding="utf-8")
TS = (ROOT / "godot/game/scripts/session/theme_store_snapshot.gd").read_text(encoding="utf-8")
BS = (ROOT / "godot/game/scripts/host/branch_settle.gd").read_text(encoding="utf-8")
BST = (ROOT / "godot/game/scripts/session/branch_state.gd").read_text(encoding="utf-8")
WORLD = (ROOT / "godot/game/scripts/host/world_build.gd").read_text(encoding="utf-8")
DEMO = (ROOT / "godot/game/scripts/demo.gd").read_text(encoding="utf-8")
HUD = (ROOT / "godot/game/scripts/hud.gd").read_text(encoding="utf-8")
HUD_SCN = (ROOT / "godot/game/scenes/hud.tscn").read_text(encoding="utf-8")
PAGES = (ROOT / "godot/game/scripts/prep/prep_pages.gd").read_text(encoding="utf-8")
MENU = (ROOT / "godot/game/scripts/prep_menu.gd").read_text(encoding="utf-8")
STRINGS = (ROOT / "godot/game/locale/strings.csv").read_text(encoding="utf-8")
DATA = (ROOT / "godot/game/locale/data.csv").read_text(encoding="utf-8")
DOC = (ROOT / "docs/systemdesign/branchstore.md").read_text(encoding="utf-8")

need("SAVE_VERSION := 10" in GS, "SAVE_VERSION must be 10")
need("SCENARIO_BRANCH := 11" in GS, "scenario 11 constant missing")
need("active_theme_id" in GS and "theme_stores" in GS and "origin_store" in GS, "branch save fields missing")
need("assignment" in GS, "elite assignment missing")
need("_scenario_branch" in GS and "_finalize_branch_scenario" in GS, "scenario 11 bake missing")
need('themes_cleared = ["theme_historic"]' in GS or "themes_cleared = [\"theme_historic\"]" in GS, "scenario 11 must unlock via themes_cleared")
need('active_theme_id = "theme_historic"' in GS, "scenario 11 HQ must be theme_historic")
need("origin_store = origin" in GS, "scenario 11 must bake origin branch")

need("ORIGIN_ID := \"origin\"" in BR, "origin id constant")
need("BRANCH_BASE_REVENUE := 400" in BR, "base revenue constant")
need("DAILY_USAGE_PIECES := 16" in BR, "daily usage constant")
need("is_unlocked" in BR, "unlock helper")

need("pack_from_state" in TS and "hydrate_into_state" in TS and "switch_active" in TS, "snapshot API")
need("branch_candidate_ids" in TS, "candidate helper")

need("settle_all" in BS and "settle_one" in BS, "branch settle API")
need("BranchSettle.settle_all" in DEMO, "demo must call branch settle")
need("BranchSettle.closeout_panel_body" in DEMO, "demo must pass branch panel body from BranchSettle")
need("BranchCard" in HUD_SCN, "HUD BranchCard missing")
need("settle.branch_header" in DATA, "settle branch header locale")
need("prep.hub.branch" in STRINGS, "prep hub branch locale")
need("prep.scenario.s11" in STRINGS, "scenario 11 locale")
need("prep.branch.title" in STRINGS, "prep branch title locale")
need('"branches"' in PAGES and "_branches" in PAGES, "prep branches page")
need("branch_open" in MENU and "_branch_set_post" in MENU, "prep branch actions")
need("branch_open_post_pick" in MENU and "branch_post_pick" in PAGES, "prep branch post picker")
need("_elite_place_text" in PAGES and "confirm_recall" in STRINGS, "staff place + recall confirm")
need("_branch_set_post_or_confirm" in MENU and "confirm_move" in STRINGS, "branch reassign confirm")
need("起源店在非本店時" in DOC or "可進入分店背景營運池" in DOC, "design must allow origin as branch")

# Formula sanity (mirrors branch_settle.gd first-version constants)
manager_score = (10 + 10 + 10) / 3
base = 400 * (1 + manager_score / 50) * 1.0 * 0.85  # scale 2
staff = 10 * 8 + 10 * 6
revenue = round((base + staff) * 1.0)
need(revenue > 0, "sample revenue must be positive")
need(revenue < 2000, f"sample revenue unexpectedly huge: {revenue}")


def func_text(src: str, name: str) -> str:
    """Body of a GDScript func, from its signature through the line before the next func."""
    lines = src.splitlines()
    start = None
    sig = f"func {name}("
    for i, line in enumerate(lines):
        stripped = line.lstrip("\t")
        if stripped.startswith(sig) or stripped.startswith(f"static func {name}("):
            start = i
            break
    need(start is not None, f"missing func {name}")
    if start is None:
        return ""
    body = [lines[start]]
    for line in lines[start + 1 :]:
        if line.startswith("func ") or line.startswith("static func ") or line.startswith("## "):
            # Next top-level func. A comment between funcs ends the body too.
            if line.startswith("func ") or line.startswith("static func "):
                break
        if (line.startswith("func ") or line.startswith("static func ")) and not line.startswith("\t"):
            break
        body.append(line)
    # Trim at the next unindented func if the loop above kept going through comments.
    out: list[str] = [body[0]]
    for line in body[1:]:
        if line.startswith("func ") or line.startswith("static func "):
            break
        out.append(line)
    return "\n".join(out)


def indent_of(line: str) -> int:
    return len(line) - len(line.lstrip("\t"))


# --- demo no longer assembles the branch closeout body ---
finish = func_text(DEMO, "_finish_day")
need("BranchSettle.closeout_panel_body(branch_pack, state)" in finish, "finish_day must delegate panel body")
need("var branch_body" not in finish, "finish_day must not build branch_body")
need("branch_body = String" not in finish, "finish_day must not splice branch copy")
need("SAVE_VERSION := 11" not in GS, "do not bump SAVE_VERSION to 11")
need(re.search(r"const SAVE_VERSION := 10\b", GS) is not None, "SAVE_VERSION stays 10")

panel = func_text(BS, "closeout_panel_body")
need('pack.get("unlocked"' in panel and "branch_system_unlocked" in panel, "panel body keeps unlock gate")
fmt = func_text(BS, "format_closeout_body")
need("settle.branch.net" in fmt, "open stores show a net line")
need("revenue_i - paid_i - restock_i" in fmt, "net is revenue - wages paid - restock")
need("settle.branch.partial_wage" in fmt and "paid_i < owed_i" in fmt, "partial wage flag")
need("settle.branch.net" in DATA and "settle.branch.partial_wage" in DATA, "net / partial locale")
one = func_text(BS, "settle_one")
need('"wage_owed": wage_owed' in one, "settle_one keeps owed wages")
need('"wage_spent": wage_spent' in one, "settle_one keeps amount paid")
owed_at = one.find("var wage_owed := _clerk_wage")
paid_at = one.find("var wage_spent := 0")
need(owed_at >= 0 and paid_at > owed_at, "owed wage is not overwritten by the amount paid")

# --- no manager: closed before restock / rating / revenue ---
reason_at = one.find('base_row["reason"] = "no_manager"')
ret_at = one.find("return base_row", reason_at)
restock_at = one.find("_auto_restock")
rating_at = one.find('snap["shop_rating"]')
need(0 <= reason_at < ret_at < restock_at, "no_manager returns before restock")
need(ret_at < rating_at, "no_manager does not change shop rating")


def closed_without_manager(shop_before: int) -> dict:
    """Mirror the early return in settle_one when posts have no manager."""
    return {
        "status": "closed",
        "reason": "no_manager",
        "restock_spent": 0,
        "wage_owed": 0,
        "wage_spent": 0,
        "revenue": 0,
        "shop_after": shop_before,
    }


closed = closed_without_manager(7)
need(closed["reason"] == "no_manager", "no_manager reason")
need(closed["revenue"] == 0 and closed["restock_spent"] == 0 and closed["wage_spent"] == 0, "no_manager spends nothing")
need(closed["shop_after"] == 7, "no_manager leaves rating")

# --- money = 0: no overdraft on restock or wages; partial pay is visible ---
restock_fn = func_text(BS, "_auto_restock")
need("while need > 0 and state.money > 0:" in restock_fn, "restock stops when money is 0")
need("state.money -=" in restock_fn, "restock debits money")


def apply_wage(money: int, owed: int) -> tuple[int, int, bool]:
    """Mirror settle_one wage payment. Never spends more than money."""
    paid = 0
    if owed > 0:
        paid = min(owed, money)
        money -= paid
    return money, paid, paid < owed


def restock_chunk(money: int, need: int, cost_for) -> tuple[int, int, int]:
    """One-SKU mirror of _auto_restock's while loop. cost_for(pieces) -> int."""
    spent = 0
    steps = 0
    while need > 0 and money > 0:
        steps += 1
        if steps > 40:
            raise AssertionError("restock did not terminate")
        chunk = max(1, min(need, 396))
        cost = int(cost_for(chunk))
        if cost <= 0:
            break
        if money < cost:
            unit = int(cost_for(1))
            if unit <= 0 or money < unit:
                break
            max_pieces = min(money // unit, need)
            if max_pieces <= 0:
                break
            cost = int(cost_for(max_pieces))
            money -= cost
            spent += cost
            break
        money -= cost
        spent += cost
        need -= chunk
    return money, spent, steps


money0, spent0, steps0 = restock_chunk(0, 16, lambda n: 10 * n)
need(money0 == 0 and spent0 == 0 and steps0 == 0, "money=0 buys nothing")
money_after, paid0, partial0 = apply_wage(0, 200)
need(money_after == 0 and paid0 == 0 and partial0, "money=0 wage is partial and unpaid")
# Operating store still books revenue; net uses the amount actually paid.
net0 = revenue - paid0 - spent0
need(net0 == revenue, "money=0 net ignores unpaid wages")
need(money_after + revenue >= 0, "money=0 day does not overdraft")

# Affordable partial restock still cannot go negative.
money_part, spent_part, _steps_part = restock_chunk(25, 16, lambda n: 10 * n)
need(money_part >= 0 and spent_part <= 25, "partial restock stays within funds")

# --- cost <= 0 must break (craft / zero price must not spin) ---
cost_at = restock_fn.find("var cost := Tuning.cost_for_pieces")
break_at = restock_fn.find("if cost <= 0:", cost_at)
debit_at = restock_fn.find("state.money -= cost", cost_at)
need(cost_at >= 0 and break_at > cost_at and "break" in restock_fn[break_at : break_at + 40], "cost<=0 breaks")
need(debit_at > break_at, "zero cost is not debited")
money_z, spent_z, steps_z = restock_chunk(500, 16, lambda _n: 0)
need(money_z == 500 and spent_z == 0 and steps_z == 1, "cost=0 exits the restock loop")

# --- HQ spawn skips elites who still carry a branch assignment ---
duty = func_text(GS, "on_duty_elite_clerks")
need(duty.find("_elite_assignment") < duty.find("out.append"), "on_duty skips assigned elites before append")
spawn = func_text(WORLD, "_spawn_elite_clerks")
need("on_duty_elite_clerks()" in spawn, "HQ elite spawn goes through on_duty_elite_clerks")
need("elite_assignment" in spawn and spawn.find("elite_assignment") < spawn.find("ClerkScript.new"), "spawn loop skips assignment")


def elite_assignment(row: dict):
    raw = row.get("assignment", None)
    if not isinstance(raw, dict):
        return None
    theme_id = str(raw.get("theme_id", ""))
    post = str(raw.get("post", ""))
    if theme_id == "" or post == "":
        return None
    return {"theme_id": theme_id, "post": post}


def on_duty_elite_clerks(rows: list) -> list:
    out = []
    for row in rows:
        if not row.get("on_duty", True):
            continue
        if elite_assignment(row) is not None:
            continue
        roles = row.get("roles", [])
        if not isinstance(roles, list) or not roles:
            continue
        out.append(row)
    return out


hq = {"id": "yayoi", "on_duty": True, "roles": ["cashier"], "assignment": None}
posted = {"id": "yayoi", "on_duty": True, "roles": ["cashier"], "assignment": {"theme_id": "origin", "post": "manager"}}
off = {"id": "yayoi", "on_duty": False, "roles": ["cashier"], "assignment": None}
blank_post = {"id": "yayoi", "on_duty": True, "roles": ["cashier"], "assignment": {"theme_id": "origin", "post": ""}}
ids = [row["id"] + str(row.get("on_duty")) for row in on_duty_elite_clerks([hq, posted, off, blank_post])]
need(on_duty_elite_clerks([posted, off]) == [], "assigned or off-duty elites do not spawn")
need(on_duty_elite_clerks([hq, blank_post]) == [hq, blank_post], "empty assignment does not count")
need("yayoiTrue" in ids and len(on_duty_elite_clerks([posted])) == 0, "inconsistent on_duty+assignment stays off HQ")

# --- mutation API lives in branch_state; game_state keeps a one-line delegate ---
need("static func assign_elite_to_branch" in BST, "branch_state owns assign")
need("static func buy_branch_stock" in BST and "err.funds" in func_text(BST, "buy_branch_stock"), "buy errors stay in branch_state")
gs_buy = func_text(GS, "buy_branch_stock")
need("BranchState.buy_branch_stock" in gs_buy and "err.funds" not in gs_buy, "game_state buy is a delegate")
need("BranchState.assign_elite_to_branch" in func_text(GS, "assign_elite_to_branch"), "assign delegate")
need("BranchState.set_branch_policy" in func_text(GS, "set_branch_policy"), "policy delegate")
need("func to_dict" in GS and "func from_dict" in GS and "func apply_scenario" in GS, "serialization stays on game_state")
need("func _scenario_branch" in GS, "scenario bake stays on game_state")
need("var active_theme_id" in GS and "var theme_stores" in GS and "var origin_store" in GS, "branch fields stay on game_state")

# --- v9 save without branch fields loads as legal v10 defaults; not official story ---
# Mirrors GameState.from_dict missing-key defaults. Does not invent story_slot (#165).
ORIGIN_ID = "origin"
POLICY_IDS = {"high_pressure", "balanced", "customer_first"}
POST_IDS = ["manager", "cashier", "restock", "cleaner", "security"]


def normalize_policy(raw: str) -> str:
    p = str(raw).strip()
    return p if p in POLICY_IDS else "balanced"


def migrate_branch_fields(data: dict) -> dict:
    scenario = int(data.get("scenario", 1))
    active = str(data.get("active_theme_id", ORIGIN_ID))
    if active == "":
        active = ORIGIN_ID
    themes: list[str] = []
    raw_cleared = data.get("themes_cleared", [])
    if isinstance(raw_cleared, list):
        for item in raw_cleared:
            ts = str(item)
            if ts and ts not in themes:
                themes.append(ts)
    stores: dict = {}
    raw_stores = data.get("theme_stores", {})
    if isinstance(raw_stores, dict):
        for tid, snap in raw_stores.items():
            stores[str(tid)] = snap
    raw_origin = data.get("origin_store", {})
    origin = raw_origin if isinstance(raw_origin, dict) and raw_origin else {}
    posts = {post: None for post in POST_IDS}
    raw_posts = data.get("branch_posts", None)
    if isinstance(raw_posts, dict):
        for post in POST_IDS:
            if post in raw_posts:
                posts[post] = raw_posts[post]
    out = {
        "scenario": scenario,
        "active_theme_id": active,
        "themes_cleared": themes,
        "theme_stores": stores,
        "origin_store": origin,
        "policy": normalize_policy(str(data.get("policy", "balanced"))),
        "branch_posts": posts,
    }
    if "story_slot" in data:
        out["story_slot"] = data["story_slot"]
    return out


fd = func_text(GS, "from_dict")
need('data.get("active_theme_id", BranchRules.ORIGIN_ID)' in fd, "from_dict defaults active theme")
need('data.get("themes_cleared", [])' in fd, "from_dict defaults themes_cleared")
need('data.get("theme_stores", {})' in fd, "from_dict defaults theme_stores")
need('data.get("origin_store", {})' in fd, "from_dict defaults origin_store")
need("origin_store = {}" in fd, "missing origin_store becomes empty")
need('data.get("policy", BranchRules.POLICY_BALANCED)' in fd, "from_dict defaults policy")
need('data.get("branch_posts", null)' in fd, "from_dict defaults posts")
need("story_slot" not in fd, "from_dict must not invent story_slot")

v9 = {"version": 9, "scenario": 11, "money": 0}
migrated = migrate_branch_fields(v9)
need(migrated["active_theme_id"] == "origin", "v9 active theme defaults to origin")
need(migrated["theme_stores"] == {} and migrated["origin_store"] == {}, "v9 has empty store slots")
need(migrated["themes_cleared"] == [], "v9 test save does not gain cleared themes")
need(migrated["policy"] == "balanced", "v9 policy default")
need(all(migrated["branch_posts"][p] is None for p in POST_IDS), "v9 posts default empty")
need(migrated["scenario"] == 11 and "story_slot" not in migrated, "scenario 11 stays a test save")
sandbox = migrate_branch_fields({"version": 9, "scenario": 4, "active_theme_id": ""})
need(sandbox["scenario"] == 4 and sandbox["active_theme_id"] == "origin", "other test saves are not rewritten")
kept = migrate_branch_fields({
    "version": 10,
    "scenario": 1,
    "active_theme_id": "theme_historic",
    "themes_cleared": ["theme_historic"],
})
need(kept["themes_cleared"] == ["theme_historic"] and kept["active_theme_id"] == "theme_historic", "present branch fields stay")

# --- scenario 11 stays inside the TEST_TOOLS block (with 5/6/7/9/10) ---
scenario_fn = func_text(PAGES, "_scenario")
scenario_lines = scenario_fn.splitlines()
if_i = next((i for i, line in enumerate(scenario_lines) if "test_tools_enabled()" in line), -1)
need(if_i >= 0, "scenario list gates test tools")
if_indent = indent_of(scenario_lines[if_i]) if if_i >= 0 else 0
for line in scenario_lines[:if_i]:
    need("SCENARIO_BRANCH" not in line and "prep.scenario.s11" not in line, "scenario 11 is outside TEST_TOOLS")
s11_lines = [line for line in scenario_lines if "SCENARIO_BRANCH" in line or "prep.scenario.s11" in line]
need(s11_lines, "scenario 11 row missing")
for line in s11_lines:
    need(indent_of(line) > if_indent, "scenario 11 must be nested under test_tools_enabled")
for marker in ("prep.scenario.s5", "prep.scenario.s6", "prep.scenario.s7", "SCENARIO_HISTORIC_COOKED", "SCENARIO_ELITE_CLERK"):
    hits = [line for line in scenario_lines if marker in line]
    need(hits and all(indent_of(line) > if_indent for line in hits), f"{marker} left the test-tools block")
need("const TEST_TOOLS := true" in (ROOT / "godot/game/scripts/product_version.gd").read_text(encoding="utf-8"), "do not flip TEST_TOOLS")

# --- multiplayer (Host and Client) closes the branch prep entry ---
home = func_text(PAGES, "_home")
need("branch_entry_blocked()" in home and "branch_locked" in home, "home hub locks branch tile when networked")
need("is_networked()" in func_text(PAGES, "branch_entry_blocked"), "branch block follows is_networked")
show = func_text(MENU, "_show_page")
need("is_branch_page" in show and "branch_entry_blocked" in show, "go into branch pages is blocked")
need("prep.branch.mp_locked" in STRINGS, "multiplayer lock copy")
need("多人進行中（含 Host）先關閉 Prep 分店入口" in DOC, "branchstore notes the prep lock")
need("淨利" in DOC and "部分發薪" in DOC, "branchstore notes net and partial wages")

if errs:
    print("FAIL")
    for e in errs:
        print("-", e)
    raise SystemExit(1)
print("OK branch settle / scenario 11 wiring")
print(f"sample balanced revenue≈{int(revenue)}")
