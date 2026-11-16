#!/usr/bin/env python3
"""Preview-only shading compare: cartoon vs classic vs outline_only.

Writes PNGs under /opt/cursor/artifacts (and optional --out).
Game bake default is outline_only; this tool still renders all three for QA.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import voxel_sprites as vs  # noqa: E402

VARIANTS = {
    "cartoon": vs.SHADING_CARTOON,
    "classic": vs.SHADING_CLASSIC,
    "outline_only": vs.SHADING_OUTLINE_ONLY,
}

DEFAULT_IDS = ("player_alt3", "customer")
ARTIFACTS = Path("/opt/cursor/artifacts")


def _to_pil(width: int, height: int, image: list) -> Image.Image:
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    img.putdata(image)
    return img


def render_variant(stem: str, params: dict) -> Image.Image:
    path = vs.SRC / f"{stem}.vox"
    size, cells, palette = vs.read_vox(path)
    # Facing 0 (south / front) for readable skin compare.
    rsize, rcells = vs.rotate_facing(size, cells, 0, 16)
    w, h, image = vs.render_display(rsize, rcells, palette, params)
    return _to_pil(w, h, image)


def pad_canvas(img: Image.Image, canvas: tuple[int, int], bg=(245, 245, 248, 255)) -> Image.Image:
    out = Image.new("RGBA", canvas, bg)
    x = (canvas[0] - img.width) // 2
    y = canvas[1] - img.height - 8
    out.alpha_composite(img, (max(0, x), max(0, y)))
    return out


def compose_strip(images: list[Image.Image], labels: list[str], gap: int = 16) -> Image.Image:
    from PIL import ImageDraw, ImageFont

    cell_w = max(im.width for im in images) + gap * 2
    cell_h = max(im.height for im in images) + 36
    strip = Image.new("RGBA", (cell_w * len(images), cell_h), (232, 234, 240, 255))
    draw = ImageDraw.Draw(strip)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 14)
    except OSError:
        font = ImageFont.load_default()
    for i, (im, label) in enumerate(zip(images, labels)):
        cell = pad_canvas(im, (cell_w, cell_h - 28))
        strip.alpha_composite(cell, (i * cell_w, 28))
        draw.text((i * cell_w + 10, 6), label, fill=(30, 30, 36, 255), font=font)
    return strip


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", type=Path, default=ARTIFACTS)
    ap.add_argument("--ids", default=",".join(DEFAULT_IDS))
    args = ap.parse_args()
    out: Path = args.out
    out.mkdir(parents=True, exist_ok=True)
    ids = [s.strip() for s in args.ids.split(",") if s.strip()]

    for stem in ids:
        vox = vs.SRC / f"{stem}.vox"
        if not vox.is_file():
            print(f"skip missing {vox}")
            continue
        imgs = []
        labels = []
        for name, params in VARIANTS.items():
            img = render_variant(stem, params)
            path = out / f"preview_shading_{stem}_{name}.png"
            img.save(path)
            x4 = img.resize((img.width * 4, img.height * 4), Image.NEAREST)
            x4_path = out / f"preview_shading_{stem}_{name}_x4.png"
            x4.save(x4_path)
            print(f"wrote {path} {img.size}; {x4_path} {x4.size}")
            imgs.append(img)
            labels.append(name)
        strip = compose_strip(imgs, labels)
        strip_path = out / f"preview_shading_{stem}_strip.png"
        strip.save(strip_path)
        strip_x4 = strip.resize((strip.width * 4, strip.height * 4), Image.NEAREST)
        strip_x4_path = out / f"preview_shading_{stem}_strip_x4.png"
        strip_x4.save(strip_x4_path)
        print(f"wrote {strip_path} {strip.size}; {strip_x4_path} {strip_x4.size}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
