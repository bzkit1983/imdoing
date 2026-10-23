#!/usr/bin/env python3
"""Assert restock clerks keep walking while a job plan is active."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLERK = ROOT / "godot" / "game" / "scripts" / "clerk.gd"


def main() -> int:
    text = CLERK.read_text(encoding="utf-8")
    m = re.search(r"func _tick_restock\([\s\S]*?\nfunc _find_job", text)
    if not m:
        print("FAIL: missing _tick_restock")
        return 1
    body = m.group(0)
    errs: list[str] = []
    # Cooldown may only gate idle job search, not an active plan follow.
    if "_plan_sku == \"\"" not in body and "_plan_sku == ''" not in body:
        errs.append("_tick_restock must branch on empty _plan_sku before job-search CD")
    # After plan is set, _follow to restock point must still be reachable without
    # requiring another CD wait in the same branch.
    plan_follow = re.search(
        r"_plan_sku == \"\"[\s\S]*?_job_search_cd[\s\S]*?_plan_sku = String"
        r"[\s\S]*?_follow\(",
        body,
    )
    if not plan_follow:
        errs.append("active plan path must call _follow after job search block")
    # Anti-pattern: set CD then immediately require CD before any follow on plan.
    bad = re.search(
        r"_job_search_cd = Tuning\.CLERK_JOB_SEARCH_SEC\s*\n"
        r"\s*var job := _find_job\(\)[\s\S]{0,400}?"
        r"if not _follow\([\s\S]{0,200}?"
        r"_job_search_cd -= delta",
        body,
    )
    if bad:
        errs.append("job-search CD must not interrupt follow after a plan is chosen")
    if errs:
        print("FAIL")
        for e in errs:
            print(" ", e)
        return 1
    print("OK clerk restock follow not gated by job-search CD")
    return 0


if __name__ == "__main__":
    sys.exit(main())
