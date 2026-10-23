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
# TrueType (glyf) — CFF/OTF subsets often garbble CJK on iOS Safari Web (no system fallback).
OUT_FONT = FONTS / "NotoSansTC-Game.ttf"
OUT_FONT_LEGACY_OTF = FONTS / "NotoSansTC-Game.otf"
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


def _otf_cff_to_ttf(otf_path: Path, ttf_path: Path) -> None:
	"""Convert CFF/OTTO OpenType to TrueType outlines (iOS Safari / FreeType friendly)."""
	from fontTools.pens.cu2quPen import Cu2QuPen
	from fontTools.pens.ttGlyphPen import TTGlyphPen
	from fontTools.ttLib import TTFont, newTable

	font = TTFont(otf_path)
	if font.sfntVersion != "OTTO" or "CFF " not in font:
		font.save(ttf_path)
		return

	glyph_order = font.getGlyphOrder()
	glyphs = font.getGlyphSet()
	quad: dict = {}
	for name in glyph_order:
		pen = TTGlyphPen(glyphs)
		glyphs[name].draw(Cu2QuPen(pen, max_err=1.0, reverse_direction=True))
		quad[name] = pen.glyph()

	font["loca"] = newTable("loca")
	font["glyf"] = glyf = newTable("glyf")
	glyf.glyphOrder = glyph_order
	glyf.glyphs = quad
	del font["CFF "]
	if "VORG" in font:
		del font["VORG"]
	glyf.compile(font)

	hmtx = font["hmtx"]
	for glyph_name, glyph in glyf.glyphs.items():
		if hasattr(glyph, "xMin"):
			hmtx[glyph_name] = (hmtx[glyph_name][0], glyph.xMin)

	font["maxp"] = maxp = newTable("maxp")
	maxp.tableVersion = 0x00010000
	maxp.maxZones = 1
	maxp.maxTwilightPoints = 0
	maxp.maxStorage = 0
	maxp.maxFunctionDefs = 0
	maxp.maxInstructionDefs = 0
	maxp.maxStackElements = 0
	maxp.maxSizeOfInstructions = 0
	maxp.maxComponentElements = max(
		(len(g.components) if hasattr(g, "components") else 0) for g in glyf.glyphs.values()
	)
	maxp.compile(font)

	post = font["post"]
	post.formatType = 2.0
	post.extraNames = []
	post.mapping = {}
	post.glyphOrder = glyph_order
	try:
		post.compile(font)
	except OverflowError:
		post.formatType = 3

	font.sfntVersion = "\x00\x01\x00\x00"
	font.save(ttf_path)


def run_subset(source: Path) -> None:
	# Import here so --harvest-only works without fontTools if needed.
	from fontTools.subset import main as pyftsubset_main

	OUT_FONT.parent.mkdir(parents=True, exist_ok=True)
	tmp_otf = OUT_FONT.with_suffix(".subset.otf")
	args = [
		str(source),
		f"--text-file={CHARSET_PATH}",
		f"--output-file={tmp_otf}",
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
	if not tmp_otf.exists():
		raise SystemExit("subset failed: temp OTF missing")
	try:
		_otf_cff_to_ttf(tmp_otf, OUT_FONT)
	except Exception as exc:  # noqa: BLE001
		raise SystemExit(
			f"OTF→TTF conversion failed ({exc}). Install: pip install fonttools cu2qu"
		) from exc
	finally:
		if tmp_otf.exists():
			tmp_otf.unlink()
	# Drop legacy CFF runtime font so Godot cannot pick the wrong face.
	for legacy in (OUT_FONT_LEGACY_OTF, Path(str(OUT_FONT_LEGACY_OTF) + ".import")):
		if legacy.exists():
			legacy.unlink()
			print(f"Removed legacy {legacy.name}", file=sys.stderr)
	if not OUT_FONT.exists():
		raise SystemExit("subset failed: output TTF missing")
	size = OUT_FONT.stat().st_size
	print(f"Wrote {OUT_FONT} ({size / 1024:.1f} KiB, TrueType)", file=sys.stderr)


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
