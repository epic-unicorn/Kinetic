"""Export brand icon PNG masters (no external SVG renderer required)."""
from __future__ import annotations

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


def draw_k(draw: ImageDraw.ImageDraw, fill: tuple[int, int, int, int] = (255, 255, 255, 255)) -> None:
    # Connected bold K (single silhouette), launcher-like proportions.
    # Stem + joined upper/lower arms as one polygon.
    k = [
        (280, 200),
        (420, 200),
        (420, 430),
        (680, 200),
        (840, 200),
        (530, 512),
        (840, 824),
        (680, 824),
        (420, 594),
        (420, 824),
        (280, 824),
    ]
    draw.polygon(k, fill=fill)


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

    # Square (full-bleed) for flutter_launcher_icons / adaptive icons
    parent_sq = render("logo-parent-1024.png", *parent_c, rounded=False)
    kids_sq = render("logo-kids-1024.png", *kids_c, rounded=False)
    # Rounded for README / in-app headers
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
