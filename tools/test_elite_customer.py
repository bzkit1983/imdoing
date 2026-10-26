#!/usr/bin/env python3
"""Static checks for EliteCustomer (麻煩客人) wiring."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CUSTOMER = (ROOT / "godot/game/scripts/customer.gd").read_text(encoding="utf-8")
DEMO = (ROOT / "godot/game/scripts/demo.gd").read_text(encoding="utf-8")
TUNING = (ROOT / "godot/game/scripts/tuning.gd").read_text(encoding="utf-8")
STATE = (ROOT / "godot/game/scripts/game_state.gd").read_text(encoding="utf-8")
DOC = (ROOT / "docs/systemdesign/elitecustomer.md").read_text(encoding="utf-8")
LOCALE = (ROOT / "godot/game/locale/strings.csv").read_text(encoding="utf-8")


def main() -> int:
    errs: list[str] = []
    PREP = (ROOT / "godot/game/scripts/prep/prep_pages.gd").read_text(encoding="utf-8")
    PREP_MENU = (ROOT / "godot/game/scripts/prep_menu.gd").read_text(encoding="utf-8")
    for needle, where in [
        ("func become_elite", CUSTOMER),
        ("func payout_total", CUSTOMER),
        ("smash_shelf", CUSTOMER),
        ("passive_shop", CUSTOMER),
        ("elite_ruck_cart", CUSTOMER),
        ("elite_drive_off", CUSTOMER),
        ("ELITE_SPAWN_CHANCE_MIN", TUNING),
        ("ELITE_REVENUE_MULT", TUNING),
        ("announce_elite_customer", DEMO),
        ("queue_elite_zoom", DEMO),
        ("customers_in_radius", DEMO),
        ("spawn_dirt_at", DEMO),
        ("configure_elite_test", DEMO),
        ("elite_test_need_one", DEMO),
        ("XP_ELITE_SERVE", STATE),
        ("demo.elite_banner", LOCALE),
        ("prep.home.elite_test", LOCALE),
        ("prep.elite_test.mixed", LOCALE),
        ("麻煩客人注意", LOCALE),
        ("1%–5%", DOC),
        ("清空該架", DOC),
        ("_elite_test", PREP),
        ("elite_open", PREP_MENU),
    ]:
        if needle not in where:
            errs.append(f"missing {needle!r}")
    if "become_elite" not in DEMO:
        errs.append("demo spawn should call become_elite")
    if not re.search(r"elite_spawn_chance", DEMO):
        errs.append("demo should roll elite_spawn_chance")
    if "ELITE_TEST_SPAWN_CHANCE" not in DEMO:
        errs.append("elite test mode should use ELITE_TEST_SPAWN_CHANCE")
    tun = (ROOT / "godot/game/scripts/tuning.gd").read_text(encoding="utf-8")
    if "ELITE_TEST_SPAWN_CHANCE" not in tun:
        errs.append("tuning missing ELITE_TEST_SPAWN_CHANCE")
    if "payout_total" not in (ROOT / "godot/game/scripts/player.gd").read_text(encoding="utf-8"):
        errs.append("player checkout should use payout_total")
    if "elite_test_need_one" not in DEMO or "elite_test_need_one = false" not in DEMO:
        errs.append("guaranteed first elite should clear elite_test_need_one")
    if "約 40%" not in DOC and "40%" not in DOC:
        errs.append("elitecustomer.md should note elevated test spawn rate")
    if errs:
        print("FAIL")
        for e in errs:
            print(" ", e)
        return 1
    print("OK EliteCustomer wiring")
    return 0


if __name__ == "__main__":
    sys.exit(main())
