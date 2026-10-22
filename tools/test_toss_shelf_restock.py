#!/usr/bin/env python3
"""Pure logic check for directional toss → shelf restock remainder rules."""

from __future__ import annotations

import sys


def restock(box_n: int, shelf_space: int) -> tuple[int, int]:
    """Return (placed, leftover on floor)."""
    if box_n <= 0 or shelf_space <= 0:
        return 0, max(0, box_n)
    placed = min(box_n, shelf_space)
    return placed, box_n - placed


def main() -> int:
    errors: list[str] = []

    p, left = restock(4, 4)
    if (p, left) != (4, 0):
        errors.append(f"exact fill {p},{left}")

    p, left = restock(4, 2)
    if (p, left) != (2, 2):
        errors.append(f"partial {p},{left}")

    p, left = restock(4, 0)
    if (p, left) != (0, 4):
        errors.append(f"full shelf {p},{left}")

    p, left = restock(1, 10)
    if (p, left) != (1, 0):
        errors.append(f"box empties {p},{left}")

    # Feet drop / no matching shelf: whole box on floor (placed 0)
    p, left = restock(4, 0)
    if left != 4:
        errors.append("no-shelf must leave full box")

    if errors:
        print("FAIL")
        for e in errors:
            print(" ", e)
        return 1
    print("OK toss shelf restock remainder rules")
    return 0


if __name__ == "__main__":
    sys.exit(main())
