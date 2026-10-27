#!/usr/bin/env python3
"""Saved skill sets: five presets, empty ult, English names, SAVE_VERSION stays 1."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOC = (ROOT / "docs/systemdesign/customizedskillset.md").read_text(encoding="utf-8")
STATE = (ROOT / "godot/game/scripts/game_state.gd").read_text(encoding="utf-8")
PREP = (ROOT / "godot/game/scripts/prep/prep_pages.gd").read_text(encoding="utf-8")
MENU = (ROOT / "godot/game/scripts/prep_menu.gd").read_text(encoding="utf-8")
PLAYER = (ROOT / "godot/game/scripts/player.gd").read_text(encoding="utf-8")
PAUSE = (ROOT / "godot/game/scripts/pause_menu.gd").read_text(encoding="utf-8")
HUD = (ROOT / "godot/game/scripts/hud.gd").read_text(encoding="utf-8")
VERSION = (ROOT / "godot/game/scripts/product_version.gd").read_text(encoding="utf-8")

errs: list[str] = []


def need(ok: bool, msg: str) -> None:
    if not ok:
        errs.append(msg)


need("已實作" in DOC, "doc marks the feature implemented")
need("已拍板" in DOC, "locked answers stay in the doc")
need("沒有。" in DOC, "no open questions")
need("自訂技能組合1" in DOC and "自訂技能組合5" in DOC, "default names")
need("SAVE_VERSION" in DOC and "維持 1" in DOC, "save version stays 1")
need("const SAVE_VERSION := 1" in STATE, "SAVE_VERSION constant stays 1")
need("var skill_sets: Array[Dictionary]" in STATE, "five sets live on game state")
need("func equip_set(" in STATE, "equip targets one set")
need("func unequip_set(" in STATE and 'slot_i == 5' in STATE, "ult slot can be cleared")
need('pack["ult_id"] = ""' in STATE, "clearing ult stores an empty id")
need("func select_skill_set(" in STATE, "prep can select a set")
need("func rename_skill_set(" in STATE, "names can be edited")
need("名稱只用英文字母" in STATE, "custom names are English letters")
need("名稱已被使用" in STATE, "duplicate names are rejected")
need("_persist_skill_edit" in STATE and "save_to_disk" in STATE, "edits write the save")
need("_migrate_single_loadout" in STATE, "old saves become set 1")
need('"skill_sets"' in STATE and '"skill_set_index"' in STATE, "new keys are saved")
need('"slots"' in STATE and '"ult_id"' in STATE, "selected set still mirrored")
need("skill_set" in PREP and "skill_rename" in PREP, "prep pages list and rename sets")
need("equip_set" in MENU and "select_skill_set" in MENU, "prep menu edits any open set")
need("沒有裝備奧義" in PLAYER, "empty ult does not cast")
need("select_skill_set" not in PAUSE, "pause menu cannot switch sets")
need("奧義 空" in HUD, "hud shows an empty ult")
need("1.2.0" in VERSION, "product version stays v1.2.0")

if errs:
    print("FAIL")
    for e in errs:
        print("-", e)
    raise SystemExit(1)
print("OK customized skill sets")
