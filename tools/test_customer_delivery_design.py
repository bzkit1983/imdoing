#!/usr/bin/env python3
"""customerdelivery.md is design-only and names the live-line conflicts."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOC = (ROOT / "docs/systemdesign/customerdelivery.md").read_text(encoding="utf-8")
VER = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
PV = (ROOT / "godot/game/scripts/product_version.gd").read_text(encoding="utf-8")
PLAYER = (ROOT / "godot/game/scripts/player.gd").read_text(encoding="utf-8")

errs: list[str] = []


def need(ok: bool, msg: str) -> None:
    if not ok:
        errs.append(msg)


need(VER == "1.2.0", f"VERSION should be 1.2.0, got {VER!r}")
need('TAG := "v1.2.0"' in PV, "product_version tag")
need("尚未實作" in DOC, "doc must say not implemented")
need("待拍板" in DOC, "open questions section")
need("衝刺交付" in DOC and "親手交付" in DOC and "短按" in DOC, "core flows")
need("禮貌衝撞" in DOC and "Screen KO" in DOC, "dash conflict called out")
for n in range(1, 15):
    need(f"{n}. **" in DOC or f"{n}. " in DOC, f"question {n}")
need("衝刺交付" not in PLAYER, "do not implement dash-delivery in player.gd yet")

if errs:
    print("FAIL")
    for e in errs:
        print("-", e)
    raise SystemExit(1)
print("OK customer delivery design (not implemented)")
