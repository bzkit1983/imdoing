#!/usr/bin/env python3
"""Pure logic: after skill-dir mode ends, move stays locked until stick neutral."""

from __future__ import annotations

import sys

DEADZONE = 0.25


def move_axis(
    *,
    in_dir_mode: bool,
    locked: bool,
    stick_len: float,
) -> tuple[bool, bool]:
    """Return (allow_move, locked_after)."""
    if in_dir_mode:
        return False, True
    if locked:
        if stick_len < DEADZONE:
            return True, False
        return False, True
    return True, False


def main() -> int:
    errors: list[str] = []

    allow, locked = move_axis(in_dir_mode=True, locked=False, stick_len=1.0)
    if allow or not locked:
        errors.append("dir mode must block and arm lock")

    # Menu closed but W still held
    allow, locked = move_axis(in_dir_mode=False, locked=True, stick_len=1.0)
    if allow or not locked:
        errors.append("held key after menu must stay locked")

    # Release keys
    allow, locked = move_axis(in_dir_mode=False, locked=True, stick_len=0.0)
    if not allow or locked:
        errors.append("neutral must clear lock")

    # Normal walk
    allow, locked = move_axis(in_dir_mode=False, locked=False, stick_len=0.8)
    if not allow or locked:
        errors.append("normal move must allow")

    if errors:
        print("FAIL")
        for e in errors:
            print(" ", e)
        return 1
    print("OK skill-menu move lock until neutral")
    return 0


if __name__ == "__main__":
    sys.exit(main())
