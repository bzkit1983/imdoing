#!/usr/bin/env python3
"""Bake MagicaVoxel .vox files into gameplay sprites for the living line.

Reads godot/game/art/src/*.vox and writes godot/game/art/sprites.
Does not modify the .vox sources. 4 px = 1 voxel, so 16 voxels match one 64 px shop tile.

Facing (characters, 16-way): 0 south … 15 SSW (22.5° steps).
Facing (furniture, 4-way): 0 south, 1 east, 2 north, 3 west — same as legacy.

Shading: VOXEL_SHADING=classic|cartoon (default cartoon). See docs/alpha/voxel-cartoon-shading.md.
Filter ids: VOXEL_BAKE_IDS=player,shelf_dry (comma-separated; empty = all).

Frozen Alpha art stays in godot/alpha_v0_1/art/ — do not point this tool there.
"""

from __future__ import annotations

import json
import math
import os
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "godot" / "game" / "art" / "src"
OUT = ROOT / "godot" / "game" / "art" / "sprites"
PREVIEW = ROOT / "godot" / "game" / "art" / "preview"
PX = 4

## Face light scales + posterize / outline (docs/alpha/voxel-cartoon-shading.md).
SHADING_CLASSIC = {
    "top": 1.08,
    "front": 0.78,
    "side": 0.62,
    "posterize": 0,
    "outline": False,
}
SHADING_CARTOON = {
    "top": 1.15,
    "front": 0.72,
    "side": 0.52,
    "posterize": 4,
    "outline": True,
}
OUTLINE_RGBA = (26, 26, 26, 255)


def shading_mode() -> str:
    raw = os.environ.get("VOXEL_SHADING", "cartoon").strip().lower()
    if raw in ("classic", "cartoon"):
        return raw
    return "cartoon"


def shading_params() -> dict:
    return SHADING_CLASSIC if shading_mode() == "classic" else SHADING_CARTOON


def bake_id_filter() -> set[str] | None:
    raw = os.environ.get("VOXEL_BAKE_IDS", "").strip()
    if not raw:
        return None
    return {part.strip() for part in raw.split(",") if part.strip()}

# Characters: 16 yaw steps. Furniture / props: still 4 cardinals.
CHAR_WAY = {
    "player",
    "player_alt1",
    "player_alt2",
    "customer",
    "thief",
    "clerk_cashier",
    "clerk_restock",
}
## Back-compat alias for older callers / docs.
EIGHT_WAY = CHAR_WAY
FOUR_WAY = CHAR_WAY | {
    "register",
    "restock_dry",
    "restock_frozen",
    "restock_ice",
    "shelf_dry",
    "shelf_frozen",
    "shelf_ice",
    "wall",
    "door",
}


def read_vox(path: Path):
    data = path.read_bytes()
    pos = 8
    _tag, _content, children = _chunk(data, pos)
    pos = 20
    end = pos + children
    size = (1, 1, 1)
    cells = {}
    palette = [(0, 0, 0)] * 256
    while pos < end:
        tag, content, child = _chunk(data, pos)
        if tag == b"SIZE":
            size = struct.unpack_from("<iii", content)
        elif tag == b"XYZI":
            count = struct.unpack_from("<i", content)[0]
            for i in range(count):
                x, y, z, index = struct.unpack_from("<BBBB", content, 4 + i * 4)
                cells[(x, y, z)] = index
        elif tag == b"RGBA":
            palette = [struct.unpack_from("<BBB", content, i * 4) for i in range(256)]
        pos += 12 + len(content) + child
    return size, cells, palette


def _chunk(data, pos):
    tag = data[pos : pos + 4]
    content_size, children = struct.unpack_from("<ii", data, pos + 4)
    content = data[pos + 12 : pos + 12 + content_size]
    return tag, content, children


