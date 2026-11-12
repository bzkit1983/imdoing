#!/usr/bin/env python3
"""Bake Alpha character action sprites (pose × facing × frame).

Shading follows voxel_sprites.render (VOXEL_SHADING=classic|cartoon, default cartoon).
Does NOT overwrite designer .vox in art/src/.

When `art/src/{id}.vox` exists, that MagicaVoxel model is the appearance source:
limb/torso pose offsets are applied to its voxels (shared 12×10×20 regions).
When missing, falls back to the procedural person template (voxel_blockout).

Designer MagicaVoxel frame sequences can also override a whole anim by placing:
  art/src/anim/{id}_{anim}_{facing}_{frame}.vox
Facing in that path is 16-way (0 south … 15 SSW) when complete (full16).
Legacy 8-way packs (0–7) map to even outs 0/2/…/14 with 22.5° half-steps.
Legacy 4-way packs (0–3 = S/E/N/W) map to 0/4/8/12 with intermediate yaws.

Output:
  godot/game/art/sprites/{id}_{anim}_{facing}_{frame}.png
  godot/game/art/sprites/anim_manifest.json

Facing (16-way): 0 s, 1 sse, 2 se, 3 ese, 4 e, 5 ene, 6 ne, 7 nne,
  8 n, 9 nnw, 10 nw, 11 wnw, 12 w, 13 wsw, 14 sw, 15 ssw.
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
SRC = vs.SRC
ANIM_SRC = SRC / "anim"
MANIFEST_PATH = OUT / "anim_manifest.json"
FACINGS = 16
FACING_NAMES = [
    "s",
    "sse",
    "se",
    "ese",
    "e",
    "ene",
    "ne",
    "nne",
    "n",
    "nnw",
    "nw",
    "wnw",
    "w",
    "wsw",
    "sw",
    "ssw",
]

# Character kits: shirt, shirt_dark, hair, extras
# customer_hurry / customer_slow = Alpha pace variants (not full recolors of one mesh).
## Player skins share the same anim kit; appearance comes from art/src/{id}.vox.
PLAYER_IDS = ["player", "player_alt1", "player_alt2"]

CHARS = {
    "player": dict(shirt="player", shirt_dark="player_dark", hair="hair"),
    "player_alt1": dict(shirt="player", shirt_dark="player_dark", hair="hair"),
    "player_alt2": dict(shirt="player", shirt_dark="player_dark", hair="hair"),
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
        "chars": list(PLAYER_IDS),
    },
    "dash": {
        "frames": [
            {"lean": 2, "leg_l_y": -1, "leg_r_y": -1, "arm_l_y": 1, "arm_r_y": 1, "bob": 0},
            {"lean": 3, "leg_l_y": -2, "leg_r_y": 0, "arm_l_y": 2, "arm_r_y": 0, "bob": 1},
            {"lean": 2, "leg_l_y": 0, "leg_r_y": -2, "arm_l_y": 0, "arm_r_y": 2, "bob": 0},
        ],
        "fps": 14,
        "chars": list(PLAYER_IDS),
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
        "chars": list(PLAYER_IDS),
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
        "chars": list(PLAYER_IDS) + ["thief"],
    },
    # button / card tap
    "checkout": {
        "frames": [
            {"arm_r_y": 1, "arm_r_z": 0, "lean": 0},
            {"arm_r_y": 2, "arm_r_z": 1, "lean": 0},
            {"arm_r_y": 2, "arm_r_z": 0, "lean": 0},
        ],
        "fps": 6,
        "chars": list(PLAYER_IDS) + ["clerk_cashier"],
    },
    "slip": {
        "frames": [
            {"leg_l_y": 2, "leg_r_y": -1, "lean": -1, "arm_l_y": -1, "arm_r_y": 2},
            {"leg_l_y": 2, "leg_r_y": -2, "lean": -2, "arm_l_y": -2, "arm_r_y": 2, "bob": -1},
        ],
        "fps": 6,
        "chars": list(PLAYER_IDS),
    },
    "down": {
        "frames": [{"leg_l_y": 1, "leg_r_y": 1, "lean": -2, "arm_l_z": -2, "arm_r_z": -2, "bob": -1}],
        "fps": 1,
        "chars": list(PLAYER_IDS),
    },
    "restock": {
        "frames": [
            {"arm_l_y": 1, "arm_r_y": 1, "arm_l_z": 1, "arm_r_z": 1, "lean": 1},
            {"arm_l_y": 2, "arm_r_y": 2, "arm_l_z": 0, "arm_r_z": 0, "lean": 1},
            {"arm_l_y": 2, "arm_r_y": 2, "arm_l_z": 1, "arm_r_z": 1, "lean": 1},
        ],
        "fps": 6,
        "chars": ["clerk_restock"] + list(PLAYER_IDS),
    },
    "walk_carry": {
        "frames": _walk_carry_frames(),
        "fps": 8,
        "chars": ["clerk_restock", "clerk_cashier"] + list(PLAYER_IDS),
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
        "chars": list(PLAYER_IDS),
    },
    # help / combo hand-off
    "deliver": {
        "frames": [
            {"arm_r_y": 2, "arm_r_z": 1, "lean": 1},
            {"arm_r_y": 3, "arm_r_z": 0, "lean": 1},
        ],
        "fps": 6,
        "chars": list(PLAYER_IDS),
    },
}


def _clamp(v: int, lo: int, hi: int) -> int:
    return max(lo, min(hi, v))


def _load_designer(char_id: str):
    """Return (size, cells, palette) from art/src/{id}.vox, or None."""
    path = SRC / f"{char_id}.vox"
    if not path.exists():
        return None
    return vs.read_vox(path)


def _mv_frame_path(char_id: str, anim: str, facing: int, frame: int) -> Path:
    return ANIM_SRC / f"{char_id}_{anim}_{facing}_{frame}.vox"


def _has_mv_anim_range(char_id: str, anim: str, frame_count: int, n_face: int) -> bool:
    """True when every facing in 0..n_face-1 × frame MagicaVoxel override exists."""
    for facing in range(n_face):
        for fi in range(frame_count):
            if not _mv_frame_path(char_id, anim, facing, fi).exists():
                return False
    return True


def _has_mv_anim_16(char_id: str, anim: str, frame_count: int) -> bool:
    return _has_mv_anim_range(char_id, anim, frame_count, 16)


def _has_mv_anim_legacy8(char_id: str, anim: str, frame_count: int) -> bool:
    """True when legacy 8-way (0–7) MagicaVoxel overrides are complete."""
    return _has_mv_anim_range(char_id, anim, frame_count, 8)


def _has_mv_anim_legacy4(char_id: str, anim: str, frame_count: int) -> bool:
    """True when legacy S/E/N/W (facing 0–3) MagicaVoxel overrides are complete."""
    return _has_mv_anim_range(char_id, anim, frame_count, 4)


def _write_mv_frames(
    anchors: dict,
    char_id: str,
    anim: str,
    frame_count: int,
    mode: str,
) -> int:
    """Bake MagicaVoxel overrides into 16-way PNGs. Returns frames written."""
    written = 0
    for fi in range(frame_count):
        for facing in range(FACINGS):
            name = f"{char_id}_{anim}_{facing}_{fi}"
            if mode == "full16":
                size, cells, pal = vs.read_vox(_mv_frame_path(char_id, anim, facing, fi))
                _write_frame(anchors, name, size, cells, pal)
            elif mode == "legacy8":
                ## 0..7 Magica → even outs 0/2/…/14; odds = previous + 22.5°.
                leg = facing // 2
                size, cells, pal = vs.read_vox(_mv_frame_path(char_id, anim, leg, fi))
                if facing % 2 == 1:
                    size, cells = vs.rotate_yaw_degrees(size, cells, 22.5)
                _write_frame(anchors, name, size, cells, pal)
            else:
                ## Legacy 4-way 0/1/2/3 = S/E/N/W → outs 0/4/8/12 + intermediate yaw.
                leg = facing // 4
                rem = facing % 4
                size, cells, pal = vs.read_vox(_mv_frame_path(char_id, anim, leg, fi))
                if rem:
                    size, cells = vs.rotate_yaw_degrees(size, cells, 22.5 * rem)
                _write_frame(anchors, name, size, cells, pal)
            written += 1
    return written


def _apply_pose_to_vox(size, cells: dict, pose: dict | None):
    """Shift designer voxels by shared limb regions (12×10×20 person layout).

    Regions (MagicaVoxel: X right, Y forward, Z up):
      leg L x3-5 z0-6 · leg R x7-9 z0-6
      arm L x0-1 z7-11 · arm R x10-11 z7-11
      torso/head: lean (+Y) and bob (+Z)
    """
    pose = pose or {}
    leg_l_y = int(pose.get("leg_l_y", 0))
    leg_r_y = int(pose.get("leg_r_y", 0))
    arm_l_y = int(pose.get("arm_l_y", 0))
    arm_r_y = int(pose.get("arm_r_y", 0))
    arm_l_z = int(pose.get("arm_l_z", 0))
    arm_r_z = int(pose.get("arm_r_z", 0))
    lean = int(pose.get("lean", 0))
    bob = int(pose.get("bob", 0))
    if not any((leg_l_y, leg_r_y, arm_l_y, arm_r_y, arm_l_z, arm_r_z, lean, bob)):
        return size, cells

    sx, sy, sz = size
    out_sy = sy + abs(lean) + 2
    out_sz = sz + max(0, bob) + max(0, max(arm_l_z, arm_r_z))
    moved: dict = {}

    def put(x: int, y: int, z: int, index: int) -> None:
        if 0 <= x < sx and 0 <= y < out_sy and 0 <= z < out_sz:
            moved[(x, y, z)] = index

    for (x, y, z), index in cells.items():
        dy = lean if lean > 0 and z >= 7 else (lean if lean < 0 and z >= 7 else 0)
        dz = bob
        if 3 <= x <= 5 and z <= 6:
            dy += leg_l_y
        elif 7 <= x <= 9 and z <= 6:
            dy += leg_r_y
        elif x <= 1 and 7 <= z <= 11:
            dy += arm_l_y
            dz += arm_l_z
        elif x >= 10 and 7 <= z <= 11:
            dy += arm_r_y
            dz += arm_r_z
        put(x, y + dy, z + dz, index)
    return (sx, out_sy, out_sz), moved


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


def _write_frame(anchors: dict, name: str, size, cells, palette) -> None:
    width, height, image = vs.render(size, cells, palette)
    vs.save_png(OUT / f"{name}.png", width, height, image)
    sx, sy, sz = size
    anchors[name] = {
        "ax": sx * vs.PX / 2,
        "ay": sz * vs.PX + sy * vs.PX / 2,
        "fw": sx * vs.PX,
        "fh": sy * vs.PX,
    }


def bake() -> dict:
    OUT.mkdir(parents=True, exist_ok=True)
    # Keep existing anchors from static bake; merge anim keys.
    anchors_path = OUT / "anchors.json"
    if anchors_path.exists():
        anchors = json.loads(anchors_path.read_text(encoding="utf-8"))
    else:
        anchors = {"px": vs.PX, "tile_px": 16 * vs.PX}

    blockout_pal = [(0, 0, 0)] * 256
    for i, (_n, rgb) in enumerate(vb.PALETTE):
        blockout_pal[i] = rgb

    manifest: dict = {
        "version": 4,
        "facing": list(FACING_NAMES),
        "facings": FACINGS,
        "characters": {},
        "sources": {},
    }
    written = 0

    for char_id, kit in CHARS.items():
        designer = _load_designer(char_id)
        source = "procedural"
        if designer is not None:
            source = "designer_vox"
        manifest["sources"][char_id] = source
        char_anims: dict = {}
        for anim, spec in ANIMS.items():
            if char_id not in _chars_for(spec):
                continue
            frames = spec["frames"]
            fps = int(spec["fps"])
            char_anims[anim] = {"frames": len(frames), "fps": fps}
            if _has_mv_anim_16(char_id, anim, len(frames)):
                char_anims[anim]["source"] = "magica_frames"
                written += _write_mv_frames(anchors, char_id, anim, len(frames), "full16")
                continue
            if _has_mv_anim_legacy8(char_id, anim, len(frames)):
                char_anims[anim]["source"] = "magica_frames_legacy8"
                written += _write_mv_frames(anchors, char_id, anim, len(frames), "legacy8")
                continue
            if _has_mv_anim_legacy4(char_id, anim, len(frames)):
                char_anims[anim]["source"] = "magica_frames_legacy4"
                written += _write_mv_frames(anchors, char_id, anim, len(frames), "legacy4")
                continue
            for fi, pose in enumerate(frames):
                if designer is not None:
                    size, cells = _apply_pose_to_vox(designer[0], designer[1], pose)
                    pal = designer[2]
                else:
                    model = person_posed(**kit, pose=pose)
                    size = model.size
                    cells = model.cells
                    pal = blockout_pal
                for facing in range(FACINGS):
                    rsize, rcells = vs.rotate_facing(size, cells, facing, FACINGS)
                    name = f"{char_id}_{anim}_{facing}_{fi}"
                    _write_frame(anchors, name, rsize, rcells, pal)
                    written += 1
        manifest["characters"][char_id] = char_anims

    anchors_path.write_text(json.dumps(anchors, indent=2) + "\n", encoding="utf-8")
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {written} anim sprites → {OUT}")
    print(f"manifest → {MANIFEST_PATH}")
    for cid, src in manifest["sources"].items():
        print(f"  {cid}: {src}")
    return manifest


if __name__ == "__main__":
    bake()
