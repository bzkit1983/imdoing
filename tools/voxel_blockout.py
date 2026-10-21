#!/usr/bin/env python3
"""Write MagicaVoxel blockouts for the living godot/game art tree.

Running this overwrites godot/game/art/src/*.vox.
After a designer edits a .vox in MagicaVoxel, do not run this again
or those edits are replaced by the blockout.

Frozen Alpha sources in godot/alpha_v0_1/art/ are not touched.
"""

import json
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "godot" / "game" / "art"
SRC = ART / "src"
PREVIEW = ART / "preview"

# MagicaVoxel palette index 1 is the first entry. Index 0 is empty.
PALETTE = [
    ("skin", (244, 211, 180)),
    ("skin_shade", (214, 166, 130)),
    ("hair", (42, 33, 24)),
    ("hair_brown", (107, 79, 58)),
    ("eye", (28, 36, 31)),
    ("white", (244, 241, 234)),
    ("player", (42, 107, 74)),
    ("player_dark", (26, 74, 50)),
    ("customer", (107, 91, 149)),
    ("customer_dark", (74, 61, 110)),
    ("thief", (61, 31, 36)),
    ("hood", (26, 18, 20)),
    ("clerk", (31, 78, 121)),
    ("clerk_dark", (20, 52, 86)),
    ("clerk_stock", (31, 107, 74)),
    ("pants", (36, 48, 42)),
    ("shoe", (28, 36, 31)),
    ("wood", (92, 64, 51)),
    ("wood_dark", (58, 42, 30)),
    ("floor", (215, 196, 160)),
    ("floor_line", (176, 154, 112)),
    ("shelf_dry", (47, 93, 80)),
    ("shelf_dry_dark", (28, 58, 50)),
    ("shelf_frozen", (53, 90, 106)),
    ("shelf_ice", (44, 74, 110)),
    ("metal", (200, 212, 197)),
    ("screen", (28, 36, 31)),
    ("screen_on", (126, 203, 255)),
    ("can", (196, 92, 38)),
    ("snack", (232, 195, 106)),
    ("cup", (61, 126, 166)),
    ("drink", (126, 200, 227)),
    ("milk", (232, 236, 240)),
    ("milk_band", (58, 124, 165)),
    ("soda", (192, 57, 43)),
    ("icecream", (244, 164, 192)),
    ("cone", (176, 122, 74)),
    ("meat", (122, 48, 72)),
    ("rice", (224, 122, 61)),
    ("cardboard", (196, 165, 116)),
    ("tape", (232, 215, 160)),
    ("trash", (92, 72, 46)),
    ("puddle", (90, 158, 204)),
    ("vomit", (140, 168, 56)),
    ("glass", (169, 214, 229)),
    ("wall", (58, 42, 30)),
    ("cap", (244, 241, 234)),
]

COLOR_INDEX = {name: i + 1 for i, (name, _rgb) in enumerate(PALETTE)}


class Model:
    def __init__(self, sx, sy, sz):
        self.size = (sx, sy, sz)
        self.cells = {}

    def set(self, x, y, z, color):
        sx, sy, sz = self.size
        if not (0 <= x < sx and 0 <= y < sy and 0 <= z < sz):
            raise ValueError(f"{color} at {(x, y, z)} outside {self.size}")
        self.cells[(x, y, z)] = COLOR_INDEX[color]

    def fill(self, x0, y0, z0, x1, y1, z1, color):
        for x in range(min(x0, x1), max(x0, x1) + 1):
            for y in range(min(y0, y1), max(y0, y1) + 1):
                for z in range(min(z0, z1), max(z0, z1) + 1):
                    self.set(x, y, z, color)


