#!/usr/bin/env python3
"""Generate a test sci-fi portal MagicaVoxel model for godot/game.

Writes godot/game/art/src/portal.vox and patches catalog.json furniture entry.
Reference: paired pad teleporter — tiered base, suspended top disc, cyan beam.
Does not overwrite other .vox files.
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))

import voxel_blockout as vb  # noqa: E402
import voxel_sprites as vs  # noqa: E402

SRC = vs.SRC
CATALOG = ROOT / "godot" / "game" / "art" / "catalog.json"

## 2×1 footprint (same family as register). Taller for beam + top disc.
PORTAL = (160, 112, 168)


def cyl_z(m: vb.Model, cx: float, cy: float, z0: int, z1: int, r: float, color: str) -> None:
	idx = vb.COLOR_INDEX[color]
	sx, sy, sz = m.size
	cells = m.cells
	r2 = r * r
	za, zb = max(0, min(z0, z1)), min(sz - 1, max(z0, z1))
	for z in range(za, zb + 1):
		for y in range(int(cy - r) - 1, int(cy + r) + 2):
			for x in range(int(cx - r) - 1, int(cx + r) + 2):
				if not (0 <= x < sx and 0 <= y < sy):
					continue
				dx = x + 0.5 - cx
				dy = y + 0.5 - cy
				if dx * dx + dy * dy <= r2:
					cells[(x, y, z)] = idx


def ring_z(
	m: vb.Model,
	cx: float,
	cy: float,
	z0: int,
	z1: int,
	r_out: float,
	r_in: float,
	color: str,
) -> None:
	idx = vb.COLOR_INDEX[color]
	sx, sy, sz = m.size
	cells = m.cells
	ro2 = r_out * r_out
	ri2 = r_in * r_in
	za, zb = max(0, min(z0, z1)), min(sz - 1, max(z0, z1))
	for z in range(za, zb + 1):
		for y in range(int(cy - r_out) - 1, int(cy + r_out) + 2):
			for x in range(int(cx - r_out) - 1, int(cx + r_out) + 2):
				if not (0 <= x < sx and 0 <= y < sy):
					continue
				dx = x + 0.5 - cx
				dy = y + 0.5 - cy
				d2 = dx * dx + dy * dy
				if ri2 < d2 <= ro2:
					cells[(x, y, z)] = idx


def leds_on_rim(m: vb.Model, cx: float, cy: float, z: int, r: float, n: int, color: str) -> None:
	sx, sy, sz = m.size
	for i in range(n):
		ang = (2.0 * math.pi * i) / n
		x = int(round(cx + math.cos(ang) * r))
		y = int(round(cy + math.sin(ang) * r))
		if not (0 <= x < sx and 0 <= y < sy and 0 <= z < sz):
			continue
		m.set(x, y, z, color)
		if z + 1 < sz and 0 <= y < sy:
			m.set(x, y, z + 1, color)


def portal() -> vb.Model:
	"""Sci-fi pad teleporter: dual-tier base, cyan beam, suspended top disc."""
	m = vb.Model(*PORTAL)
	cx, cy = 80.0, 56.0

	## Floor hologram rings (z≈0). Keep inside Y depth 112 (cy±r).
	ring_z(m, cx, cy, 0, 1, 52, 48, "drink")
	ring_z(m, cx, cy, 0, 1, 42, 38, "screen_on")
	ring_z(m, cx, cy, 0, 0, 32, 30, "drink")

	## Lower base tier (wider).
	cyl_z(m, cx, cy, 0, 16, 50, "shelf_ice")
	cyl_z(m, cx, cy, 0, 4, 50, "screen")
	ring_z(m, cx, cy, 14, 16, 50, 42, "metal")
	leds_on_rim(m, cx, cy, 15, 48, 24, "white")

	## Upper base tier.
	cyl_z(m, cx, cy, 16, 34, 38, "shelf_ice")
	cyl_z(m, cx, cy, 16, 20, 38, "clerk")
	ring_z(m, cx, cy, 32, 34, 38, 30, "metal")
	leds_on_rim(m, cx, cy, 33, 36, 20, "white")

	## Top surface HUD rings + center glow.
	ring_z(m, cx, cy, 34, 36, 34, 28, "screen_on")
	ring_z(m, cx, cy, 34, 36, 24, 18, "drink")
	ring_z(m, cx, cy, 34, 36, 14, 8, "screen_on")
	cyl_z(m, cx, cy, 34, 38, 7, "white")
	cyl_z(m, cx, cy, 36, 40, 4, "screen_on")

	## Radial tick marks on base top (hi-tech UI).
	for i in range(12):
		ang = (2.0 * math.pi * i) / 12
		for t in range(14, 34):
			x = int(round(cx + math.cos(ang) * t))
			y = int(round(cy + math.sin(ang) * t))
			if 0 <= x < m.size[0] and 0 <= y < m.size[1]:
				m.set(x, y, 35, "metal" if t % 3 else "screen_on")

	## Energy beam column (sparse so it reads as glow, not solid).
	for z in range(40, 128):
		phase = (z - 40) / 88.0
		rad = 14 + int(6 * math.sin(phase * math.pi))
		## Soft outer shell every other slice.
		if z % 2 == 0:
			ring_z(m, cx, cy, z, z, rad + 4, rad + 1, "drink")
		## Core
		if z % 3 != 1:
			cyl_z(m, cx, cy, z, z, max(3, rad // 3), "screen_on")
		## Sparkles
		if z % 5 == 0:
			for j in range(5):
				ang = (2.0 * math.pi * (j + z * 0.17)) / 5
				rr = 4 + (j * 3) % 12
				x = int(round(cx + math.cos(ang) * rr))
				y = int(round(cy + math.sin(ang) * rr))
				if 0 <= x < m.size[0] and 0 <= y < m.size[1]:
					m.set(x, y, z, "white" if j % 2 == 0 else "screen_on")

	## Extra floating particles mid-beam.
	for i, (ox, oy, oz) in enumerate(
		[
			(10, 0, 60),
			(-8, 6, 72),
			(6, -10, 88),
			(-12, -4, 100),
			(0, 12, 110),
			(8, 8, 50),
			(-6, -8, 120),
		]
	):
		x, y, z = int(cx + ox), int(cy + oy), oz
		if 0 <= x < m.size[0] and 0 <= y < m.size[1] and 0 <= z < m.size[2]:
			m.set(x, y, z, "white" if i % 2 == 0 else "drink")

	## Suspended top disc.
	cyl_z(m, cx, cy, 128, 148, 42, "shelf_ice")
	cyl_z(m, cx, cy, 128, 132, 42, "clerk")
	ring_z(m, cx, cy, 146, 148, 42, 34, "metal")
	leds_on_rim(m, cx, cy, 147, 40, 22, "white")

	## Underside emitter (bright).
	cyl_z(m, cx, cy, 126, 130, 20, "white")
	cyl_z(m, cx, cy, 124, 128, 12, "screen_on")
	ring_z(m, cx, cy, 128, 130, 32, 24, "drink")
	ring_z(m, cx, cy, 128, 130, 20, 14, "screen_on")

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
		"id": "portal",
		"name": "傳送門",
		"file": "portal.vox",
		"size": list(PORTAL),
		"voxels": voxel_count,
		"note": "測試版科幻墊式傳送門（雙層底座＋頂盤＋青色光束）。佔格 2×1。",
	}
	replaced = False
	for i, m in enumerate(models):
		if str(m.get("id", "")) == "portal":
			models[i] = entry
			replaced = True
			break
	if not replaced:
		models.append(entry)
	CATALOG.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
	SRC.mkdir(parents=True, exist_ok=True)
	model = portal()
	path = SRC / "portal.vox"
	vb.write_vox(path, model)
	patch_catalog(len(model.cells))
	print(f"wrote {path} size={PORTAL} voxels={len(model.cells)}")


if __name__ == "__main__":
	main()
