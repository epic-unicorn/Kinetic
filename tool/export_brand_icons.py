"""Export brand icon PNG masters matching the classic header K."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / "brand"
SIZE = 1024
RX = 225  # ~22% like original logo-mark
STROKE = 92


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


def draw_k(draw: ImageDraw.ImageDraw) -> None:
    """Classic Kinetic K: round-capped stem + chevron arms meeting at mid-stem."""
    white = (255, 255, 255, 255)
    r = STROKE // 2
    # Caps at all terminals + joint
    for cx, cy in (
        (307, 246),
        (307, 778),
        (307, 512),
        (676, 246),
        (676, 778),
    ):
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=white)
    draw.line([(307, 246), (307, 778)], fill=white, width=STROKE)
    draw.line([(307, 512), (676, 246)], fill=white, width=STROKE)
    draw.line([(307, 512), (676, 778)], fill=white, width=STROKE)


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