def person(shirt, shirt_dark, hair, hood=False, mask=False, badge=False, bag=False):
    """Shared 12 x 10 x 20 body. Feet on z=0, face toward +Y."""
    m = Model(12, 10, 20)
    m.fill(3, 4, 0, 5, 6, 0, "shoe")
    m.fill(7, 4, 0, 9, 6, 0, "shoe")
    m.fill(3, 4, 1, 5, 6, 6, "pants")
    m.fill(7, 4, 1, 9, 6, 6, "pants")
    m.fill(2, 3, 7, 9, 7, 12, shirt)
    m.fill(2, 3, 7, 2, 7, 12, shirt_dark)
    m.fill(9, 3, 7, 9, 7, 12, shirt_dark)
    m.fill(4, 7, 12, 7, 7, 12, "white")
    m.fill(0, 4, 8, 1, 6, 11, shirt)
    m.fill(10, 4, 8, 11, 6, 11, shirt)
    m.fill(0, 4, 7, 1, 6, 7, "skin")
    m.fill(10, 4, 7, 11, 6, 7, "skin")
    m.fill(3, 3, 13, 8, 8, 17, "skin")
    if hood:
        m.fill(2, 2, 12, 9, 8, 19, "hood")
        m.fill(4, 7, 14, 7, 9, 16, "skin")
    else:
        m.fill(3, 3, 17, 8, 8, 19, hair)
        m.fill(3, 3, 14, 8, 4, 17, hair)
        m.fill(3, 8, 16, 8, 8, 17, hair)
    if mask:
        m.fill(3, 8, 15, 8, 9, 15, "hood")
        m.set(4, 9, 15, "white")
        m.set(7, 9, 15, "white")
    else:
        m.set(4, 8, 15, "eye")
        m.set(7, 8, 15, "eye")
        m.set(5, 8, 14, "skin_shade")
        m.set(6, 8, 14, "skin_shade")
    if badge:
        m.fill(5, 8, 9, 6, 8, 10, "white")
    if bag:
        m.fill(10, 5, 5, 11, 8, 11, "customer_dark")
    return m


def shelf(body, dark, goods, closed=False, glass_front=False):
    """2 x 1 shop tiles: 32 x 16 footprint. Front is +Y."""
    w, d, h = 32, 16, 18
    m = Model(w, d, h)
    m.fill(0, 0, 0, w - 1, d - 1, 1, dark)
    m.fill(0, 0, 0, 1, d - 1, 16, body)
    m.fill(w - 2, 0, 0, w - 1, d - 1, 16, body)
    m.fill(2, 0, 2, w - 3, 1, 16, body)
    for z in (4, 8, 12):
        m.fill(2, 2, z, w - 3, d - 3, z, body)
    slots = (4, 10, 16, 22)
    for level, z in enumerate((5, 9, 13)):
        for i, x in enumerate(slots):
            color = goods[(level + i) % len(goods)]
            m.fill(x, 4, z, x + 2, 7, z + 2, color)
            m.fill(x, 9, z, x + 2, 12, z + 2, color)
    if glass_front:
        m.fill(2, d - 2, 5, w - 3, d - 1, 5, "glass")
        m.fill(2, d - 2, 15, w - 3, d - 1, 15, "glass")
        m.fill(2, d - 2, 5, 3, d - 1, 15, "glass")
        m.fill(w - 4, d - 2, 5, w - 3, d - 1, 15, "glass")
    if closed:
        m.fill(2, 2, 16, w - 3, d - 2, 17, "metal")
        m.fill(2, d - 2, 2, w - 3, d - 1, 16, body)
    return m


def restock(accent):
    w, d, h = 16, 12, 24
    m = Model(w, d, h)
    for x, y in ((0, 0), (w - 2, 0), (0, d - 2), (w - 2, d - 2)):
        m.fill(x, y, 0, x + 1, y + 1, h - 1, "metal")
    for i, z in enumerate((1, 7, 13, 19)):
        m.fill(1, 1, z, w - 2, d - 2, z, "metal")
        color = "cardboard" if i % 2 == 0 else accent
        m.fill(2, 2, z + 1, 6, 5, z + 4, color)
        m.fill(8, 2, z + 1, 13, 5, z + 4, "cardboard")
        m.fill(4, 2, z + 4, 5, 5, z + 4, "tape")
    return m


def register():
    m = Model(18, 14, 16)
    m.fill(1, 2, 0, 16, 11, 8, "wood")
    m.fill(1, 2, 0, 16, 11, 1, "wood_dark")
    m.fill(3, 11, 3, 14, 13, 6, "wood_dark")
    m.fill(0, 1, 9, 17, 12, 9, "metal")
    m.fill(5, 2, 10, 12, 4, 15, "screen")
    m.fill(6, 4, 11, 11, 4, 14, "screen_on")
    m.fill(4, 10, 10, 4, 10, 10, "can")
    m.fill(7, 10, 10, 7, 10, 10, "snack")
    m.fill(10, 10, 10, 10, 10, 10, "cup")
    return m


