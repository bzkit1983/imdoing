#!/usr/bin/env python3
"""Re-pose player_alt3 from T-pose to A-pose.

Reads tools/vox_backups/player_alt3_tpose.vox (untouched T-pose), rotates only
the arm voxels outside the torso column ~45° down around each shoulder, and
writes godot/game/art/src/player_alt3.vox. Palette and body stay intact.
Repo axis: Z-up, face +Y. Previews go under art/preview/.

Hires character envelope target is 90x40x130 (see docs/alpha/voxel-hires-scale-plan.md;
former 100x40x130 dropped). This script does not resize; crop/fit is a later pass.
"""

from __future__ import annotations

import math
import struct
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))

from voxel_sprites import SHADING_CLASSIC, render as bake_render  # noqa: E402
from voxel_sprites import save_png as save_bake_png  # noqa: E402

OUT = ROOT / "godot" / "game" / "art" / "src" / "player_alt3.vox"
# Always read the untouched T-pose so re-runs stay idempotent.
SRC = ROOT / "tools" / "vox_backups" / "player_alt3_tpose.vox"
PREVIEW = ROOT / "godot" / "game" / "art" / "preview"

# Arms sit outside this torso X band (from the T-pose silhouette).
TORSO_X0, TORSO_X1 = 34, 64
# Rotate arms this many degrees down from horizontal.
A_POSE_DEG = 45.0


def _chunk(data: bytes, pos: int):
    tag = data[pos : pos + 4]
    content_size, children = struct.unpack_from("<ii", data, pos + 4)
    content = data[pos + 12 : pos + 12 + content_size]
    return tag, content, children, 12 + content_size + children


def read_vox(path: Path):
    data = path.read_bytes()
    if data[:4] != b"VOX ":
        raise ValueError(f"not a vox: {path}")
    pos = 20
    end = pos + struct.unpack_from("<ii", data, 12)[1]
    size = (1, 1, 1)
    cells: dict[tuple[int, int, int], int] = {}
    rgba = bytearray(256 * 4)
    for i in range(256):
        rgba[i * 4 : i * 4 + 4] = bytes((0, 0, 0, 255))
    while pos < end:
        tag, content, _child, advance = _chunk(data, pos)
        if tag == b"SIZE":
            size = struct.unpack_from("<iii", content)
        elif tag == b"XYZI":
            count = struct.unpack_from("<i", content)[0]
            for i in range(count):
                x, y, z, index = struct.unpack_from("<BBBB", content, 4 + i * 4)
                cells[(x, y, z)] = index
        elif tag == b"RGBA":
            rgba = bytearray(content[: 256 * 4])
        pos += advance
    return size, cells, rgba


def write_vox(path: Path, size, cells, rgba: bytes | bytearray) -> None:
    sx, sy, sz = size
    voxels = sorted(cells.items())
    size_chunk = b"SIZE" + struct.pack("<ii", 12, 0) + struct.pack("<iii", sx, sy, sz)
    body = struct.pack("<i", len(voxels))
    body += b"".join(struct.pack("<BBBB", x, y, z, idx) for (x, y, z), idx in voxels)
    xyzi = b"XYZI" + struct.pack("<ii", len(body), 0) + body
    rgba_chunk = b"RGBA" + struct.pack("<ii", 256 * 4, 0) + bytes(rgba[: 256 * 4])
    children = size_chunk + xyzi + rgba_chunk
    path.write_bytes(b"VOX " + struct.pack("<i", 150) + b"MAIN" + struct.pack("<ii", 0, len(children)) + children)


def flood_arm(cells, tip_xs: range, torso_lo: int, torso_hi: int) -> set[tuple[int, int, int]]:
    seeds = [p for p in cells if p[0] in tip_xs and 65 <= p[2] <= 80]
    seen: set[tuple[int, int, int]] = set()
    q = deque(seeds)
    while q:
        p = q.popleft()
        if p in seen or p not in cells:
            continue
        x, y, z = p
        if torso_lo <= x <= torso_hi:
            continue
        if z < 60 or z > 90:
            continue
        seen.add(p)
        for dx, dy, dz in (
            (1, 0, 0),
            (-1, 0, 0),
            (0, 1, 0),
            (0, -1, 0),
            (0, 0, 1),
            (0, 0, -1),
        ):
            n = (x + dx, y + dy, z + dz)
            if n not in seen:
                q.append(n)
    return seen


def shoulder_pivot(arm: set[tuple[int, int, int]], side: str) -> tuple[float, float, float]:
    """Pivot at the arm voxels nearest the torso edge, densest Z band."""
    if side == "L":
        edge = max(p[0] for p in arm)
        near = [p for p in arm if p[0] >= edge - 4]
    else:
        edge = min(p[0] for p in arm)
        near = [p for p in arm if p[0] <= edge + 4]
    by_z: dict[int, int] = {}
    for _x, _y, z in near:
        by_z[z] = by_z.get(z, 0) + 1
    best_z = max(by_z, key=by_z.get)
    band = [p for p in near if abs(p[2] - best_z) <= 2]
    return (
        sum(p[0] for p in band) / len(band),
        sum(p[1] for p in band) / len(band),
        sum(p[2] for p in band) / len(band),
    )


