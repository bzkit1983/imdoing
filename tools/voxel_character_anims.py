#!/usr/bin/env python3
"""Bake Alpha character action sprites (pose × facing × frame).

Does NOT overwrite designer .vox in art/src/. Poses are built procedurally from
the shared 12×10×20 person template (same as voxel_blockout.person), then
rendered with voxel_sprites.rotate/render.

Output:
  godot/game/art/sprites/{id}_{anim}_{facing}_{frame}.png
  godot/game/art/sprites/anim_manifest.json

Facing: 0 south, 1 east, 2 north, 3 west (same as voxel_sprites).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))

import voxel_blockout as vb  # noqa: E402
import voxel_sprites as vs  # noqa: E402

OUT = vs.OUT
MANIFEST_PATH = OUT / "anim_manifest.json"

# Character kits: shirt, shirt_dark, hair, extras
# customer_hurry / customer_slow = Alpha pace variants (not full recolors of one mesh).
CHARS = {
    "player": dict(shirt="player", shirt_dark="player_dark", hair="hair"),
    "customer": dict(shirt="customer", shirt_dark="customer_dark", hair="hair_brown", bag=True),
    "customer_hurry": dict(shirt="soda", shirt_dark="thief", hair="hair", bag=True),
    "customer_slow": dict(shirt="clerk", shirt_dark="clerk_dark", hair="hair_brown", bag=True),
    "thief": dict(shirt="thief", shirt_dark="hood", hair="hair", hood=True, mask=True),
    "clerk_cashier": dict(shirt="clerk", shirt_dark="clerk_dark", hair="hair", badge=True),
    "clerk_restock": dict(shirt="clerk_stock", shirt_dark="player_dark", hair="hair_brown"),
}

# anim -> list of pose dicts (one per frame)
# Pose keys move limbs relative to idle person() layout.
#
# Legs: L x3-5, R x7-9; base y 4-6, z 0-6
# Arms: L x0-1, R x10-11; base y 4-6, z 7-11 (hands z7)


def _walk_frames(amp: int = 1) -> list[dict]:
    return [
        {"leg_l_y": amp, "leg_r_y": -amp, "arm_l_y": -amp, "arm_r_y": amp, "bob": 0},
        {"leg_l_y": 0, "leg_r_y": 0, "arm_l_y": 0, "arm_r_y": 0, "bob": 1},
        {"leg_l_y": -amp, "leg_r_y": amp, "arm_l_y": amp, "arm_r_y": -amp, "bob": 0},
        {"leg_l_y": 0, "leg_r_y": 0, "arm_l_y": 0, "arm_r_y": 0, "bob": 1},
    ]


def _walk_carry_frames() -> list[dict]:
    """Walk while arms hold a box high (clerks / player carrying)."""
    return [
        {"leg_l_y": 1, "leg_r_y": -1, "arm_l_z": 2, "arm_r_z": 2, "arm_l_y": 1, "arm_r_y": 1, "bob": 0},
        {"leg_l_y": 0, "leg_r_y": 0, "arm_l_z": 2, "arm_r_z": 2, "arm_l_y": 1, "arm_r_y": 1, "bob": 1},
        {"leg_l_y": -1, "leg_r_y": 1, "arm_l_z": 2, "arm_r_z": 2, "arm_l_y": 1, "arm_r_y": 1, "bob": 0},
        {"leg_l_y": 0, "leg_r_y": 0, "arm_l_z": 2, "arm_r_z": 2, "arm_l_y": 1, "arm_r_y": 1, "bob": 1},
    ]


CUSTOMER_IDS = ["customer", "customer_hurry", "customer_slow"]

ANIMS: dict[str, dict] = {
    # Shared locomotion
    "idle": {"frames": [{"bob": 0}, {"bob": 1}], "fps": 2, "chars": "all"},
    "walk": {"frames": _walk_frames(1), "fps": 8, "chars": "all"},
    "run": {
        "frames": _walk_frames(2)
        + [
            {"leg_l_y": 2, "leg_r_y": -2, "arm_l_y": -2, "arm_r_y": 2, "lean": 1, "bob": 0},
            {"leg_l_y": -2, "leg_r_y": 2, "arm_l_y": 2, "arm_r_y": -2, "lean": 1, "bob": 1},
        ],
        "fps": 12,
        "chars": ["player"],
    },
    "dash": {
        "frames": [
            {"lean": 2, "leg_l_y": -1, "leg_r_y": -1, "arm_l_y": 1, "arm_r_y": 1, "bob": 0},
            {"lean": 3, "leg_l_y": -2, "leg_r_y": 0, "arm_l_y": 2, "arm_r_y": 0, "bob": 1},
            {"lean": 2, "leg_l_y": 0, "leg_r_y": -2, "arm_l_y": 0, "arm_r_y": 2, "bob": 0},
        ],
        "fps": 14,
        "chars": ["player"],
    },
    # mop / sweep cycle
    "clean": {
        "frames": [
            {"arm_r_z": -2, "arm_r_y": 2, "lean": 1, "bob": 0},
            {"arm_r_z": -4, "arm_r_y": 1, "lean": 1, "bob": 0},
            {"arm_r_z": -3, "arm_r_y": 0, "lean": 1, "bob": 1},
            {"arm_r_z": -4, "arm_r_y": 2, "lean": 1, "bob": 0},
        ],
        "fps": 8,
        "chars": ["player"],
    },
    # grab → punch rhythm
    "fight": {
        "frames": [
            {"arm_l_y": 2, "arm_r_y": 2, "arm_l_z": 1, "arm_r_z": 1, "lean": 1},
            {"arm_l_y": 3, "arm_r_y": 1, "arm_l_z": 0, "arm_r_z": 0, "lean": 1},
            {"arm_l_y": 1, "arm_r_y": 3, "arm_l_z": 0, "arm_r_z": 1, "lean": 2},
            {"arm_l_y": 2, "arm_r_y": 2, "arm_l_z": 1, "arm_r_z": 1, "lean": 1},
        ],
        "fps": 12,
        "chars": ["player", "thief"],
    },
    # button / card tap
    "checkout": {
        "frames": [
            {"arm_r_y": 1, "arm_r_z": 0, "lean": 0},
            {"arm_r_y": 2, "arm_r_z": 1, "lean": 0},
            {"arm_r_y": 2, "arm_r_z": 0, "lean": 0},
        ],
        "fps": 6,
        "chars": ["player", "clerk_cashier"],
    },
    "slip": {
        "frames": [
            {"leg_l_y": 2, "leg_r_y": -1, "lean": -1, "arm_l_y": -1, "arm_r_y": 2},
            {"leg_l_y": 2, "leg_r_y": -2, "lean": -2, "arm_l_y": -2, "arm_r_y": 2, "bob": -1},
        ],
        "fps": 6,
        "chars": ["player"],
    },
    "down": {
        "frames": [{"leg_l_y": 1, "leg_r_y": 1, "lean": -2, "arm_l_z": -2, "arm_r_z": -2, "bob": -1}],
        "fps": 1,
        "chars": ["player"],
    },
    "restock": {
        "frames": [
            {"arm_l_y": 1, "arm_r_y": 1, "arm_l_z": 1, "arm_r_z": 1, "lean": 1},
            {"arm_l_y": 2, "arm_r_y": 2, "arm_l_z": 0, "arm_r_z": 0, "lean": 1},
            {"arm_l_y": 2, "arm_r_y": 2, "arm_l_z": 1, "arm_r_z": 1, "lean": 1},
        ],
        "fps": 6,
        "chars": ["clerk_restock", "player"],
    },
    "walk_carry": {
        "frames": _walk_carry_frames(),
        "fps": 8,
        "chars": ["clerk_restock", "clerk_cashier", "player"],
    },
    "angry": {
        "frames": [
            {"arm_l_y": -1, "arm_r_y": -1, "arm_l_z": 2, "arm_r_z": 2},
            {"arm_l_y": -1, "arm_r_y": -1, "arm_l_z": 3, "arm_r_z": 2, "bob": 1},
            {"arm_l_y": -1, "arm_r_y": -1, "arm_l_z": 2, "arm_r_z": 3},
        ],
        "fps": 5,
        "chars": CUSTOMER_IDS,
    },
    "leave": {"frames": _walk_frames(1), "fps": 8, "chars": CUSTOMER_IDS + ["thief"]},
    "fly": {
        "frames": [
            {"lean": 3, "leg_l_y": -1, "leg_r_y": 1, "arm_l_y": -2, "arm_r_y": 2, "bob": 2},
            {"lean": 3, "leg_l_y": 1, "leg_r_y": -1, "arm_l_y": 2, "arm_r_y": -2, "bob": 3},
            {"lean": 2, "leg_l_y": -1, "leg_r_y": 1, "arm_l_y": -1, "arm_r_y": 2, "bob": 2},
            {"lean": 3, "leg_l_y": 0, "leg_r_y": 0, "arm_l_y": -2, "arm_r_y": 2, "bob": 4},
        ],
        "fps": 12,
        "chars": ["thief"],
    },
    # skill / ult cast (arms up)
    "cast": {
        "frames": [
            {"arm_l_z": 2, "arm_r_z": 2, "arm_l_y": 0, "arm_r_y": 0, "lean": 0},
            {"arm_l_z": 3, "arm_r_z": 3, "arm_l_y": -1, "arm_r_y": 1, "lean": 1, "bob": 1},
            {"arm_l_z": 2, "arm_r_z": 2, "arm_l_y": 0, "arm_r_y": 0, "lean": 0},
        ],
        "fps": 8,
        "chars": ["player"],
    },
    # help / combo hand-off
    "deliver": {
        "frames": [
            {"arm_r_y": 2, "arm_r_z": 1, "lean": 1},
            {"arm_r_y": 3, "arm_r_z": 0, "lean": 1},
        ],
        "fps": 6,
        "chars": ["player"],
    },
}


def _clamp(v: int, lo: int, hi: int) -> int:
    return max(lo, min(hi, v))


def person_posed(
    shirt: str,
    shirt_dark: str,
    hair: str,
    hood: bool = False,
    mask: bool = False,
    badge: bool = False,
    bag: bool = False,
    pose: dict | None = None,
) -> vb.Model:
    """12×10×20 body with limb offsets. Feet stay near z=0; face +Y."""
    pose = pose or {}
    leg_l_y = int(pose.get("leg_l_y", 0))
    leg_r_y = int(pose.get("leg_r_y", 0))
    arm_l_y = int(pose.get("arm_l_y", 0))
    arm_r_y = int(pose.get("arm_r_y", 0))
    arm_l_z = int(pose.get("arm_l_z", 0))
    arm_r_z = int(pose.get("arm_r_z", 0))
    lean = int(pose.get("lean", 0))  # shift torso/head toward +Y
    bob = int(pose.get("bob", 0))

    # Extra depth for lean/walk so voxels stay in bounds
    sy = 10 + abs(lean) + 2
    sz = 20 + max(0, bob)
    m = vb.Model(12, sy, sz)

    def ly(base: int, dy: int) -> int:
        return _clamp(base + dy + (lean if lean > 0 else 0), 0, sy - 1)

    def lz(base: int) -> int:
        return _clamp(base + bob, 0, sz - 1)

    def torso_y0() -> int:
        return ly(3, 0)

    def torso_y1() -> int:
        return ly(7, lean if lean > 0 else lean)

    # Shoes + legs
    m.fill(3, ly(4, leg_l_y), lz(0), 5, ly(6, leg_l_y), lz(0), "shoe")
    m.fill(7, ly(4, leg_r_y), lz(0), 9, ly(6, leg_r_y), lz(0), "shoe")
    m.fill(3, ly(4, leg_l_y), lz(1), 5, ly(6, leg_l_y), lz(6), "pants")
    m.fill(7, ly(4, leg_r_y), lz(1), 9, ly(6, leg_r_y), lz(6), "pants")

    tz0, tz1 = lz(7), lz(12)
    m.fill(2, torso_y0(), tz0, 9, torso_y1(), tz1, shirt)
    m.fill(2, torso_y0(), tz0, 2, torso_y1(), tz1, shirt_dark)
    m.fill(9, torso_y0(), tz0, 9, torso_y1(), tz1, shirt_dark)
    m.fill(4, torso_y1(), tz1, 7, torso_y1(), tz1, "white")

    # Arms
    al_y0, al_y1 = ly(4, arm_l_y), ly(6, arm_l_y)
    ar_y0, ar_y1 = ly(4, arm_r_y), ly(6, arm_r_y)
    al_z0 = lz(8 + arm_l_z)
    al_z1 = max(al_z0, lz(11 + arm_l_z))
    ar_z0 = lz(8 + arm_r_z)
    ar_z1 = max(ar_z0, lz(11 + arm_r_z))
    m.fill(0, al_y0, al_z0, 1, al_y1, al_z1, shirt)
    m.fill(10, ar_y0, ar_z0, 11, ar_y1, ar_z1, shirt)
    m.fill(0, al_y0, lz(7 + arm_l_z), 1, al_y1, lz(7 + arm_l_z), "skin")
    m.fill(10, ar_y0, lz(7 + arm_r_z), 11, ar_y1, lz(7 + arm_r_z), "skin")

    # Head
    hz0, hz1 = lz(13), lz(17)
    hy0, hy1 = torso_y0(), _clamp(torso_y1() + 1, 0, sy - 1)
    m.fill(3, hy0, hz0, 8, hy1, hz1, "skin")
    if hood:
        m.fill(2, _clamp(hy0 - 1, 0, sy - 1), lz(12), 9, hy1, lz(19), "hood")
        m.fill(4, hy1, lz(14), 7, _clamp(hy1 + 1, 0, sy - 1), lz(16), "skin")
    else:
        m.fill(3, hy0, lz(17), 8, hy1, lz(19), hair)
        m.fill(3, hy0, lz(14), 8, _clamp(hy0 + 1, 0, sy - 1), lz(17), hair)
        m.fill(3, hy1, lz(16), 8, hy1, lz(17), hair)
    if mask:
        m.fill(3, hy1, lz(15), 8, _clamp(hy1 + 1, 0, sy - 1), lz(15), "hood")
        m.set(4, _clamp(hy1 + 1, 0, sy - 1), lz(15), "white")
        m.set(7, _clamp(hy1 + 1, 0, sy - 1), lz(15), "white")
    else:
        m.set(4, hy1, lz(15), "eye")
        m.set(7, hy1, lz(15), "eye")
        m.set(5, hy1, lz(14), "skin_shade")
        m.set(6, hy1, lz(14), "skin_shade")
    if badge:
        m.fill(5, hy1, lz(9), 6, hy1, lz(10), "white")
    if bag:
        m.fill(10, ly(5, 0), lz(5), 11, ly(8, 0), lz(11), "customer_dark")
    return m


def _chars_for(spec: dict) -> list[str]:
    who = spec["chars"]
    if who == "all":
        return list(CHARS.keys())
    return list(who)


def _palette_list():
    # MagicaVoxel index 1..n maps to PALETTE[0..]
    return [rgb for _name, rgb in vb.PALETTE]


def bake() -> dict:
    OUT.mkdir(parents=True, exist_ok=True)
    # Keep existing anchors from static bake; merge anim keys.
    anchors_path = OUT / "anchors.json"
    if anchors_path.exists():
        anchors = json.loads(anchors_path.read_text(encoding="utf-8"))
    else:
        anchors = {"px": vs.PX, "tile_px": 16 * vs.PX}

    palette = _palette_list()
    # Pad to 256 like MagicaVoxel
    while len(palette) < 256:
        palette.append((0, 0, 0))

    manifest: dict = {"version": 1, "facing": ["s", "e", "n", "w"], "characters": {}}
    written = 0

    for char_id, kit in CHARS.items():
        char_anims: dict = {}
        for anim, spec in ANIMS.items():
            if char_id not in _chars_for(spec):
                continue
            frames = spec["frames"]
            fps = int(spec["fps"])
            char_anims[anim] = {"frames": len(frames), "fps": fps}
            for fi, pose in enumerate(frames):
                model = person_posed(**kit, pose=pose)
                # Convert Model cells (color names → indices already in model.cells)
                size = model.size
                cells = model.cells
                # Build palette array indexed by color index (1-based in cells)
                pal = [(0, 0, 0)] * 256
                for i, (_n, rgb) in enumerate(vb.PALETTE):
                    pal[i] = rgb  # voxel_sprites.render uses palette[index-1]
                for facing in range(4):
                    rsize, rcells = vs.rotate(size, cells, facing)
                    width, height, image = vs.render(rsize, rcells, pal)
                    name = f"{char_id}_{anim}_{facing}_{fi}"
                    vs.save_png(OUT / f"{name}.png", width, height, image)
                    sx, sy, sz = rsize
                    anchors[name] = {
                        "ax": sx * vs.PX / 2,
                        "ay": sz * vs.PX + sy * vs.PX / 2,
                        "fw": sx * vs.PX,
                        "fh": sy * vs.PX,
                    }
                    written += 1
        manifest["characters"][char_id] = char_anims

    anchors_path.write_text(json.dumps(anchors, indent=2) + "\n", encoding="utf-8")
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {written} anim sprites → {OUT}")
    print(f"manifest → {MANIFEST_PATH}")
    return manifest


if __name__ == "__main__":
    bake()
