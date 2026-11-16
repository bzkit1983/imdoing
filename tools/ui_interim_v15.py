#!/usr/bin/env python3
"""v1.5 interim UI icons: readable SKU products, temporary skill glyphs, prep tiles.

PNG only. No letters. 64×64 SKU/skill (even pixels so a nearest 32 still reads),
96×96 prep tiles. See docs/systemdesign/art-interim-v1.5.md.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))

import voxel_sprites as vs  # noqa: E402

UI = ROOT / "godot" / "game" / "art" / "ui"
SKU_DIR = UI / "sku"
SKILL_DIR = UI / "skill"
PREP_DIR = UI / "prep"

INK = (26, 26, 26, 255)
PAPER = (244, 241, 234, 255)
GOLD = (244, 211, 94, 255)
ORANGE = (196, 92, 38, 255)
TEAL = (61, 126, 166, 255)
CYAN = (126, 200, 227, 255)
MILK = (232, 236, 240, 255)
MILK_BAND = (58, 124, 165, 255)
SODA = (192, 57, 43, 255)
PINK = (244, 164, 192, 255)
CONE = (176, 122, 74, 255)
MEAT = (122, 48, 72, 255)
RICE = (224, 122, 61, 255)
SNACK = (232, 195, 106, 255)
GREEN = (42, 107, 74, 255)
NAVY = (31, 78, 121, 255)
PURPLE = (107, 91, 149, 255)


class Icon:
    def __init__(self, n: int):
        self.n = n
        self.px = [(0, 0, 0, 0)] * (n * n)

    def put(self, x: int, y: int, c) -> None:
        if 0 <= x < self.n and 0 <= y < self.n and c[3]:
            self.px[y * self.n + x] = c

    def erase(self, cx, cy, r) -> None:
        r2 = r * r
        for y in range(int(cy - r) - 1, int(cy + r) + 2):
            for x in range(int(cx - r) - 1, int(cx + r) + 2):
                if 0 <= x < self.n and 0 <= y < self.n and (x - cx) ** 2 + (y - cy) ** 2 <= r2:
                    self.px[y * self.n + x] = (0, 0, 0, 0)

    def disc(self, cx, cy, r, c) -> None:
        r2 = r * r
        for y in range(int(cy - r) - 1, int(cy + r) + 2):
            for x in range(int(cx - r) - 1, int(cx + r) + 2):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r2:
                    self.put(x, y, c)

    def rect(self, x, y, w, h, c) -> None:
        for yy in range(int(y), int(y + h)):
            for xx in range(int(x), int(x + w)):
                self.put(xx, yy, c)

    def line(self, x0, y0, x1, y1, c, t: int = 2) -> None:
        steps = max(abs(int(x1 - x0)), abs(int(y1 - y0)), 1)
        for i in range(steps + 1):
            x = x0 + (x1 - x0) * i / steps
            y = y0 + (y1 - y0) * i / steps
            self.disc(x, y, max(1, t // 2), c)

    def tri(self, ax, ay, bx, by, cx, cy, c) -> None:
        minx = int(min(ax, bx, cx))
        maxx = int(max(ax, bx, cx))
        miny = int(min(ay, by, cy))
        maxy = int(max(ay, by, cy))

        def edge(px, py, x0, y0, x1, y1):
            return (px - x0) * (y1 - y0) - (py - y0) * (x1 - x0)

        for y in range(miny, maxy + 1):
            for x in range(minx, maxx + 1):
                w0 = edge(x, y, bx, by, cx, cy)
                w1 = edge(x, y, cx, cy, ax, ay)
                w2 = edge(x, y, ax, ay, bx, by)
                if (w0 >= 0 and w1 >= 0 and w2 >= 0) or (w0 <= 0 and w1 <= 0 and w2 <= 0):
                    self.put(x, y, c)

    def outline(self) -> None:
        src = self.px
        n = self.n
        out = list(src)
        for y in range(n):
            row = y * n
            for x in range(n):
                if src[row + x][3] == 0:
                    continue
                edge = x == 0 or y == 0 or x == n - 1 or y == n - 1
                if not edge:
                    if (
                        src[row + x - 1][3] == 0
                        or src[row + x + 1][3] == 0
                        or src[row - n + x][3] == 0
                        or src[row + n + x][3] == 0
                    ):
                        edge = True
                if edge:
                    out[row + x] = INK
        self.px = out

    def save(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        vs.save_png(path, self.n, self.n, self.px)


def sku_can() -> Icon:
    g = Icon(64)
    g.disc(32, 16, 14, (220, 224, 214, 255))
    g.rect(18, 16, 28, 34, ORANGE)
    g.disc(32, 50, 14, ORANGE)
    g.rect(22, 26, 20, 14, PAPER)
    g.rect(26, 30, 12, 6, ORANGE)
    return g


def sku_snack() -> Icon:
    g = Icon(64)
    # Soft bag: wide body, zigzag crimp. Not a gable.
    g.rect(10, 28, 44, 24, SNACK)
    g.disc(16, 40, 10, SNACK)
    g.disc(48, 40, 10, SNACK)
    g.disc(32, 46, 12, SNACK)
    for i, x in enumerate(range(10, 54, 6)):
        y0 = 18 if i % 2 == 0 else 26
        g.tri(x, 30, x + 6, 30, x + 3, y0, PAPER if i % 2 == 0 else SNACK)
    g.disc(32, 38, 6, (255, 232, 170, 255))
    return g


def sku_cup() -> Icon:
    g = Icon(64)
    g.tri(18, 18, 46, 18, 40, 48, TEAL)
    g.tri(18, 18, 24, 48, 40, 48, TEAL)
    g.rect(16, 14, 32, 8, PAPER)
    g.disc(32, 14, 16, PAPER)
    g.disc(24, 8, 4, PAPER)
    g.disc(40, 6, 3, PAPER)
    g.rect(26, 28, 12, 8, RICE)
    return g


def sku_drink() -> Icon:
    g = Icon(64)
    g.rect(26, 18, 12, 36, CYAN)
    g.disc(32, 52, 8, CYAN)
    g.rect(28, 12, 8, 8, PAPER)
    g.rect(29, 6, 6, 8, INK)
    g.rect(28, 28, 8, 14, PAPER)
    return g


def sku_milk() -> Icon:
    g = Icon(64)
    g.rect(16, 28, 28, 28, MILK)
    g.tri(16, 28, 44, 28, 30, 8, MILK)
    g.line(30, 8, 30, 28, MILK_BAND, 3)
    g.rect(16, 36, 28, 8, MILK_BAND)
    # Spout sticks out of the right face.
    g.rect(42, 36, 10, 8, MILK)
    g.rect(48, 38, 6, 4, MILK_BAND)
    return g


def sku_soda() -> Icon:
    g = Icon(64)
    g.disc(32, 14, 12, (210, 214, 206, 255))
    g.rect(20, 14, 24, 36, SODA)
    g.disc(32, 50, 12, SODA)
    g.rect(22, 26, 20, 8, PAPER)
    # Pull tab.
    g.disc(32, 12, 4, INK)
    g.rect(30, 6, 4, 6, (210, 214, 206, 255))
    return g


def sku_icecream() -> Icon:
    g = Icon(64)
    g.tri(22, 30, 42, 30, 32, 58, CONE)
    g.line(24, 34, 40, 46, CONE, 2)
    g.line(40, 34, 24, 46, CONE, 2)
    g.disc(26, 26, 10, PINK)
    g.disc(38, 24, 10, PAPER)
    return g


def sku_meat() -> Icon:
    g = Icon(64)
    g.rect(8, 22, 48, 24, PAPER)
    g.rect(12, 18, 40, 8, PAPER)
    g.disc(24, 32, 10, MEAT)
    g.disc(40, 34, 8, (160, 70, 90, 255))
    g.rect(14, 26, 36, 4, (200, 230, 236, 180))
    return g


def sku_rice() -> Icon:
    g = Icon(64)
    g.rect(8, 16, 48, 36, RICE)
    g.rect(12, 20, 18, 26, SNACK)
    g.rect(34, 20, 18, 26, (255, 220, 160, 255))
    g.rect(30, 20, 4, 26, RICE)
    # Microwave triangle.
    g.tri(24, 14, 40, 14, 32, 4, PAPER)
    return g


SKU = {
    "can": sku_can,
    "snack": sku_snack,
    "cup": sku_cup,
    "drink": sku_drink,
    "milk": sku_milk,
    "soda": sku_soda,
    "icecream": sku_icecream,
    "meat": sku_meat,
    "rice": sku_rice,
}


def _draw(n: int, ops) -> Icon:
    g = Icon(n)
    for op in ops:
        kind = op[0]
        if kind == "disc":
            g.disc(*op[1:])
        elif kind == "erase":
            g.erase(*op[1:])
        elif kind == "rect":
            g.rect(*op[1:])
        elif kind == "line":
            g.line(*op[1:])
        elif kind == "tri":
            g.tri(*op[1:])
    return g


def skill_ops() -> dict:
    """Temporary glyphs. Same ink weight; the shape is the skill."""
    p = PAPER
    gld = GOLD
    return {
        "carry_boost": [("rect", 18, 28, 28, 22, gld), ("tri", 24, 26, 40, 26, 32, 10, p)],
        "move_boost": [("tri", 8, 40, 28, 18, 28, 46, gld), ("tri", 26, 40, 46, 18, 46, 46, p), ("tri", 44, 40, 58, 22, 58, 46, ORANGE)],
        "checkout_rush": [("rect", 12, 28, 40, 22, NAVY), ("rect", 18, 16, 22, 14, CYAN), ("line", 16, 22, 48, 12, gld, 3)],
        "universal_cannon": [("rect", 10, 28, 36, 12, INK), ("disc", 46, 34, 10, ORANGE), ("rect", 14, 24, 10, 6, gld)],
        "shelf_cannon": [("rect", 8, 18, 28, 6, GREEN), ("rect", 8, 30, 28, 6, GREEN), ("rect", 8, 42, 28, 6, GREEN), ("disc", 48, 34, 10, ORANGE)],
        "kind_cannon": [("rect", 8, 28, 28, 12, INK), ("disc", 46, 24, 8, PINK), ("disc", 40, 32, 8, PINK), ("tri", 40, 34, 52, 34, 46, 46, PINK)],
        "self_checkout": [("rect", 16, 18, 32, 28, NAVY), ("rect", 22, 24, 20, 8, CYAN), ("disc", 32, 50, 6, gld)],
        "calm_zone": [("disc", 32, 32, 20, CYAN), ("disc", 32, 32, 10, p), ("disc", 32, 30, 4, TEAL)],
        "senior_cashier": [("disc", 32, 30, 16, gld), ("rect", 28, 18, 8, 24, NAVY), ("tri", 20, 22, 44, 22, 32, 10, gld)],
        "instant_restock": [("rect", 16, 26, 32, 24, CONE), ("tri", 24, 24, 40, 24, 32, 8, gld), ("line", 32, 8, 32, 22, gld, 3)],
        "soothe": [("disc", 24, 28, 10, PINK), ("disc", 40, 28, 10, PINK), ("tri", 16, 32, 48, 32, 32, 52, PINK)],
        "metal_rush": [("rect", 14, 16, 10, 28, INK), ("rect", 40, 16, 10, 28, INK), ("rect", 18, 36, 28, 8, SODA), ("disc", 22, 48, 5, gld), ("disc", 40, 50, 5, gld)],
        "hoop_ace": [("disc", 32, 22, 14, ORANGE), ("erase", 32, 22, 8), ("rect", 28, 22, 8, 28, INK), ("disc", 32, 16, 5, ORANGE)],
        "dash_deliver": [("tri", 8, 34, 36, 18, 36, 48, gld), ("rect", 36, 26, 18, 16, CONE)],
        "dasher": [("tri", 6, 36, 24, 20, 24, 48, CYAN), ("tri", 22, 36, 40, 16, 40, 48, gld), ("tri", 38, 36, 56, 20, 56, 48, p)],
        "force_sell": [("disc", 20, 40, 10, gld), ("disc", 36, 34, 10, gld), ("disc", 48, 26, 8, gld), ("tri", 12, 22, 28, 22, 20, 10, GREEN)],
        "must_deliver": [("disc", 32, 34, 16, SODA), ("disc", 32, 34, 8, p), ("disc", 32, 34, 3, SODA), ("tri", 32, 8, 26, 20, 38, 20, SODA)],
        "summon_guest": [("disc", 24, 24, 8, p), ("rect", 16, 34, 16, 18, TEAL), ("disc", 46, 40, 8, gld), ("rect", 42, 32, 8, 4, gld)],
        "harvest_chives": [("rect", 14, 36, 8, 16, GREEN), ("rect", 28, 28, 8, 24, GREEN), ("rect", 42, 20, 8, 32, GREEN), ("line", 10, 18, 50, 14, INK, 3)],
        "magneto": [("rect", 16, 16, 10, 28, SODA), ("rect", 38, 16, 10, 28, NAVY), ("rect", 16, 40, 32, 8, INK), ("disc", 32, 22, 4, gld)],
        "sweeping_monk": [("line", 16, 16, 40, 40, CONE, 4), ("rect", 34, 36, 18, 8, GREEN), ("rect", 36, 44, 6, 10, GREEN), ("rect", 44, 44, 6, 10, GREEN)],
        "shelf_sniper": [("rect", 10, 16, 22, 6, GREEN), ("rect", 10, 28, 22, 6, GREEN), ("rect", 10, 40, 22, 6, GREEN), ("disc", 46, 32, 10, INK), ("disc", 46, 32, 4, SODA)],
        "guest_sniper": [("disc", 18, 22, 8, p), ("rect", 10, 32, 16, 18, TEAL), ("disc", 46, 36, 10, INK), ("disc", 46, 36, 4, SODA)],
        "thief_sniper": [("disc", 18, 24, 10, INK), ("rect", 10, 22, 16, 6, SODA), ("disc", 46, 36, 10, INK), ("disc", 46, 36, 4, gld)],
        "dark_side": [("disc", 32, 32, 18, INK), ("erase", 40, 28, 14), ("disc", 26, 36, 4, PURPLE)],
        "shadow_clone": [("disc", 22, 22, 8, p), ("rect", 14, 32, 16, 20, TEAL), ("disc", 42, 26, 8, (180, 190, 186, 255)), ("rect", 34, 36, 16, 18, (90, 110, 104, 255))],
        "carry_passive": [("rect", 14, 30, 36, 20, CONE), ("line", 18, 40, 46, 40, gld, 3), ("line", 32, 30, 32, 50, gld, 3)],
        "move_passive": [("tri", 14, 44, 32, 16, 50, 44, CYAN), ("disc", 24, 46, 5, INK), ("disc", 42, 46, 5, INK)],
        "checkout_speed": [("rect", 12, 26, 28, 22, NAVY), ("disc", 46, 28, 10, gld), ("line", 46, 28, 46, 20, INK, 2), ("line", 46, 28, 52, 32, INK, 2)],
        "restock_speed": [("rect", 10, 30, 26, 20, CONE), ("disc", 46, 26, 10, gld), ("line", 46, 26, 46, 18, INK, 2)],
        "quick_swallow": [("disc", 32, 36, 16, p), ("disc", 32, 40, 8, INK), ("tri", 22, 18, 42, 18, 32, 32, ORANGE)],
        "polite_dash": [("disc", 22, 20, 8, p), ("rect", 14, 30, 16, 18, TEAL), ("tri", 34, 40, 54, 24, 54, 48, gld)],
        "wave_step": [("line", 8, 40, 20, 28, CYAN, 4), ("line", 20, 28, 32, 44, CYAN, 4), ("line", 32, 44, 44, 24, CYAN, 4), ("line", 44, 24, 56, 40, CYAN, 4)],
        "cold_smile": [("disc", 32, 32, 18, CYAN), ("rect", 20, 34, 8, 4, INK), ("rect", 36, 34, 8, 4, INK), ("disc", 32, 42, 6, p)],
        "haki": [("disc", 32, 32, 18, SODA), ("erase", 32, 32, 12), ("disc", 32, 32, 5, INK), ("line", 32, 6, 32, 58, gld, 3), ("line", 6, 32, 58, 32, gld, 3)],
        "the_world": [("disc", 32, 32, 20, p), ("disc", 32, 32, 16, INK), ("line", 32, 18, 32, 32, gld, 3), ("line", 32, 32, 42, 38, gld, 3)],
        "yes_my_lord": [("rect", 16, 28, 32, 8, gld), ("tri", 16, 28, 24, 12, 32, 28, gld), ("tri", 32, 28, 40, 12, 48, 28, gld), ("rect", 28, 36, 8, 14, PURPLE)],
        "fundraise": [("disc", 18, 40, 10, gld), ("disc", 34, 36, 12, gld), ("disc", 48, 28, 8, ORANGE), ("tri", 28, 16, 40, 16, 34, 8, gld)],
        "close_gate": [("rect", 12, 16, 8, 36, INK), ("rect", 44, 16, 8, 36, INK), ("rect", 12, 16, 40, 8, INK), ("rect", 20, 28, 24, 24, CONE)],
        "guest_dusk": [("disc", 44, 18, 8, ORANGE), ("rect", 8, 28, 28, 4, PURPLE), ("disc", 16, 40, 6, p), ("rect", 10, 46, 12, 10, TEAL)],
        "three_volley": [("rect", 14, 16, 8, 16, INK), ("rect", 28, 24, 8, 16, INK), ("rect", 42, 32, 8, 16, INK), ("tri", 18, 14, 22, 8, 14, 16, ORANGE), ("tri", 32, 22, 36, 16, 28, 24, ORANGE), ("tri", 46, 30, 50, 24, 42, 32, ORANGE)],
    }


def prep_ops() -> dict:
    p = PAPER
    gld = GOLD
    return {
        "char": [("disc", 48, 30, 16, gld), ("rect", 30, 48, 36, 32, p)],
        "goods": [("rect", 16, 40, 28, 28, ORANGE), ("rect", 40, 28, 32, 40, gld)],
        "shop": [("tri", 18, 44, 78, 44, 48, 16, GREEN), ("rect", 28, 44, 40, 32, p), ("rect", 42, 52, 12, 24, gld)],
        "staff": [("disc", 34, 28, 14, CYAN), ("rect", 20, 46, 28, 30, p), ("rect", 54, 40, 22, 28, gld)],
        "sys": [("rect", 22, 28, 52, 40, (90, 104, 96, 255)), ("disc", 48, 48, 12, p), ("disc", 48, 48, 5, INK)],
        "stats": [("rect", 22, 36, 14, 40, gld), ("rect", 42, 24, 14, 52, p), ("rect", 62, 44, 14, 32, ORANGE)],
        "skills": [("tri", 48, 16, 58, 40, 38, 40, gld), ("tri", 48, 80, 38, 56, 58, 56, gld), ("tri", 20, 36, 40, 28, 40, 52, ORANGE), ("tri", 76, 36, 56, 28, 56, 52, ORANGE)],
        "look": [("disc", 48, 32, 16, (90, 104, 96, 255)), ("rect", 32, 50, 32, 30, TEAL)],
        "develop": [("rect", 24, 24, 48, 48, (36, 52, 44, 255)), ("rect", 44, 32, 8, 32, gld), ("rect", 32, 44, 32, 8, gld)],
        "buy": [("rect", 18, 40, 26, 28, ORANGE), ("rect", 46, 28, 28, 40, gld)],
        "for_sale": [("rect", 22, 28, 52, 40, (36, 52, 44, 255)), ("rect", 30, 36, 36, 22, gld), ("rect", 30, 46, 36, 4, INK)],
        "furn": [("rect", 18, 30, 60, 40, GREEN), ("rect", 28, 42, 16, 20, gld), ("rect", 50, 38, 16, 24, p)],
        "expand": [("rect", 18, 48, 16, 28, p), ("rect", 40, 34, 16, 42, p), ("rect", 62, 20, 16, 56, gld)],
        "layout": [("rect", 18, 18, 60, 60, (36, 52, 44, 255)), ("rect", 18, 46, 60, 4, gld), ("rect", 46, 18, 4, 60, gld)],
        "money": [("disc", 48, 48, 26, gld), ("disc", 48, 48, 14, (28, 40, 34, 255))],
        "sfx": [("disc", 48, 48, 22, (36, 52, 44, 255)), ("disc", 36, 42, 6, p), ("disc", 60, 42, 6, p), ("rect", 30, 54, 36, 6, gld)],
        "wipe": [("rect", 30, 22, 36, 12, ORANGE), ("rect", 36, 34, 24, 36, ORANGE)],
        "stick": [("disc", 48, 52, 26, (90, 104, 96, 255)), ("disc", 48, 44, 10, gld)],
        "rating": [("tri", 48, 18, 60, 44, 36, 44, gld), ("tri", 48, 78, 36, 52, 60, 52, gld)],
        "tasks": [("rect", 22, 20, 52, 56, (36, 52, 44, 255)), ("rect", 30, 32, 28, 6, gld), ("rect", 30, 44, 36, 6, p), ("rect", 30, 56, 20, 6, ORANGE)],
        "lang": [("disc", 48, 48, 26, TEAL), ("rect", 22, 44, 52, 8, p), ("rect", 44, 24, 8, 48, p)],
    }


def luma16(px, n: int) -> list[float]:
    """4×4 average of a nearest 32×32 (even pixels), grayscale."""
    cells = 4
    step = 8  # 32/4, and we sample every other source pixel
    out = []
    for gy in range(cells):
        for gx in range(cells):
            acc = 0.0
            count = 0
            for y in range(gy * step, (gy + 1) * step, 2):
                for x in range(gx * step, (gx + 1) * step, 2):
                    r, g, b, a = px[y * n + x]
                    if a < 20:
                        continue
                    acc += 0.3 * r + 0.59 * g + 0.11 * b
                    count += 1
            out.append(0.0 if count == 0 else acc / count)
    return out


def check_sku(icons: dict[str, Icon]) -> None:
    grids = {k: luma16(v.px, v.n) for k, v in icons.items()}
    worst = ("", "", 1e9)
    snack_milk = 0.0
    ids = list(grids)
    for i, a in enumerate(ids):
        for b in ids[i + 1 :]:
            d = sum(abs(x - y) for x, y in zip(grids[a], grids[b]))
            if d < worst[2]:
                worst = (a, b, d)
            if {a, b} == {"snack", "milk"}:
                snack_milk = d
    print(f"sku grayscale closest {worst[0]}/{worst[1]} L1={worst[2]:.1f} snack-milk={snack_milk:.1f}")
    if snack_milk < 80 or worst[2] < 40:
        raise SystemExit("SKU icons are too similar at 32px grayscale")


def main() -> None:
    sku_icons = {}
    for sid, fn in SKU.items():
        icon = fn()
        icon.outline()
        icon.save(SKU_DIR / f"{sid}.png")
        sku_icons[sid] = icon
    check_sku(sku_icons)
    for sid, ops in skill_ops().items():
        icon = _draw(64, ops)
        icon.outline()
        icon.save(SKILL_DIR / f"{sid}.png")
    for sid, ops in prep_ops().items():
        icon = _draw(96, ops)
        icon.outline()
        icon.save(PREP_DIR / f"{sid}.png")
    print(f"sku {len(SKU)} skill {len(skill_ops())} prep {len(prep_ops())}")


if __name__ == "__main__":
    main()
