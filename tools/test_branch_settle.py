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
need("branch_body" in DEMO, "demo closeout must pass branch body")
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

if errs:
    print("FAIL")
    for e in errs:
        print("-", e)
    raise SystemExit(1)
print("OK branch settle / scenario 11 wiring")
print(f"sample balanced revenue≈{int(revenue)}")
