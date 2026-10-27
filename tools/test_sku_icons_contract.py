#!/usr/bin/env python3
"""Contract check for ops SKU icon UI — ids and design locks."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TUNING = ROOT / "godot/game/scripts/tuning.gd"
ICONS = ROOT / "godot/game/scripts/sku_icons.gd"
POPUP = ROOT / "godot/game/scripts/sku_popup.gd"
HUD = ROOT / "godot/game/scripts/hud.gd"
CUST = ROOT / "godot/game/scripts/customer.gd"
SHELF = ROOT / "godot/game/scripts/shelf.gd"
RESTOCK = ROOT / "godot/game/scripts/restock_point.gd"
DOC = ROOT / "docs/systemdesign/ops-sku-icon-ui.md"

SKUS = ["can", "snack", "cup", "drink", "milk", "soda", "icecream", "meat", "rice"]


def main() -> int:
    errors: list[str] = []
    tuning = TUNING.read_text(encoding="utf-8")
    for sku in SKUS:
        if f'"{sku}"' not in tuning:
            errors.append(f"tuning missing {sku}")

    icons = ICONS.read_text(encoding="utf-8")
    for sku in SKUS:
        if f'"{sku}"' not in icons and sku not in ("can",):  # match arms
            pass
    for arm in SKUS:
        if f'"{arm}":' not in icons and f'"{arm}"' not in icons:
            # match uses "can": style
            if not re.search(rf'"{arm}"\s*:', icons):
                errors.append(f"sku_icons missing match arm {arm}")

    if "_fill_soft_bag" not in icons or "_fill_milk_carton" not in icons:
        errors.append("snack/milk distinct drawers missing")
    if "KIND_MISS" not in icons or "KIND_OK" not in icons or "KIND_BAD" not in icons:
        errors.append("badge kinds missing")

    for path, needle in [
        (POPUP, "SkuIcons"),
        (HUD, "_sync_carry_icons"),
        (HUD, "last_i"),
        (CUST, "_sync_list_icons"),
        (CUST, "KIND_MISS"),
        (CUST, "KIND_OK"),
        (CUST, "KIND_BAD"),
        (CUST, "apply_toss_reject(sku"),
        (CUST, "Vector2(0, -84)"),
        (SHELF, "SkuIcons.texture"),
        (RESTOCK, "SkuIcons.texture"),
        (RESTOCK, "_sku_icon"),
        (RESTOCK, "draw_texture_rect"),
    ]:
        text = path.read_text(encoding="utf-8")
        if needle not in text:
            errors.append(f"{path.name} missing {needle}")

    doc = DOC.read_text(encoding="utf-8")
    if "已拍板" not in doc:
        errors.append("design doc not marked 拍板")
    if "末端＝下一丟" not in doc and "末端 = 下一丟" not in doc:
        errors.append("design lock trailing missing")

    cust = CUST.read_text(encoding="utf-8")
    sync = cust[cust.find("func _sync_list_icons") : cust.find("\nfunc ", cust.find("func _sync_list_icons") + 1)]
    if "Thieves keep text label" in sync or "is_thief:" in sync and "_list_icons.visible = false" in sync:
        errors.append("thieves still hide the pictogram shopping list")
    if "_list_label.visible = is_thief" in cust:
        errors.append("thief shopping list still uses the text label")

    if errors:
        print("FAIL")
        for e in errors:
            print(" ", e)
        return 1
    print("OK sku icon UI contract (9 SKUs + P0 wiring)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
