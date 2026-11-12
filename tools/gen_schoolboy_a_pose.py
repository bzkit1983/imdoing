#!/usr/bin/env python3
"""Generate MagicaVoxel schoolboy character (A-pose) at 100 x 40 x 130.

Reference sheet is T-pose; this script builds the same look with arms angled
down into an A-pose. Face toward +Y, feet on z=0 (repo convention).

Output: godot/game/art/src/schoolboy_a_pose.vox
"""

from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "godot" / "game" / "art" / "src" / "schoolboy_a_pose.vox"
PREVIEW = ROOT / "godot" / "game" / "art" / "preview"

PALETTE = [
    ("hair", (18, 16, 20)),
    ("hair_hi", (40, 38, 46)),
    ("skin", (236, 198, 168)),
    ("skin_shade", (210, 162, 132)),
    ("blush", (236, 168, 150)),
    ("eye", (28, 22, 20)),
    ("white", (250, 250, 252)),
    ("shirt", (244, 244, 246)),
    ("shirt_shade", (216, 216, 222)),
    ("collar", (214, 42, 42)),
    ("sleeve_trim", (214, 42, 42)),
    ("lanyard", (228, 92, 44)),
    ("badge_green", (64, 164, 80)),
    ("badge_orange", (236, 148, 44)),
    ("badge_blue", (52, 92, 168)),
    ("shorts", (32, 48, 92)),
    ("shorts_shade", (24, 36, 70)),
    ("socks", (248, 248, 250)),
    ("shoes", (248, 248, 250)),
    ("shoes_sole", (198, 198, 206)),
    ("shoes_shade", (226, 226, 232)),
    ("bandage", (214, 180, 132)),
    ("bandage_edge", (188, 148, 100)),
]

COLOR_INDEX = {name: i + 1 for i, (name, _rgb) in enumerate(PALETTE)}

W, D, H = 100, 40, 130


class Model:
    def __init__(self, sx: int, sy: int, sz: int):
        self.size = (sx, sy, sz)
        self.cells: dict[tuple[int, int, int], int] = {}

    def set(self, x: int, y: int, z: int, color: str) -> None:
        sx, sy, sz = self.size
        if 0 <= x < sx and 0 <= y < sy and 0 <= z < sz:
            self.cells[(x, y, z)] = COLOR_INDEX[color]

    def fill(self, x0, y0, z0, x1, y1, z1, color: str) -> None:
        for x in range(min(x0, x1), max(x0, x1) + 1):
            for y in range(min(y0, y1), max(y0, y1) + 1):
                for z in range(min(z0, z1), max(z0, z1) + 1):
                    self.set(x, y, z, color)

    def ellipsoid(self, cx, cy, cz, rx, ry, rz, color: str, soft: float = 1.02) -> None:
        rx, ry, rz = max(1, rx), max(1, ry), max(1, rz)
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
                for z in range(int(cz - rz) - 1, int(cz + rz) + 2):
                    dx = (x - cx) / rx
                    dy = (y - cy) / ry
                    dz = (z - cz) / rz
                    if dx * dx + dy * dy + dz * dz <= soft:
                        self.set(x, y, z, color)

    def cylinder_x(self, x0, x1, cy, cz, ry, rz, color: str) -> None:
        for x in range(min(x0, x1), max(x0, x1) + 1):
            for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
                for z in range(int(cz - rz) - 1, int(cz + rz) + 2):
                    dy = (y - cy) / max(1, ry)
                    dz = (z - cz) / max(1, rz)
                    if dy * dy + dz * dz <= 1.05:
                        self.set(x, y, z, color)


def _chunk(tag: bytes, content: bytes) -> bytes:
    return tag + struct.pack("<ii", len(content), 0) + content


def write_vox(path: Path, model: Model) -> None:
    sx, sy, sz = model.size
    voxels = sorted(model.cells.items())
    size_chunk = _chunk(b"SIZE", struct.pack("<iii", sx, sy, sz))
    body = struct.pack("<i", len(voxels))
    body += b"".join(struct.pack("<BBBB", x, y, z, index) for (x, y, z), index in voxels)
    xyzi_chunk = _chunk(b"XYZI", body)
    rgba = bytearray(256 * 4)
    for i, (_name, rgb) in enumerate(PALETTE):
        rgba[i * 4 : i * 4 + 4] = bytes((*rgb, 255))
    for i in range(len(PALETTE), 256):
        rgba[i * 4 : i * 4 + 4] = bytes((0, 0, 0, 255))
    children = size_chunk + xyzi_chunk + _chunk(b"RGBA", bytes(rgba))
    main = b"MAIN" + struct.pack("<ii", 0, len(children)) + children
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"VOX " + struct.pack("<i", 150) + main)


