"""Draw each language's home-screen icon: the Mimik tilde on the language's colour.

Reads "color" from each site/<code>/phrases.json and writes icon.svg, icon-180.png and
icon-512.png into that folder. The output is committed, so deploys don't need Pillow;
rerun this after adding a language or changing a colour.

Usage: python scripts/gen_icons.py   (requires: pip install pillow)
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw

SITE = Path(__file__).resolve().parent.parent / "site"
# Same mark as site/icon.svg, in its 100-unit viewBox.
CURVES = [((24, 58), (32, 38), (44, 39), (50, 50)), ((50, 50), (56, 61), (68, 62), (76, 42))]
STROKE = 10
SVG = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <rect width="100" height="100" fill="{color}"/>
  <path d="M24 58 C32 38 44 39 50 50 C56 61 68 62 76 42" fill="none" stroke="#fff" stroke-width="10" stroke-linecap="round"/>
</svg>
"""
SUPERSAMPLE = 4


def bezier(p0, p1, p2, p3, steps=400):
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        yield tuple(u**3 * a + 3 * u * u * t * b + 3 * u * t * t * c + t**3 * d for a, b, c, d in zip(p0, p1, p2, p3))


def png(color, size):
    big = size * SUPERSAMPLE
    k = big / 100
    img = Image.new("RGB", (big, big), color)
    draw = ImageDraw.Draw(img)
    # A wide polyline leaves notches at its joins; stamping round dots densely along the
    # curve gives a clean stroke with round caps.
    r = STROKE * k / 2
    for curve in CURVES:
        for x, y in bezier(*curve):
            draw.ellipse((x * k - r, y * k - r, x * k + r, y * k + r), fill="white")
    return img.resize((size, size), Image.LANCZOS)


def main():
    for phrases in sorted(SITE.glob("*/phrases.json")):
        folder = phrases.parent
        color = json.loads(phrases.read_text())["color"]
        (folder / "icon.svg").write_text(SVG.format(color=color))
        for size in (180, 512):
            png(color, size).save(folder / f"icon-{size}.png", optimize=True)
        print(f"{folder.name}: {color}")


main()