def box():
    m = Model(8, 8, 6)
    m.fill(0, 0, 0, 7, 7, 5, "cardboard")
    m.fill(0, 3, 5, 7, 4, 5, "tape")
    m.fill(3, 0, 5, 4, 7, 5, "tape")
    return m


def can():
    m = Model(8, 8, 10)
    for x in range(2, 6):
        for y in range(2, 6):
            m.fill(x, y, 0, x, y, 7, "can")
    m.fill(2, 2, 8, 5, 5, 8, "metal")
    m.fill(3, 2, 3, 4, 2, 5, "white")
    return m


def snack():
    m = Model(8, 8, 8)
    m.fill(1, 2, 2, 6, 5, 5, "snack")
    m.fill(0, 3, 3, 7, 4, 4, "snack")
    m.fill(2, 3, 4, 5, 4, 4, "white")
    return m


def cup():
    m = Model(8, 8, 10)
    for x in range(2, 6):
        for y in range(2, 6):
            m.fill(x, y, 0, x, y, 6, "cup")
    m.fill(2, 2, 7, 5, 5, 8, "cap")
    m.fill(3, 2, 2, 4, 2, 4, "rice")
    return m


def drink():
    m = Model(8, 8, 12)
    m.fill(3, 3, 0, 4, 4, 8, "drink")
    m.fill(3, 3, 9, 4, 4, 10, "white")
    m.fill(3, 3, 11, 4, 4, 11, "cap")
    return m


def milk():
    m = Model(8, 8, 12)
    m.fill(2, 2, 0, 5, 5, 8, "milk")
    m.fill(2, 2, 4, 5, 5, 6, "milk_band")
    m.fill(3, 2, 9, 4, 5, 11, "milk")
    m.fill(3, 2, 10, 4, 2, 10, "milk_band")
    return m


def soda():
    m = Model(8, 8, 10)
    for x in range(2, 6):
        for y in range(2, 6):
            m.fill(x, y, 0, x, y, 8, "soda")
    m.fill(2, 2, 3, 5, 5, 4, "white")
    m.fill(2, 2, 8, 5, 5, 8, "metal")
    return m


def icecream():
    m = Model(8, 8, 12)
    m.fill(3, 3, 0, 4, 4, 4, "cone")
    m.fill(2, 2, 5, 5, 5, 8, "icecream")
    m.fill(3, 3, 9, 4, 4, 10, "white")
    return m


def meat():
    m = Model(10, 8, 4)
    m.fill(0, 1, 0, 9, 6, 1, "white")
    m.fill(1, 2, 1, 8, 5, 2, "meat")
    m.fill(2, 2, 3, 7, 5, 3, "glass")
    return m


def rice():
    m = Model(10, 8, 4)
    m.fill(0, 1, 0, 9, 6, 1, "rice")
    m.fill(1, 2, 2, 8, 5, 3, "snack")
    m.fill(0, 1, 1, 9, 1, 1, "white")
    return m


def trash():
    m = Model(14, 12, 6)
    m.fill(2, 2, 0, 10, 8, 2, "trash")
    m.fill(4, 3, 3, 8, 7, 4, "cardboard")
    m.fill(1, 4, 1, 4, 6, 3, "wood_dark")
    m.fill(8, 2, 2, 12, 5, 3, "white")
    return m


def puddle():
    m = Model(16, 14, 1)
    m.fill(2, 2, 0, 13, 11, 0, "puddle")
    m.fill(4, 1, 0, 11, 12, 0, "puddle")
    m.fill(6, 5, 0, 8, 7, 0, "white")
    return m


def vomit():
    m = Model(14, 12, 2)
    m.fill(2, 2, 0, 11, 9, 0, "vomit")
    m.fill(4, 3, 1, 9, 7, 1, "vomit")
    m.fill(5, 4, 1, 7, 6, 1, "snack")
    return m


def floor_tile():
    m = Model(16, 16, 1)
    m.fill(0, 0, 0, 15, 15, 0, "floor")
    m.fill(0, 0, 0, 15, 0, 0, "floor_line")
    m.fill(0, 0, 0, 0, 15, 0, "floor_line")
    return m


