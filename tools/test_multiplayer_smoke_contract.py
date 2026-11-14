#!/usr/bin/env python3
"""Static anchors for tech-review v0.2 G2 multiplayer smoke (manual checklist companion).

Does not launch host+client. Guarantees Session / transport / intent / day-cycle
surfaces still exist so the manual smoke path is not blocked by missing APIs.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "godot" / "game" / "scripts"
DOCS = ROOT / "docs"

errs: list[str] = []


def need(cond: bool, msg: str) -> None:
    if not cond:
        errs.append(msg)


session_path = SCRIPTS / "session" / "session_service.gd"
need(session_path.is_file(), "SessionService script at scripts/session/session_service.gd")
session = session_path.read_text(encoding="utf-8") if session_path.is_file() else ""
need("func create_room" in session, "SessionService.create_room")
need(re.search(r"lan_enet|steam|local", session) is not None, "Session transport modes")

demo = (SCRIPTS / "demo.gd").read_text(encoding="utf-8")
need("func _net_tick_intents_and_sync" in demo, "demo intent tick")
need("@rpc" in session, "SessionService still has RPC surface")

player = (SCRIPTS / "player.gd").read_text(encoding="utf-8")
need("var remote_move" in player and "func is_net_puppet" in player, "player net puppet / remote move")

checklist = DOCS / "alpha" / "multiplayer-smoke-checklist.md"
need(checklist.is_file(), "G2 manual checklist doc exists")
body = checklist.read_text(encoding="utf-8")
need("開日" in body and "日結" in body, "checklist covers open-day / settle")
need("intent" in body.lower() or "意圖" in body, "checklist covers intent")
need("host" in body.lower() or "Host" in body, "checklist covers host+client")

need((DOCS / "systemdesign" / "multiplayer.md").is_file(), "multiplayer design doc present")

if errs:
    print("FAIL")
    for e in errs:
        print(" -", e)
    raise SystemExit(1)
print("OK multiplayer smoke contract (static)")
