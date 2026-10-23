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

# Preferred local full fonts (dev machine / frozen demos in this monorepo).
LOCAL_FULL_CANDIDATES = (
	FONTS / "NotoSansTC-Regular.otf",
	SOURCE_DIR / "NotoSansTC-Regular.otf",
	SOURCE_DIR / "NotoSansCJKtc-Regular.otf",
	ROOT / "godot" / "alpha_v0_1" / "fonts" / "NotoSansTC-Regular.otf",
	ROOT / "godot" / "demo_v0_6" / "fonts" / "NotoSansTC-Regular.otf",
)
# Upstream OFL source (path renamed to NotoSansCJKtc-* in noto-cjk).
SOURCE_URL = (
	"https://raw.githubusercontent.com/notofonts/noto-cjk/"
	"main/Sans/OTF/TraditionalChinese/NotoSansCJKtc-Regular.otf"
)

# Always keep UI / format scaffolding even if not present in string literals yet.
FORCE_CHARS = (
	"0123456789"
	"abcdefghijklmnopqrstuvwxyz"
	"ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	" $%.,:;!?/+-*=<>_#@&|()[]{}'\"`~^\\"
	"，。！？、：；「」『』（）【】…—－·•×÷±℃°／％＄"
	"０１２３４５６７８９"
	"▶→←↑↓−＋＝※"
	# Pause / HUD extras that land via Loc before the next harvest cycle.
	"閉項調音量聲點選右上"
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


def _harvest_locale_csv(chars: set[str]) -> None:
	"""Include zh_TW (and key) columns from the runtime Loc table."""
	csv_path = GAME / "locale" / "strings.csv"
	if not csv_path.is_file():
		return
	try:
		text = csv_path.read_text(encoding="utf-8")
	except UnicodeDecodeError:
		return
	# CSV: key,zh_TW,en — take first two fields so Loc.t() CJK is never skipped.
	for i, line in enumerate(text.splitlines()):
		if i == 0 and line.startswith("key"):
			continue
		# Naive split is wrong for quoted commas; pull CJK from the whole line
		# plus the unquoted zh_TW field when simple.
		chars.update(line)
		parts = line.split(",", 2)
		if len(parts) >= 2:
			chars.update(parts[0])
			chars.update(parts[1].strip('"'))


def harvest_chars() -> str:
	chars: set[str] = set(FORCE_CHARS)
	roots = [
		GAME / "scripts",
		GAME / "scenes",
		GAME / "themes",
		GAME / "audio",  # sfx_catalog.txt trigger column
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
			# Plain-text tables (e.g. audio/sfx_catalog.txt) have no quotes.
			if path.suffix == ".txt":
				chars.update(text)
	_harvest_locale_csv(chars)
	# Design-doc trigger column (CJK) — cover SFX copy even before catalog regen.
	doc = ROOT / "docs" / "systemdesign" / "soundeffects.md"
	if doc.is_file():
		try:
			chars.update(doc.read_text(encoding="utf-8"))
		except UnicodeDecodeError:
			pass
	# Stable order: code point ascending, skip pure controls except space/tab/newline already forced.
	ordered = sorted(c for c in chars if ord(c) >= 32 or c in "\n\t")
	return "".join(ordered)


def ensure_source_font() -> Path:
	for candidate in LOCAL_FULL_CANDIDATES:
		if candidate.exists() and candidate.stat().st_size > 1_000_000:
			return candidate
	SOURCE_DIR.mkdir(parents=True, exist_ok=True)
	dest = SOURCE_DIR / "NotoSansCJKtc-Regular.otf"
	print(f"Downloading full Noto Sans TC → {dest}", file=sys.stderr)
	try:
		urllib.request.urlretrieve(SOURCE_URL, dest)
	except Exception as exc:  # noqa: BLE001 — surface download hints
		raise SystemExit(
			f"Could not download source font ({exc}).\n"
			f"Place a full NotoSansTC/NotoSansCJKtc Regular OTF under {SOURCE_DIR} "
			f"or pass --source."
		) from exc
	return dest


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