def rotate(size, cells, turns):
    """Rotate yaw by `turns` × 90° clockwise (Z-up), matching MagicaVoxel top view."""
    sx, sy, sz = size
    out = cells
    for _ in range(turns % 4):
        nxt = {}
        for (x, y, z), index in out.items():
            nxt[(y, sx - 1 - x, z)] = index
        out = nxt
        sx, sy = sy, sx
    return (sx, sy, sz), out


def rotate_yaw_degrees(size, cells, degrees: float):
    """Nearest-neighbor yaw about Z (clockwise from above). Used for 45° diagonals."""
    sx, sy, sz = size
    if not cells:
        return size, cells
    rad = math.radians(degrees)
    cos_a = math.cos(rad)
    sin_a = math.sin(rad)
    cx = (sx - 1) / 2.0
    cy = (sy - 1) / 2.0
    pts: list[tuple[float, float, int, int]] = []
    for (x, y, z), index in cells.items():
        xc = x - cx
        yc = y - cy
        # Clockwise: matches rotate() 90° = (x,y)->(y, sx-1-x)
        nx = xc * cos_a + yc * sin_a
        ny = -xc * sin_a + yc * cos_a
        pts.append((nx, ny, z, index))
    min_x = min(p[0] for p in pts)
    min_y = min(p[1] for p in pts)
    max_x = max(p[0] for p in pts)
    max_y = max(p[1] for p in pts)
    out: dict = {}
    for nx, ny, z, index in pts:
        x = int(round(nx - min_x))
        y = int(round(ny - min_y))
        out[(x, y, z)] = index
    out_sx = int(round(max_x - min_x)) + 1
    out_sy = int(round(max_y - min_y)) + 1
    return (out_sx, out_sy, sz), out


def rotate_facing(size, cells, facing: int, facings: int = 16):
    """Rotate model to facing index.

    facings=1 → identity; 4 → exact 90°; 8/16 (power-of-2 ≥8) → south… with
    45°/22.5° yaw steps via rotate + rotate_yaw_degrees.
    """
    if facings <= 1:
        return size, cells
    facing = int(facing) % facings
    if facings == 4:
        return rotate(size, cells, facing)
    if facings < 8 or (facings & (facings - 1)) != 0:
        raise ValueError(f"unsupported facings count: {facings}")
    ## Degrees clockwise from south; exact 90° uses discrete rotate().
    deg = facing * (360.0 / float(facings))
    turns = int(round(deg / 90.0)) % 4
    rem = deg - turns * 90.0
    ## Keep rem in (-45, 45] for stable nearest-cardinal + yaw.
    if rem > 45.0:
        turns = (turns + 1) % 4
        rem -= 90.0
    elif rem <= -45.0:
        turns = (turns - 1) % 4
        rem += 90.0
    rsize, rcells = rotate(size, cells, turns)
    if abs(rem) < 1e-6:
        return rsize, rcells
    return rotate_yaw_degrees(rsize, rcells, rem)


def _posterize_channel(value: int, buckets: int) -> int:
    if buckets <= 1:
        return value
    # Map 0–255 into `buckets` even steps (e.g. 4 → 0,85,170,255).
    step = 255 / (buckets - 1)
    return max(0, min(255, int(round(round(value / step) * step))))


def _posterize_rgba(color: tuple[int, int, int, int], buckets: int) -> tuple[int, int, int, int]:
    if buckets <= 0 or color[3] == 0:
        return color
    return (
        _posterize_channel(color[0], buckets),
        _posterize_channel(color[1], buckets),
        _posterize_channel(color[2], buckets),
        color[3],
    )


def _apply_silhouette_outline(
    width: int, height: int, image: list[tuple[int, int, int, int]], ink: tuple[int, int, int, int]
) -> list[tuple[int, int, int, int]]:
    """1px outline on transparent pixels that touch an opaque neighbor (4-connected)."""
    out = list(image)
    opaque = [pix[3] > 0 for pix in image]
    for y in range(height):
        for x in range(width):
            i = y * width + x
            if opaque[i]:
                continue
            edge = False
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < width and 0 <= ny < height and opaque[ny * width + nx]:
                    edge = True
                    break
            if edge:
                out[i] = ink
    return out


