#!/usr/bin/env python3
"""Static checks for tech-review v0.2 F3 GameHost hot-path call coverage."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HOST = (ROOT / "godot/game/scripts/host/game_host.gd").read_text(encoding="utf-8")
host_api = set(re.findall(r"^func (\w+)\s*\(", HOST, re.M))

HOT = [
    "godot/game/scripts/customer.gd",
    "godot/game/scripts/clerk.gd",
    "godot/game/scripts/shadow_clone.gd",
    "godot/game/scripts/player.gd",
    "godot/game/scripts/hud.gd",
    "godot/game/scripts/calm_zone.gd",
    "godot/game/scripts/player/fight_controller.gd",
    "godot/game/scripts/player/skill_caster.gd",
    "godot/game/scripts/player/toss_controller.gd",
]

errs: list[str] = []


def need(cond: bool, msg: str) -> None:
    if not cond:
        errs.append(msg)


# Contract grew for F3 hot paths.
for name in (
    "shelf_stand",
    "find_path",
    "world_delta",
    "spawn_dropped_box",
    "spawn_loot_inplace",
    "customers_in_radius",
    "play_is_easy",
    "restock_for",
    "sync_stock",
    "deploy_calm_zone",
    "cast_shadow_clone",
):
    need(name in host_api, f"GameHost missing {name}")

need(len(host_api) >= 80, f"GameHost API too small ({len(host_api)})")

host_objs = r"(?:_game|game|g|host|clone_host)"
duck_re = re.compile(rf"{host_objs}\.(?:call|callv|has_method)\(\s*\"(\w+)\"")

for rel in HOT:
    text = (ROOT / rel).read_text(encoding="utf-8")
    for i, line in enumerate(text.splitlines(), 1):
        for m in duck_re.finditer(line):
            meth = m.group(1)
            if meth in host_api:
                errs.append(f"{rel}:{i} still duck-calls GameHost.{meth}")

if errs:
    print("FAIL")
    for e in errs:
        print(" -", e)
    raise SystemExit(1)
print(f"OK game host F3 ({len(host_api)} APIs; hot paths typed)")
