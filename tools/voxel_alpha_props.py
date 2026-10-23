#!/usr/bin/env python3
"""Bake Alpha enrichment props: shelf fill levels, dirt clean fades, event FX.

Alpha presentation only — designers replace with MagicaVoxel art later.
Does not overwrite art/src/*.vox.

Output under godot/game/art/sprites/:
  shelf_{dry|frozen|ice}_fill_{0..3}_{facing}.png   (four-way)
  {trash|puddle|vomit}_clean_{0..2}_0.png            (facing 0)
  fx_{suck|spray|coin|combo|timestop|clean_spark|skid}_{frame}.png
  props_manifest.json
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

OUT = vs.OUT
MANIFEST_PATH = OUT / "props_manifest.json"

SHELF_CATS = ("dry", "frozen", "ice")
SHELF_COLORS = {
    "dry": ("shelf_dry", "shelf_dry_dark", "can"),
    "frozen": ("shelf_frozen", "metal", "drink"),
    "ice": ("shelf_ice", "glass", "icecream"),
}
DIRTS = ("trash", "puddle", "vomit")
FX_IDS = ("suck", "spray", "coin", "combo", "timestop", "clean_spark", "skid")


def _pal() -> list:
    pal = [(0, 0, 0)] * 256
    for i, (_n, rgb) in enumerate(vb.PALETTE):
        pal[i] = rgb
    return pal


def _load_anchors() -> dict:
    path = OUT / "anchors.json"
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    return {"px": vs.PX, "tile_px": 16 * vs.PX}


def _save_model(name: str, model: vb.Model, facing: int, anchors: dict, pal: list) -> None:
    size = model.size
    cells = model.cells
    rsize, rcells = vs.rotate(size, cells, facing)
    width, height, image = vs.render(rsize, rcells, pal)
    vs.save_png(OUT / f"{name}.png", width, height, image)
    sx, sy, sz = rsize
    anchors[name] = {
        "ax": sx * vs.PX / 2,
        "ay": sz * vs.PX + sy * vs.PX / 2,
        "fw": sx * vs.PX,
        "fh": sy * vs.PX,
    }


def _shelf_model(cat: str, fill: int) -> vb.Model:
    """fill 0 empty … 3 full. Goods stack height grows with fill."""
    body, trim, goods = SHELF_COLORS[cat]
    m = vb.Model(14, 10, 16)
    # Cabinet
    m.fill(1, 2, 0, 12, 8, 2, body)
    m.fill(1, 2, 3, 12, 8, 10, trim)
    m.fill(1, 2, 11, 12, 8, 12, body)
    # Posts
    m.fill(1, 2, 0, 2, 3, 12, body)
    m.fill(11, 2, 0, 12, 3, 12, body)
    if fill <= 0:
        return m
    # Goods rows: 1→low, 2→mid, 3→top shelf packed
    rows = min(fill, 3)
    for ri in range(rows):
        z0 = 3 + ri * 3
        z1 = z0 + 1
        m.fill(3, 3, z0, 10, 7, z1, goods)
        # Speckle SKU colors
        for x in range(3, 11, 2):
            m.set(x, 5, z1, "player" if ri % 2 == 0 else "can")
    return m


def _dirt_clean_model(dirt: str, stage: int) -> vb.Model:
    """stage 0 solid → 2 nearly gone."""
    m = vb.Model(10, 10, 4)
    colors = {
        "trash": ("trash", "wood_dark"),
        "puddle": ("puddle", "glass"),
        "vomit": ("vomit", "customer_dark"),
    }
    c0, c1 = colors[dirt]
    # Shrink footprint + height by stage
    inset = stage
    z_top = max(0, 2 - stage)
    m.fill(1 + inset, 1 + inset, 0, 8 - inset, 8 - inset, z_top, c0)
    if stage == 0:
        m.fill(3, 3, z_top, 6, 6, z_top, c1)
    return m


def _fx_frames(fx: str) -> list[list[tuple[int, int, int, int]]]:
    """Return list of small RGBA frames (24×24)."""
    size = 24
    frames: list[list[tuple[int, int, int, int]]] = []

    def blank():
        return [(0, 0, 0, 0)] * (size * size)

    def put(img, x, y, rgba):
        if 0 <= x < size and 0 <= y < size:
            img[y * size + x] = rgba

    def disc(img, cx, cy, r, rgba):
        for y in range(size):
            for x in range(size):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    put(img, x, y, rgba)

    if fx == "suck":
        for i in range(4):
            img = blank()
            r = 10 - i * 2
            disc(img, 12, 12, r, (120, 200, 255, 200 - i * 40))
            disc(img, 12, 12, max(1, r - 3), (0, 0, 0, 0))
            frames.append(img)
    elif fx == "spray":
        for i in range(4):
            img = blank()
            for k in range(6):
                ang = (i * 0.4 + k) * 0.9
                x = int(12 + math.cos(ang) * (4 + i * 2))
                y = int(12 + math.sin(ang) * (4 + i * 2) - i)
                disc(img, x, y, 2, (255, 220, 120, 220 - i * 40))
            frames.append(img)
    elif fx == "coin":
        for i in range(3):
            img = blank()
            disc(img, 12, 14 - i * 2, 5, (255, 210, 60, 230))
            disc(img, 12, 14 - i * 2, 3, (255, 240, 140, 230))
            frames.append(img)
    elif fx == "combo":
        for i in range(3):
            img = blank()
            disc(img, 12, 12, 8 - i, (255, 120, 80, 200))
            disc(img, 12, 12, 4, (255, 220, 180, 220))
            frames.append(img)
    elif fx == "timestop":
        for i in range(4):
            img = blank()
            a = 160 - i * 30
            for t in range(0, 360, 15):
                rad = math.radians(t + i * 10)
                x = int(12 + math.cos(rad) * (9 - i))
                y = int(12 + math.sin(rad) * (9 - i))
                put(img, x, y, (160, 220, 255, a))
            frames.append(img)
    elif fx == "clean_spark":
        for i in range(3):
            img = blank()
            for dx, dy in ((0, -1), (1, 0), (0, 1), (-1, 0), (1, -1), (-1, 1)):
                disc(img, 12 + dx * (2 + i), 12 + dy * (2 + i), 2, (220, 255, 180, 220 - i * 50))
            frames.append(img)
    elif fx == "skid":
        for i in range(3):
            img = blank()
            for x in range(4 + i, 20 - i):
                put(img, x, 16 + (x % 3) - 1, (90, 70, 50, 180 - i * 40))
                put(img, x, 18, (70, 55, 40, 140 - i * 30))
            frames.append(img)
    else:
        frames.append(blank())
    return frames


def bake() -> dict:
    OUT.mkdir(parents=True, exist_ok=True)
    anchors = _load_anchors()
    pal = _pal()
    written = 0
    manifest: dict = {"version": 1, "shelves": {}, "dirts": {}, "fx": {}}

    for cat in SHELF_CATS:
        levels = {}
        for fill in range(4):
            model = _shelf_model(cat, fill)
            levels[f"fill_{fill}"] = {"frames": 1, "facings": 4}
            for facing in range(4):
                name = f"shelf_{cat}_fill_{fill}_{facing}"
                _save_model(name, model, facing, anchors, pal)
                written += 1
        manifest["shelves"][f"shelf_{cat}"] = levels

    for dirt in DIRTS:
        stages = {}
        for stage in range(3):
            model = _dirt_clean_model(dirt, stage)
            stages[f"clean_{stage}"] = {"frames": 1}
            name = f"{dirt}_clean_{stage}_0"
            _save_model(name, model, 0, anchors, pal)
            written += 1
        manifest["dirts"][dirt] = stages

    for fx in FX_IDS:
        frames = _fx_frames(fx)
        manifest["fx"][fx] = {"frames": len(frames), "size": 24}
        for fi, img in enumerate(frames):
            name = f"fx_{fx}_{fi}"
            vs.save_png(OUT / f"{name}.png", 24, 24, img)
            anchors[name] = {"ax": 12, "ay": 12, "fw": 24, "fh": 24}
            written += 1

    (OUT / "anchors.json").write_text(json.dumps(anchors, indent=2) + "\n", encoding="utf-8")
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {written} prop/fx sprites → {OUT}")
    print(f"manifest → {MANIFEST_PATH}")
    return manifest


if __name__ == "__main__":
    bake()