def wall():
    m = Model(16, 2, 16)
    m.fill(0, 0, 0, 15, 1, 15, "wall")
    m.fill(0, 0, 14, 15, 1, 15, "wood")
    return m


def door():
    m = Model(16, 2, 16)
    m.fill(0, 0, 0, 2, 1, 15, "wall")
    m.fill(13, 0, 0, 15, 1, 15, "wall")
    m.fill(0, 0, 13, 15, 1, 15, "wall")
    m.fill(3, 0, 0, 12, 1, 1, "floor")
    m.fill(6, 0, 7, 9, 1, 11, "glass")
    return m


CATALOG = [
    {
        "id": "characters",
        "name": "人物",
        "models": [
            ("player", "玩家", person("player", "player_dark", "hair"), "綠衣、深色頭髮。店長。"),
            ("customer", "客人", person("customer", "customer_dark", "hair_brown", bag=True), "紫衣、側袋。和店員的制服分開。"),
            ("thief", "小偷", person("thief", "hood", "hood", hood=True, mask=True), "兜帽和面罩。遠看也要和客人分開。"),
            ("clerk_cashier", "收銀店員", person("clerk", "clerk_dark", "hair", badge=True), "藍衣、白牌。看收銀機。"),
            ("clerk_restock", "補貨店員", person("clerk_stock", "player_dark", "hair_brown"), "綠衣、沒有白牌。和店長以髮色、衣色分開。"),
        ],
    },
    {
        "id": "furniture",
        "name": "店內物件",
        "models": [
            ("register", "收銀機", register(), "櫃檯加螢幕。佔地仍是玩法裡的那一格尺寸，模型先做成一台。"),
            ("restock_dry", "乾貨補貨架", restock("can"), "倉庫架，上面是箱。"),
            ("restock_frozen", "凍櫃補貨架", restock("drink"), "同一座倉庫架，箱色用凍飲色。"),
            ("restock_ice", "冰櫃補貨架", restock("icecream"), "同一座倉庫架，箱色用雪糕色。"),
            ("shelf_dry", "乾貨貨架", shelf("shelf_dry", "shelf_dry_dark", ("can", "snack", "cup")), "2×1 格。4、8、12、24 件是容量，這版不做成四個長度。"),
            ("shelf_frozen", "凍櫃貨架", shelf("shelf_frozen", "shelf_ice", ("drink", "milk", "soda"), glass_front=True), "前面有一圈玻璃框。"),
            ("shelf_ice", "冰櫃貨架", shelf("shelf_ice", "screen", ("icecream", "meat", "rice"), closed=True), "有頂蓋，前面較密。"),
        ],
    },
    {
        "id": "goods",
        "name": "貨品",
        "models": [
            ("box", "貨箱", box(), "一箱 4 件。手上、地上、架上都用這一個。"),
            ("can", "罐頭", can(), "圓罐。"),
            ("snack", "零食", snack(), "扁袋。"),
            ("cup", "杯麵", cup(), "有蓋的杯。"),
            ("drink", "支裝凍飲", drink(), "細長瓶子。"),
            ("milk", "牛奶", milk(), "方盒，有屋頂。"),
            ("soda", "汽水", soda(), "紅罐，一條白帶。"),
            ("icecream", "雪糕", icecream(), "甜筒。"),
            ("meat", "凍肉", meat(), "平盤。"),
            ("rice", "叮叮飯", rice(), "平盒。角色 LV10 才賣，模型先做。"),
        ],
    },
    {
        "id": "place",
        "name": "地面與污物",
        "models": [
            ("floor_tile", "地磚", floor_tile(), "一格店面，16×16。"),
            ("wall", "牆", wall(), "一格寬的牆段。"),
            ("door", "店門", door(), "門口留空，中間一塊玻璃。"),
            ("trash", "垃圾", trash(), "一堆，比水漬高。"),
            ("puddle", "水漬", puddle(), "貼地。透明留待之後的材質。"),
            ("vomit", "嘔吐物", vomit(), "貼地，比水漬厚一點、顏色分開。"),
        ],
    },
]


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
    path.write_bytes(b"VOX " + struct.pack("<i", 150) + main)


