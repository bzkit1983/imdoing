#!/usr/bin/env python3
"""Static checks for tech-review v0.2 F1 demo host extraction."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEMO = (ROOT / "godot/game/scripts/demo.gd").read_text(encoding="utf-8")
WORLD = (ROOT / "godot/game/scripts/host/world_build.gd").read_text(encoding="utf-8")
NET = (ROOT / "godot/game/scripts/host/net_world.gd").read_text(encoding="utf-8")
SETTLE = (ROOT / "godot/game/scripts/host/day_settle.gd").read_text(encoding="utf-8")
TOSS = (ROOT / "godot/game/scripts/host/toss_world.gd").read_text(encoding="utf-8")

errs: list[str] = []


def need(cond: bool, msg: str) -> None:
    if not cond:
        errs.append(msg)


need(
    "WorldBuildScript" in DEMO
    and "NetWorldScript" in DEMO
    and "TossWorldScript" in DEMO
    and "CookedWorldScript" in DEMO,
    "demo preloads host modules",
)
need("NetDayChromeScript" in DEMO and "_day_chrome.bind(self)" in DEMO, "demo preloads／binds net_day_chrome")
need("BossWorldScript" in DEMO and "_boss_world.bind(self)" in DEMO, "demo preloads／binds boss_world")
need("DayBeginScript" in DEMO and "_day_begin.bind(self)" in DEMO, "demo preloads／binds day_begin")
need("EarlyCloseScript" in DEMO and "_early_close.bind(self)" in DEMO, "demo preloads／binds early_close")
need("_day_begin.begin_day(" in DEMO, "demo delegates begin_day")
need("_early_close.consider_early_close(" in DEMO, "demo delegates early-close consider")
need("_world_spawn.tick_ambient(" in DEMO, "demo delegates ambient spawn tick")
need(
    "_world_build.bind(self)" in DEMO
    and "_net.bind(self)" in DEMO
    and "_toss_world.bind(self)" in DEMO
    and "_cooked_world.bind(self)" in DEMO,
    "demo binds host modules",
)
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
need("func spawn_dropped_box(" in TOSS and "func _resolve_toss_landing(" in TOSS, "toss_world drop logic")
need("_toss_world.spawn_dropped_box(" in DEMO, "demo delegates toss spawn")
need("host._world.add_child" in TOSS and "host._emit_net_flight" in TOSS, "toss_world uses host for world/net")
## Boss-day wiring adds thin deferred entry points; ambient tick peeled to world_spawn.
need(len(DEMO.splitlines()) <= 4000, f"demo.gd line budget ({len(DEMO.splitlines())} > 4000)")
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