def render(size, cells, palette, shading: dict | None = None):
    params = shading if shading is not None else shading_params()
    top_s = float(params["top"])
    front_s = float(params["front"])
    side_s = float(params["side"])
    buckets = int(params.get("posterize", 0))
    do_outline = bool(params.get("outline", False))

    sx, sy, sz = size
    width = sx * PX
    height = sy * PX + sz * PX
    image = [(0, 0, 0, 0)] * (width * height)

    def shade(index, scale):
        r, g, b = palette[index - 1]
        color = (
            max(0, min(255, int(r * scale))),
            max(0, min(255, int(g * scale))),
            max(0, min(255, int(b * scale))),
            255,
        )
        return _posterize_rgba(color, buckets)

    def put(x, y, color):
        if 0 <= x < width and 0 <= y < height and color[3]:
            image[y * width + x] = color

    def rect(x0, y0, w, h, color):
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                put(x, y, color)

    order = sorted(cells.items(), key=lambda item: (item[0][1], item[0][0], item[0][2]))
    for (x, y, z), index in order:
        gx = x * PX
        gy = sz * PX + y * PX
        if (x, y, z + 1) not in cells:
            rect(gx, gy - (z + 1) * PX, PX, PX, shade(index, top_s))
        if (x, y + 1, z) not in cells:
            rect(gx, gy - z * PX, PX, PX, shade(index, front_s))
        if (x + 1, y, z) not in cells:
            rect(gx + PX - max(1, PX // 3), gy - (z + 1) * PX, max(1, PX // 3), PX, shade(index, side_s))

    if do_outline:
        image = _apply_silhouette_outline(width, height, image, OUTLINE_RGBA)
    return width, height, image


def save_png(path, width, height, image):
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            raw.extend(image[y * width + x])

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    path.write_bytes(png)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    mode = shading_mode()
    params = shading_params()
    id_filter = bake_id_filter()
    print(f"shading={mode} posterize={params.get('posterize', 0)} outline={params.get('outline', False)}")
    if id_filter:
        print(f"filter={','.join(sorted(id_filter))}")
    ## Merge — do not wipe shelf fill / dirt clean / fx keys from voxel_alpha_props.
    anchors_path = OUT / "anchors.json"
    if anchors_path.exists():
        try:
            anchors = json.loads(anchors_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            anchors = {}
    else:
        anchors = {}
    if not isinstance(anchors, dict):
        anchors = {}
    anchors["px"] = PX
    anchors["tile_px"] = 16 * PX
    baked = 0
    for path in sorted(SRC.glob("*.vox")):
        if id_filter is not None and path.stem not in id_filter:
            continue
        size, cells, palette = read_vox(path)
        if path.stem in CHAR_WAY:
            facings = 16
        elif path.stem in FOUR_WAY:
            facings = 4
        else:
            facings = 1
        for k in range(facings):
            rsize, rcells = rotate_facing(size, cells, k, facings)
            width, height, image = render(rsize, rcells, palette, params)
            name = f"{path.stem}_{k}"
            save_png(OUT / f"{name}.png", width, height, image)
            sx, sy, sz = rsize
            anchors[name] = {
                "ax": sx * PX / 2,
                "ay": sz * PX + sy * PX / 2,
                "fw": sx * PX,
                "fh": sy * PX,
            }
        baked += 1
        print(path.stem, "x".join(str(n) for n in size), f"facings={facings}")
    anchors_path.write_text(json.dumps(anchors, indent=2) + "\n", encoding="utf-8")
    print(f"sprites baked={baked} anchors_keys={len(anchors) - 2}")


if __name__ == "__main__":
    main()
