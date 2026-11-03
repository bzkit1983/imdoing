#!/usr/bin/env python3
"""Static checks for prep restock default_sku wiring."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STATE = (ROOT / "godot/game/scripts/game_state.gd").read_text(encoding="utf-8")
PREP = (ROOT / "godot/game/scripts/prep_menu.gd").read_text(encoding="utf-8")
DEMO = (ROOT / "godot/game/scripts/demo.gd").read_text(encoding="utf-8")
RP = (ROOT / "godot/game/scripts/restock_point.gd").read_text(encoding="utf-8")
SHOP = (ROOT / "docs/systemdesign/shopsetup.md").read_text(encoding="utf-8")
REP = (ROOT / "docs/systemdesign/replenishmentsystem.md").read_text(encoding="utf-8")
LOC = (ROOT / "godot/game/locale/strings.csv").read_text(encoding="utf-8")

errs: list[str] = []


def need(cond: bool, msg: str) -> None:
    if not cond:
        errs.append(msg)


need("default_sku" in STATE and "set_restock_default_sku" in STATE, "state default_sku API")
need("is_restock_type" in STATE and "restock_category_of_type" in STATE, "state restock helpers")
need('_try_begin_restock_sku_pick' in PREP and "_commit_sku_pick" in PREP, "prep sku pick")
need("_hold_default_sku" in PREP, "preserve default on pickup")
need("SKU_PICK_HOLD" in PREP, "long-press threshold")
need("apply_default_sku" in DEMO and "apply_default_sku" in RP, "ops apply default")
# apply_default_sku must run after add_child so skus() sees the game group.
_restock_at = DEMO.find("func _restock(")
need(_restock_at >= 0, "_restock helper present")
restock_fn = DEMO[_restock_at : DEMO.find("\nfunc ", _restock_at + 1)]
need(
    "add_child(node)" in restock_fn
    and restock_fn.find("add_child(node)")
    < restock_fn.find("node.apply_default_sku"),
    "_restock must add_child before apply_default_sku",
)
need("default_sku" in SHOP and "長按確定" in SHOP, "shopsetup docs")
need("不回寫" in REP or "不回寫店舖設計" in REP, "ops pick day-only docs")
need("prep.layout.sku_pick" in LOC and "prep.layout.sku_set" in LOC, "locale keys")

if errs:
    print("FAIL")
    for e in errs:
        print("-", e)
    raise SystemExit(1)
print("OK restock default_sku wiring")
