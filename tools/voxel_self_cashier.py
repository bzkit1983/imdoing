#!/usr/bin/env python3
"""Generate a test self-checkout kiosk MagicaVoxel model for godot/game.

Writes godot/game/art/src/self_cashier.vox and patches catalog.json furniture entry.
Reference: upright SCO kiosk — pedestal + deck + portrait screen + bag hooks.
Does not overwrite other .vox files.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))

import voxel_blockout as vb  # noqa: E402
import voxel_sprites as vs  # noqa: E402

SRC = vs.SRC
CATALOG = ROOT / "godot" / "game" / "art" / "catalog.json"

## 2×1 footprint (same family as register). Taller for portrait screen.
SELF_CASHIER = (144, 112, 160)


def fill(m: vb.Model, x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, color: str) -> None:
	m.fill(x0, y0, z0, x1, y1, z1, color)


def shell(
	m: vb.Model,
	x0: int,
	y0: int,
	z0: int,
	x1: int,
	y1: int,
	z1: int,
	color: str,
	t: int = 2,
) -> None:
	## Hollow box walls thickness t (outer fill, carve interior).
	fill(m, x0, y0, z0, x1, y1, z1, color)
	ix0, iy0, iz0 = x0 + t, y0 + t, z0 + t
	ix1, iy1, iz1 = x1 - t, y1 - t, z1 - t
	if ix0 <= ix1 and iy0 <= iy1 and iz0 <= iz1:
		for x in range(ix0, ix1 + 1):
			for y in range(iy0, iy1 + 1):
				for z in range(iz0, iz1 + 1):
					m.cells.pop((x, y, z), None)


def self_cashier() -> vb.Model:
	"""Upright self-checkout: base plate, pedestal, deck+tray, portrait head, bag hooks."""
	m = vb.Model(*SELF_CASHIER)
	## World: X right, Y forward (guest side +Y), Z up. Feet on z=0.

	## --- Base plate (slight front notch) ---
	fill(m, 28, 18, 0, 115, 94, 4, "metal")
	fill(m, 32, 22, 1, 111, 90, 5, "shelf_ice")
	## Front arch cut (guest approach).
	for x in range(52, 92):
		for y in range(88, 95):
			m.cells.pop((x, y, 0), None)
			m.cells.pop((x, y, 1), None)
			m.cells.pop((x, y, 2), None)
			m.cells.pop((x, y, 3), None)
			m.cells.pop((x, y, 4), None)
	## Corner bolt holes.
	for cx, cy in ((34, 24), (109, 24), (34, 86), (109, 86)):
		fill(m, cx, cy, 4, cx + 3, cy + 3, 5, "screen")

	## --- Pedestal column ---
	fill(m, 58, 40, 5, 85, 72, 54, "white")
	fill(m, 60, 42, 5, 83, 70, 54, "shelf_ice")
	## Front panel accent stripe.
	fill(m, 62, 70, 12, 81, 72, 48, "screen_on")

	## --- Deck / scan table ---
	fill(m, 36, 28, 54, 107, 78, 62, "white")
	fill(m, 38, 30, 55, 105, 76, 61, "metal")
	## Deck top surface.
	fill(m, 38, 30, 61, 105, 76, 62, "white")

	## --- Side bagging tray (raised walls, guest-right / +X) ---
	fill(m, 100, 34, 54, 130, 78, 56, "metal")
	## Tray walls.
	fill(m, 100, 34, 56, 130, 36, 70, "white")
	fill(m, 100, 76, 56, 130, 78, 70, "white")
	fill(m, 128, 34, 56, 130, 78, 70, "white")
	fill(m, 100, 34, 56, 102, 78, 70, "shelf_ice")
	## Tray floor.
	fill(m, 102, 36, 56, 127, 75, 58, "shelf_ice")

	## --- Portrait head housing ---
	hx0, hx1 = 48, 95
	hy0, hy1 = 44, 68
	hz0, hz1 = 62, 148
	fill(m, hx0, hy0, hz0, hx1, hy1, hz1, "white")
	## Soft bevel / shade sides.
	fill(m, hx0, hy0, hz0, hx0 + 1, hy1, hz1, "metal")
	fill(m, hx1 - 1, hy0, hz0, hx1, hy1, hz1, "metal")

	## Sensor bar on top.
	fill(m, 54, 48, 144, 89, 64, 150, "screen")
	for sx in (60, 72, 84):
		fill(m, sx, 52, 146, sx + 4, 60, 149, "eye")

	## Screen bezel + lit panel (faces +Y guest).
	fill(m, 54, 66, 92, 89, 68, 138, "screen")
	fill(m, 56, 67, 96, 87, 68, 134, "screen_on")
	## Simple UI chrome on screen (top bar + buttons).
	fill(m, 58, 68, 128, 85, 68, 132, "white")
	fill(m, 60, 68, 104, 68, 68, 112, "drink")
	fill(m, 72, 68, 104, 83, 68, 112, "drink")
	fill(m, 60, 68, 98, 83, 68, 100, "metal")

	## Lower modules under screen: printer slot + card reader.
	fill(m, 54, 66, 72, 70, 68, 88, "screen")
	fill(m, 56, 67, 76, 68, 68, 84, "eye")  # slot
	fill(m, 74, 66, 72, 89, 68, 88, "metal")
	fill(m, 76, 67, 76, 87, 68, 84, "white")  # NFC pad

	## Green bag hooks on guest-right of head (+X).
	for z in (118, 128):
		fill(m, 95, 52, z, 118, 56, z + 3, "player")
		fill(m, 116, 52, z - 2, 118, 56, z + 3, "player")
		fill(m, 116, 52, z - 2, 118, 56, z - 1, "player_dark")

	## Small scanner window on deck (front edge).
	fill(m, 58, 72, 62, 85, 76, 64, "screen_on")
	fill(m, 62, 74, 64, 81, 75, 65, "drink")

	return m


def patch_catalog(voxel_count: int) -> None:
	data = json.loads(CATALOG.read_text(encoding="utf-8"))
	groups = data.get("groups", data.get("categories", []))
	furniture = None
	for g in groups:
		if str(g.get("id", "")) == "furniture":
			furniture = g
			break
	if furniture is None:
		raise SystemExit("catalog furniture group missing")
	models = furniture.setdefault("models", [])
	entry = {
		"id": "self_cashier",
		"name": "自助收銀機",
		"file": "self_cashier.vox",
		"size": list(SELF_CASHIER),
		"voxels": voxel_count,
		"note": "測試版自助收銀亭（立柱＋檯面＋直式螢幕＋掛袋勾）。佔格 2×1。",
	}
	replaced = False
	for i, m in enumerate(models):
		if str(m.get("id", "")) == "self_cashier":
			models[i] = entry
			replaced = True
			break
	if not replaced:
		models.append(entry)
	CATALOG.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
	SRC.mkdir(parents=True, exist_ok=True)
	model = self_cashier()
	path = SRC / "self_cashier.vox"
	vb.write_vox(path, model)
	patch_catalog(len(model.cells))
	print(f"wrote {path} size={SELF_CASHIER} voxels={len(model.cells)}")


if __name__ == "__main__":
	main()
