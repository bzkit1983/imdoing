#!/usr/bin/env python3
"""Static checks for tech-review v0.2 F2 player controller extraction."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLAYER = (ROOT / "godot/game/scripts/player.gd").read_text(encoding="utf-8")
TOSS = (ROOT / "godot/game/scripts/player/toss_controller.gd").read_text(encoding="utf-8")
FIGHT = (ROOT / "godot/game/scripts/player/fight_controller.gd").read_text(encoding="utf-8")
SKILL = (ROOT / "godot/game/scripts/player/skill_caster.gd").read_text(encoding="utf-8")
CHECKOUT = (ROOT / "godot/game/scripts/player/checkout_controller.gd").read_text(encoding="utf-8")
INPUT = (ROOT / "godot/game/scripts/player/input_controller.gd").read_text(encoding="utf-8")
WORK = (ROOT / "godot/game/scripts/player/work_ticker.gd").read_text(encoding="utf-8")
INTERACT = (ROOT / "godot/game/scripts/player/interact_controller.gd").read_text(encoding="utf-8")

errs: list[str] = []


def need(cond: bool, msg: str) -> None:
    if not cond:
        errs.append(msg)


need("TossControllerScript" in PLAYER, "player preloads toss_controller")
need("FightControllerScript" in PLAYER, "player preloads fight_controller")
need("SkillCasterScript" in PLAYER, "player preloads skill_caster")
need("CheckoutControllerScript" in PLAYER, "player preloads checkout_controller")
need("InputControllerScript" in PLAYER, "player preloads input_controller")
need("WorkTickerScript" in PLAYER, "player preloads work_ticker")
need("InteractControllerScript" in PLAYER, "player preloads interact_controller")
need("_toss.bind(self)" in PLAYER, "player binds toss")
need("_fight_ctrl.bind(self)" in PLAYER, "player binds fight")
need("_skills.bind(self)" in PLAYER, "player binds skills")
need("_checkout.bind(self)" in PLAYER, "player binds checkout")
need("_input_ctrl.bind(self)" in PLAYER, "player binds input")
need("_work.bind(self)" in PLAYER, "player binds work")
need("_interact.bind(self)" in PLAYER, "player binds interact")

need("extends RefCounted" in TOSS and "func bind(" in TOSS, "toss is host-bound RefCounted")
need("extends RefCounted" in FIGHT and "func bind(" in FIGHT, "fight is host-bound RefCounted")
need("extends RefCounted" in SKILL and "func bind(" in SKILL, "skill is host-bound RefCounted")
need("extends RefCounted" in CHECKOUT and "func bind(" in CHECKOUT, "checkout is host-bound RefCounted")
need("extends RefCounted" in INPUT and "func bind(" in INPUT, "input is host-bound RefCounted")
need("extends RefCounted" in WORK and "func bind(" in WORK, "work is host-bound RefCounted")
need("extends RefCounted" in INTERACT and "func bind(" in INTERACT, "interact is host-bound RefCounted")

need("func launch_piece_toss(" in TOSS and "func toss_top_piece(" in TOSS, "toss launch/toss_top")
need("func play_ko_sequence(" in FIGHT and "func end_fight(" in FIGHT, "fight KO/end")
need("func cast_slot(" in SKILL and "func cast_ultimate(" in SKILL, "skill cast paths")
need("func tick_cashier(" in CHECKOUT and "func try_dir(" in CHECKOUT, "checkout tick/try_dir")
need("func set_hold(" in INPUT and "func move_axis(" in INPUT and "func input(" in INPUT, "input hold/move/input")
need("func tick_action(" in WORK and "func tick_restock(" in WORK and "func tick_clean(" in WORK, "work ticks")
need("func do_short_interact(" in INTERACT and "func hand_deliver(" in INTERACT and "func try_pickup(" in INTERACT, "interact actions")

# Facades remain on player (call sites / puppets keep working).
need("func _launch_piece_toss(" in PLAYER, "launch facade on player")
need("await _fight_ctrl.play_ko_sequence(" in PLAYER, "KO sequence awaits controller")
need("func _cast_slot(" in PLAYER, "cast_slot facade on player")
need("_toss.launch_piece_toss(" in PLAYER, "launch delegates to toss")
need("_skills.cast_slot(" in PLAYER, "cast_slot delegates to skills")
need("_checkout.tick_cashier(" in PLAYER, "tick_cashier delegates to checkout")
need("_checkout.try_dir(" in PLAYER, "try_dir delegates to checkout")
need("_input_ctrl.set_hold(" in PLAYER, "set_hold delegates to input")
need("_input_ctrl.move_axis(" in PLAYER, "move_axis delegates to input")
need("func set_hold(" in PLAYER and "func move_state(" in PLAYER, "hold/move_state facades on player")
need("_work.tick_action(" in PLAYER and "_work.tick_clean(" in PLAYER, "work ticks delegate")
need("func _tick_action(" in PLAYER and "func _tick_triggers(" in PLAYER, "work facades stay on player")
need("_interact.hand_deliver(" in PLAYER and "func _hand_deliver(" in PLAYER, "deliver facade stays on player")
need("_interact.do_short_interact(" in PLAYER, "short interact delegates")

# Parse hazards learned from F1 / F2 rewrites.
_HOSTED = (TOSS, SKILL, CHECKOUT, INPUT, FIGHT, WORK, INTERACT)
need(all("var host.name" not in src for src in _HOSTED), "no mangled var host.name")
need(all("for host." not in src for src in _HOSTED), "no for host._i rewrite")
need(all("Callable(host, \"host." not in src for src in _HOSTED), "Callable method names not double-prefixed")
need(all("var host := host._game()" not in src and "var host: Node = host._game()" not in src for src in _HOSTED), "no host shadow with _game")

# Input / physics stay on player host (F2 scope).
need("func _physics_process(" in PLAYER, "physics_process stays on player")
need("func _input(" in PLAYER or "func _unhandled_input(" in PLAYER, "input stays on player")

if errs:
    print("FAIL")
    for e in errs:
        print(" -", e)
    raise SystemExit(1)
print("OK player extract F2")