def _chunk(tag: bytes, content: bytes) -> bytes:
    return tag + struct.pack("<ii", len(content), 0) + content


def read_vox(path: Path):
    data = path.read_bytes()
    if data[:4] != b"VOX ":
        raise ValueError(path)
    pos = 8
    _tag, _content, children = _read_chunk(data, pos)
    pos = 8 + 12
    end = pos + children
    size = None
    count = 0
    while pos < end:
        tag, content, child = _read_chunk(data, pos)
        if tag == b"SIZE":
            size = struct.unpack_from("<iii", content)
        elif tag == b"XYZI":
            count = struct.unpack_from("<i", content)[0]
        pos += 12 + len(content) + child
    return size, count


def _read_chunk(data, pos):
    tag = data[pos : pos + 4]
    content_size, children_size = struct.unpack_from("<ii", data, pos + 4)
    content = data[pos + 12 : pos + 12 + content_size]
    return tag, content, children_size


def _shade(rgb, scale):
    return tuple(max(0, min(255, int(c * scale))) for c in rgb)


class Canvas:
    def __init__(self, w, h, color):
        self.w = w
        self.h = h
        self.px = [color] * (w * h)

    def set(self, x, y, color):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y * self.w + x] = color

    def paste(self, other, x0, y0):
        for y in range(other.h):
            for x in range(other.w):
                self.set(x0 + x, y0 + y, other.px[y * other.w + x])

    def polygon(self, pts, color):
        if len(pts) < 3:
            return
        y0 = max(0, int(min(p[1] for p in pts)))
        y1 = min(self.h - 1, int(max(p[1] for p in pts)))
        for y in range(y0, y1 + 1):
            xs = []
            for i, (x1, yy1) in enumerate(pts):
                x2, yy2 = pts[(i + 1) % len(pts)]
                if (yy1 <= y < yy2) or (yy2 <= y < yy1):
                    t = (y - yy1) / (yy2 - yy1) if yy2 != yy1 else 0
                    xs.append(x1 + t * (x2 - x1))
            xs.sort()
            for i in range(0, len(xs) - 1, 2):
                a = int(xs[i])
                b = int(xs[i + 1])
                row = y * self.w
                for x in range(max(0, a), min(self.w, b + 1)):
                    self.px[row + x] = color

    def text(self, x, y, message, color):
        for i, ch in enumerate(message):
            glyph = _FONT.get(ch, _FONT[" "])
            for gy, row in enumerate(glyph):
                for gx, bit in enumerate(row):
                    if bit == "#":
                        self.set(x + i * 6 + gx, y + gy, color)

    def save(self, path: Path):
        raw = bytearray()
        for y in range(self.h):
            raw.append(0)
            for x in range(self.w):
                raw.extend(self.px[y * self.w + x])
        def chunk(tag, data):
            return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        ihdr = struct.pack(">IIBBBBB", self.w, self.h, 8, 2, 0, 0, 0)
        png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
        path.write_bytes(png)


_FONT = {}


def _glyph(rows):
    return rows


def _build_font():
    # 5x7 glyphs for the contact-sheet labels.
    raw = {
        " ": [".....", ".....", ".....", ".....", ".....", ".....", "....."],
        "_": [".....", ".....", ".....", ".....", ".....", ".....", "#####"],
        "-": [".....", ".....", ".....", "#####", ".....", ".....", "....."],
        "a": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "b": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
        "c": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
        "d": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
        "e": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
        "f": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
        "g": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
        "h": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "i": ["###..", ".#...", ".#...", ".#...", ".#...", ".#...", "###.."],
        "k": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
        "l": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
        "m": ["#...#", "##.##", "#.#.#", "#...#", "#...#", "#...#", "#...#"],
        "n": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
        "o": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "p": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
        "r": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
        "s": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
        "t": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
        "u": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "v": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
        "w": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
        "x": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
        "y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
        "z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
    }
    for ch, rows in raw.items():
        _FONT[ch] = rows
    for digit, rows in {
        "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
        "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
        "3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
        "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
        "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
        "6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
        "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
        "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
        "9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
    }.items():
        _FONT[digit] = rows


_build_font()


