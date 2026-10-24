#!/usr/bin/env python3
"""Static checks for v1.1.0 design-gap constants and docs anchors."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
TUNING = (ROOT / "godot/game/scripts/tuning.gd").read_text(encoding="utf-8")
SKILLS = (ROOT / "godot/game/scripts/skills.gd").read_text(encoding="utf-8")
MOVE = (ROOT / "docs/systemdesign/playermovement.md").read_text(encoding="utf-8")
ULT = (ROOT / "docs/systemdesign/playerultimateskills.md").read_text(encoding="utf-8")


def const_expr(name: str) -> str:
    m = re.search(rf"const {name} := (.+)", TUNING)
    assert m, f"missing {name}"
    return m.group(1).strip()


def const_float(name: str) -> float:
    return float(const_expr(name))


def main() -> None:
    assert "3.0 * BODY_LENGTH" in const_expr("CROWD_RADIUS")
    assert abs(const_float("CROWD_SPEED_MULT") - 0.5) < 1e-6
    assert abs(const_float("DASH_GUEST_DISSAT") - 50.0) < 1e-6
    assert abs(const_float("DASH_GUEST_STUN_SEC") - 2.0) < 1e-6
    assert abs(const_float("TOSS_GUEST_WRONG_DISSAT") - 15.0) < 1e-6
    assert int(const_float("STAT_RESET_FEE_PER_LEVEL")) == 1000
    assert "polite_dash" in SKILLS
    assert "ignore_vomit_sick" in SKILLS
    customer = (ROOT / "godot/game/scripts/customer.gd").read_text(encoding="utf-8")
    clerk = (ROOT / "godot/game/scripts/clerk.gd").read_text(encoding="utf-8")
    assert "dash_knock_guest" in customer
    assert "_begin_checkout" in customer
    assert "accept_toss_box" in customer
    assert "customers_near" in (ROOT / "godot/game/scripts/demo.gd").read_text(encoding="utf-8")
    assert "不包括小偷" in ULT
    assert "唔該借借" in MOVE
    assert "2 秒" in MOVE
    assert "不重抽" in MOVE
    clerk_doc = (ROOT / "docs/systemdesign/clerksystem.md").read_text(encoding="utf-8")
    clean_doc = (ROOT / "docs/systemdesign/cleaningsystem.md").read_text(encoding="utf-8")
    cust_doc = (ROOT / "docs/systemdesign/customer.md").read_text(encoding="utf-8")
    action_doc = (ROOT / "docs/systemdesign/playeraction.md").read_text(encoding="utf-8")
    assert "每幀繼續跟隨" in clerk_doc or "每幀繼續跟蹤" in clerk_doc
    assert "CLERK_JOB_SEARCH_SEC" in clerk_doc
    assert "sit on _job_search_cd" in clerk or "Active plan: keep walking" in clerk
    assert "黃色" in clean_doc and "Loading Circle" in clean_doc
    assert "不重抽" in cust_doc
    assert "清單清空" in action_doc and "收銀" in action_doc
    print("OK design-gap constants / docs anchors")


if __name__ == "__main__":
    try:
        main()
    except AssertionError as e:
        print("FAIL:", e, file=sys.stderr)
        sys.exit(1)
