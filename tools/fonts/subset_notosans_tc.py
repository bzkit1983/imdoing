#!/usr/bin/env python3
"""Build a game-scoped Noto Sans TC subset for godot/game.

Harvests unique characters from living-line sources, writes charset_game.txt,
then runs pyftsubset. Full source font is downloaded on demand (not shipped).

Usage (from repo root):
  python3 tools/fonts/subset_notosans_tc.py
  python3 tools/fonts/subset_notosans_tc.py --harvest-only
"""

from __future__ import annotations

import argparse
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "godot" / "game"
FONTS = GAME / "fonts"
CHARSET_PATH = FONTS / "charset_game.txt"
OUT_FONT = FONTS / "NotoSansTC-Game.otf"
SOURCE_DIR = FONTS / "source"
SOURCE_FONT = SOURCE_DIR / "NotoSansTC-Regular.otf"

# Preferred local full font (dev machine / existing checkout).
LEGACY_FULL = FONTS / "NotoSansTC-Regular.otf"
# Upstream OFL source (noto-cjk release asset layout may move; override with --source).
SOURCE_URL = (
	"https://raw.githubusercontent.com/notofonts/noto-cjk/"
	"main/Sans/OTF/TraditionalChinese/NotoSansTC-Regular.otf"
)

# Always keep UI / format scaffolding even if not present in string literals yet.
FORCE_CHARS = (
	"0123456789"
	"abcdefghijklmnopqrstuvwxyz"
	"ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	" $%.,:;!?/+-*=<>_#@&|()[]{}'\"`~^\\"
	"，。！？、：；「」『』（）【】…—－·•×÷±℃°／％＄"
	"０１２３４５６７８９"
	"\n\t "
)

STRING_RE = re.compile(
	r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|"""[\s\S]*?"""|\'\'\'[\s\S]*?\'\'\''
)
TEXT_PROP_RE = re.compile(r'^\s*text\s*=\s*"(.*)"\s*$')


def _unescape_gd(s: str) -> str:
	return (
		s.replace("\\n", "\n")
		.replace("\\t", "\t")
		.replace('\\"', '"')
		.replace("\\'", "'")
		.replace("\\\\", "\\")
	)


def harvest_chars() -> str:
	chars: set[str] = set(FORCE_CHARS)
	roots = [
		GAME / "scripts",
		GAME / "scenes",
		GAME / "themes",
	]
	for root in roots:
		if not root.exists():
			continue
		for path in root.rglob("*"):
			if path.suffix not in {".gd", ".tscn", ".tres", ".md", ".txt", ".json"}:
				continue
			try:
				text = path.read_text(encoding="utf-8")
			except UnicodeDecodeError:
				continue
			if path.suffix == ".tscn":
				for line in text.splitlines():
					m = TEXT_PROP_RE.match(line)
					if m:
						chars.update(_unescape_gd(m.group(1)))
			for m in STRING_RE.finditer(text):
				raw = m.group(0)
				if raw.startswith('"""') or raw.startswith("'''"):
					body = raw[3:-3]
				else:
					body = raw[1:-1]
				chars.update(_unescape_gd(body))
	# Stable order: code point ascending, skip pure controls except space/tab/newline already forced.
	ordered = sorted(c for c in chars if ord(c) >= 32 or c in "\n\t")
	return "".join(ordered)


def ensure_source_font() -> Path:
	for candidate in (SOURCE_FONT, LEGACY_FULL):
		if candidate.exists() and candidate.stat().st_size > 1_000_000:
			return candidate
	SOURCE_DIR.mkdir(parents=True, exist_ok=True)
	print(f"Downloading full Noto Sans TC → {SOURCE_FONT}", file=sys.stderr)
	try:
		urllib.request.urlretrieve(SOURCE_URL, SOURCE_FONT)
	except Exception as exc:  # noqa: BLE001 — surface download hints
		raise SystemExit(
			f"Could not download source font ({exc}).\n"
			f"Place NotoSansTC-Regular.otf at {SOURCE_FONT} or pass --source."
		) from exc
	return SOURCE_FONT


def write_charset(text: str) -> None:
	FONTS.mkdir(parents=True, exist_ok=True)
	CHARSET_PATH.write_text(text + "\n", encoding="utf-8")
	print(f"Wrote {CHARSET_PATH} ({len(text)} chars)", file=sys.stderr)


def run_subset(source: Path) -> None:
	# Import here so --harvest-only works without fontTools if needed.
	from fontTools.subset import main as pyftsubset_main

	OUT_FONT.parent.mkdir(parents=True, exist_ok=True)
	args = [
		str(source),
		f"--text-file={CHARSET_PATH}",
		f"--output-file={OUT_FONT}",
		"--layout-features=*",
		"--glyph-names",
		"--symbol-cmap",
		"--legacy-cmap",
		"--notdef-glyph",
		"--notdef-outline",
		"--recommended-glyphs",
		"--name-IDs=*",
		"--name-legacy",
		"--name-languages=*",
	]
	print("fonttools subset", " ".join(args), file=sys.stderr)
	try:
		pyftsubset_main(args)
	except SystemExit as exc:
		if exc.code not in (0, None):
			raise
	if not OUT_FONT.exists():
		raise SystemExit("subset failed: output font missing")
	size = OUT_FONT.stat().st_size
	print(f"Wrote {OUT_FONT} ({size / 1024:.1f} KiB)", file=sys.stderr)


def main() -> int:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--harvest-only", action="store_true")
	parser.add_argument("--source", type=Path, default=None, help="Full NotoSansTC OTF path")
	args = parser.parse_args()
	charset = harvest_chars()
	write_charset(charset)
	if args.harvest_only:
		return 0
	source = args.source if args.source else ensure_source_font()
	if not source.exists():
		print(f"missing source font: {source}", file=sys.stderr)
		return 1
	run_subset(source)
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
