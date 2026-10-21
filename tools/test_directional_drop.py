#!/usr/bin/env python3
"""Pure math check for Tuning.drop_offset directional toss rules."""

from __future__ import annotations

import math
import sys

BODY_LENGTH = 26.0
DROP_TOSS_BODY_LENGTHS = 3.0
DROP_TOSS_DIST = DROP_TOSS_BODY_LENGTHS * BODY_LENGTH
DROP_DIR_DEADZONE = 0.35
DROP_FEET_OFFSET = (0.0, 22.0)


def drop_offset(toss_dir: tuple[float, float], toss_dist: float | None = None) -> tuple[float, float]:
    dist = DROP_TOSS_DIST if toss_dist is None else toss_dist
    x, y = toss_dir
    if x * x + y * y < 0.0001:
        return DROP_FEET_OFFSET
    length = math.hypot(x, y)
    return (x / length * dist, y / length * dist)


def main() -> int:
    errors: list[str] = []
    ox, oy = drop_offset((0.0, 0.0))
    if (ox, oy) != DROP_FEET_OFFSET:
        errors.append(f"in-place expected {DROP_FEET_OFFSET} got {(ox, oy)}")

    if abs(DROP_TOSS_DIST - 3.0 * BODY_LENGTH) > 0.01:
        errors.append("base toss must be 3 body lengths")

    for label, d in [("right", (1, 0)), ("left", (-1, 0)), ("down", (0, 1)), ("up", (0, -1))]:
        x, y = drop_offset(d)
        dist = math.hypot(x, y)
        if abs(dist - DROP_TOSS_DIST) > 0.01:
            errors.append(f"{label} dist {dist} != {DROP_TOSS_DIST}")

    # Skill hook: longer toss_dist
    x, y = drop_offset((1.0, 0.0), toss_dist=5.0 * BODY_LENGTH)
    if abs(x - 5.0 * BODY_LENGTH) > 0.01:
        errors.append("custom toss_dist not applied")

    if DROP_DIR_DEADZONE <= 0.0:
        errors.append("deadzone must be positive")

    if errors:
        print("FAIL")
        for e in errors:
            print(" ", e)
        return 1
    print("OK directional drop offsets (3 body lengths)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
