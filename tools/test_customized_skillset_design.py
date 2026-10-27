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
need("已拍板" in DOC, "answers must be locked")
need("沒有。" in DOC, "open questions closed")
need("COST" in DOC and "5 以內" in DOC, "cost cap")
need("自訂技能組合1" in DOC and "自訂技能組合5" in DOC, "default names use arabic 5")
need("英文字母" in DOC and "10" in DOC, "custom names are at most 10 English letters")
need("立刻寫" in DOC, "edits save immediately")
need("SAVE_VERSION" in DOC and "維持 1" in DOC, "save version stays 1")
need("skill_sets" not in STATE, "game state has no preset list yet")
need('var slots: Array[String]' in STATE, "live line is still one slot row")

if errs:
    print("FAIL")
    for e in errs:
        print("-", e)
    raise SystemExit(1)
print("OK customized skill set is design-only")