def _iso(model: Model, cell: int) -> Canvas:
    rgb_of = {i + 1: rgb for i, (_n, rgb) in enumerate(PALETTE)}
    pts = [(x, y, z, rgb_of[index]) for (x, y, z), index in model.cells.items()]
    img = Canvas(cell, cell, (20, 28, 24))
    if not pts:
        return img

    def project(x, y, z, scale):
        return ((x - y) * scale, (x + y) * scale * 0.5 - z * scale)

    raw = []
    for x, y, z, _rgb in pts:
        raw.extend([
            project(x, y, z + 1, 1),
            project(x + 1, y, z + 1, 1),
            project(x + 1, y + 1, z + 1, 1),
            project(x, y + 1, z + 1, 1),
            project(x, y, z, 1),
            project(x + 1, y + 1, z, 1),
        ])
    min_x = min(p[0] for p in raw)
    max_x = max(p[0] for p in raw)
    min_y = min(p[1] for p in raw)
    max_y = max(p[1] for p in raw)
    span = max(max_x - min_x, max_y - min_y, 1)
    scale = (cell - 36) / span
    ox = cell / 2 - (min_x + max_x) * 0.5 * scale
    oy = cell / 2 - (min_y + max_y) * 0.5 * scale + 6

    def P(x, y, z):
        px, py = project(x, y, z, scale)
        return (ox + px, oy + py)

    for x, y, z, rgb in sorted(pts, key=lambda item: (item[0] + item[1], item[2])):
        top = [P(x, y, z + 1), P(x + 1, y, z + 1), P(x + 1, y + 1, z + 1), P(x, y + 1, z + 1)]
        right = [P(x + 1, y, z), P(x + 1, y + 1, z), P(x + 1, y + 1, z + 1), P(x + 1, y, z + 1)]
        left = [P(x, y + 1, z), P(x + 1, y + 1, z), P(x + 1, y + 1, z + 1), P(x, y + 1, z + 1)]
        img.polygon(left, _shade(rgb, 0.72))
        img.polygon(right, _shade(rgb, 0.88))
        img.polygon(top, _shade(rgb, 1.08))
    return img


def write_sheet(entries):
    cell = 180
    cols = 6
    label_h = 16
    rows = (len(entries) + cols - 1) // cols
    sheet = Canvas(cols * cell, rows * (cell + label_h) + 8, (12, 18, 16))
    for i, (model_id, _name, model) in enumerate(entries):
        col = i % cols
        row = i // cols
        thumb = _iso(model, cell - 8)
        x = col * cell + 4
        y = row * (cell + label_h) + 4
        sheet.paste(thumb, x, y)
        sheet.text(x + 6, y + cell - 14, model_id, (244, 241, 234))
    PREVIEW.mkdir(parents=True, exist_ok=True)
    sheet.save(PREVIEW / "sheet.png")


def main():
    SRC.mkdir(parents=True, exist_ok=True)
    groups = []
    flat = []
    for group in CATALOG:
        models = []
        for model_id, name, model, note in group["models"]:
            path = SRC / f"{model_id}.vox"
            write_vox(path, model)
            size, count = read_vox(path)
            if size != model.size or count != len(model.cells):
                raise SystemExit(f"{model_id} roundtrip failed: {size} {count}")
            models.append({
                "id": model_id,
                "name": name,
                "file": f"{model_id}.vox",
                "size": list(model.size),
                "voxels": len(model.cells),
                "note": note,
            })
            flat.append((model_id, name, model))
            print(f"{model_id:16} {model.size[0]:3}x{model.size[1]:<3}x{model.size[2]:<3} {len(model.cells):5} voxels")
        groups.append({"id": group["id"], "name": group["name"], "models": models})
    catalog = {
        "version": "alpha-v0.1",
        "voxel_meters": 0.1,
        "tile_voxels": 16,
        "axis": "MagicaVoxel X right, Y forward, Z up. Feet on z=0. Characters face +Y.",
        "palette": [{"index": i + 1, "name": name, "rgb": list(rgb)} for i, (name, rgb) in enumerate(PALETTE)],
        "groups": groups,
    }
    (ART / "catalog.json").write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    write_sheet(flat)
    print(f"wrote {len(flat)} models")


if __name__ == "__main__":
    main()
