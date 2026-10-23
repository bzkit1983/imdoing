#!/usr/bin/env python3
"""Assert Alpha SFX catalog, wavs, and doc IDs stay aligned."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / "docs" / "systemdesign" / "soundeffects.md"
WAV_DIR = ROOT / "godot" / "game" / "audio" / "sfx"
CATALOG_GD = ROOT / "godot" / "game" / "scripts" / "sfx_catalog.gd"
CATALOG_TXT = ROOT / "godot" / "game" / "audio" / "sfx_catalog.txt"


def doc_ids() -> set[str]:
    text = DOC.read_text(encoding="utf-8")
    return set(re.findall(r"`(sfx_[a-z0-9_]+)`", text))


def gd_ids() -> set[str]:
    text = CATALOG_GD.read_text(encoding="utf-8")
    return set(re.findall(r'"id": "(sfx_[a-z0-9_]+)"', text))


def wav_ids() -> set[str]:
    return {p.stem for p in WAV_DIR.glob("sfx_*.wav")}


def main() -> int:
    d, g, w = doc_ids(), gd_ids(), wav_ids()
    errs: list[str] = []
    if d - g:
        errs.append(f"in doc missing from catalog.gd: {sorted(d - g)}")
    if g - d:
        errs.append(f"in catalog.gd missing from doc: {sorted(g - d)}")
    if g - w:
        errs.append(f"catalog without wav: {sorted(g - w)}")
    if w - g:
        errs.append(f"wav without catalog: {sorted(w - g)}")
    if not CATALOG_TXT.is_file():
        errs.append("missing audio/sfx_catalog.txt")
    if errs:
        print("FAIL")
        for e in errs:
            print(" ", e)
        return 1
    print(f"OK {len(g)} SFX ids aligned (doc/catalog/wav)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
