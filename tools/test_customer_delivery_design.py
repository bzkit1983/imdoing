#!/usr/bin/env python3
"""Check implemented customer-delivery rules and product-version consistency."""
import re
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


need(f'SEMVER := "{VER}"' in PV, "product_version semver matches VERSION")
need(f'TAG := "v{VER}"' in PV, "product_version tag matches VERSION")
need("已實作" in DOC, "doc must say implemented")
need("仍待拍板" in DOC and "沒有。" in DOC, "open questions closed")
need("已拍板" in DOC and "1/4" in DOC, "piece weight locked")
need("近的先" in DOC and "COST 1" in DOC and "5 秒" in DOC, "locked delivery rules")
need("短按取消" in DOC and "只補 1 件" in DOC, "single-piece toss")
need("不再歸零" in DOC and "仍扣 **50**" in DOC, "box dissatisfaction and dash stamina")
need("不再另外加不滿" in DOC and "每一記衝刺都算" in DOC, "dash-delivery window")
need("衝刺交付" in DOC and "親手交付" in DOC, "core flows")
need("dash_deliver" in PLAYER and "func _hand_deliver" in PLAYER, "player implements delivery")
need("func _toss_top_piece" in PLAYER, "single-piece toss")
SKILLS = (ROOT / "godot/game/scripts/skills.gd").read_text(encoding="utf-8")
dash_skill = re.search(r'\{"id": "dash_deliver",[^\n]+', SKILLS)
need(dash_skill is not None, "dash-delivery skill catalog entry")
if dash_skill:
    need('"cost": 1,' in dash_skill.group(), "dash delivery costs 1")
    need('"cd": 5.0' in dash_skill.group() and '"duration": 5.0' in dash_skill.group(), "dash delivery keeps 5-second cooldown and duration")
PROJECT = (ROOT / "godot/game/project.godot").read_text(encoding="utf-8")
need(f'config/version="{VER}"' in PROJECT, "Godot product version matches VERSION")
need("DELIVER_PIECE_DISSAT" in (ROOT / "godot/game/scripts/customer.gd").read_text(encoding="utf-8"), "per-piece dissatisfaction")

if errs:
    print("FAIL")
    for e in errs:
        print("-", e)
    raise SystemExit(1)
print("OK customer delivery rules are implemented")
