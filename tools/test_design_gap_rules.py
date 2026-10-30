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
    active_doc = (ROOT / "docs/systemdesign/playeractiveskills.md").read_text(encoding="utf-8")
    thief_doc = (ROOT / "docs/systemdesign/thiefsystem.md").read_text(encoding="utf-8")
    restock_doc = (ROOT / "docs/systemdesign/replenishmentsystem.md").read_text(encoding="utf-8")
    delivery_doc = (ROOT / "docs/systemdesign/customerdelivery.md").read_text(encoding="utf-8")
    assert "每幀繼續跟隨" in clerk_doc or "每幀繼續跟蹤" in clerk_doc
    assert "CLERK_JOB_SEARCH_SEC" in clerk_doc
    assert "sit on _job_search_cd" in clerk or "Active plan: keep walking" in clerk
    assert "黃色" in clean_doc and "Loading Circle" in clean_doc
    assert "不重抽" in cust_doc
    assert "清單清空" in action_doc and "收銀" in action_doc
    assert "thief_sniper" in SKILLS and "guest_sniper" in SKILLS and "shelf_sniper" in SKILLS
    assert "dark_side" in SKILLS and "Dark Side" in SKILLS
    assert "狙擊手（小偷）" in active_doc and "小偷 → 客人 → 貨架" in active_doc
    assert "Dark Side" in active_doc
    assert "多重影分身" in active_doc
    dark = (ROOT / "docs/systemdesign/darkside.md").read_text(encoding="utf-8")
    assert "活線已實作" in dark
    assert "尚未實作" not in dark
    clone = (ROOT / "docs/systemdesign/shadowclone.md").read_text(encoding="utf-8")
    assert "已拍板，未實作" in clone
    assert "shadow_clone" in clone
    assert "不是客人" in clone
    assert "撞到多重影分身" in MOVE
    assert "多重影分身不計入" in MOVE
    stats_doc = (ROOT / "docs/systemdesign/playerstats.md").read_text(encoding="utf-8")
    assert "多重影分身" in stats_doc and "快照" in stats_doc
    assert "多重影分身" in clerk_doc and "不是客人" in clerk_doc
    assert "多重影分身" in cust_doc
    assert "多重影分身" in ULT
    assert "不亮" in action_doc and "多重影分身" in action_doc
    assert "狙擊手（小偷）" in thief_doc
    assert "狙擊手（貨架）" in restock_doc
    assert "狙擊手（客人）" in delivery_doc
    assert "小偷 → 客人 → 貨架" in action_doc
    print("OK design-gap constants / docs anchors")


if __name__ == "__main__":
    try:
        main()
    except AssertionError as e:
        print("FAIL:", e, file=sys.stderr)
        sys.exit(1)
