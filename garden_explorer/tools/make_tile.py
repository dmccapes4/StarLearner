#!/usr/bin/env python3
"""Generate the 512×512 Star Learner tile_garden drawable."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = (
    ROOT.parent
    / "ant_explorer/kiosk_placeholder/app/src/main/res/drawable/tile_garden.png"
)


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    name = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
    return ImageFont.truetype(f"/usr/share/fonts/truetype/dejavu/{name}", size)


def main() -> None:
    image = Image.new("RGB", (512, 512), "#14261a")
    draw = ImageDraw.Draw(image)
    gold = "#ffd14d"
    cream = "#f6f7ff"
    leaf = "#5cc772"
    soil = "#6b4a2e"
    flower = "#e64d7a"
    sky = "#3a7a52"

    draw.rounded_rectangle((24, 24, 488, 488), radius=56, fill="#1d3a28", outline=gold, width=10)
    # Soil bed.
    draw.rounded_rectangle((88, 300, 424, 390), radius=28, fill=soil, outline=gold, width=6)
    # Stems + leaves.
    for x in (168, 256, 344):
        draw.line([(x, 300), (x, 190)], fill=leaf, width=10)
        draw.ellipse((x - 42, 168, x - 4, 214), fill=leaf)
        draw.ellipse((x + 4, 168, x + 42, 214), fill=leaf)
        draw.ellipse((x - 28, 128, x + 28, 184), fill=flower)
        draw.ellipse((x - 12, 144, x + 12, 168), fill=gold)

    # Small sky badge with leaf glyph (no emoji font dependency).
    draw.ellipse((196, 58, 316, 178), fill=sky, outline=gold, width=8)
    draw.polygon([(256, 78), (286, 128), (256, 158), (226, 128)], fill=leaf)
    draw.ellipse((236, 118, 276, 158), fill=gold)

    draw.text((256, 425), "GARDEN", anchor="mm", font=font(48, True), fill=cream)
    draw.text((256, 468), "JARDIN", anchor="mm", font=font(26, True), fill=gold)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUT, optimize=True)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
