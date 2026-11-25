#!/usr/bin/env python3
"""theme_historic interim art: SKUs, fish, furniture, place shell, guest skins.

Writes godot/game/art/src/<id>.vox, art/ui/sku/<id>.png (64²),
art/ui/furniture/<id>.png (64²), and patches catalog.json.
Does not overwrite unrelated v1.5 models.

Run:
  python3 tools/voxel_historic_theme.py
  VOXEL_BAKE_IDS=cooked_stall,fish_tank,grain,soy_sauce,onigiri,yakimochi,nigiri,saba,tai,sanma,aji,ayu,floor_tile_sengoku,wall_sengoku \\
    python3 tools/voxel_sprites.py
  VOXEL_BAKE_IDS=customer_sengoku_samurai,customer_sengoku_civilian,customer_sengoku_merchant,thief_sengoku \\
    python3 tools/voxel_character_anims.py
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))

import voxel_blockout as vb  # noqa: E402
import voxel_interim_v15 as v15  # noqa: E402
import voxel_sprites as vs  # noqa: E402

SRC = vs.SRC
CATALOG = ROOT / "godot" / "game" / "art" / "catalog.json"
SKU_DIR = ROOT / "godot" / "game" / "art" / "ui" / "sku"
FURN_DIR = ROOT / "godot" / "game" / "art" / "ui" / "furniture"

SHELF = (256, 128, 144)  # cooked_stall 2×1
## Wide short desktop aquarium (ref: landscape tank, not a tall cabinet). 2×2 footprint.
TANK = (240, 144, 72)

fill = v15.fill
shell = v15.shell
ball = v15.ball
cyl_z = v15.cyl_z
front_icon = v15.front_icon


SKU_IDS = ("grain", "soy_sauce", "onigiri", "yakimochi", "nigiri")
FISH_IDS = ("saba", "tai", "sanma", "aji", "ayu")
FURN_IDS = ("cooked_stall", "fish_tank")
PLACE_IDS = ("floor_tile_sengoku", "wall_sengoku")
CHAR_IDS = (
	"customer_sengoku_samurai",
	"customer_sengoku_civilian",
	"customer_sengoku_merchant",
	"thief_sengoku",
)
ALL_ICON_IDS = SKU_IDS + FISH_IDS


def _grain() -> vb.Model:
	"""Bulging rice sack — front silhouette is a fat bag, not a bottle."""
	m = vb.Model(72, 56, 64)
	# Wide sack body (bulge mid-height).
	for z in range(0, 44):
		t = z / 43.0
		bulge = 1.0 + 0.35 * math.sin(t * math.pi)
		half = int(22 * bulge)
		fill(m, 36 - half, 14, z, 36 + half, 46, z, "cardboard")
		# Weave stripes on front.
		if z % 5 < 2:
			fill(m, 36 - half, 40, z, 36 + half, 44, z, "tape")
	# Gathered top (short — not a bottle neck).
	fill(m, 26, 22, 42, 46, 40, 50, "tape")
	fill(m, 30, 24, 48, 42, 38, 54, "white")
	# Rope knot sitting on top.
	ball(m, 36, 32, 54, 6, 5, 4, "wood_dark")
	fill(m, 28, 30, 52, 44, 34, 56, "wood")
	# Front brand patch + rice kanji block.
	fill(m, 26, 42, 16, 46, 48, 32, "white")
	fill(m, 30, 44, 20, 42, 48, 28, "can")
	# Spilled rice grains at feet (front).
	for cx, cy in ((16, 44), (20, 48), (52, 44), (56, 48), (36, 50)):
		ball(m, cx, cy, 3, 3, 3, 2, "white")
	return m


def _soy_sauce() -> vb.Model:
	"""Classic ceramic shoyu bottle with red cap and label."""
	m = vb.Model(48, 48, 80)
	# Round dark body.
	cyl_z(m, 24, 24, 0, 52, 14, "wood_dark")
	cyl_z(m, 24, 24, 0, 6, 15, "shoe")
	# Shoulder taper.
	for z in range(52, 64):
		rad = 14 - int(8 * (z - 52) / 12)
		cyl_z(m, 24, 24, z, z, max(4, rad), "wood_dark")
	# Neck + red cap.
	cyl_z(m, 24, 24, 62, 70, 5, "wood")
	cyl_z(m, 24, 24, 70, 78, 7, "soda")
	# Label band.
	fill(m, 10, 34, 18, 38, 38, 40, "white")
	fill(m, 14, 36, 22, 34, 38, 34, "soda")
	# Small pour spout hint on front.
	fill(m, 22, 36, 66, 26, 42, 72, "wood")
	return m


def _onigiri() -> vb.Model:
	"""Triangular rice ball with nori wrap — front (+Y) reads as △."""
	m = vb.Model(64, 48, 64)
	# Build a standing triangle in XZ; thick in Y for volume.
	for z in range(4, 58):
		t = (z - 4) / 54.0
		# Wide at bottom, point at top.
		half = int(26 * (1.0 - t) + 2)
		fill(m, 32 - half, 12, z, 32 + half, 40, z, "white")
		fill(m, 32 - half, 12, z, 32 - half + 2, 40, z, "milk")
		fill(m, 32 + half - 2, 12, z, 32 + half, 40, z, "milk")
	# Nori wrap on lower front face.
	fill(m, 12, 34, 4, 52, 42, 28, "pants")
	fill(m, 14, 36, 6, 50, 40, 26, "shoe")
	# Sesame on upper rice.
	for cx, cz in ((26, 40), (38, 42), (32, 48)):
		ball(m, cx, 20, cz, 1.6, 1.6, 1.6, "wood_dark")
	return m


def _yakimochi() -> vb.Model:
	"""Skewered grilled mochi with soy glaze drip."""
	m = vb.Model(80, 48, 48)
	# Wooden skewer.
	fill(m, 4, 20, 18, 76, 26, 24, "cone")
	fill(m, 0, 21, 19, 6, 25, 23, "wood_dark")
	# Three mochi cubes with char.
	for i, x0 in enumerate((14, 34, 54)):
		fill(m, x0, 12, 8, x0 + 16, 34, 36, "tape")
		fill(m, x0 + 2, 14, 10, x0 + 14, 32, 34, "white")
		# Grill marks.
		for gz in (14, 22, 30):
			fill(m, x0 + 3, 30, gz, x0 + 13, 34, gz + 2, "wood_dark")
		# Soy glaze top.
		fill(m, x0 + 4, 14, 32, x0 + 12, 22, 36, "wood_dark")
		if i == 1:
			# Extra drip.
			fill(m, x0 + 10, 30, 6, x0 + 14, 34, 12, "wood_dark")
	return m


def _nigiri() -> vb.Model:
	"""Nigiri: rice finger + fish fillet on top."""
	m = vb.Model(64, 48, 40)
	# Rice oval base.
	ball(m, 32, 24, 10, 22, 12, 8, "white")
	fill(m, 14, 16, 2, 50, 32, 14, "white")
	fill(m, 16, 18, 0, 48, 30, 4, "milk")
	# Fish fillet draped on top.
	ball(m, 32, 24, 22, 24, 10, 6, "meat")
	fill(m, 12, 18, 16, 52, 30, 26, "meat")
	# Belly highlight stripe.
	fill(m, 16, 26, 20, 48, 30, 24, "skin_shade")
	# Thin nori belt under fish.
	fill(m, 28, 14, 12, 36, 34, 18, "pants")
	# Tiny sesame.
	ball(m, 24, 20, 28, 1.5, 1.5, 1.5, "wood_dark")
	ball(m, 40, 22, 28, 1.5, 1.5, 1.5, "wood_dark")
	return m


def _fish_body(
	m: vb.Model,
	cx: int,
	cy: int,
	cz: int,
	length: int,
	height: int,
	depth: int,
	body: str,
	belly: str,
	stripe: str | None = None,
) -> None:
	"""Horizontal fish facing +X (tail left, head right) for front (+Y) icon."""
	half_h = height // 2
	half_d = depth // 2
	for x in range(cx - length // 2, cx + length // 2 + 1):
		t = (x - (cx - length // 2)) / max(1, length)
		# taper both ends
		scale = 1.0 - abs(t - 0.55) * 1.1
		scale = max(0.25, scale)
		hh = max(2, int(half_h * scale))
		dd = max(2, int(half_d * scale))
		fill(m, x, cy - dd, cz - hh, x, cy + dd, cz + hh, body)
		# Belly lower third.
		fill(m, x, cy - dd, cz - hh, x, cy + dd, cz - max(1, hh // 3), belly)
		if stripe and int(x) % 5 < 2 and 0.2 < t < 0.8:
			fill(m, x, cy + dd - 1, cz - hh // 2, x, cy + dd, cz + hh // 2, stripe)
	# Head bump.
	hx = cx + length // 2 - 2
	ball(m, hx, cy, cz, 5, depth // 2 + 1, half_h, body)
	# Eye.
	fill(m, hx - 1, cy + half_d - 1, cz + 1, hx + 1, cy + half_d, cz + 3, "eye")
	fill(m, hx, cy + half_d, cz + 2, hx, cy + half_d, cz + 2, "white")
	# Tail fan (left).
	tx = cx - length // 2
	for i in range(8):
		fill(m, tx - i, cy - 1, cz - half_h + i // 2, tx - i + 1, cy + 1, cz + half_h - i // 2, body)
	# Dorsal fin.
	fill(m, cx - 4, cy - 1, cz + half_h, cx + 6, cy + 1, cz + half_h + 6, body)


def _saba() -> vb.Model:
	m = vb.Model(80, 40, 40)
	_fish_body(m, 40, 20, 18, 52, 16, 10, "metal", "white", "shelf_ice")
	return m


def _tai() -> vb.Model:
	m = vb.Model(72, 40, 48)
	_fish_body(m, 36, 20, 20, 44, 22, 12, "soda", "skin", "white")
	# Spot near head.
	ball(m, 50, 26, 24, 3, 2, 3, "white")
	return m


def _sanma() -> vb.Model:
	m = vb.Model(96, 32, 32)
	_fish_body(m, 48, 16, 14, 72, 10, 8, "shelf_frozen", "milk", "pants")
	return m


def _aji() -> vb.Model:
	m = vb.Model(72, 40, 40)
	_fish_body(m, 36, 20, 18, 48, 14, 10, "vomit", "white", "wood_dark")
	return m


def _ayu() -> vb.Model:
	m = vb.Model(64, 36, 36)
	_fish_body(m, 32, 18, 16, 40, 12, 8, "glass", "white", "shelf_dry")
	return m


def _cooked_stall() -> vb.Model:
	"""Japanese yatai: wood counter, noren, awning, griddle, lanterns. 2×1."""
	w, d, h = SHELF
	m = vb.Model(w, d, h)
	# Base planks.
	fill(m, 8, 16, 0, w - 9, d - 8, 8, "wood_dark")
	fill(m, 12, 20, 8, w - 13, d - 12, 40, "wood")
	# Counter top.
	fill(m, 10, 18, 40, w - 11, d - 6, 48, "wood_dark")
	fill(m, 14, 22, 46, w - 15, d - 10, 50, "wood")
	# Back wall / posts.
	for x in (16, w // 2 - 6, w - 28):
		fill(m, x, 20, 48, x + 10, 28, 120, "wood_dark")
	fill(m, 16, 18, 110, w - 17, 30, 120, "wood")
	# Awning / fabric roof (front overhang).
	fill(m, 8, 40, 100, w - 9, d - 4, 118, "can")
	fill(m, 8, 48, 96, w - 9, d - 2, 108, "soda")
	# Striped awning underside.
	for i, x in enumerate(range(12, w - 12, 16)):
		col = "white" if i % 2 == 0 else "soda"
		fill(m, x, 50, 98, x + 12, d - 4, 106, col)
	# Noren curtain panels (front face).
	for i, x0 in enumerate((40, 90, 140, 190)):
		fill(m, x0, d - 14, 52, x0 + 36, d - 6, 100, "white" if i % 2 == 0 else "snack")
		# Split slits.
		for z in range(56, 98, 4):
			m.cells.pop((x0 + 18, d - 10, z), None)
			m.cells.pop((x0 + 18, d - 8, z), None)
	# Griddle / teppan on counter.
	fill(m, 60, 40, 50, 160, 70, 56, "metal")
	fill(m, 68, 44, 54, 152, 66, 58, "screen")
	# Steam / heat glow.
	fill(m, 90, 48, 56, 130, 62, 60, "rice")
	# Sauce bottles on side.
	cyl_z(m, 40, 50, 50, 70, 5, "wood_dark")
	cyl_z(m, 40, 50, 70, 76, 4, "soda")
	cyl_z(m, 200, 50, 50, 68, 5, "white")
	cyl_z(m, 200, 50, 68, 74, 4, "can")
	# Paper lanterns hanging.
	for lx in (48, w - 56):
		cyl_z(m, lx, 36, 88, 108, 10, "snack")
		cyl_z(m, lx, 36, 108, 112, 4, "wood_dark")
		cyl_z(m, lx, 36, 84, 88, 4, "wood_dark")
		fill(m, lx - 2, 36, 94, lx + 2, 38, 102, "can")
	# Menu board.
	fill(m, 170, 24, 70, 230, 30, 108, "wood_dark")
	fill(m, 174, 28, 74, 226, 30, 104, "white")
	for zy in (80, 88, 96):
		fill(m, 180, 29, zy, 220, 30, zy + 3, "can")
	# Small rice balls / mochi display on left.
	ball(m, 50, 60, 58, 8, 6, 6, "white")
	fill(m, 44, 58, 52, 56, 66, 56, "pants")
	fill(m, 180, 55, 52, 210, 68, 58, "tape")
	return m


def _fish_tank() -> vb.Model:
	"""Wide short desktop aquarium (ref image) — grey rims, teal water, goldfish."""
	w, d, h = TANK
	m = vb.Model(w, d, h)
	# Short feet under base (not a tall cabinet).
	for x, y in ((10, 14), (w - 26, 14), (10, d - 26), (w - 26, d - 26)):
		fill(m, x, y, 0, x + 14, y + 10, 4, "metal")
	# Bottom rim / base.
	fill(m, 6, 10, 4, w - 7, d - 8, 12, "metal")
	fill(m, 10, 14, 10, w - 11, d - 12, 14, "milk")
	# Glass walls (shell) — short height.
	shell(m, 12, 16, 12, w - 13, d - 12, 58, "glass", 3)
	# Carve open top (desktop tank is open) + front viewing window.
	for x in range(16, w - 16):
		for y in range(20, d - 16):
			for z in range(54, 59):
				m.cells.pop((x, y, z), None)
	for x in range(18, w - 18):
		for z in range(16, 52):
			for y in range(d - 14, d - 11):
				m.cells.pop((x, y, z), None)
	# Water volume (stops short of front so contents win silhouette).
	fill(m, 16, 20, 14, w - 17, d - 28, 50, "puddle")
	fill(m, 18, 22, 48, w - 19, d - 30, 52, "glass")
	# Light sand bed + pebbles.
	fill(m, 16, 20, 12, w - 17, d - 16, 18, "milk")
	fill(m, 18, 22, 16, w - 19, d - 18, 18, "drink")
	for gx in range(28, w - 28, 14):
		ball(m, gx, d - 22, 17, 2, 2, 1.5, "cup")
	# Left rock + seagrass (ref).
	ball(m, 48, d - 24, 22, 10, 8, 6, "trash")
	ball(m, 54, d - 26, 20, 6, 5, 4, "metal")
	for leaf, ox in enumerate((-4, 0, 5)):
		for zz in range(22, 46):
			cyl_z(m, 48 + ox, d - 20 + leaf, zz, zz, 1 + (1 if zz > 34 else 0), "shelf_dry")
		ball(m, 48 + ox, d - 19 + leaf, 44, 3, 2, 3, "vomit")
	# Shells on sand (center / right).
	ball(m, 110, d - 22, 19, 5, 3, 2, "white")
	fill(m, 106, d - 24, 18, 114, d - 20, 20, "milk")
	ball(m, 140, d - 24, 19, 4, 3, 2, "skin")
	# Orange goldfish (right, front) — readable in UI / world front.
	_fish_body(m, 170, d - 18, 34, 36, 14, 8, "rice", "white", None)
	ball(m, 186, d - 16, 36, 5, 4, 4, "rice")
	fill(m, 184, d - 14, 35, 188, d - 13, 38, "eye")
	# Top rim.
	fill(m, 6, 10, 56, w - 7, d - 8, 64, "metal")
	fill(m, 10, 14, 60, w - 11, d - 12, 66, "milk")
	# Orange power accent (front-right corner of rim).
	fill(m, w - 36, d - 18, 58, w - 18, d - 12, 66, "rice")
	fill(m, w - 32, d - 16, 60, w - 22, d - 13, 64, "can")
	# Back filter / light bar (T-shaped overhang).
	fill(m, 70, 12, 58, 170, 28, 70, "metal")
	fill(m, 90, 14, 66, 150, 40, 70, "milk")
	fill(m, 100, 16, 52, 108, 22, 66, "screen")
	fill(m, 132, 16, 52, 140, 22, 66, "screen")
	# Soft water ripples near surface (sparse).
	for rx in range(40, w - 40, 18):
		fill(m, rx, 40, 50, rx + 8, 52, 51, "white")
	return m


def _floor_tile_sengoku() -> vb.Model:
	"""Quiet wood floor — solid warm fill, sparse plank seams only (no stripes／knots)."""
	m = vb.Model(128, 128, 8)
	fill(m, 0, 0, 0, 127, 127, 2, "wood")
	# Wide plank seams every 32 (same cadence as v1.5 grout), thin and soft.
	for y in range(0, 128, 32):
		fill(m, 0, y, 0, 127, min(y, 127), 2, "wood_dark")
	return m


def _wall_sengoku() -> vb.Model:
	"""White plaster wall + dark timber frame (same envelope as v1.5 wall)."""
	m = vb.Model(128, 16, 128)
	fill(m, 0, 0, 0, 127, 15, 127, "white")
	# Timber posts every 32.
	for x in range(0, 128, 32):
		fill(m, x, 0, 0, min(x + 5, 127), 15, 127, "wood_dark")
	# Mid rail + base + crown.
	fill(m, 0, 0, 0, 127, 15, 12, "wood")
	fill(m, 0, 10, 56, 127, 15, 68, "wood")
	fill(m, 0, 0, 116, 127, 15, 127, "wood_dark")
	# Soft plaster wash on face.
	fill(m, 8, 12, 14, 120, 15, 112, "milk")
	# Small noren hook plate.
	fill(m, 48, 14, 88, 80, 15, 104, "wood")
	fill(m, 52, 15, 92, 76, 15, 100, "soda")
	return m


def _customer_sengoku_samurai() -> vb.Model:
	"""Armored guest — metal torso, kabuto silhouette."""
	m = vb.person("metal", "wood_dark", "hair", bag=False)
	# Kabuto dome + crest.
	m.fill(2, 2, 16, 9, 8, 19, "metal")
	m.fill(4, 1, 18, 7, 3, 19, "soda")
	m.fill(5, 0, 17, 6, 2, 19, "metal")
	# Face slit.
	m.fill(4, 7, 14, 7, 9, 16, "skin")
	m.set(4, 8, 15, "eye")
	m.set(7, 8, 15, "eye")
	# Breastplate ridge.
	m.fill(4, 7, 8, 7, 7, 11, "metal")
	m.fill(3, 3, 9, 8, 3, 11, "wood_dark")
	return m


def _customer_sengoku_civilian() -> vb.Model:
	"""Kimono commoner — warm wrap, no bag."""
	m = vb.person("rice", "wood", "hair_brown", bag=False)
	# Obis sash.
	m.fill(2, 3, 7, 9, 7, 8, "wood_dark")
	m.fill(5, 7, 7, 6, 8, 9, "snack")
	# Collar V.
	m.fill(5, 7, 11, 6, 7, 12, "white")
	return m


def _customer_sengoku_merchant() -> vb.Model:
	"""Haori merchant — darker wrap + money bag."""
	m = vb.person("customer", "customer_dark", "hair", bag=True)
	# Haori hem stripe.
	m.fill(2, 3, 7, 9, 7, 8, "wood")
	m.fill(4, 7, 9, 7, 7, 11, "white")
	# Ledger pouch accent on bag.
	m.fill(10, 6, 8, 11, 8, 10, "cardboard")
	return m


def _thief_sengoku() -> vb.Model:
	"""Comic blue ninja — round nose, open face, white sash (Ebisumaru-inspired, not IP copy)."""
	m = vb.person("clerk", "clerk_dark", "hair", hood=True, mask=False, bag=False)
	# Blue hood (overwrite dark hood with clerk blues).
	m.fill(2, 2, 12, 9, 8, 19, "clerk")
	m.fill(2, 2, 12, 9, 3, 19, "clerk_dark")
	# Open face window + big round nose.
	m.fill(4, 7, 14, 7, 9, 16, "skin")
	m.set(4, 8, 15, "eye")
	m.set(7, 8, 15, "eye")
	m.fill(5, 9, 14, 6, 9, 15, "skin")
	m.set(5, 9, 14, "skin_shade")
	m.set(6, 9, 14, "skin_shade")
	# White sash.
	m.fill(2, 3, 7, 9, 7, 8, "white")
	# Mesh chest suggestion.
	m.fill(4, 4, 9, 7, 6, 11, "screen")
	# Tabi feet.
	m.fill(3, 4, 0, 5, 6, 0, "white")
	m.fill(7, 4, 0, 9, 6, 0, "white")
	m.fill(3, 4, 0, 3, 6, 0, "soda")
	m.fill(9, 4, 0, 9, 6, 0, "soda")
	return m


MODELS: dict[str, tuple[str, object, str]] = {
	"grain": ("米糧", _grain, "theme_historic：米袋。正面剪影即 UI。"),
	"soy_sauce": ("醬油", _soy_sauce, "theme_historic：陶瓷醬油瓶。正面剪影即 UI。"),
	"onigiri": ("飯糰", _onigiri, "theme_historic：三角飯糰海苔。正面剪影即 UI。"),
	"yakimochi": ("烤麻糬", _yakimochi, "theme_historic：串燒麻糬。正面剪影即 UI。"),
	"nigiri": ("握壽司", _nigiri, "theme_historic：握壽司。正面剪影即 UI。"),
	"saba": ("鯖", _saba, "theme_historic：鯖魚圖示模型。"),
	"tai": ("鯛", _tai, "theme_historic：鯛魚圖示模型。"),
	"sanma": ("秋刀魚", _sanma, "theme_historic：秋刀魚圖示模型。"),
	"aji": ("鰺", _aji, "theme_historic：鰺魚圖示模型。"),
	"ayu": ("鮎", _ayu, "theme_historic：鮎魚圖示模型。"),
	"cooked_stall": ("熟食檔攤", _cooked_stall, "theme_historic：屋台攤（2×1）。佔格不變。"),
	"fish_tank": ("魚缸", _fish_tank, "theme_historic：矮寬桌上魚缸（2×2）。佔格不變。"),
	"floor_tile_sengoku": ("戰國地板", _floor_tile_sengoku, "theme_historic：木地板一格。"),
	"wall_sengoku": ("戰國牆", _wall_sengoku, "theme_historic：白壁土牆一格段。"),
	"customer_sengoku_samurai": ("戰國武士", _customer_sengoku_samurai, "theme_historic：一般客人—武士。"),
	"customer_sengoku_civilian": ("戰國平民", _customer_sengoku_civilian, "theme_historic：一般客人—古裝平民。"),
	"customer_sengoku_merchant": ("戰國商人", _customer_sengoku_merchant, "theme_historic：一般客人—古裝商人。"),
	"thief_sengoku": ("戰國小偷", _thief_sengoku, "theme_historic：喜劇風藍忍小偷。"),
}

def _check_icon_distinct(icons: dict[str, list]) -> None:
	def luma16(px: list, n: int) -> list[float]:
		step = 8
		out = []
		for gy in range(4):
			for gx in range(4):
				acc = 0.0
				count = 0
				for y in range(gy * step, (gy + 1) * step, 2):
					for x in range(gx * step, (gx + 1) * step, 2):
						r, g, b, a = px[y * n + x]
						if a < 20:
							continue
						acc += 0.3 * r + 0.59 * g + 0.11 * b
						count += 1
				out.append(0.0 if count == 0 else acc / count)
		return out

	grids = {k: luma16(px, 64) for k, px in icons.items()}
	worst = ("", "", 1e9)
	ids = list(grids)
	for i, a in enumerate(ids):
		for b in ids[i + 1 :]:
			dist = sum(abs(x - y) for x, y in zip(grids[a], grids[b]))
			if dist < worst[2]:
				worst = (a, b, dist)
	print(f"historic icons closest {worst[0]}/{worst[1]} L1={worst[2]:.1f}")
	if worst[2] < 30:
		raise SystemExit("historic icons are too similar at 32px grayscale")


def write_icons(models: dict[str, vb.Model]) -> None:
	SKU_DIR.mkdir(parents=True, exist_ok=True)
	FURN_DIR.mkdir(parents=True, exist_ok=True)
	icons: dict[str, list] = {}
	for sid in ALL_ICON_IDS:
		img = front_icon(models[sid], 64)
		vs.save_png(SKU_DIR / f"{sid}.png", 64, 64, img)
		icons[sid] = img
	for fid in FURN_IDS:
		img = front_icon(models[fid], 64)
		vs.save_png(FURN_DIR / f"{fid}.png", 64, 64, img)
		icons[fid] = img
	_check_icon_distinct(icons)
	print(f"sku icons {len(ALL_ICON_IDS)} → {SKU_DIR}")
	print(f"furniture icons {len(FURN_IDS)} → {FURN_DIR}")


def upsert_catalog(stats: dict[str, tuple]) -> None:
	data = json.loads(CATALOG.read_text(encoding="utf-8"))
	groups = {str(g.get("id")): g for g in data.get("groups", [])}
	goods = groups.get("goods")
	furniture = groups.get("furniture")
	place = groups.get("place")
	characters = groups.get("characters")
	if goods is None or furniture is None or place is None:
		raise SystemExit("catalog missing goods/furniture/place group")
	if characters is None:
		characters = {"id": "characters", "name": "人物", "models": []}
		data.setdefault("groups", []).append(characters)
		groups["characters"] = characters

	def upsert(group: dict, mid: str, name: str, size, voxels: int, note: str) -> None:
		entry = {
			"id": mid,
			"name": name,
			"file": f"{mid}.vox",
			"size": list(size),
			"voxels": voxels,
			"note": note,
		}
		models = group.setdefault("models", [])
		for i, m in enumerate(models):
			if str(m.get("id")) == mid:
				models[i] = entry
				return
		models.append(entry)

	for mid, (name, _builder, note) in MODELS.items():
		size, voxels = stats[mid]
		if mid in FURN_IDS:
			group = furniture
		elif mid in PLACE_IDS:
			group = place
		elif mid in CHAR_IDS:
			group = characters
		else:
			group = goods
		upsert(group, mid, name, size, voxels, note)
	CATALOG.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
	SRC.mkdir(parents=True, exist_ok=True)
	built: dict[str, vb.Model] = {}
	stats: dict[str, tuple] = {}
	for mid, (_name, builder, note) in MODELS.items():
		model = builder()
		built[mid] = model
		if model.size[0] > 256 or model.size[1] > 256 or model.size[2] > 256:
			raise SystemExit(f"{mid} exceeds byte voxel coords {model.size}")
		path = SRC / f"{mid}.vox"
		vb.write_vox(path, model)
		stats[mid] = (model.size, len(model.cells))
		print(f"wrote {mid} {model.size} voxels={len(model.cells)} — {note}")
	icon_models = {k: built[k] for k in list(ALL_ICON_IDS) + list(FURN_IDS)}
	write_icons(icon_models)
	upsert_catalog(stats)
	print(f"catalog {CATALOG}")


if __name__ == "__main__":
	main()