def rotate_arm_xz(
    arm: dict[tuple[int, int, int], int],
    pivot: tuple[float, float, float],
    deg: float,
) -> dict[tuple[int, int, int], int]:
    """Inverse-map rotate around Y through pivot. deg>0 lowers a +X arm."""
    rad = math.radians(deg)
    cos_a = math.cos(rad)
    sin_a = math.sin(rad)
    px, py, pz = pivot

    # Source bounds in pivot space → dest AABB.
    src_pts = []
    for (x, y, z), idx in arm.items():
        src_pts.append((x - px, y - py, z - pz, idx))

    # Dest sampling grid from forward transform of corners / all points.
    dest_candidates: set[tuple[int, int, int]] = set()
    for dx, dy, dz, _idx in src_pts:
        # Forward: same convention as inverse below.
        fx = dx * cos_a + dz * sin_a
        fz = -dx * sin_a + dz * cos_a
        for ox in (-0.5, 0.0, 0.5):
            for oz in (-0.5, 0.0, 0.5):
                dest_candidates.add(
                    (int(round(px + fx + ox)), int(round(py + dy)), int(round(pz + fz + oz)))
                )

    out: dict[tuple[int, int, int], int] = {}
    # Build source occupancy for inverse lookup.
    src_map = {(int(round(px + dx)), int(round(py + dy)), int(round(pz + dz))): idx for dx, dy, dz, idx in src_pts}
    # Prefer exact source keys from original arm.
    src_map = dict(arm)

    inv_cos = math.cos(-rad)
    inv_sin = math.sin(-rad)
    for x, y, z in dest_candidates:
        # Inverse rotate dest → source.
        dx = x - px
        dy = y - py
        dz = z - pz
        sx = dx * inv_cos + dz * inv_sin
        sz = -dx * inv_sin + dz * inv_cos
        # Nearest source voxel; accept if within arm solid.
        best = None
        best_d = 1.15  # allow slight thickening so rotation does not swiss-cheese
        for ix in (math.floor(sx + px), math.ceil(sx + px)):
            for iy in (math.floor(py + dy), math.ceil(py + dy)):
                for iz in (math.floor(sz + pz), math.ceil(sz + pz)):
                    key = (ix, iy, iz)
                    if key not in src_map:
                        continue
                    d = (ix - (sx + px)) ** 2 + (iy - (py + dy)) ** 2 + (iz - (sz + pz)) ** 2
                    if d < best_d:
                        best_d = d
                        best = src_map[key]
        if best is not None:
            out[(x, y, z)] = best
    return out


def repose_to_a_pose(size, cells):
    left_keys = flood_arm(cells, range(0, 6), TORSO_X0, TORSO_X1)
    right_keys = flood_arm(cells, range(size[0] - 6, size[0]), TORSO_X0, TORSO_X1)
    if not left_keys or not right_keys:
        raise RuntimeError(f"arm flood failed L={len(left_keys)} R={len(right_keys)}")

    left = {p: cells[p] for p in left_keys}
    right = {p: cells[p] for p in right_keys}
    lp = shoulder_pivot(left_keys, "L")
    rp = shoulder_pivot(right_keys, "R")

    # Left arm extends -X → negative Y-rotation lowers it; right extends +X → positive.
    left_new = rotate_arm_xz(left, lp, -A_POSE_DEG)
    right_new = rotate_arm_xz(right, rp, A_POSE_DEG)

    body = {p: idx for p, idx in cells.items() if p not in left_keys and p not in right_keys}
    # Arms lose to existing body on overlap (keep torso/lanyard intact).
    for p, idx in left_new.items():
        if p not in body:
            body[p] = idx
    for p, idx in right_new.items():
        if p not in body:
            body[p] = idx

    # Keep canvas size; clip anything that drifted out.
    sx, sy, sz = size
    clipped = {
        (x, y, z): idx
        for (x, y, z), idx in body.items()
        if 0 <= x < sx and 0 <= y < sy and 0 <= z < sz
    }
    meta = {
        "left_n": len(left_keys),
        "right_n": len(right_keys),
        "left_pivot": lp,
        "right_pivot": rp,
        "out_n": len(clipped),
    }
    return clipped, meta


