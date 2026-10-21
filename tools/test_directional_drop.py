#!/usr/bin/env python3
"""Pure math check for Tuning.drop_offset directional toss rules."""

from __future__ import annotations

import math
import sys

BODY_LENGTH = 26.0
DROP_TOSS_DIST = 2.0 * BODY_LENGTH
DROP_DIR_DEADZONE = 0.35


def drop_offset(toss_dir: tuple[float, float]) -> tuple[float, float]:
    x, y = toss_dir
    if x * x + y * y < 0.0001:
        # In-place uses random jitter in-engine; here we only assert "near feet".
        return (0.0, 22.0)
    length = math.hypot(x, y)
    return (x / length * DROP_TOSS_DIST, y / length * DROP_TOSS_DIST)


def main() -> int:
    errors: list[str] = []
    ox, oy = drop_offset((0.0, 0.0))
    if abs(oy - 22.0) > 0.01:
        errors.append(f"in-place y expected ~22 got {oy}")

    for label, d in [("right", (1, 0)), ("left", (-1, 0)), ("down", (0, 1)), ("up", (0, -1))]:
        x, y = drop_offset(d)
        dist = math.hypot(x, y)
        if abs(dist - DROP_TOSS_DIST) > 0.01:
            errors.append(f"{label} dist {dist} != {DROP_TOSS_DIST}")
        if abs(x - d[0] * DROP_TOSS_DIST) > 0.01 or abs(y - d[1] * DROP_TOSS_DIST) > 0.01:
            errors.append(f"{label} offset {(x, y)} wrong")

    # Diagonal normalizes
    x, y = drop_offset((1.0, 1.0))
    dist = math.hypot(x, y)
    if abs(dist - DROP_TOSS_DIST) > 0.01:
        errors.append(f"diag dist {dist}")

    # Deadzone policy: below threshold treated as no dir by player (_sample), not by drop_offset
    if DROP_DIR_DEADZONE <= 0.0:
        errors.append("deadzone must be positive")

    if errors:
        print("FAIL")
        for e in errors:
            print(" ", e)
        return 1
    print("OK directional drop offsets")
    return 0


if __name__ == "__main__":
    sys.exit(main())
