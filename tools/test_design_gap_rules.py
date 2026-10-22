#!/usr/bin/env python3
"""Static checks for v1.1.0 design-gap constants and docs anchors."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
TUNING = (ROOT / "godot/game/scripts/tuning.gd").read_text()
SKILLS = (ROOT / "godot/game/scripts/skills.gd").read_text()
GAPS = (ROOT / "docs/systemdesign-gaps.md").read_text()
MOVE = (ROOT / "docs/systemdesign/playermovement.md").read_text()


def const_float(name: str) -> float:
    m = re.search(rf"const {name} := ([0-9.]+)", TUNING)
    assert m, f"missing {name}"
    return float(m.group(1))


def main() -> None:
    body = const_float("BODY_LENGTH")
    assert abs(const_float("CROWD_RADIUS") - 3.0 * body) < 1e-6
    assert abs(const_float("CROWD_SPEED_MULT") - 0.5) < 1e-6
    assert abs(const_float("DASH_GUEST_DISSAT") - 50.0) < 1e-6
    assert abs(const_float("DASH_GUEST_STUN_SEC") - 2.0) < 1e-6
    assert abs(const_float("TOSS_GUEST_WRONG_DISSAT") - 15.0) < 1e-6
    assert int(const_float("STAT_RESET_FEE_PER_LEVEL")) == 1000
    assert "polite_dash" in SKILLS and "true" in SKILLS
    assert "ignore_vomit_sick" in SKILLS
    ult = (ROOT / "docs/systemdesign/playerultimateskills.md").read_text()
    assert "不包括小偷" in ult or "不包括小偷" in GAPS
    assert "唔該借借" in MOVE
    assert "50" in MOVE and "2 秒" in MOVE
    print("OK design-gap constants / docs anchors")


if __name__ == "__main__":
    try:
        main()
    except AssertionError as e:
        print("FAIL:", e, file=sys.stderr)
        sys.exit(1)
