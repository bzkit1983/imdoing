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
need("func keeps_room_after_settle" in session, "SessionService.keeps_room_after_settle (§12.10)")
need("func return_to_lobby_after_settle" in session, "SessionService.return_to_lobby_after_settle (§12.10)")
need("func begin_post_settle_lobby" in session, "SessionService.begin_post_settle_lobby (§12.10)")
need("func refresh_owned_sheets" in session, "SessionService.refresh_owned_sheets (§12.10)")

demo = (SCRIPTS / "demo.gd").read_text(encoding="utf-8")
need("func _net_tick_intents_and_sync" in demo, "demo intent tick")
need("@rpc" in session, "SessionService still has RPC surface")
need("keeps_room_after_settle" in demo and "return_to_lobby_after_settle" in demo, "demo keep-room return path")
need("NetPresentation" in demo or "net_presentation" in demo, "demo §8.4 NetPresentation")
need("_net_apply_presentation" in demo and "NET_DT" in demo, "demo fixed net tick + presentation")

pres = SCRIPTS / "session" / "net_presentation.gd"
need(pres.is_file(), "net_presentation.gd present")
pres_body = pres.read_text(encoding="utf-8") if pres.is_file() else ""
need("NET_HZ" in pres_body and "INTERP_DELAY" in pres_body, "net_presentation constants")
need("reconcile_owned" in pres_body and "INTENT_STALE_TICKS" in pres_body, "net_presentation reconcile／stale")

need("func intent_is_stale" in session, "SessionService.intent_is_stale (§8.4)")
need("next_intent_seq" in session, "SessionService intent seq (§8.4)")
need("broadcast_day_clock_state" in session, "SessionService.broadcast_day_clock_state (§8.1)")
need("day_clock_state_received" in session, "SessionService day_clock signal")

player = (SCRIPTS / "player.gd").read_text(encoding="utf-8")
need("var remote_move" in player and "func is_net_puppet" in player, "player net puppet / remote move")
need("func _world_authority" in player, "player Host world-authority gate")
need("take_pending_aim_confirm" in player and "toss_intent_snapshot" in player, "player aim／toss intent helpers")
need("local_guest_seat_id" in (SCRIPTS / "session" / "seat_table.gd").read_text(encoding="utf-8"), "SeatTable.local_guest_seat_id")

need("aim_confirm" in demo and "toss_dx" in demo and "restock_cursor" in demo, "demo Intent aim／toss／restock fields")
need("_broadcast_day_clock_state" in demo, "demo Host day clock broadcast")
need("is_client()" in demo and "DayPhase.advance" in demo, "demo Client clock gate near DayPhase")

checklist = DOCS / "alpha" / "multiplayer-smoke-checklist.md"
need(checklist.is_file(), "G2 manual checklist doc exists")
body = checklist.read_text(encoding="utf-8")
need("開日" in body and "日結" in body, "checklist covers open-day / settle")
need("intent" in body.lower() or "意圖" in body, "checklist covers intent")
need("host" in body.lower() or "Host" in body, "checklist covers host+client")
need("留房" in body or "§12.10" in body, "checklist covers keep-room after settle")
need("§8.4" in body or "流暢" in body, "checklist covers client feel §8.4")

mp = DOCS / "systemdesign" / "multiplayer.md"
need(mp.is_file(), "multiplayer design doc present")
mp_body = mp.read_text(encoding="utf-8") if mp.is_file() else ""
need("12.10" in mp_body and "留房" in mp_body, "multiplayer.md §12.10 keep-room section")
need("8.4" in mp_body and "30" in mp_body and "插值" in mp_body, "multiplayer.md §8.4 client feel")

if errs:
    print("FAIL")
    for e in errs:
        print(" -", e)
    raise SystemExit(1)
print("OK multiplayer smoke contract (static)")
