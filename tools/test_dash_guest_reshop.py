#!/usr/bin/env python3
"""Assert dash-KO guest keeps shopping list and rebuys (no re-roll)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CUSTOMER = ROOT / "godot" / "game" / "scripts" / "customer.gd"
MOVE_DOC = ROOT / "docs" / "systemdesign" / "playermovement.md"


def main() -> int:
    text = CUSTOMER.read_text(encoding="utf-8")
    errs: list[str] = []
    m = re.search(r"func dash_knock_guest[\s\S]*?func _play_dash_ko_hop", text)
    if not m:
        errs.append("missing dash_knock_guest body")
    else:
        body = m.group(0)
        if "_roll_list()" in body:
            errs.append("dash_knock_guest must not call _roll_list() (keep list)")
        if "rebuy" not in body and "shopping =" not in body:
            errs.append("dash_knock_guest must rebuild shopping from cart+shopping")
        if "for s in cart" not in body or "for s in shopping" not in body:
            errs.append("dash_knock_guest should append cart then remaining shopping")
        if "_drop_cart_inplace" not in body:
            errs.append("dash_knock_guest should still drop cart inplace")
    doc = MOVE_DOC.read_text(encoding="utf-8")
    if "重抽清單" in doc:
        errs.append("playermovement.md still says 重抽清單")
    if "購物清單不變" not in doc:
        errs.append("playermovement.md should say 購物清單不變")
    if errs:
        print("FAIL")
        for e in errs:
            print(" ", e)
        return 1
    print("OK dash-guest reshop keeps list (no re-roll)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
