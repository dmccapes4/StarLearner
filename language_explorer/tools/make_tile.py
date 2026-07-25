#!/usr/bin/env python3
"""Generate the 512×512 Star Learner tile_language drawable."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = (
    ROOT.parent
    / "ant_explorer/kiosk_placeholder/app/src/main/res/drawable/tile_language.png"
)


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    name = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
    return ImageFont.truetype(f"/usr/share/fonts/truetype/dejavu/{name}", size)


def main() -> None:
    image = Image.new("RGB", (512, 512), "#191f34")
    draw = ImageDraw.Draw(image)
    gold = "#ffd14d"
    cream = "#f6f7ff"
    blue = "#4d8cf2"
    red = "#e64d47"
    green = "#5cc772"

    draw.rounded_rectangle((24, 24, 488, 488), radius=56, fill="#292f4c", outline=gold, width=10)
    # Open book.
    draw.rounded_rectangle((68, 132, 252, 340), radius=24, fill="#f1f1e8", outline=gold, width=7)
    draw.rounded_rectangle((260, 132, 444, 340), radius=24, fill="#f1f1e8", outline=gold, width=7)
    draw.polygon([(252, 146), (260, 146), (260, 348), (256, 362), (252, 348)], fill="#bd9a33")
    for y, color in [(190, red), (236, blue), (282, green)]:
        draw.rounded_rectangle((96, y, 224, y + 18), radius=9, fill=color)
        draw.rounded_rectangle((288, y, 416, y + 18), radius=9, fill=color)

    # Bilingual letter badge.
    draw.ellipse((164, 66, 348, 250), fill="#202642", outline=gold, width=8)
    draw.text((256, 150), "A  Ñ", anchor="mm", font=font(54, True), fill=gold)

    draw.text((256, 395), "WORDS", anchor="mm", font=font(54, True), fill=cream)
    draw.text((256, 447), "PALABRAS", anchor="mm", font=font(29, True), fill=gold)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUT, optimize=True)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
