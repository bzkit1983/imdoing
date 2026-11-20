#!/usr/bin/env python3
"""UI fixes: restock list near the clerk, piece-toss stops, larger shelf/list icons."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLAYER = (ROOT / "godot/game/scripts/player.gd").read_text(encoding="utf-8")
TOSS = (ROOT / "godot/game/scripts/player/toss_controller.gd").read_text(encoding="utf-8")
RESTOCK = (ROOT / "godot/game/scripts/restock_point.gd").read_text(encoding="utf-8")
CUSTOMER = (ROOT / "godot/game/scripts/customer.gd").read_text(encoding="utf-8")
SHELF = (ROOT / "godot/game/scripts/shelf.gd").read_text(encoding="utf-8")

errs: list[str] = []


def need(ok: bool, msg: str) -> None:
    if not ok:
        errs.append(msg)


## Short toss: brief foot plant via _toss_move_pause (flight itself does not lock walk).
start = TOSS.find("func toss_top_piece")
end = TOSS.find("\nfunc ", start + 1)
toss = TOSS[start:end]
need("_apply_toss_move_pause" in toss, "piece toss applies a brief move pause")
need("_move_locked_until_neutral" not in toss, "piece toss must not wait for a neutral stick")
pause = TOSS[TOSS.find("func _apply_toss_move_pause"):TOSS.find("\nfunc ", TOSS.find("func _apply_toss_move_pause") + 1)]
need("host._toss_move_pause_left" in pause, "piece toss arms _toss_move_pause_left")
need("host.velocity = Vector2.ZERO" in pause, "piece toss clears velocity on pause")
landed = TOSS[TOSS.find("func on_piece_drop_landed"):TOSS.find("\nfunc ", TOSS.find("func on_piece_drop_landed") + 1)]
need("host._piece_flights" in landed or "_piece_flights" in landed, "landing tracks in-flight piece count")
move_axis = PLAYER[PLAYER.find("func _move_axis"):PLAYER.find("\nfunc ", PLAYER.find("func _move_axis") + 1)]
need("_toss_move_pause_left" in move_axis, "move axis honors the toss move pause")
need("func _toss_top_piece" in PLAYER and "_toss.toss_top_piece" in PLAYER, "player still facades toss_top_piece")
need("func _list_anchor" in RESTOCK, "restock list anchors near the player")
need("get_visible_rect" in RESTOCK, "restock list clamps into the viewport")
need("40.0 if i == 0 else 32.0" in CUSTOMER, "guest list icons enlarged")
need("60.0 / float(SkuIcons.SIZE)" in SHELF, "shelf face icon enlarged")

if errs:
    print("FAIL")
    for e in errs:
        print("-", e)
    raise SystemExit(1)
print("OK restock menu, drop stop, and icon sizes")
