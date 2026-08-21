"""Export brand icon PNG masters: classic launcher k as clean geometry."""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / "brand"
SIZE = 1024
RX = 225

# Classic 48×48 launcher glyph. Stem width == arm stroke width.
STEM = (15.0, 12.0, 20.0, 37.0)  # x0,y0,x1,y1  → width 5
STEM_W = STEM[2] - STEM[0]  # 5
# Diagonals read thinner than verticals; slight optical boost so they match by eye.
STROKE = STEM_W * 1.12
# Centerlines: start inside stem so the join reads as one letter; tips near ref.
UPPER = ((17.5, 22.5), (32.0, 14.0))
LOWER = ((17.5, 25.5), (32.0, 34.0))


def lerp(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))  # type: ignore[return-value]


def gradient_bg(
    size: int,
    c0: tuple[int, int, int],
    c1: tuple[int, int, int],
) -> Image.Image:
    img = Image.new("RGBA", (size, size))
    px = img.load()
    assert px is not None
    denom = 2 * (size - 1)
    table = [lerp(c0, c1, i / denom) for i in range(denom + 1)]
    for y in range(size):
        for x in range(size):
            px[x, y] = (*table[x + y], 255)
    return img


def rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def parallelogram(
    p0: tuple[float, float],
    p1: tuple[float, float],
    width: float,
) -> list[tuple[float, float]]:
    x0, y0 = p0
    x1, y1 = p1
    dx, dy = x1 - x0, y1 - y0
    length = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / length * width / 2, dx / length * width / 2
    return [
        (x0 + nx, y0 + ny),
        (x1 + nx, y1 + ny),
        (x1 - nx, y1 - ny),
        (x0 - nx, y0 - ny),
    ]


def draw_k(draw: ImageDraw.ImageDraw, size: int = SIZE) -> None:
    s = size / 48.0
    white = (255, 255, 255, 255)
    x0, y0, x1, y1 = STEM
    draw.rectangle((x0 * s, y0 * s, x1 * s - 1e-3, y1 * s - 1e-3), fill=white)
    for p0, p1 in (UPPER, LOWER):
        draw.polygon([(x * s, y * s) for x, y in parallelogram(p0, p1, STROKE)], fill=white)


def render(
    name: str,
    c0: tuple[int, int, int],
    c1: tuple[int, int, int],
    *,
    rounded: bool,
) -> Path:
    aa = 3
    big = SIZE * aa
    bg = gradient_bg(big, c0, c1)
    if rounded:
        mask = rounded_mask(big, RX * aa)
        tile = Image.new("RGBA", (big, big), (0, 0, 0, 0))
        tile.paste(bg, (0, 0), mask)
    else:
        tile = bg
    draw_k(ImageDraw.Draw(tile), size=big)
    out = BRAND / name
    tile.resize((SIZE, SIZE), Image.Resampling.LANCZOS).save(out, "PNG")
    return out


def write_svgs() -> None:
    x0, y0, x1, y1 = STEM

    def arm_d(p0: tuple[float, float], p1: tuple[float, float]) -> str:
        pts = parallelogram(p0, p1, STROKE)
        return "M" + " L".join(f"{x:g},{y:g}" for x, y in pts) + " Z"

    body = f"""  <rect x="{x0:g}" y="{y0:g}" width="{x1 - x0:g}" height="{y1 - y0:g}" fill="#FFFFFF"/>
  <path fill="#FFFFFF" d="{arm_d(*UPPER)}"/>
  <path fill="#FFFFFF" d="{arm_d(*LOWER)}"/>"""
    parent = f"""<!-- Kinetic Link — classic launcher k (stem + arms same stroke). -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" role="img" aria-label="Kinetic Link">
  <title>Kinetic Link</title>
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#3B82F6"/>
      <stop offset="100%" stop-color="#2563EB"/>
    </linearGradient>
  </defs>
  <rect width="48" height="48" rx="10.5" fill="url(#bg)"/>
{body}
</svg>
"""
    kids = parent.replace("Kinetic Link", "Kinetic Kids").replace("#3B82F6", "#F97316").replace(
        "#2563EB", "#EC4899"
    )
    (BRAND / "logo-parent.svg").write_text(parent, encoding="utf-8")
    (BRAND / "logo-kids.svg").write_text(kids, encoding="utf-8")


def main() -> None:
    BRAND.mkdir(parents=True, exist_ok=True)
    write_svgs()
    parent_c = ((0x3B, 0x82, 0xF6), (0x25, 0x63, 0xEB))
    kids_c = ((0xF9, 0x73, 0x16), (0xEC, 0x48, 0x99))

    parent_sq = render("logo-parent-1024.png", *parent_c, rounded=False)
    kids_sq = render("logo-kids-1024.png", *kids_c, rounded=False)
    render("logo-parent-1024-rounded.png", *parent_c, rounded=True)
    render("logo-kids-1024-rounded.png", *kids_c, rounded=True)

    for src_name, dest_name in (
        ("logo-parent-1024-rounded.png", "logo-parent-512.png"),
        ("logo-kids-1024-rounded.png", "logo-kids-512.png"),
    ):
        Image.open(BRAND / src_name).resize((512, 512), Image.Resampling.LANCZOS).save(
            BRAND / dest_name, "PNG"
        )
    print("wrote", parent_sq.name, kids_sq.name)


if __name__ == "__main__":
    main()
