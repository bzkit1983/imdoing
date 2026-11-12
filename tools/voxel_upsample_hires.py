#!/usr/bin/env python3
"""Nearest-neighbor upsample art/src/*.vox toward hi-res envelopes.

- Characters in CHAR_WAY (except player_alt3): scale to 90×40×130 (player_alt3 standard).
- All other props: ×8 (tile 16→128, shelves 32×16→256×128, …).
- Skips player_alt3 (already at target). Does not touch tools/vox_backups.

See docs/alpha/voxel-hires-scale-plan.md.
"""

from __future__ import annotations

import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))

import voxel_sprites as vs  # noqa: E402

SRC = vs.SRC
CHAR_TARGET = vs.HIRES_CHAR_SIZE  # (90, 40, 130)
PROP_SCALE = 8
SKIP = {"player_alt3"}


def _chunk(tag: bytes, content: bytes) -> bytes:
    return tag + struct.pack("<ii", len(content), 0) + content


def write_vox(path: Path, size, cells: dict, rgba: bytes | bytearray) -> None:
    sx, sy, sz = size
    voxels = sorted(cells.items())
    size_chunk = _chunk(b"SIZE", struct.pack("<iii", sx, sy, sz))
    body = struct.pack("<i", len(voxels))
    body += b"".join(struct.pack("<BBBB", x, y, z, idx) for (x, y, z), idx in voxels)
    rgba_chunk = _chunk(b"RGBA", bytes(rgba[: 256 * 4]))
    children = size_chunk + _chunk(b"XYZI", body) + rgba_chunk
    path.write_bytes(b"VOX " + struct.pack("<i", 150) + b"MAIN" + struct.pack("<ii", 0, len(children)) + children)


def read_vox_rgba(path: Path):
    data = path.read_bytes()
    pos = 20
    end = pos + struct.unpack_from("<ii", data, 12)[1]
    size = (1, 1, 1)
    cells: dict = {}
    rgba = bytearray(256 * 4)
    for i in range(256):
        rgba[i * 4 : i * 4 + 4] = bytes((0, 0, 0, 255))
    while pos < end:
        tag = data[pos : pos + 4]
        cs, ch = struct.unpack_from("<ii", data, pos + 4)
        content = data[pos + 12 : pos + 12 + cs]
        if tag == b"SIZE":
            size = struct.unpack_from("<iii", content)
        elif tag == b"XYZI":
            n = struct.unpack_from("<i", content)[0]
            for i in range(n):
                x, y, z, idx = struct.unpack_from("<BBBB", content, 4 + i * 4)
                cells[(x, y, z)] = idx
        elif tag == b"RGBA":
            rgba = bytearray(content[: 256 * 4])
        pos += 12 + cs + ch
    return size, cells, rgba


def upsample(size, cells: dict, tx: int, ty: int, tz: int) -> tuple:
    sx, sy, sz = size
    if (sx, sy, sz) == (tx, ty, tz):
        return size, cells
    if sx < 1 or sy < 1 or sz < 1:
        return size, cells
    out: dict = {}
    for (x, y, z), idx in cells.items():
        x0 = int(x * tx / sx)
        y0 = int(y * ty / sy)
        z0 = int(z * tz / sz)
        x1 = int((x + 1) * tx / sx)
        y1 = int((y + 1) * ty / sy)
        z1 = int((z + 1) * tz / sz)
        for nx in range(x0, max(x0 + 1, x1)):
            for ny in range(y0, max(y0 + 1, y1)):
                for nz in range(z0, max(z0 + 1, z1)):
                    if 0 <= nx < tx and 0 <= ny < ty and 0 <= nz < tz:
                        out[(nx, ny, nz)] = idx
    return (tx, ty, tz), out


def target_size(stem: str, size) -> tuple[int, int, int]:
    sx, sy, sz = size
    if stem in vs.CHAR_WAY:
        return CHAR_TARGET
    return (sx * PROP_SCALE, sy * PROP_SCALE, max(1, sz * PROP_SCALE))


def main() -> None:
    changed = 0
    for path in sorted(SRC.glob("*.vox")):
        if path.stem in SKIP:
            print(f"skip {path.stem} (standard)")
            continue
        size, cells, rgba = read_vox_rgba(path)
        tgt = target_size(path.stem, size)
        if size == tgt:
            print(f"ok   {path.stem} already {size}")
            continue
        if vs.is_hires_size(size) and path.stem not in vs.CHAR_WAY:
            print(f"skip {path.stem} already hires-ish {size}")
            continue
        new_size, new_cells = upsample(size, cells, *tgt)
        write_vox(path, new_size, new_cells, rgba)
        print(f"up   {path.stem} {size} → {new_size} voxels={len(new_cells)}")
        changed += 1
    print(f"done changed={changed}")


if __name__ == "__main__":
    main()
