#!/usr/bin/env python3
"""List CJK string literals in godot/game that are not yet Loc keys in locale/strings.csv.

Usage (repo root):
  python3 tools/i18n_harvest.py
  python3 tools/i18n_harvest.py --json > /tmp/i18n_todo.json
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]  # repo root (file lives in tools/)
GAME = ROOT / "godot" / "game"
CSV_PATH = GAME / "locale" / "strings.csv"
SCRIPTS = GAME / "scripts"
SCENES = GAME / "scenes"

STRING_RE = re.compile(
	r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\''
)
CJK_RE = re.compile(r"[\u4e00-\u9fff]")


def load_keys() -> set[str]:
	if not CSV_PATH.exists():
		return set()
	keys: set[str] = set()
	with CSV_PATH.open(encoding="utf-8", newline="") as f:
		reader = csv.DictReader(f)
		for row in reader:
			k = (row.get("key") or "").strip()
			if k:
				keys.add(k)
			# Also treat zh_TW values as "covered" for fuzzy reporting
			zh = (row.get("zh_TW") or "").replace("\\n", "\n")
			if zh:
				keys.add(zh)
	return keys


def unescape(s: str) -> str:
	return (
		s.replace("\\n", "\n")
		.replace("\\t", "\t")
		.replace('\\"', '"')
		.replace("\\'", "'")
		.replace("\\\\", "\\")
	)


def harvest() -> list[dict]:
	known = load_keys()
	hits: list[dict] = []
	seen: set[str] = set()
	for root in (SCRIPTS, SCENES):
		if not root.exists():
			continue
		for path in sorted(root.rglob("*")):
			if path.suffix not in {".gd", ".tscn"}:
				continue
			text = path.read_text(encoding="utf-8")
			rel = str(path.relative_to(GAME))
			for m in STRING_RE.finditer(text):
				raw = m.group(0)
				body = unescape(raw[1:-1])
				if not CJK_RE.search(body):
					continue
				if body in known or body in seen:
					continue
				# Skip Loc.t("key") keys themselves (no CJK usually)
				seen.add(body)
				line_no = text.count("\n", 0, m.start()) + 1
				hits.append({"file": rel, "line": line_no, "text": body})
	return hits


def main() -> int:
	ap = argparse.ArgumentParser(description=__doc__)
	ap.add_argument("--json", action="store_true")
	args = ap.parse_args()
	hits = harvest()
	if args.json:
		json.dump(hits, sys.stdout, ensure_ascii=False, indent=2)
		sys.stdout.write("\n")
	else:
		print(f"{len(hits)} CJK literals not in locale/strings.csv (zh_TW or key)", file=sys.stderr)
		for h in hits[:80]:
			preview = h["text"].replace("\n", "\\n")
			if len(preview) > 72:
				preview = preview[:69] + "..."
			print(f"{h['file']}:{h['line']}: {preview}")
		if len(hits) > 80:
			print(f"... and {len(hits) - 80} more", file=sys.stderr)
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
