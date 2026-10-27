#!/usr/bin/env python3
"""customizedskillset.md stays a design doc until the open questions are closed."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOC = (ROOT / "docs/systemdesign/customizedskillset.md").read_text(encoding="utf-8")
STATE = (ROOT / "godot/game/scripts/game_state.gd").read_text(encoding="utf-8")

errs: list[str] = []


def need(ok: bool, msg: str) -> None:
    if not ok:
        errs.append(msg)


need("尚未實作" in DOC, "doc must stay unimplemented")
need("仍待拍板" in DOC, "open questions section")
need("COST" in DOC and "5 以內" in DOC, "cost cap")
need("自訂技能組合1" in DOC and "自訂技能組合五" in DOC, "default names from the request")
need("SAVE_VERSION" in DOC, "save version called out")
need("skill_sets" not in STATE, "game state has no preset list yet")
need('var slots: Array[String]' in STATE, "live line is still one slot row")

if errs:
    print("FAIL")
    for e in errs:
        print("-", e)
    raise SystemExit(1)
print("OK customized skill set is design-only")
