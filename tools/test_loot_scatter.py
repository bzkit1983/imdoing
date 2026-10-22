#!/usr/bin/env python3
"""Checks Tuning.loot_scatter_positions spacing and range rules."""

from __future__ import annotations

import math
import sys

BODY_LENGTH = 26.0
LOOT_SCATTER_MELEE_MIN = 0.55 * BODY_LENGTH
LOOT_SCATTER_MELEE_MAX = 1.75 * BODY_LENGTH
LOOT_SCATTER_DASH_MIN = 2.2 * BODY_LENGTH
LOOT_SCATTER_DASH_MAX = 5.0 * BODY_LENGTH
LOOT_SCATTER_MIN_GAP = 30.0
BOX_SIZE = 4


def loot_scatter_positions(
    origin: tuple[float, float],
    count: int,
    min_r: float,
    max_r: float,
    min_gap: float = LOOT_SCATTER_MIN_GAP,
) -> list[tuple[float, float]]:
    out: list[tuple[float, float]] = []
    if count <= 0:
        return out
    lo = min(min_r, max_r)
    hi = max(min_r, max_r)
    hi = max(hi, lo + 0.01)
    need_r = (min_gap * float(count)) / (2.0 * math.pi)
    if need_r > hi:
        hi = need_r
    golden = math.pi * (3.0 - math.sqrt(5.0))
    ox, oy = origin
    for i in range(count):
        t = (float(i) + 0.55) / float(count)
        r = lo + (hi - lo) * math.sqrt(t)
        ang = float(i) * golden
        px = ox + math.cos(ang) * r
        py = oy + math.sin(ang) * r
        for _pass in range(8):
            pushed = False
            for j, (qx, qy) in enumerate(out):
                dx, dy = px - qx, py - qy
                gap = math.hypot(dx, dy)
                if gap < min_gap:
                    if gap > 0.01:
                        push_x, push_y = dx / gap, dy / gap
                    else:
                        a = ang + float(j)
                        push_x, push_y = math.cos(a), math.sin(a)
                    px = qx + push_x * min_gap
                    py = qy + push_y * min_gap
                    pushed = True
            if not pushed:
                break
            from_o = math.hypot(px - ox, py - oy)
            if from_o > hi * 1.15 and from_o > 0.01:
                s = (hi * 1.15) / from_o
                px = ox + (px - ox) * s
                py = oy + (py - oy) * s
        out.append((px, py))
    return out


def loot_piles_from_cart(cart: list[str]) -> list[dict]:
    groups: dict[str, int] = {}
    for sku in cart:
        groups[sku] = groups.get(sku, 0) + 1
    piles: list[dict] = []
    for sku, total in groups.items():
        left = total
        while left > 0:
            n = min(BOX_SIZE, left)
            piles.append({"sku": sku, "n": n})
            left -= n
    return piles


def main() -> int:
    errors: list[str] = []
    origin = (100.0, 200.0)

    melee = loot_scatter_positions(origin, 6, LOOT_SCATTER_MELEE_MIN, LOOT_SCATTER_MELEE_MAX)
    if len(melee) != 6:
        errors.append("melee count")
    for i in range(len(melee)):
        for j in range(i + 1, len(melee)):
            gap = math.hypot(melee[i][0] - melee[j][0], melee[i][1] - melee[j][1])
            if gap + 1e-3 < LOOT_SCATTER_MIN_GAP:
                errors.append(f"melee overlap {gap:.3f}")

    dash = loot_scatter_positions(origin, 5, LOOT_SCATTER_DASH_MIN, LOOT_SCATTER_DASH_MAX)
    for p in dash:
        d = math.hypot(p[0] - origin[0], p[1] - origin[1])
        if d > LOOT_SCATTER_DASH_MAX * 1.15 + 0.5:
            errors.append(f"dash too far {d}")

    if abs(LOOT_SCATTER_DASH_MAX - 5.0 * BODY_LENGTH) > 0.01:
        errors.append("dash max must be 5 body lengths")

    piles = loot_piles_from_cart(["can", "can", "can", "can", "can", "snack"])
    total = sum(int(p["n"]) for p in piles)
    if total != 6:
        errors.append(f"pile item total {total}")
    if any(int(p["n"]) > BOX_SIZE for p in piles):
        errors.append("pile exceeds box size")

    if errors:
        print("FAIL")
        for e in errors:
            print(" ", e)
        return 1
    print("OK loot scatter positions (melee + dash ≤5 body)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
