#!/usr/bin/env python3
"""Static checks for tech-review v0.2 J2 drop-flight / VFX object pools."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DROP = (ROOT / "godot/game/scripts/drop_flight.gd").read_text(encoding="utf-8")
FX = (ROOT / "godot/game/scripts/fx_burst.gd").read_text(encoding="utf-8")
FLOAT = (ROOT / "godot/game/scripts/ui/float_text.gd").read_text(encoding="utf-8")
DEMO = (ROOT / "godot/game/scripts/demo.gd").read_text(encoding="utf-8")
NET = (ROOT / "godot/game/scripts/host/net_world.gd").read_text(encoding="utf-8")

errs: list[str] = []


def need(cond: bool, msg: str) -> None:
    if not cond:
        errs.append(msg)


need("static func acquire(" in DROP and "func _recycle(" in DROP, "drop_flight pool acquire/recycle")
need("static var _pool" in DROP and "POOL_CAP" in DROP, "drop_flight pool storage")
need("queue_free()" in DROP and "_pool.append" in DROP, "drop_flight caps with free overflow")

need("static func spawn(" in FX and "func _recycle(" in FX, "fx_burst pool spawn/recycle")
need("_frames_cache" in FX, "fx_burst caches textures across reuse")

need("func _recycle(" in FLOAT and "static var _pool" in FLOAT, "float_text pool")
need("_tween.kill()" in FLOAT or "kill()" in FLOAT, "float_text kills tween on recycle")

need("DropFlightScript.acquire()" in DEMO, "demo acquires drop flights")
need("CONNECT_ONE_SHOT" in DEMO, "demo finished listeners are one-shot")
need("DropFlightScript.new()" not in DEMO, "demo no longer news drop flights")
need("DropFlightScript.acquire()" in NET, "net_world acquires drop flights")
need("DropFlightScript.new()" not in NET, "net_world no longer news drop flights")

if errs:
    print("FAIL")
    for e in errs:
        print(" -", e)
    raise SystemExit(1)
print("OK vfx pool J2")
