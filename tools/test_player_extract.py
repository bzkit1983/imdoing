#!/usr/bin/env python3
"""Static checks for tech-review v0.2 F2 player controller extraction."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLAYER = (ROOT / "godot/game/scripts/player.gd").read_text(encoding="utf-8")
TOSS = (ROOT / "godot/game/scripts/player/toss_controller.gd").read_text(encoding="utf-8")
FIGHT = (ROOT / "godot/game/scripts/player/fight_controller.gd").read_text(encoding="utf-8")
SKILL = (ROOT / "godot/game/scripts/player/skill_caster.gd").read_text(encoding="utf-8")

errs: list[str] = []


def need(cond: bool, msg: str) -> None:
    if not cond:
        errs.append(msg)


need("TossControllerScript" in PLAYER, "player preloads toss_controller")
need("FightControllerScript" in PLAYER, "player preloads fight_controller")
need("SkillCasterScript" in PLAYER, "player preloads skill_caster")
need("_toss.bind(self)" in PLAYER, "player binds toss")
need("_fight_ctrl.bind(self)" in PLAYER, "player binds fight")
need("_skills.bind(self)" in PLAYER, "player binds skills")

need("extends RefCounted" in TOSS and "func bind(" in TOSS, "toss is host-bound RefCounted")
need("extends RefCounted" in FIGHT and "func bind(" in FIGHT, "fight is host-bound RefCounted")
need("extends RefCounted" in SKILL and "func bind(" in SKILL, "skill is host-bound RefCounted")

need("func launch_piece_toss(" in TOSS and "func toss_top_piece(" in TOSS, "toss launch/toss_top")
need("func play_ko_sequence(" in FIGHT and "func end_fight(" in FIGHT, "fight KO/end")
need("func cast_slot(" in SKILL and "func cast_ultimate(" in SKILL, "skill cast paths")

# Facades remain on player (call sites / puppets keep working).
need("func _launch_piece_toss(" in PLAYER, "launch facade on player")
need("await _fight_ctrl.play_ko_sequence(" in PLAYER, "KO sequence awaits controller")
need("func _cast_slot(" in PLAYER, "cast_slot facade on player")
need("_toss.launch_piece_toss(" in PLAYER, "launch delegates to toss")
need("_skills.cast_slot(" in PLAYER, "cast_slot delegates to skills")

# Parse hazards learned from F1 / F2 rewrites.
need("var host.name" not in TOSS and "var host.name" not in SKILL, "no mangled var host.name")
need("for host." not in TOSS and "for host." not in SKILL, "no for host._i rewrite")
need("Callable(host, \"host." not in TOSS, "Callable method names not double-prefixed")
need("var host := host._game()" not in TOSS and "var host := host._game()" not in SKILL, "no host shadow with _game")

# Input / physics stay on player host (F2 scope).
need("func _physics_process(" in PLAYER, "physics_process stays on player")
need("func _input(" in PLAYER or "func _unhandled_input(" in PLAYER, "input stays on player")

if errs:
    print("FAIL")
    for e in errs:
        print(" -", e)
    raise SystemExit(1)
print("OK player extract F2")
