#!/usr/bin/env python3
"""Static checks for tech-review v0.2 F1 demo host extraction."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEMO = (ROOT / "godot/game/scripts/demo.gd").read_text(encoding="utf-8")
WORLD = (ROOT / "godot/game/scripts/host/world_build.gd").read_text(encoding="utf-8")
NET = (ROOT / "godot/game/scripts/host/net_world.gd").read_text(encoding="utf-8")
SETTLE = (ROOT / "godot/game/scripts/host/day_settle.gd").read_text(encoding="utf-8")

errs: list[str] = []


def need(cond: bool, msg: str) -> None:
    if not cond:
        errs.append(msg)


need("WorldBuildScript" in DEMO and "NetWorldScript" in DEMO, "demo preloads host modules")
need("_world_build.bind(self)" in DEMO and "_net.bind(self)" in DEMO, "demo binds host modules")
need("_net.connect_session()" in DEMO, "net session connect from demo ready")
need("func build_furniture(" in WORLD and "func build_floor(" in WORLD, "world_build furniture/floor")
need("func register_net_agent(" in NET and "func apply_agent_spawn_payload(" in NET, "net_world agent sync")
need("static func return_unsold_to_warehouse(" in SETTLE, "day_settle unsold credit")
need("DaySettle.return_unsold_to_warehouse(self)" in DEMO, "demo delegates unsold")
# Inside day_settle.gd there is no class_name — self-calls must be bare static names.
need("DaySettle.add_pieces" not in SETTLE, "day_settle must not self-qualify add_pieces")
need("DaySettle.collect_" not in SETTLE, "day_settle must not self-qualify collect_*")
need("host.sync_stock()" in NET, "net_world stock apply uses host.sync_stock")
need("var was_thief: bool" in NET, "net_world types was_thief")
need("_world_build.build_furniture(nodes)" in DEMO, "demo delegates furniture")
need("_net.register_net_agent(node, kind, extra)" in DEMO, "demo delegates net register")
# Puppets / intent tick stay on demo for F1.
need("func _spawn_customer_puppet(" in DEMO, "customer puppet remains on demo")
need("func _net_tick_intents_and_sync(" in DEMO, "intent tick remains on demo")
need(
    "add_child(node)" in WORLD
    and WORLD.find("add_child(node)") < WORLD.find("node.apply_default_sku"),
    "restock still add_child before apply_default_sku",
)
# host is typed Node — FLOOR_* reads need Vector2 annotations for `:=` inference.
need("var o: Vector2 = host.FLOOR_ORIGIN" in WORLD, "walls_and_door types FLOOR_ORIGIN")
need("var s: Vector2 = host.FLOOR_SIZE" in WORLD, "walls_and_door types FLOOR_SIZE")

if errs:
    print("FAIL")
    for e in errs:
        print("-", e)
    raise SystemExit(1)
print("OK demo host F1 extract")
