#!/usr/bin/env python3
"""Static checks for pictorial prep hub IA."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAGES = (ROOT / "godot/game/scripts/prep/prep_pages.gd").read_text(encoding="utf-8")
MENU = (ROOT / "godot/game/scripts/prep_menu.gd").read_text(encoding="utf-8")
SCENE = (ROOT / "godot/game/scenes/prep_menu.tscn").read_text(encoding="utf-8")
LOCALE = (ROOT / "godot/game/locale/strings.csv").read_text(encoding="utf-8")
ICONS = (ROOT / "godot/game/scripts/prep/prep_icons.gd").read_text(encoding="utf-8")
DOC = (ROOT / "docs/systemdesign/storepreparationphase.md").read_text(encoding="utf-8")

errs: list[str] = []


def need( Cond: bool, msg: str) -> None:
    if not Cond:
        errs.append(msg)


need("hub_char" in PAGES and "hub_goods" in PAGES and "hub_shop" in PAGES and "hub_sys" in PAGES, "hub pages missing")
need("_develop" in PAGES and "_buy" in PAGES, "develop/buy split missing")
need("locked_look" in PAGES or "locked_look" in MENU, "appearance lock missing")
need("HubPanel" in SCENE and "OpenBar" in SCENE and "OpenMain" in SCENE, "scene hub/open chrome missing")
need("_rebuild_hub_tiles" in MENU and "_setup_open_bar" in MENU, "hub rebuild helpers missing")
need("_layout_hub_chrome" in MENU, "hub chrome layout helper missing")
need("SIZE_SHRINK_BEGIN" in (ROOT / "godot/game/scripts/prep/prep_widgets.gd").read_text(encoding="utf-8"), "hub tiles must not vertically expand")
W = (ROOT / "godot/game/scripts/prep/prep_widgets.gd").read_text(encoding="utf-8")
need("LIST_ROW_H" in W and "list_row_spacer" in W, "ItemList touch row spacer missing")
need("list_row_spacer" in MENU, "prep_menu must attach list row spacer icons")
need("parent_page" in PAGES, "parent_page helper missing")
need("prep.hub.char" in LOCALE and "prep.home.develop" in LOCALE and "prep.home.buy" in LOCALE, "locale hub keys missing")
need("開始營運" in LOCALE and "麻煩客人模式" in LOCALE, "open labels missing")
need("art/ui/prep" in ICONS, "icon override path missing")
need("角色整備" in DOC and "貨品管理" in DOC and "系統工具" in DOC, "design doc not aligned")
need('page == "buy"' in MENU or '_page == "buy"' in MENU, "qty flow should use buy page")

if errs:
    print("FAIL")
    for e in errs:
        print("-", e)
    raise SystemExit(1)
print("OK prep hub UI wiring")
