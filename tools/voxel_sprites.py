#!/usr/bin/env python3
"""Bake Alpha v0.1 .vox files into gameplay sprites.

Reads godot/alpha_v0_1/art/src/*.vox and writes art/sprites.
Does not modify the .vox sources. 4 px = 1 voxel, so 16 voxels match one 64 px shop tile.
Facing: 0 south, 1 east, 2 north, 3 west.
"""

import json
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "godot" / "alpha_v0_1" / "art" / "src"
OUT = ROOT / "godot" / "alpha_v0_1" / "art" / "sprites"
PX = 4

FOUR_WAY = {
    "player", "customer", "thief", "clerk_cashier", "clerk_restock",
    "register", "restock_dry", "restock_frozen", "restock_ice",
    "shelf_dry", "shelf_frozen", "shelf_ice", "wall", "door",
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
    sx, sy, sz = size
    out = cells
    for _ in range(turns % 4):
        nxt = {}
        for (x, y, z), index in out.items():
            nxt[(y, sx - 1 - x, z)] = index
        out = nxt
        sx, sy = sy, sx
    return (sx, sy, sz), out


def render(size, cells, palette):
    sx, sy, sz = size
    width = sx * PX
    height = sy * PX + sz * PX
    image = [(0, 0, 0, 0)] * (width * height)

    def shade(index, scale):
        r, g, b = palette[index - 1]
        return (max(0, min(255, int(r * scale))), max(0, min(255, int(g * scale))), max(0, min(255, int(b * scale))), 255)

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
            rect(gx, gy - (z + 1) * PX, PX, PX, shade(index, 1.08))
        if (x, y + 1, z) not in cells:
            rect(gx, gy - z * PX, PX, PX, shade(index, 0.78))
        if (x + 1, y, z) not in cells:
            rect(gx + PX - max(1, PX // 3), gy - (z + 1) * PX, max(1, PX // 3), PX, shade(index, 0.62))
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
    anchors = {"px": PX, "tile_px": 16 * PX}
    for path in sorted(SRC.glob("*.vox")):
        size, cells, palette = read_vox(path)
        turns = (0, 1, 2, 3) if path.stem in FOUR_WAY else (0,)
        for k in turns:
            rsize, rcells = rotate(size, cells, k)
            width, height, image = render(rsize, rcells, palette)
            name = f"{path.stem}_{k}"
            save_png(OUT / f"{name}.png", width, height, image)
            sx, sy, sz = rsize
            anchors[name] = {
                "ax": sx * PX / 2,
                "ay": sz * PX + sy * PX / 2,
                "fw": sx * PX,
                "fh": sy * PX,
            }
        print(path.stem, "x".join(str(n) for n in size))
    (OUT / "anchors.json").write_text(json.dumps(anchors, indent=2) + "\n", encoding="utf-8")
    print(f"sprites {len(anchors) - 2}")


if __name__ == "__main__":
    main()
