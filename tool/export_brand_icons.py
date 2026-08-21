"""Export brand icon PNG masters (no external SVG renderer required)."""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / "brand"
SIZE = 1024
RX = 120


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
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            px[x, y] = (*lerp(c0, c1, t), 255)
    return img


def rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def thick_segment(
    draw: ImageDraw.ImageDraw,
    x0: float,
    y0: float,
    x1: float,
    y1: float,
    width: float,
    fill: tuple[int, int, int, int],
) -> None:
    """Axis-aligned square-capped thick line as a parallelogram."""
    dx, dy = x1 - x0, y1 - y0
    length = math.hypot(dx, dy) or 1.0
    ux, uy = dx / length, dy / length
    px, py = -uy * (width / 2.0), ux * (width / 2.0)
    draw.polygon(
        [
            (x0 + px, y0 + py),
            (x1 + px, y1 + py),
            (x1 - px, y1 - py),
            (x0 - px, y0 - py),
        ],
        fill=fill,
    )


def draw_k(draw: ImageDraw.ImageDraw) -> None:
    white = (255, 255, 255, 255)
    # Geometric stroked K with square terminals and a small kinetic gap at the joint.
    thick_segment(draw, 320, 220, 320, 804, 118, white)
    thick_segment(draw, 400, 500, 740, 250, 108, white)
    thick_segment(draw, 400, 524, 740, 774, 108, white)


def render(
    name: str,
    c0: tuple[int, int, int],
    c1: tuple[int, int, int],
    *,
    rounded: bool,
) -> Path:
    bg = gradient_bg(SIZE, c0, c1)
    if rounded:
        mask = rounded_mask(SIZE, RX)
        tile = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        tile.paste(bg, (0, 0), mask)
    else:
        tile = bg
    draw = ImageDraw.Draw(tile)
    draw_k(draw)
    out = BRAND / name
    tile.save(out, "PNG")
    return out


def main() -> None:
    BRAND.mkdir(parents=True, exist_ok=True)
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
