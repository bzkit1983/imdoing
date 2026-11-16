#!/usr/bin/env python3
"""v1.5 interim voxel pass: NPCs, restock, shelves, register, goods, floor, wall, dirt.

Writes godot/game/art/src/<id>.vox and patches catalog size/voxel counts.
Does not touch player skins or door.
Limb boxes match tools/voxel_character_anims.py (12×10×20 scaled by sx/12, sz/20).

See docs/systemdesign/art-interim-v1.5.md.
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

CHAR = (90, 40, 130)
# X matches the shelf so Vox.fit scale stays ~1 and on-screen height matches Z=144.
RESTOCK = (256, 96, 144)
SHELF = (256, 128, 144)
REGISTER = (144, 112, 128)
# Board bottoms inside the shelf. Fill props stamp goods on these.
SHELF_BOARDS = (28, 60, 92, 120)


def regions(sx: int = 90, sz: int = 130) -> dict:
    rx = sx / 12.0
    rz = sz / 20.0
    return {
        "leg_z_max": int(round(6 * rz)),
        "arm_z0": int(round(7 * rz)),
        "arm_z1": int(round(11 * rz)),
        "leg_l0": int(round(3 * rx)),
        "leg_l1": int(round(5 * rx)),
        "leg_r0": int(round(7 * rx)),
        "leg_r1": int(round(9 * rx)),
        "arm_l_xmax": int(round(1 * rx)),
        "arm_r_xmin": int(round(10 * rx)),
    }


def fill(m: vb.Model, x0, y0, z0, x1, y1, z1, color: str) -> None:
    idx = vb.COLOR_INDEX[color]
    sx, sy, sz = m.size
    xa, xb = max(0, min(x0, x1)), min(sx - 1, max(x0, x1))
    ya, yb = max(0, min(y0, y1)), min(sy - 1, max(y0, y1))
    za, zb = max(0, min(z0, z1)), min(sz - 1, max(z0, z1))
    if xa > xb or ya > yb or za > zb:
        return
    cells = m.cells
    for x in range(xa, xb + 1):
        for y in range(ya, yb + 1):
            for z in range(za, zb + 1):
                cells[(x, y, z)] = idx


def shell(m: vb.Model, x0, y0, z0, x1, y1, z1, color: str, t: int = 2) -> None:
    idx = vb.COLOR_INDEX[color]
    sx, sy, sz = m.size
    xa, xb = max(0, min(x0, x1)), min(sx - 1, max(x0, x1))
    ya, yb = max(0, min(y0, y1)), min(sy - 1, max(y0, y1))
    za, zb = max(0, min(z0, z1)), min(sz - 1, max(z0, z1))
    cells = m.cells
    for x in range(xa, xb + 1):
        for y in range(ya, yb + 1):
            for z in range(za, zb + 1):
                if (
                    x <= xa + t
                    or x >= xb - t
                    or y <= ya + t
                    or y >= yb - t
                    or z <= za + t
                    or z >= zb - t
                ):
                    cells[(x, y, z)] = idx


def ball(m: vb.Model, cx, cy, cz, rx, ry, rz, color: str) -> None:
    idx = vb.COLOR_INDEX[color]
    sx, sy, sz = m.size
    cells = m.cells
    rx = max(rx, 0.5)
    ry = max(ry, 0.5)
    rz = max(rz, 0.5)
    for z in range(int(cz - rz) - 1, int(cz + rz) + 2):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if not (0 <= x < sx and 0 <= y < sy and 0 <= z < sz):
                    continue
                dx = (x + 0.5 - cx) / rx
                dy = (y + 0.5 - cy) / ry
                dz = (z + 0.5 - cz) / rz
                if dx * dx + dy * dy + dz * dz <= 1.0:
                    cells[(x, y, z)] = idx


def cyl_z(m: vb.Model, cx, cy, z0, z1, r, color: str) -> None:
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


def person(kind: str) -> vb.Model:
    """A-pose NPC inside the student envelope. Hands and feet sit in anim regions."""
    m = vb.Model(*CHAR)
    r = regions()
    shirt = {
        "customer": "customer",
        "thief": "thief",
        "clerk_cashier": "clerk",
        "clerk_restock": "clerk_stock",
    }[kind]
    dark = {
        "customer": "customer_dark",
        "thief": "hood",
        "clerk_cashier": "clerk_dark",
        "clerk_restock": "player_dark",
    }[kind]
    hair = "hood" if kind == "thief" else ("hair" if kind == "clerk_cashier" else "hair_brown")

    # Legs: only inside the swing boxes, gap between them stays empty below the hips.
    fill(m, 24, 16, 0, 36, 28, 7, "shoe")
    fill(m, 54, 16, 0, 66, 28, 7, "shoe")
    fill(m, 26, 17, 6, 34, 27, r["leg_z_max"], "pants")
    fill(m, 56, 17, 6, 64, 27, r["leg_z_max"], "pants")
    # Hips sit above leg_z_max so they bob with the torso instead of a third leg.
    fill(m, 24, 15, 40, 66, 29, 52, "pants")
    shell(m, 30, 12, 50, 60, 31, 94, shirt, 3)
    fill(m, 30, 12, 50, 34, 31, 94, dark)
    fill(m, 56, 12, 50, 60, 31, 94, dark)
    fill(m, 40, 26, 70, 50, 31, 86, "white")  # front placket
    # Neck and head.
    fill(m, 40, 16, 90, 50, 28, 104, "skin")
    ball(m, 45, 22, 114, 13, 11, 14, "skin")
    # Hair or hood over the crown and back, then restore the face.
    ball(m, 45, 18, 120, 14, 12, 12, hair)
    fill(m, 32, 14, 118, 58, 24, 129, hair)
    for (x, y, z), idx in list(m.cells.items()):
        if idx == vb.COLOR_INDEX[hair] and y >= 26 and 104 <= z <= 122 and 34 <= x <= 56:
            m.cells[(x, y, z)] = vb.COLOR_INDEX["skin"]
    # Eyes, brows, mouth on the front.
    fill(m, 38, 30, 112, 42, 33, 116, "white")
    fill(m, 48, 30, 112, 52, 33, 116, "white")
    fill(m, 39, 31, 113, 41, 33, 115, "eye")
    fill(m, 49, 31, 113, 51, 33, 115, "eye")
    fill(m, 37, 30, 117, 43, 32, 119, hair)
    fill(m, 47, 30, 117, 53, 32, 119, hair)
    fill(m, 42, 31, 107, 48, 33, 109, "skin_shade")

    # Shoulders bridge the torso to the arm slabs. They stay outside the arm
    # x-range, so the walk cycle swings the hands and not the chest.
    fill(m, r["arm_l_xmax"] + 1, 14, 60, 32, 29, 80, shirt)
    fill(m, 58, 14, 60, r["arm_r_xmin"] - 1, 29, 80, shirt)
    # Arms in the swing slabs (A-pose: separated from the torso).
    ax1 = r["arm_r_xmin"] + 8
    fill(m, 0, 15, 50, r["arm_l_xmax"], 27, r["arm_z1"] - 2, shirt)
    fill(m, r["arm_r_xmin"], 15, 50, ax1, 27, r["arm_z1"] - 2, shirt)
    fill(m, 0, 16, r["arm_z0"], r["arm_l_xmax"], 26, 52, "skin")
    fill(m, r["arm_r_xmin"], 16, r["arm_z0"], ax1, 26, 52, "skin")
    # Short sleeves stay on the arm voxels so they swing together.
    fill(m, 0, 15, 64, r["arm_l_xmax"], 27, r["arm_z1"], dark)
    fill(m, r["arm_r_xmin"], 15, 64, ax1, 27, r["arm_z1"], dark)

    if kind == "customer":
        # Bag hangs beside the hip, outside both arm and leg boxes.
        fill(m, 10, 8, 52, 20, 18, 86, "customer_dark")
        fill(m, 12, 10, 78, 18, 16, 84, "white")
        fill(m, 14, 18, 70, 16, 28, 90, "customer_dark")
    elif kind == "thief":
        fill(m, 34, 28, 112, 56, 34, 118, "hood")
        fill(m, 38, 32, 113, 42, 34, 116, "white")
        fill(m, 48, 32, 113, 52, 34, 116, "white")
        fill(m, 39, 33, 114, 41, 34, 115, "eye")
        fill(m, 49, 33, 114, 51, 34, 115, "eye")
    elif kind == "clerk_cashier":
        fill(m, 42, 30, 72, 52, 33, 84, "white")
        fill(m, 46, 32, 76, 48, 33, 80, "screen_on")
        fill(m, 34, 18, 122, 56, 30, 129, "clerk")
    elif kind == "clerk_restock":
        fill(m, 34, 28, 54, 56, 33, 90, "white")
        fill(m, 64, 4, 40, 74, 14, 62, "cardboard")
        fill(m, 66, 6, 58, 72, 12, 61, "tape")
        fill(m, 36, 16, 122, 54, 28, 129, "clerk_stock")
    return m


def audit_person(m: vb.Model, kind: str) -> None:
    r = regions()
    feet_l = feet_r = hand_l = hand_r = gap = 0
    for (x, _y, z) in m.cells:
        if z <= 6 and r["leg_l0"] <= x <= r["leg_l1"]:
            feet_l += 1
        if z <= 6 and r["leg_r0"] <= x <= r["leg_r1"]:
            feet_r += 1
        if r["arm_z0"] <= z <= r["arm_z0"] + 6 and x <= r["arm_l_xmax"]:
            hand_l += 1
        if r["arm_z0"] <= z <= r["arm_z0"] + 6 and x >= r["arm_r_xmin"]:
            hand_r += 1
        if 39 <= x <= 51 and z <= r["leg_z_max"]:
            gap += 1
    if min(feet_l, feet_r, hand_l, hand_r) < 12 or gap != 0 or len(m.cells) < 8000:
        raise SystemExit(
            f"{kind} limb audit failed feet={feet_l}/{feet_r} hands={hand_l}/{hand_r} "
            f"gap={gap} voxels={len(m.cells)} regions={r}"
        )


def cabinet(body: str, dark: str, glass: bool = False, lid: bool = False, stripe: str = "can") -> vb.Model:
    w, d, h = SHELF
    m = vb.Model(w, d, h)
    fill(m, 0, 4, 0, w - 1, 14, 6, dark)
    fill(m, 0, d - 18, 0, w - 1, d - 4, 6, dark)
    fill(m, 0, 4, 0, 16, d - 4, 6, dark)
    fill(m, w - 17, 4, 0, w - 1, d - 4, 6, dark)
    # Four posts, not full-depth slabs.
    for x, y in ((0, 10), (w - 12, 10), (0, d - 22), (w - 12, d - 22)):
        fill(m, x, y, 0, x + 11, y + 11, h - 8, body)
    for z in (10, 44, 76, 108, h - 14):
        fill(m, 12, 2, z, w - 13, 8, z + 4, dark)
    fill(m, 12, 2, 8, 18, 8, h - 10, dark)
    fill(m, w - 19, 2, 8, w - 13, 8, h - 10, dark)
    for z in SHELF_BOARDS:
        fill(m, 16, 16, z, w - 17, 36, z + 3, body)
        fill(m, 16, 34, z, w - 17, 56, z + 3, dark)
    fill(m, 16, d - 8, 10, w - 17, d - 2, 16, "metal")
    fill(m, 24, d - 6, 11, w - 25, d - 3, 15, stripe)
    if glass:
        fill(m, 18, d - 10, 22, w - 19, d - 4, 26, "glass")
        fill(m, 18, d - 10, 66, w - 19, d - 4, 72, "glass")
        fill(m, 18, d - 10, h - 24, w - 19, d - 4, h - 12, "glass")
        fill(m, 18, d - 10, 22, 26, d - 4, h - 12, "glass")
        fill(m, w - 27, d - 10, 22, w - 19, d - 4, h - 12, "glass")
    if lid:
        fill(m, 12, 8, h - 12, w - 13, d - 10, h - 2, "metal")
        fill(m, 28, d - 16, h - 18, w - 29, d - 4, h - 10, "glass")
    return m


def restock(accent: str) -> vb.Model:
    w, d, h = RESTOCK
    m = vb.Model(w, d, h)
    for x, y in ((0, 0), (w - 10, 0), (0, d - 10), (w - 10, d - 10)):
        fill(m, x, y, 0, x + 9, y + 9, h - 1, "metal")
    for i, z in enumerate((8, 50, 92)):
        fill(m, 10, 10, z, w - 11, 16, z + 3, "metal")
        fill(m, 10, d - 18, z, w - 11, d - 11, z + 3, "metal")
        fill(m, 10, 10, z, 18, d - 11, z + 3, "metal")
        fill(m, w - 19, 10, z, w - 11, d - 11, z + 3, "metal")
        color = accent if i == 1 else "cardboard"
        shell(m, 18, 16, z + 5, 112, 44, z + 28, color, 2)
        fill(m, 40, 18, z + 26, 90, 42, z + 29, "tape")
        shell(m, 132, 16, z + 5, 230, 44, z + 28, "cardboard", 2)
        fill(m, 156, 18, z + 26, 200, 42, z + 29, "tape")
    return m


def register() -> vb.Model:
    m = vb.Model(*REGISTER)
    shell(m, 4, 8, 0, 139, 96, 48, "wood", 3)
    fill(m, 4, 8, 0, 139, 96, 6, "wood_dark")
    fill(m, 8, 78, 36, 132, 100, 52, "wood_dark")
    fill(m, 0, 6, 50, 143, 88, 58, "metal")
    shell(m, 36, 12, 60, 108, 34, 122, "screen", 3)
    fill(m, 44, 28, 70, 100, 34, 112, "screen_on")
    for i, x in enumerate(range(20, 120, 14)):
        fill(m, x, 84, 52, x + 8, 96, 56, "can" if i % 2 == 0 else "snack")
    fill(m, 16, 22, 18, 42, 68, 34, "wood_dark")
    return m


def _goods_box() -> vb.Model:
    m = vb.Model(64, 64, 48)
    shell(m, 2, 2, 0, 61, 61, 46, "cardboard", 3)
    fill(m, 2, 28, 44, 61, 36, 47, "tape")
    fill(m, 28, 2, 44, 36, 61, 47, "tape")
    return m


def _can() -> vb.Model:
    m = vb.Model(64, 64, 80)
    cyl_z(m, 32, 32, 4, 62, 20, "can")
    cyl_z(m, 32, 32, 62, 74, 21, "metal")
    cyl_z(m, 32, 32, 0, 6, 18, "metal")
    fill(m, 22, 46, 24, 42, 52, 48, "white")
    fill(m, 26, 48, 28, 38, 52, 44, "can")
    return m


def _snack() -> vb.Model:
    m = vb.Model(64, 64, 64)
    # Soft wide bag. Top is a zigzag crimp, not a gable.
    fill(m, 8, 18, 10, 55, 46, 40, "snack")
    fill(m, 4, 24, 16, 59, 40, 36, "snack")
    fill(m, 14, 22, 8, 50, 42, 16, "snack")
    for i, x in enumerate(range(6, 58, 6)):
        z1 = 52 if i % 2 == 0 else 44
        fill(m, x, 26, 40, x + 4, 38, z1, "white" if i % 2 == 0 else "snack")
    fill(m, 24, 40, 22, 40, 48, 32, "white")
    return m


def _cup() -> vb.Model:
    m = vb.Model(64, 64, 80)
    # Noodle cup: paper body, wide lid, horizontal label. No dots that read as a face.
    cyl_z(m, 32, 32, 0, 48, 18, "cup")
    cyl_z(m, 32, 32, 46, 62, 22, "cap")
    cyl_z(m, 32, 32, 18, 34, 19, "rice")
    fill(m, 20, 46, 20, 44, 54, 32, "snack")
    return m


def _drink() -> vb.Model:
    m = vb.Model(64, 64, 96)
    cyl_z(m, 32, 32, 0, 70, 10, "drink")
    cyl_z(m, 32, 32, 70, 82, 8, "white")
    cyl_z(m, 32, 32, 82, 94, 7, "cap")
    fill(m, 28, 40, 24, 36, 44, 52, "white")
    return m


def _milk() -> vb.Model:
    m = vb.Model(64, 64, 96)
    # Rigid carton: rectangular body, short gable, side spout.
    fill(m, 14, 14, 0, 49, 50, 64, "milk")
    fill(m, 14, 14, 0, 49, 50, 4, "metal")
    fill(m, 14, 14, 22, 49, 50, 36, "milk_band")
    fill(m, 14, 14, 0, 18, 50, 64, "milk_band")
    for z in range(64, 90):
        t = (z - 64) / 26.0
        half = max(4, int(18 * (1.0 - t)))
        fill(m, 32 - half, 16, z, 32 + half, 48, z, "milk")
    fill(m, 30, 16, 64, 34, 48, 88, "milk_band")
    fill(m, 50, 26, 34, 62, 42, 50, "milk")
    fill(m, 56, 28, 38, 63, 40, 48, "cap")
    return m


def _soda() -> vb.Model:
    m = vb.Model(64, 64, 80)
    cyl_z(m, 32, 32, 2, 64, 16, "soda")
    cyl_z(m, 32, 32, 64, 74, 17, "metal")
    cyl_z(m, 32, 32, 0, 6, 14, "metal")
    fill(m, 20, 44, 28, 44, 50, 40, "white")
    # Pull tab on the lid.
    fill(m, 28, 36, 74, 36, 44, 78, "metal")
    fill(m, 30, 38, 76, 34, 42, 79, "white")
    return m


def _icecream() -> vb.Model:
    m = vb.Model(64, 64, 96)
    # Waffle cone, point on the ground, two scoops stacked on the same axis.
    for z in range(0, 44):
        half = 4 + int(15 * z / 43)
        fill(m, 32 - half, 28, z, 32 + half, 44, z, "cone")
        if z % 7 < 2:
            fill(m, 32 - half, 34, z, 32 + half, 38, z, "wood_dark")
    ball(m, 32, 36, 54, 16, 14, 14, "icecream")
    ball(m, 32, 36, 74, 12, 11, 12, "white")
    return m


def _meat() -> vb.Model:
    m = vb.Model(80, 64, 32)
    fill(m, 4, 8, 0, 75, 55, 8, "white")
    fill(m, 10, 14, 8, 70, 50, 20, "meat")
    fill(m, 18, 20, 18, 40, 36, 26, "meat")
    fill(m, 44, 22, 16, 66, 42, 24, "skin_shade")
    fill(m, 8, 48, 10, 72, 54, 14, "glass")
    return m


def _rice() -> vb.Model:
    m = vb.Model(80, 64, 32)
    shell(m, 4, 6, 0, 75, 57, 28, "rice", 3)
    fill(m, 10, 12, 16, 36, 50, 26, "snack")
    fill(m, 42, 12, 16, 68, 50, 26, "can")
    # Microwave triangle on the lid.
    for i in range(10):
        fill(m, 36 - i, 52, 26 + i // 3, 44 + i, 58, 27 + i // 3, "white")
    return m


def floor_tile() -> vb.Model:
    """One CELL of shop floor: 128² with readable grout and light wear."""
    m = vb.Model(128, 128, 8)
    fill(m, 0, 0, 0, 127, 127, 2, "floor")
    # 32px boards → 4×4 tiles inside one cell; dark grout on the seams.
    for i in range(0, 128, 32):
        fill(m, i, 0, 0, min(i + 1, 127), 127, 2, "floor_line")
        fill(m, 0, i, 0, 127, min(i + 1, 127), 2, "floor_line")
    # Soft checker so neighbouring cells still read as tiles when repeated.
    for ty in range(0, 128, 32):
        for tx in range(0, 128, 32):
            if ((tx // 32) + (ty // 32)) % 2 == 0:
                fill(m, tx + 4, ty + 4, 2, tx + 28, ty + 28, 3, "floor")
            else:
                fill(m, tx + 6, ty + 6, 2, tx + 26, ty + 26, 2, "tape")
            # Tiny scuffs / rubber marks.
            fill(m, tx + 10, ty + 18, 3, tx + 14, ty + 20, 3, "floor_line")
            fill(m, tx + 20, ty + 8, 3, tx + 22, ty + 12, 3, "wood")
    # Outer cell edge stays darker so the grid reads under furniture.
    fill(m, 0, 0, 0, 127, 0, 3, "floor_line")
    fill(m, 0, 0, 0, 0, 127, 3, "floor_line")
    fill(m, 0, 127, 0, 127, 127, 3, "floor_line")
    fill(m, 127, 0, 0, 127, 127, 3, "floor_line")
    return m


def wall() -> vb.Model:
    """One-cell wall segment with baseboard, panel grooves, and crown."""
    m = vb.Model(128, 16, 128)
    fill(m, 0, 0, 0, 127, 15, 127, "wall")
    # Lighter face wash so the wall is not a flat brown slab.
    fill(m, 0, 12, 8, 127, 15, 118, "wood")
    # Vertical panel seams every 24 voxels.
    for x in range(12, 128, 24):
        fill(m, x, 13, 10, x + 1, 15, 116, "wall")
        fill(m, x + 2, 14, 14, x + 3, 15, 40, "wood_dark")
    # Baseboard + top crown.
    fill(m, 0, 0, 0, 127, 15, 10, "wood_dark")
    fill(m, 0, 10, 8, 127, 15, 14, "wood")
    fill(m, 0, 0, 118, 127, 15, 127, "wood_dark")
    fill(m, 0, 10, 112, 127, 15, 118, "wood")
    # Mid rail.
    fill(m, 0, 12, 58, 127, 15, 66, "wood_dark")
    fill(m, 4, 14, 60, 124, 15, 64, "metal")
    # Occasional wall socket / notice plate.
    fill(m, 88, 14, 28, 104, 15, 42, "white")
    fill(m, 92, 15, 32, 100, 15, 38, "screen")
    fill(m, 20, 14, 78, 44, 15, 102, "tape")
    fill(m, 24, 15, 84, 40, 15, 96, "can")
    return m


def trash() -> vb.Model:
    """Readable litter pile: bag, can, carton, paper."""
    m = vb.Model(112, 96, 48)
    # Ground shadow smear.
    fill(m, 10, 12, 0, 100, 84, 1, "wood_dark")
    # Crushed cardboard box.
    shell(m, 18, 20, 0, 70, 62, 22, "cardboard", 2)
    fill(m, 28, 28, 20, 60, 52, 23, "tape")
    fill(m, 22, 24, 6, 36, 40, 16, "wood_dark")
    # Soft snack bag.
    fill(m, 58, 30, 2, 96, 58, 18, "snack")
    fill(m, 62, 34, 16, 92, 54, 24, "white")
    fill(m, 66, 36, 18, 88, 50, 22, "snack")
    for i, x in enumerate(range(60, 94, 6)):
        fill(m, x, 38, 20, x + 3, 48, 26 if i % 2 == 0 else 22, "white")
    # Knocked soda can on its side.
    cyl_z(m, 34, 72, 2, 14, 8, "soda")
    fill(m, 26, 64, 8, 42, 80, 12, "soda")
    fill(m, 28, 66, 10, 40, 78, 12, "white")
    # Paper wad + bottle.
    ball(m, 82, 70, 8, 12, 10, 6, "white")
    fill(m, 74, 64, 2, 90, 78, 4, "trash")
    cyl_z(m, 88, 24, 0, 28, 6, "drink")
    fill(m, 84, 20, 26, 92, 28, 32, "white")
    # Loose peel / rind scrap.
    fill(m, 12, 48, 2, 28, 66, 8, "trash")
    fill(m, 14, 50, 6, 24, 60, 10, "cone")
    return m


def puddle() -> vb.Model:
    """Irregular wet patch with edge and highlight."""
    m = vb.Model(128, 112, 8)
    # Layered irregular discs instead of a rectangle.
    blobs = [
        (64, 56, 42, 34),
        (40, 48, 28, 22),
        (88, 62, 30, 24),
        (58, 78, 26, 18),
        (70, 34, 24, 16),
    ]
    for cx, cy, rx, ry in blobs:
        ball(m, cx, cy, 1, rx, ry, 1.2, "puddle")
    # Darker rim.
    for (x, y, z), idx in list(m.cells.items()):
        if idx != vb.COLOR_INDEX["puddle"]:
            continue
        edge = False
        for dx, dy in ((-2, 0), (2, 0), (0, -2), (0, 2)):
            if (x + dx, y + dy, z) not in m.cells:
                edge = True
                break
        if edge:
            m.cells[(x, y, z)] = vb.COLOR_INDEX["shelf_frozen"]
    # Specular streak.
    fill(m, 48, 40, 2, 78, 48, 2, "glass")
    fill(m, 54, 42, 2, 72, 46, 3, "white")
    fill(m, 60, 60, 2, 70, 66, 2, "glass")
    return m


def vomit() -> vb.Model:
    """Thicker sick splat, distinct from the blue puddle."""
    m = vb.Model(112, 96, 16)
    blobs = [
        (56, 48, 34, 28, 2.5),
        (36, 40, 20, 16, 2.0),
        (78, 54, 22, 18, 2.2),
        (52, 68, 18, 14, 1.8),
        (64, 30, 16, 12, 1.6),
    ]
    for cx, cy, rx, ry, rz in blobs:
        ball(m, cx, cy, 2, rx, ry, rz, "vomit")
    # Chunks / texture.
    ball(m, 48, 44, 5, 6, 5, 3, "snack")
    ball(m, 68, 52, 6, 5, 4, 3, "cone")
    ball(m, 58, 36, 4, 4, 4, 2, "customer_dark")
    fill(m, 42, 58, 3, 54, 70, 5, "snack")
    # Darker rim so it separates from floor.
    for (x, y, z), idx in list(m.cells.items()):
        if idx != vb.COLOR_INDEX["vomit"] or z > 1:
            continue
        for dx, dy in ((-2, 0), (2, 0), (0, -2), (0, 2)):
            if (x + dx, y + dy, z) not in m.cells:
                m.cells[(x, y, z)] = vb.COLOR_INDEX["wood_dark"]
                break
    return m


MODELS = {
    "customer": ("客人", lambda: person("customer"), "v1.5 中期稿。紫衣、側袋。包絡對齊學生。"),
    "thief": ("小偷", lambda: person("thief"), "v1.5 中期稿。兜帽和面罩。"),
    "clerk_cashier": ("收銀店員", lambda: person("clerk_cashier"), "v1.5 中期稿。藍衣、白牌。"),
    "clerk_restock": ("補貨店員", lambda: person("clerk_restock"), "v1.5 中期稿。綠圍裙、側箱。"),
    "register": ("收銀機", register, "v1.5 中期稿。櫃檯加螢幕。佔格不變。"),
    "restock_dry": ("乾貨補貨架", lambda: restock("can"), "v1.5：256×96×144，畫面高度對齊貨架。佔格仍 2×2。"),
    "restock_frozen": ("凍櫃補貨架", lambda: restock("drink"), "v1.5：同一座較矮倉庫架，箱色用凍飲色。"),
    "restock_ice": ("冰櫃補貨架", lambda: restock("icecream"), "v1.5：同一座較矮倉庫架，箱色用雪糕色。"),
    "shelf_dry": ("乾貨貨架", lambda: cabinet("shelf_dry", "shelf_dry_dark", stripe="can"), "v1.5 中期稿。2×1 格，Z 維持 144。"),
    "shelf_frozen": (
        "凍櫃貨架",
        lambda: cabinet("shelf_frozen", "shelf_ice", glass=True, stripe="drink"),
        "v1.5 中期稿。前面有玻璃框。",
    ),
    "shelf_ice": (
        "冰櫃貨架",
        lambda: cabinet("shelf_ice", "screen", lid=True, stripe="icecream"),
        "v1.5 中期稿。有頂蓋。",
    ),
    "box": ("貨箱", _goods_box, "v1.5 中期稿。紙箱加膠帶。"),
    "can": ("罐頭", _can, "v1.5 中期稿。金屬圓罐。"),
    "snack": ("零食", _snack, "v1.5 中期稿。軟袋，鋸齒封口。"),
    "cup": ("杯麵", _cup, "v1.5 中期稿。有蓋的杯。"),
    "drink": ("支裝凍飲", _drink, "v1.5 中期稿。細長瓶子。"),
    "milk": ("牛奶", _milk, "v1.5 中期稿。屋脊紙盒加倒出口。"),
    "soda": ("汽水", _soda, "v1.5 中期稿。高罐加拉環。"),
    "icecream": ("雪糕", _icecream, "v1.5 中期稿。甜筒雙球。"),
    "meat": ("凍肉", _meat, "v1.5 中期稿。托盤。"),
    "rice": ("叮叮飯", _rice, "v1.5 中期稿。微波盒。"),
    "floor_tile": ("地磚", floor_tile, "v1.5 中期稿。128² 一格，磚縫可辨。"),
    "wall": ("牆", wall, "v1.5 中期稿。踢腳線與分縫；佔格不變。"),
    "trash": ("垃圾", trash, "v1.5 中期稿。紙箱、袋子、罐子可分。"),
    "puddle": ("水漬", puddle, "v1.5 中期稿。不規則水漬加高光。"),
    "vomit": ("嘔吐物", vomit, "v1.5 中期稿。比水漬厚、顏色分開。"),
}


def patch_catalog(stats: dict[str, tuple]) -> None:
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    for group in data["groups"]:
        for model in group["models"]:
            mid = model["id"]
            if mid not in stats:
                continue
            size, voxels, note = stats[mid]
            model["size"] = list(size)
            model["voxels"] = voxels
            model["note"] = note
    CATALOG.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    SRC.mkdir(parents=True, exist_ok=True)
    stats = {}
    for mid, (_name, builder, note) in MODELS.items():
        model = builder()
        if mid in ("customer", "thief", "clerk_cashier", "clerk_restock"):
            audit_person(model, mid)
        if model.size[0] > 256 or model.size[1] > 256 or model.size[2] > 256:
            raise SystemExit(f"{mid} exceeds byte voxel coords {model.size}")
        path = SRC / f"{mid}.vox"
        vb.write_vox(path, model)
        stats[mid] = (model.size, len(model.cells), note)
        print(f"wrote {mid} {model.size} voxels={len(model.cells)}")
    patch_catalog(stats)
    print(f"catalog {CATALOG}")


if __name__ == "__main__":
    main()
