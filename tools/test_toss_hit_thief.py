#!/usr/bin/env python3
"""Pure logic checks for directional toss → thief hit / inplace loot."""

from __future__ import annotations

import math
import sys


DROP_THIEF_HIT_RADIUS = 72.0
LOOT_INPLACE_MAX = 0.35 * 26.0


def dist_point_to_segment(p: tuple[float, float], a: tuple[float, float], b: tuple[float, float]) -> float:
    ax, ay = a
    bx, by = b
    px, py = p
    abx, aby = bx - ax, by - ay
    len_sq = abx * abx + aby * aby
    if len_sq < 1e-8:
        return math.hypot(px - ax, py - ay)
    t = ((px - ax) * abx + (py - ay) * aby) / len_sq
    t = max(0.0, min(1.0, t))
    qx, qy = ax + abx * t, ay + aby * t
    return math.hypot(px - qx, py - qy)


def thief_hit(
    from_p: tuple[float, float],
    dest: tuple[float, float],
    thieves: list[tuple[float, float]],
    radius: float = DROP_THIEF_HIT_RADIUS,
) -> int | None:
    """Return index of nearest thief within radius of path/landing, else None."""
    best_i: int | None = None
    best_d = radius
    for i, p in enumerate(thieves):
        d = min(dist_point_to_segment(p, from_p, dest), math.hypot(dest[0] - p[0], dest[1] - p[1]))
        if d <= best_d:
            best_d = d
            best_i = i
    return best_i


def main() -> int:
    errors: list[str] = []

    # Mid-path hit
    hit = thief_hit((0, 0), (130, 0), [(65, 20)])
    if hit != 0:
        errors.append(f"mid-path should hit, got {hit}")

    # Far off path miss
    hit = thief_hit((0, 0), (130, 0), [(65, 100)])
    if hit is not None:
        errors.append(f"far thief should miss, got {hit}")

    # Landing near thief
    hit = thief_hit((0, 0), (100, 0), [(105, 10)])
    if hit != 0:
        errors.append(f"landing near should hit, got {hit}")

    # Nearest of two
    hit = thief_hit((0, 0), (100, 0), [(200, 0), (50, 10)])
    if hit != 1:
        errors.append(f"nearest should be index 1, got {hit}")

    # Feet drop (zero toss) never uses this path — simulate no directional
    # by requiring caller to skip when toss_dir ~ 0 (documented contract).
    if LOOT_INPLACE_MAX > 20.0:
        errors.append(f"inplace ring too wide: {LOOT_INPLACE_MAX}")

    # Priority: thief before shelf — if hit index found, shelf skipped
    hit = thief_hit((0, 0), (80, 0), [(80, 0)])
    shelf_would_apply = hit is None
    if shelf_would_apply:
        errors.append("thief at landing must win over shelf")

    if errors:
        print("FAIL")
        for e in errors:
            print(" ", e)
        return 1
    print("OK toss hit thief path / inplace loot rules")
    return 0


if __name__ == "__main__":
    sys.exit(main())
