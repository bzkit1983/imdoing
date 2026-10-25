#!/usr/bin/env python3
"""Pure logic check for closeout unsold shelf/floor → warehouse box credit.

Mirrors game_state.credit_unsold_pieces: aggregate pieces by SKU, then
ceil(pieces / BOX_SIZE) boxes returned to stock.
"""

from __future__ import annotations

import math
import sys

BOX_SIZE = 4


def credit_unsold_pieces(stock: dict[str, int], pieces_by_sku: dict[str, int]) -> int:
    total = 0
    for sku, pieces in pieces_by_sku.items():
        if not sku or pieces <= 0:
            continue
        boxes = (pieces + BOX_SIZE - 1) // BOX_SIZE
        stock[sku] = int(stock.get(sku, 0)) + boxes
        total += boxes
    return total


def collect(shelves: list[dict], drops: list[dict], flights: list[dict] | None = None) -> dict[str, int]:
    out: dict[str, int] = {}
    for row in shelves + drops + (flights or []):
        sku = str(row.get("sku", ""))
        n = int(row.get("count", 0))
        if not sku or n <= 0:
            continue
        out[sku] = out.get(sku, 0) + n
    return out


def main() -> int:
    errors: list[str] = []

    # Exact box on shelf → 1 box back
    stock = {"can": 2}
    boxes = credit_unsold_pieces(stock, {"can": 4})
    if boxes != 1 or stock["can"] != 3:
        errors.append(f"exact box {boxes} {stock}")

    # Partial shelf pieces ceil to 1 box
    stock = {"can": 0}
    boxes = credit_unsold_pieces(stock, {"can": 1})
    if boxes != 1 or stock["can"] != 1:
        errors.append(f"ceil remainder {boxes} {stock}")

    # Aggregate shelf+floor before ceil (4×1pc must be 1 box, not 4)
    pieces = collect(
        [{"sku": "can", "count": 1}],
        [{"sku": "can", "count": 1}, {"sku": "can", "count": 1}, {"sku": "can", "count": 1}],
    )
    stock = {"can": 0}
    boxes = credit_unsold_pieces(stock, pieces)
    if pieces["can"] != 4 or boxes != 1 or stock["can"] != 1:
        errors.append(f"aggregate before ceil {pieces} {boxes} {stock}")

    # Multi-SKU + in-flight
    pieces = collect(
        [{"sku": "can", "count": 5}, {"sku": "snack", "count": 2}],
        [{"sku": "snack", "count": 3}],
        [{"sku": "can", "count": 3}],
    )
    stock = {"can": 1, "snack": 0}
    boxes = credit_unsold_pieces(stock, pieces)
    # can: 5+3=8 → 2 boxes; snack: 2+3=5 → 2 boxes
    if pieces != {"can": 8, "snack": 5}:
        errors.append(f"multi collect {pieces}")
    if boxes != 4 or stock != {"can": 3, "snack": 2}:
        errors.append(f"multi credit {boxes} {stock}")

    # Empty → no-op
    stock = {"can": 7}
    boxes = credit_unsold_pieces(stock, {})
    if boxes != 0 or stock["can"] != 7:
        errors.append("empty credit changed stock")

    # math.ceil equivalence check
    for n in range(0, 17):
        got = (n + BOX_SIZE - 1) // BOX_SIZE if n > 0 else 0
        want = int(math.ceil(n / BOX_SIZE)) if n > 0 else 0
        if got != want:
            errors.append(f"ceil formula {n}: {got}!={want}")

    if errors:
        print("FAIL")
        for e in errors:
            print(" ", e)
        return 1
    print("OK unsold shelf/floor → warehouse credit rules")
    return 0


if __name__ == "__main__":
    sys.exit(main())