def _thick_segment(a, b, radius: float):
    ax, ay, az = a
    bx, by, bz = b
    length = math.dist(a, b)
    steps = max(1, int(length * 3))
    out = []
    for i in range(steps + 1):
        t = i / steps
        cx = ax + (bx - ax) * t
        cy = ay + (by - ay) * t
        cz = az + (bz - az) * t
        r = radius * (1.0 - 0.12 * t)
        ri = max(2, int(math.ceil(r)))
        for dx in range(-ri, ri + 1):
            for dy in range(-ri, ri + 1):
                for dz in range(-ri, ri + 1):
                    if dx * dx + dy * dy + dz * dz <= r * r + 0.6:
                        out.append((int(round(cx + dx)), int(round(cy + dy)), int(round(cz + dz)), t))
    return out


def build_schoolboy() -> Model:
    m = Model(W, D, H)

    # ===== Feet / shoes (chunky sneakers) =====
    # Character left = low X, right = high X (repo person() convention).
    for x0 in (36, 53):
        m.fill(x0, 13, 0, x0 + 10, 28, 2, "shoes_sole")
        m.fill(x0, 13, 2, x0 + 10, 28, 6, "shoes")
        m.fill(x0 + 1, 26, 3, x0 + 9, 29, 6, "shoes")  # toe
        m.fill(x0 + 2, 14, 6, x0 + 8, 25, 9, "shoes_shade")  # ankle

    # ===== Socks =====
    m.fill(38, 15, 9, 46, 25, 18, "socks")
    m.fill(53, 15, 9, 61, 25, 18, "socks")

    # ===== Legs =====
    m.fill(38, 15, 19, 46, 25, 52, "skin")
    m.fill(53, 15, 19, 61, 25, 52, "skin")
    m.fill(38, 15, 19, 46, 16, 52, "skin_shade")
    m.fill(53, 15, 19, 61, 16, 52, "skin_shade")

    # Bandage on character RIGHT knee (high X) — matches reference front/side.
    m.fill(54, 24, 32, 60, 26, 38, "bandage")
    m.fill(54, 26, 32, 60, 26, 38, "bandage_edge")
    m.fill(56, 26, 34, 58, 26, 36, "bandage")

    # ===== Shorts =====
    m.fill(35, 14, 50, 64, 26, 64, "shorts")
    m.fill(35, 14, 50, 64, 15, 64, "shorts_shade")
    m.fill(35, 14, 50, 36, 26, 64, "shorts_shade")
    m.fill(63, 14, 50, 64, 26, 64, "shorts_shade")
    # Slight flare at openings
    m.fill(36, 14, 50, 47, 26, 53, "shorts")
    m.fill(52, 14, 50, 63, 26, 53, "shorts")

    # ===== Torso / shirt =====
    m.fill(34, 13, 65, 65, 27, 94, "shirt")
    m.fill(34, 13, 65, 65, 14, 94, "shirt_shade")
    m.fill(34, 13, 65, 35, 27, 94, "shirt_shade")
    m.fill(64, 13, 65, 65, 27, 94, "shirt_shade")
    m.fill(36, 26, 70, 63, 28, 90, "shirt")  # chest round

    # Red collar ring
    m.fill(39, 15, 93, 60, 27, 96, "collar")
    m.fill(41, 25, 92, 58, 28, 95, "collar")
    # Front V opening
    m.fill(46, 27, 92, 53, 28, 94, "shirt")

    # Neck
    m.fill(43, 16, 95, 56, 25, 103, "skin")
    m.fill(43, 16, 95, 56, 17, 103, "skin_shade")

    # ===== Head (chibi, large) =====
    m.ellipsoid(50, 20, 114, 18, 14, 16, "skin")
    m.fill(34, 10, 102, 65, 31, 122, "skin")
    m.fill(36, 9, 106, 63, 32, 120, "skin")
    m.fill(40, 26, 102, 59, 32, 110, "skin")  # chin / jaw

    # Clear face front slab so features read
    m.fill(36, 28, 106, 63, 32, 120, "skin")

    # Eyes — larger, dark, wide-set
    m.fill(41, 31, 113, 44, 32, 116, "eye")
    m.fill(55, 31, 113, 58, 32, 116, "eye")
    # Blush
    m.fill(38, 31, 110, 41, 32, 112, "blush")
    m.fill(58, 31, 110, 61, 32, 112, "blush")
    # Nose protrusion
    m.fill(49, 32, 112, 50, 33, 113, "skin_shade")

    # ===== Messy hair =====
    m.ellipsoid(50, 19, 120, 19, 15, 11, "hair")
    m.fill(32, 8, 112, 67, 28, 129, "hair")
    # Back volume
    m.fill(34, 7, 108, 65, 16, 124, "hair")
    # Sideburns / ear cover
    m.fill(32, 14, 108, 35, 26, 120, "hair")
    m.fill(64, 14, 108, 67, 26, 120, "hair")

    # Open forehead / face window (keep skin + features)
    for x in range(37, 63):
        for y in range(27, 33):
            for z in range(106, 118):
                key = (x, y, z)
                if key in m.cells and m.cells[key] in (
                    COLOR_INDEX["hair"],
                    COLOR_INDEX["hair_hi"],
                ):
                    # Keep temple hair above z 117 or near sides
                    if 40 <= x <= 59 and z < 118:
                        del m.cells[key]

    # Re-assert face
    m.fill(37, 28, 106, 62, 32, 118, "skin")
    m.fill(41, 31, 113, 44, 32, 116, "eye")
    m.fill(55, 31, 113, 58, 32, 116, "eye")
    m.fill(38, 31, 110, 41, 32, 112, "blush")
    m.fill(58, 31, 110, 61, 32, 112, "blush")
    m.fill(49, 32, 112, 50, 33, 113, "skin_shade")

    # Spiky clumps (irregular)
    spikes = [
        (50, 16, 129, 4, 3, 1),
        (45, 14, 128, 3, 3, 2),
        (55, 14, 128, 3, 3, 2),
        (40, 15, 127, 3, 3, 2),
        (60, 15, 127, 3, 3, 2),
        (36, 17, 125, 2, 3, 2),
        (64, 17, 125, 2, 3, 2),
        (50, 11, 127, 3, 2, 2),
        (43, 10, 126, 2, 2, 2),
        (57, 10, 126, 2, 2, 2),
        (48, 12, 129, 2, 2, 1),
        (52, 12, 129, 2, 2, 1),
        (33, 18, 118, 2, 3, 4),
        (66, 18, 118, 2, 3, 4),
        (31, 15, 114, 2, 2, 3),
        (68, 15, 114, 2, 2, 3),
        (34, 24, 112, 2, 2, 3),
        (65, 24, 112, 2, 2, 3),
        (50, 8, 118, 8, 2, 6),
        (42, 8, 116, 3, 2, 4),
        (58, 8, 116, 3, 2, 4),
        (46, 9, 123, 2, 2, 2),
        (54, 9, 123, 2, 2, 2),
        (38, 26, 119, 2, 2, 2),
        (61, 26, 119, 2, 2, 2),
        (36, 25, 116, 2, 2, 2),
        (63, 25, 116, 2, 2, 2),
    ]
    for x, y, z, rx, ry, rz in spikes:
        m.fill(x - rx, y - ry, z - rz, x + rx, y + ry, z + rz, "hair")
        if (x + z) % 2 == 0:
            m.set(x, y, min(H - 1, z + rz + 1), "hair_hi")

    # ===== Lanyard V + badge =====
    for i in range(16):
        lx = 48 - (i + 1) // 2
        rx = 51 + (i + 1) // 2
        zz = 90 - i
        m.fill(lx, 27, zz, lx + 1, 28, zz, "lanyard")
        m.fill(rx, 27, zz, rx + 1, 28, zz, "lanyard")
    # Badge hangs forward of chest
    m.fill(45, 27, 70, 54, 30, 80, "badge_green")
    m.fill(45, 27, 70, 54, 30, 74, "badge_orange")
    m.fill(47, 30, 76, 52, 30, 78, "badge_blue")
    m.fill(47, 27, 80, 52, 29, 81, "lanyard")

    # ===== A-pose arms (~45° down from horizontal) =====
    # Shoulder height ~ z 90; hands near hip ~ z 60, out to sides.
    left_shoulder = (33, 20, 90)
    right_shoulder = (66, 20, 90)
    # Drop 30 over run 22 → ~54° from horizontal (clear A-pose)
    left_elbow = (22, 20, 76)
    right_elbow = (77, 20, 76)
    left_hand = (12, 20, 58)
    right_hand = (87, 20, 58)

    for shoulder, elbow, hand in (
        (left_shoulder, left_elbow, left_hand),
        (right_shoulder, right_elbow, right_hand),
    ):
        upper = _thick_segment(shoulder, elbow, radius=5.0)
        lower = _thick_segment(elbow, hand, radius=4.4)
        # Sleeve on upper arm; thin red cuff ring near elbow; skin forearm/hand.
        for x, y, z, t in upper:
            if t < 0.72:
                m.set(x, y, z, "shirt")
            elif t < 0.88:
                m.set(x, y, z, "sleeve_trim")
            else:
                m.set(x, y, z, "skin")
        for x, y, z, _t in lower:
            m.set(x, y, z, "skin")
        hx, hy, hz = hand
        m.ellipsoid(hx, hy, hz, 4, 4, 4, "skin")

    # Shoulder caps into torso
    m.fill(31, 15, 86, 38, 25, 94, "shirt")
    m.fill(61, 15, 86, 68, 25, 94, "shirt")

    return m


