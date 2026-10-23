#!/usr/bin/env python3
"""Assert toss-to-guest completion routes the guest to checkout."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CUSTOMER = ROOT / "godot" / "game" / "scripts" / "customer.gd"


def main() -> int:
    text = CUSTOMER.read_text(encoding="utf-8")
    errs: list[str] = []
    if "func accept_toss_box" not in text:
        errs.append("missing accept_toss_box")
    if "func _begin_checkout" not in text:
        errs.append("missing _begin_checkout helper")
    # Completion path must call checkout, not leave mood stuck on 找不到.
    m = re.search(
        r"func accept_toss_box[\s\S]*?func apply_toss_reject",
        text,
    )
    if not m:
        errs.append("could not locate accept_toss_box body")
    else:
        body = m.group(0)
        if "_begin_checkout" not in body:
            errs.append("accept_toss_box must call _begin_checkout when list done")
        if "shopping.is_empty()" not in body:
            errs.append("accept_toss_box must check shopping.is_empty()")
        if "謝謝！去付款" not in body and "去付款" not in body:
            errs.append("accept_toss_box should set checkout mood")
    after = re.search(r"func _after_think\(\)[\s\S]*?func _begin_checkout", text)
    if not after:
        errs.append("_after_think should handle empty shopping before _begin_checkout")
    else:
        if "shopping.is_empty()" not in after.group(0):
            errs.append("_after_think must bail to checkout when shopping empty")
        if "_begin_checkout" not in after.group(0):
            errs.append("_after_think must call _begin_checkout when empty")
    if errs:
        print("FAIL")
        for e in errs:
            print(" ", e)
        return 1
    print("OK toss-guest checkout path wired in customer.gd")
    return 0


if __name__ == "__main__":
    sys.exit(main())
