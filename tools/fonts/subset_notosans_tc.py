#!/usr/bin/env python3
"""Build game-scoped CJK subset fonts for godot/game (zh_TW / zh_CN / ja / en).

Harvests unique characters from living-line sources + all locale CSV columns,
writes charset_game.txt, then runs pyftsubset for Regular / Bold / Black.

Usage (from repo root):
  python3 tools/fonts/subset_notosans_tc.py
  python3 tools/fonts/subset_notosans_tc.py --harvest-only
  python3 tools/fonts/subset_notosans_tc.py --weights regular,bold
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "godot" / "game"
FONTS = GAME / "fonts"
CHARSET_PATH = FONTS / "charset_game.txt"
SOURCE_DIR = FONTS / "source"

# TrueType (glyf) — CFF/OTF subsets often garble CJK on iOS Safari Web.
WEIGHT_SPECS: dict[str, dict[str, object]] = {
	"regular": {
		"out": FONTS / "NotoSansTC-Game.ttf",
		"legacy_otf": FONTS / "NotoSansTC-Game.otf",
		"local": (
			SOURCE_DIR / "NotoSansCJKjp-Regular.otf",
			SOURCE_DIR / "NotoSansCJKtc-Regular.otf",
			SOURCE_DIR / "NotoSansTC-Regular.otf",
			FONTS / "NotoSansTC-Regular.otf",
			ROOT / "godot" / "alpha_v0_1" / "fonts" / "NotoSansTC-Regular.otf",
			ROOT / "godot" / "demo_v0_6" / "fonts" / "NotoSansTC-Regular.otf",
		),
		"url_jp": (
			"https://raw.githubusercontent.com/notofonts/noto-cjk/"
			"main/Sans/OTF/Japanese/NotoSansCJKjp-Regular.otf"
		),
		"url_tc": (
			"https://raw.githubusercontent.com/notofonts/noto-cjk/"
			"main/Sans/OTF/TraditionalChinese/NotoSansCJKtc-Regular.otf"
		),
		"download_jp": SOURCE_DIR / "NotoSansCJKjp-Regular.otf",
		"download_tc": SOURCE_DIR / "NotoSansCJKtc-Regular.otf",
	},
	"bold": {
		"out": FONTS / "NotoSansTC-Game-Bold.ttf",
		"legacy_otf": None,
		"local": (
			SOURCE_DIR / "NotoSansCJKjp-Bold.otf",
			SOURCE_DIR / "NotoSansCJKtc-Bold.otf",
		),
		"url_jp": (
			"https://raw.githubusercontent.com/notofonts/noto-cjk/"
			"main/Sans/OTF/Japanese/NotoSansCJKjp-Bold.otf"
		),
		"url_tc": (
			"https://raw.githubusercontent.com/notofonts/noto-cjk/"
			"main/Sans/OTF/TraditionalChinese/NotoSansCJKtc-Bold.otf"
		),
		"download_jp": SOURCE_DIR / "NotoSansCJKjp-Bold.otf",
		"download_tc": SOURCE_DIR / "NotoSansCJKtc-Bold.otf",
	},
	"black": {
		"out": FONTS / "NotoSansTC-Game-Black.ttf",
		"legacy_otf": None,
		"local": (
			SOURCE_DIR / "NotoSansCJKjp-Black.otf",
			SOURCE_DIR / "NotoSansCJKtc-Black.otf",
		),
		"url_jp": (
			"https://raw.githubusercontent.com/notofonts/noto-cjk/"
			"main/Sans/OTF/Japanese/NotoSansCJKjp-Black.otf"
		),
		"url_tc": (
			"https://raw.githubusercontent.com/notofonts/noto-cjk/"
			"main/Sans/OTF/TraditionalChinese/NotoSansCJKtc-Black.otf"
		),
		"download_jp": SOURCE_DIR / "NotoSansCJKjp-Black.otf",
		"download_tc": SOURCE_DIR / "NotoSansCJKtc-Black.otf",
	},
}

FORCE_CHARS = (
	"0123456789"
	"abcdefghijklmnopqrstuvwxyz"
	"ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	" $%.,:;!?/+-*=<>_#@&|()[]{}'\"`~^\\"
	"，。！？、：；「」『』（）【】…—－·•×÷±℃°／％＄"
	"０１２３４５６７８９"
	"▶→←↑↓−＋＝※"
	"閉項調音量聲點選右上"
	"善良的炮三段火槍陣枪阵銃斉"
	"ぁあぃいぅうぇえぉおかがきぎくぐけげこごさざしじすずせぜそぞただちぢっつづてでとどなにぬねのはばぱひびぴふぶぷへべぺほぼぽまみむめもゃやゅゆょよらりるれろゎわゐゑをんゔゕゖ゛゜ゝゞ"
	"ァアィイゥウェエォオカガキギクグケゲコゴサザシジスズセゼソゾタダチヂッツヅテデトドナニヌネノハバパヒビピフブプヘベペホボポマミムメモャヤュユョヨラリルレロヮワヰヱヲンヴヵヶヷヸヹヺ・ーヽヾ"
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
	locale_dir = GAME / "locale"
	if not locale_dir.is_dir():
		return
	for csv_path in sorted(locale_dir.glob("*.csv")):
		try:
			with csv_path.open(encoding="utf-8", newline="") as f:
				reader = csv.DictReader(f)
				for row in reader:
					for _col, cell in row.items():
						if not cell:
							continue
						if isinstance(cell, list):
							cell = "\n".join(str(x) for x in cell if x)
						else:
							cell = str(cell)
						chars.update(cell.replace("\\n", "\n"))
		except (UnicodeDecodeError, csv.Error):
			try:
				chars.update(csv_path.read_text(encoding="utf-8"))
			except UnicodeDecodeError:
				continue


def harvest_chars() -> str:
	chars: set[str] = set(FORCE_CHARS)
	roots = [
		GAME / "scripts",
		GAME / "scenes",
		GAME / "themes",
		GAME / "audio",
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
			if path.suffix == ".txt":
				chars.update(text)
	_harvest_locale_csv(chars)
	doc = ROOT / "docs" / "systemdesign" / "soundeffects.md"
	if doc.is_file():
		try:
			chars.update(doc.read_text(encoding="utf-8"))
		except UnicodeDecodeError:
			pass
	ordered = sorted(c for c in chars if ord(c) >= 32 or c in "\n\t")
	return "".join(ordered)


def write_charset(text: str) -> None:
	FONTS.mkdir(parents=True, exist_ok=True)
	CHARSET_PATH.write_text(text + "\n", encoding="utf-8")
	print(f"Wrote {CHARSET_PATH} ({len(text)} chars)", file=sys.stderr)


def ensure_source_font(weight: str) -> Path:
	spec = WEIGHT_SPECS[weight]
	for candidate in spec["local"]:  # type: ignore[union-attr]
		cand = Path(candidate)
		if cand.exists() and cand.stat().st_size > 1_000_000:
			return cand
	SOURCE_DIR.mkdir(parents=True, exist_ok=True)
	dest = Path(spec["download_jp"])  # type: ignore[arg-type]
	print(f"Downloading Noto Sans CJK JP {weight} → {dest}", file=sys.stderr)
	if not _download(str(spec["url_jp"]), dest):
		print("JP download failed; trying TC…", file=sys.stderr)
		dest = Path(spec["download_tc"])  # type: ignore[arg-type]
		if not _download(str(spec["url_tc"]), dest):
			raise SystemExit(
				f"Could not download {weight} source font.\n"
				f"Place NotoSansCJKjp-{{Regular|Bold|Black}}.otf under {SOURCE_DIR}."
			)
	return dest


def _download(url: str, dest: Path) -> bool:
	## Prefer curl (macOS Python often lacks certs for urllib).
	import shutil
	import subprocess

	curl = shutil.which("curl")
	if curl:
		try:
			subprocess.run(
				[curl, "-fsSL", "-o", str(dest), url],
				check=True,
			)
			return dest.exists() and dest.stat().st_size > 1_000_000
		except (subprocess.CalledProcessError, OSError) as exc:
			print(f"curl failed: {exc}", file=sys.stderr)
	try:
		urllib.request.urlretrieve(url, dest)
		return dest.exists() and dest.stat().st_size > 1_000_000
	except Exception as exc:  # noqa: BLE001
		print(f"urllib failed: {exc}", file=sys.stderr)
		return False


def _otf_cff_to_ttf(otf_path: Path, ttf_path: Path) -> None:
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


def run_subset(source: Path, out_font: Path, legacy_otf: Path | None = None) -> None:
	from fontTools.subset import main as pyftsubset_main

	out_font.parent.mkdir(parents=True, exist_ok=True)
	tmp_otf = out_font.with_suffix(".subset.otf")
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
		raise SystemExit(f"subset failed: temp OTF missing for {out_font.name}")
	try:
		_otf_cff_to_ttf(tmp_otf, out_font)
	except Exception as exc:  # noqa: BLE001
		raise SystemExit(
			f"OTF→TTF conversion failed ({exc}). Install: pip install fonttools cu2qu"
		) from exc
	finally:
		if tmp_otf.exists():
			tmp_otf.unlink()
	if legacy_otf is not None:
		for legacy in (legacy_otf, Path(str(legacy_otf) + ".import")):
			if legacy.exists():
				legacy.unlink()
				print(f"Removed legacy {legacy.name}", file=sys.stderr)
	if not out_font.exists():
		raise SystemExit(f"subset failed: output TTF missing ({out_font})")
	size = out_font.stat().st_size
	print(f"Wrote {out_font} ({size / 1024:.1f} KiB, TrueType)", file=sys.stderr)


def main() -> int:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--harvest-only", action="store_true")
	parser.add_argument(
		"--weights",
		default="regular,bold,black",
		help="Comma list: regular,bold,black",
	)
	parser.add_argument(
		"--source",
		type=Path,
		default=None,
		help="Override source OTF (applies only when a single weight is requested)",
	)
	args = parser.parse_args()
	charset = harvest_chars()
	write_charset(charset)
	if args.harvest_only:
		return 0
	weights = [w.strip().lower() for w in args.weights.split(",") if w.strip()]
	for w in weights:
		if w not in WEIGHT_SPECS:
			print(f"unknown weight: {w}", file=sys.stderr)
			return 1
	if args.source is not None and len(weights) != 1:
		print("--source requires exactly one --weights entry", file=sys.stderr)
		return 1
	for w in weights:
		spec = WEIGHT_SPECS[w]
		source = args.source if args.source else ensure_source_font(w)
		if not source.exists():
			print(f"missing source font: {source}", file=sys.stderr)
			return 1
		run_subset(source, Path(spec["out"]), spec["legacy_otf"])  # type: ignore[arg-type]
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