class Canvas:
    def __init__(self, w, h, color):
        self.w = w
        self.h = h
        self.px = [color] * (w * h)

    def set(self, x, y, color):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y * self.w + x] = color

    def save(self, path: Path):
        raw = bytearray()
        for y in range(self.h):
            raw.append(0)
            for x in range(self.w):
                raw.extend(self.px[y * self.w + x])

        def chunk(tag, data):
            return (
                struct.pack(">I", len(data))
                + tag
                + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
            )

        ihdr = struct.pack(">IIBBBBB", self.w, self.h, 8, 2, 0, 0, 0)
        png = (
            b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", ihdr)
            + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
            + chunk(b"IEND", b"")
        )
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(png)


def render_ortho(model: Model, view: str, scale: int = 3) -> Canvas:
    rgb_of = {i + 1: rgb for i, (_n, rgb) in enumerate(PALETTE)}
    sx, sy, sz = model.size
    bg = (210, 218, 226)

    if view == "front":
        img = Canvas(sx * scale, sz * scale, bg)
        for (x, y, z), idx in sorted(model.cells.items(), key=lambda kv: kv[0][1]):
            c = rgb_of[idx]
            shade = 0.82 + 0.18 * (y / max(1, sy - 1))
            col = tuple(max(0, min(255, int(v * shade))) for v in c)
            for dx in range(scale):
                for dz in range(scale):
                    img.set(x * scale + dx, (sz - 1 - z) * scale + dz, col)
    elif view == "side":
        img = Canvas(sy * scale, sz * scale, bg)
        for (x, y, z), idx in sorted(model.cells.items(), key=lambda kv: kv[0][0]):
            c = rgb_of[idx]
            shade = 0.82 + 0.18 * (x / max(1, sx - 1))
            col = tuple(max(0, min(255, int(v * shade))) for v in c)
            for dy in range(scale):
                for dz in range(scale):
                    img.set(y * scale + dy, (sz - 1 - z) * scale + dz, col)
    elif view == "back":
        img = Canvas(sx * scale, sz * scale, bg)
        for (x, y, z), idx in sorted(model.cells.items(), key=lambda kv: -kv[0][1]):
            c = rgb_of[idx]
            shade = 0.82 + 0.18 * ((sy - 1 - y) / max(1, sy - 1))
            col = tuple(max(0, min(255, int(v * shade))) for v in c)
            for dx in range(scale):
                for dz in range(scale):
                    img.set((sx - 1 - x) * scale + dx, (sz - 1 - z) * scale + dz, col)
    elif view == "top":
        img = Canvas(sx * scale, sy * scale, bg)
        for (x, y, z), idx in sorted(model.cells.items(), key=lambda kv: kv[0][2]):
            c = rgb_of[idx]
            shade = 0.72 + 0.28 * (z / max(1, sz - 1))
            col = tuple(max(0, min(255, int(v * shade))) for v in c)
            for dx in range(scale):
                for dy in range(scale):
                    img.set(x * scale + dx, (sy - 1 - y) * scale + dy, col)
    else:
        raise ValueError(view)
    return img


def main() -> None:
    model = build_schoolboy()
    write_vox(OUT, model)
    print(f"wrote {OUT} size={model.size} voxels={len(model.cells)}")

    # Occupied bounds
    xs = [p[0] for p in model.cells]
    ys = [p[1] for p in model.cells]
    zs = [p[2] for p in model.cells]
    print(
        f"bounds x={min(xs)}..{max(xs)} y={min(ys)}..{max(ys)} z={min(zs)}..{max(zs)}"
    )

    PREVIEW.mkdir(parents=True, exist_ok=True)
    for view in ("front", "side", "back", "top"):
        path = PREVIEW / f"schoolboy_a_pose_{view}.png"
        render_ortho(model, view, scale=3).save(path)
        print(f"preview {path}")


if __name__ == "__main__":
    main()
