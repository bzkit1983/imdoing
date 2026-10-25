#!/usr/bin/env python3
"""Pure logic check for closeout unsold goods → warehouse box credit.

Mirrors game_state.credit_unsold_pieces + demo collection sources:
shelves, floor/flights, player carry, clerk held, unpaid completed carts.
Aggregate pieces by SKU, then ceil(pieces / BOX_SIZE) boxes to stock.
"""

from __future__ import annotations

import math
import sys

BOX_SIZE = 4

# customer.gd State enum indices
TO_CASHIER = 4
QUEUE = 5
PAYING = 6
LEAVE = 7


def credit_unsold_pieces(stock: dict[str, int], pieces_by_sku: dict[str, int]) -> int:
    total = 0
    for sku, pieces in pieces_by_sku.items():
        if not sku or pieces <= 0:
            continue
        boxes = (pieces + BOX_SIZE - 1) // BOX_SIZE
        stock[sku] = int(stock.get(sku, 0)) + boxes
        total += boxes
    return total


def add_pieces(dst: dict[str, int], src: dict[str, int]) -> None:
    for sku, n in src.items():
        if n <= 0:
            continue
        dst[sku] = dst.get(sku, 0) + n


def collect_rows(rows: list[dict]) -> dict[str, int]:
    out: dict[str, int] = {}
    for row in rows:
        sku = str(row.get("sku", ""))
        n = int(row.get("count", 0))
        if not sku or n <= 0:
            continue
        out[sku] = out.get(sku, 0) + n
    return out


def collect_player_carry(items: list[str]) -> dict[str, int]:
    out: dict[str, int] = {}
    for sku in items:
        if not sku:
            continue
        out[sku] = out.get(sku, 0) + 1
    return out


def collect_clerk_held(clerks: list[dict]) -> dict[str, int]:
    out: dict[str, int] = {}
    for c in clerks:
        if str(c.get("role", "")) != "restock":
            continue
        sku = str(c.get("_box_sku", ""))
        n = int(c.get("_box_n", 0))
        if not sku or n <= 0:
            continue
        out[sku] = out.get(sku, 0) + n
    return out


def unsold_checkout_cart(guest: dict) -> list[str]:
    """Mirror customer.unsold_checkout_cart after finish_paid clears cart."""
    if guest.get("is_thief"):
        return []
    shopping = guest.get("shopping") or []
    cart = guest.get("cart") or []
    if shopping or not cart:
        return []
    # Paid guests clear cart in finish_paid before LEAVE.
    if guest.get("paid"):
        return []
    return list(cart)


def collect_unpaid_checkouts(guests: list[dict]) -> dict[str, int]:
    out: dict[str, int] = {}
    for g in guests:
        for sku in unsold_checkout_cart(g):
            out[sku] = out.get(sku, 0) + 1
    return out


def collect_all(
    shelves: list[dict] | None = None,
    drops: list[dict] | None = None,
    flights: list[dict] | None = None,
    player_items: list[str] | None = None,
    clerks: list[dict] | None = None,
    guests: list[dict] | None = None,
) -> dict[str, int]:
    out: dict[str, int] = {}
    add_pieces(out, collect_rows((shelves or []) + (drops or []) + (flights or [])))
    add_pieces(out, collect_player_carry(player_items or []))
    add_pieces(out, collect_clerk_held(clerks or []))
    add_pieces(out, collect_unpaid_checkouts(guests or []))
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
    pieces = collect_all(
        shelves=[{"sku": "can", "count": 1}],
        drops=[
            {"sku": "can", "count": 1},
            {"sku": "can", "count": 1},
            {"sku": "can", "count": 1},
        ],
    )
    stock = {"can": 0}
    boxes = credit_unsold_pieces(stock, pieces)
    if pieces["can"] != 4 or boxes != 1 or stock["can"] != 1:
        errors.append(f"aggregate before ceil {pieces} {boxes} {stock}")

    # Player carry + clerk held
    pieces = collect_all(
        player_items=["can", "can", "snack"],
        clerks=[
            {"role": "restock", "_box_sku": "can", "_box_n": 2},
            {"role": "cashier", "_box_sku": "can", "_box_n": 4},  # ignored
        ],
    )
    if pieces != {"can": 4, "snack": 1}:
        errors.append(f"carry/clerk {pieces}")

    # Unpaid completed checkout → return; mid-shop / paid / thief skip
    pieces = collect_all(
        guests=[
            {
                "is_thief": False,
                "shopping": [],
                "cart": ["can", "snack"],
                "state": QUEUE,
                "paid": False,
            },
            {
                "is_thief": False,
                "shopping": ["can"],
                "cart": ["snack"],
                "state": 1,
                "paid": False,
            },  # list not done
            {
                "is_thief": False,
                "shopping": [],
                "cart": [],
                "state": LEAVE,
                "paid": True,
            },  # paid cleared
            {
                "is_thief": True,
                "shopping": [],
                "cart": ["can", "can"],
                "state": LEAVE,
                "paid": False,
            },
            {
                "is_thief": False,
                "shopping": [],
                "cart": ["can"],
                "state": TO_CASHIER,
                "paid": False,
            },
            {
                "is_thief": False,
                "shopping": [],
                "cart": ["snack", "snack"],
                "state": PAYING,
                "paid": False,
            },
        ]
    )
    if pieces != {"can": 2, "snack": 3}:
        errors.append(f"unpaid checkout {pieces}")

    # Combined sources then credit
    pieces = collect_all(
        shelves=[{"sku": "can", "count": 3}],
        player_items=["can"],
        clerks=[{"role": "restock", "_box_sku": "snack", "_box_n": 4}],
        guests=[
            {
                "is_thief": False,
                "shopping": [],
                "cart": ["snack"],
                "state": QUEUE,
                "paid": False,
            }
        ],
    )
    stock = {"can": 0, "snack": 1}
    boxes = credit_unsold_pieces(stock, pieces)
    # can: 3+1=4 → 1; snack: 4+1=5 → 2
    if pieces != {"can": 4, "snack": 5}:
        errors.append(f"combined collect {pieces}")
    if boxes != 3 or stock != {"can": 1, "snack": 3}:
        errors.append(f"combined credit {boxes} {stock}")

    # Empty → no-op
    stock = {"can": 7}
    boxes = credit_unsold_pieces(stock, {})
    if boxes != 0 or stock["can"] != 7:
        errors.append("empty credit changed stock")

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
    print("OK unsold return (shelf/floor/carry/clerk/unpaid-checkout)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
