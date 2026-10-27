#!/usr/bin/env python3
"""UI fixes: restock list near the clerk, piece-toss stops, larger shelf/list icons."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLAYER = (ROOT / "godot/game/scripts/player.gd").read_text(encoding="utf-8")
RESTOCK = (ROOT / "godot/game/scripts/restock_point.gd").read_text(encoding="utf-8")
CUSTOMER = (ROOT / "godot/game/scripts/customer.gd").read_text(encoding="utf-8")
SHELF = (ROOT / "godot/game/scripts/shelf.gd").read_text(encoding="utf-8")

errs: list[str] = []


def need(ok: bool, msg: str) -> None:
    if not ok:
        errs.append(msg)


start = PLAYER.find("func _toss_top_piece")
end = PLAYER.find("\nfunc ", start + 1)
toss = PLAYER[start:end]
need("_piece_drop_lock = true" in toss, "piece toss stops while the piece is in the air")
need("_move_locked_until_neutral" not in toss, "piece toss must not wait for a neutral stick")
need("velocity = Vector2.ZERO" in toss, "piece toss clears velocity")
landed = PLAYER[PLAYER.find("func _on_piece_drop_landed"):PLAYER.find("\nfunc ", PLAYER.find("func _on_piece_drop_landed") + 1)]
need("_piece_flights > 0" in landed, "another piece in the air keeps the stop")
need("_piece_drop_lock = false" in landed, "the last landing releases the stop")
need("_piece_drop_lock" in PLAYER[PLAYER.find("func _move_axis"):PLAYER.find("\nfunc ", PLAYER.find("func _move_axis") + 1)], "move axis honors the piece-drop stop")
need("func _list_anchor" in RESTOCK, "restock list anchors near the player")
need("get_visible_rect" in RESTOCK, "restock list clamps into the viewport")
need("40.0 if i == 0 else 32.0" in CUSTOMER, "guest list icons enlarged")
need("30.0 / float(SkuIcons.SIZE)" in SHELF, "shelf face icon enlarged")

if errs:
    print("FAIL")
    for e in errs:
        print("-", e)
    raise SystemExit(1)
print("OK restock menu, drop stop, and icon sizes")