def render_ortho(size, cells, rgba, view: str, scale: int = 3):
    sx, sy, sz = size
    bg = (210, 214, 220)

    def rgb(idx: int):
        i = (idx - 1) * 4
        return rgba[i], rgba[i + 1], rgba[i + 2]

    def canvas(w, h):
        return [[bg for _ in range(w)] for _ in range(h)]

    def put(img, x, y, color):
        if 0 <= x < len(img[0]) and 0 <= y < len(img):
            img[y][x] = color

    if view == "front":
        # Camera +Y; flip X so character left is screen-right? Match Magica front:
        # keep model X as screen X (character right = high X = screen right when facing -Y).
        # Repo faces +Y; front view from +Y looking -Y → screen X = model X.
        front = {}
        for (x, y, z), idx in cells.items():
            key = (x, z)
            prev = front.get(key)
            if prev is None or y > prev[0]:
                front[key] = (y, idx)
        img = canvas(sx * scale, sz * scale)
        for (x, z), (y, idx) in front.items():
            shade = 0.78 + 0.22 * (y / max(1, sy - 1))
            col = tuple(max(0, min(255, int(c * shade))) for c in rgb(idx))
            for dx in range(scale):
                for dz in range(scale):
                    put(img, x * scale + dx, (sz - 1 - z) * scale + dz, col)
    elif view == "side":
        side = {}
        for (x, y, z), idx in cells.items():
            key = (y, z)
            prev = side.get(key)
            if prev is None or x < prev[0]:
                side[key] = (x, idx)
        img = canvas(sy * scale, sz * scale)
        for (y, z), (x, idx) in side.items():
            shade = 0.78 + 0.2 * ((sx - 1 - x) / max(1, sx - 1))
            col = tuple(max(0, min(255, int(c * shade))) for c in rgb(idx))
            for dy in range(scale):
                for dz in range(scale):
                    put(img, (sy - 1 - y) * scale + dy, (sz - 1 - z) * scale + dz, col)
    elif view == "back":
        back = {}
        for (x, y, z), idx in cells.items():
            key = (x, z)
            prev = back.get(key)
            if prev is None or y < prev[0]:
                back[key] = (y, idx)
        img = canvas(sx * scale, sz * scale)
        for (x, z), (y, idx) in back.items():
            shade = 0.74 + 0.2 * ((sy - 1 - y) / max(1, sy - 1))
            col = tuple(max(0, min(255, int(c * shade))) for c in rgb(idx))
            for dx in range(scale):
                for dz in range(scale):
                    put(img, (sx - 1 - x) * scale + dx, (sz - 1 - z) * scale + dz, col)
    elif view == "top":
        top = {}
        for (x, y, z), idx in cells.items():
            key = (x, y)
            prev = top.get(key)
            if prev is None or z > prev[0]:
                top[key] = (z, idx)
        img = canvas(sx * scale, sy * scale)
        for (x, y), (z, idx) in top.items():
            shade = 0.8 + 0.2 * (z / max(1, sz - 1))
            col = tuple(max(0, min(255, int(c * shade))) for c in rgb(idx))
            for dx in range(scale):
                for dy in range(scale):
                    put(img, x * scale + dx, (sy - 1 - y) * scale + dy, col)
    else:
        raise ValueError(view)

    # Encode PNG via bake helper shape: flatten
    flat = [px for row in img for px in row]
    # reuse save via RGBA list
    w, h = len(img[0]), len(img)
    rgba_img = [(r, g, b, 255) for (r, g, b) in flat]
    return w, h, rgba_img


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"missing T-pose backup: {SRC}")
    size, cells, rgba = read_vox(SRC)
    print(f"read {SRC} size={size} voxels={len(cells)}")

    PREVIEW.mkdir(parents=True, exist_ok=True)
    palette_rgb = [tuple(rgba[i * 4 : i * 4 + 3]) for i in range(256)]
    w, h, image = bake_render(size, cells, palette_rgb, SHADING_CLASSIC)
    save_bake_png(PREVIEW / "player_alt3_tpose_bake.png", w, h, image)

    new_cells, meta = repose_to_a_pose(size, cells)
    print(
        f"A-pose L={meta['left_n']} R={meta['right_n']} "
        f"pivots L={tuple(round(v,1) for v in meta['left_pivot'])} "
        f"R={tuple(round(v,1) for v in meta['right_pivot'])} "
        f"out={meta['out_n']}"
    )
    write_vox(OUT, size, new_cells, rgba)
    print(f"wrote {OUT}")

    for view in ("front", "side", "back", "top"):
        w, h, image = render_ortho(size, new_cells, rgba, view, scale=3)
        save_bake_png(PREVIEW / f"player_alt3_a_pose_{view}.png", w, h, image)
        print(f"preview {view} {w}x{h}")

    w, h, image = bake_render(size, new_cells, palette_rgb, SHADING_CLASSIC)
    save_bake_png(PREVIEW / "player_alt3_a_pose_bake.png", w, h, image)
    print(f"bake {w}x{h}")


if __name__ == "__main__":
    main()
