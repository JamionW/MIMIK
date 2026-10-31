"""Assemble each language folder in site/ from the shared app shell in app/.

Every folder site/<code>/ holding a phrases.json is a language. Into each one this writes
index.html and sw.js from app/, plus a manifest.webmanifest naming the language and a
human.json listing which clips have human recordings in audio-human/, and it writes
site/languages.json for the root picker. All of these are build output.

Usage: python scripts/build.py [--version SHA]
--version stamps the service workers (the root one in place) so installs pick up a deploy.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "app"
SITE = ROOT / "site"
# Page backgrounds from app/index.html; the theme is checked against them.
LIGHT_BG, DARK_BG = "#f6f3ee", "#121212"
VERSION_LINE = re.compile(r"^const VERSION = '[^']*';$", re.M)
LANG_LINE = re.compile(r"^const LANG = '[^']*';$", re.M)


def rgb(hex_):
    return tuple(int(hex_[i:i + 2], 16) for i in (1, 3, 5))


def hexa(c):
    return "#" + "".join(f"{round(v):02x}" for v in c)


def mix(a, b, t):
    """Blend colour a toward b by fraction t."""
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def contrast(a, b):
    def lum(c):
        lin = [(v / 255) / 12.92 if v <= 10.3 else (((v / 255) + 0.055) / 1.055) ** 2.4 for v in c]
        return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]
    hi, lo = sorted((lum(a), lum(b)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)


def toward(c, target, against, ratio):
    """Step c toward target until it reaches the contrast ratio against every colour given."""
    for i in range(101):
        out = mix(c, target, i / 100)
        if all(contrast(out, x) >= ratio for x in against):
            return out
    return target


def theme(color):
    """CSS overriding the blue accent tokens with ones built from the language's icon colour.

    Light mode uses the colour itself, darkened if needed so phonetic text on the page and
    white play arrows both stay readable (4.5:1). Dark mode uses a light tint of it, as the
    blue theme does, with a near-black ink of the same hue.
    """
    c = rgb(color)
    white, black = (255, 255, 255), (0, 0, 0)
    light = toward(c, black, [rgb(LIGHT_BG), white], 4.5)
    dark = toward(c, white, [rgb(DARK_BG)], 7)
    tokens = {
        "light": {"accent": light, "accent-ink": white, "tag": mix(c, white, 0.88)},
        "dark": {"accent": dark, "accent-ink": mix(c, black, 0.85), "tag": mix(c, rgb(DARK_BG), 0.82)},
    }
    decl = {k: " ".join(f"--{n}: {hexa(v)};" for n, v in t.items()) for k, t in tokens.items()}
    return f":root {{ {decl['light']} }} @media (prefers-color-scheme: dark) {{ :root {{ {decl['dark']} }} }}"


def stamp(js, version):
    return VERSION_LINE.sub(f"const VERSION = '{version}';", js, count=1)


def main():
    args = sys.argv[1:]
    version = args[args.index("--version") + 1] if "--version" in args else "dev"
    shell = (APP / "index.html").read_text()
    worker = stamp((APP / "sw.js").read_text(), version)

    listing = []
    for phrases in sorted(SITE.glob("*/phrases.json")):
        folder = phrases.parent
        code = folder.name
        data = json.loads(phrases.read_text())
        title = f"Mimik {code.upper()}"
        page = shell.replace("{{TITLE}}", title).replace("{{NAME}}", data["name"]).replace("/*{{THEME}}*/", theme(data["color"]))
        (folder / "index.html").write_text(page)
        (folder / "sw.js").write_text(LANG_LINE.sub(f"const LANG = '{code}';", worker, count=1))
        manifest = {
            "name": f"Mimik: {data['name']}",
            "short_name": title,
            "lang": data["lang"],
            "start_url": "./",
            "scope": "./",
            "display": "standalone",
            "background_color": "#121212",
            "theme_color": "#121212",
            "icons": [
                {"src": "icon-180.png", "sizes": "180x180", "type": "image/png"},
                {"src": "icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any maskable"},
            ],
        }
        (folder / "manifest.webmanifest").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
        # Ids with a human recording, per voice; the app and worker use these in place of the TTS clip.
        human = {g: sorted(p.stem for p in (folder / "audio-human" / sub).glob("*.m4a")) for g, sub in (("m", ""), ("f", "f"))}
        (folder / "human.json").write_text(json.dumps(human, ensure_ascii=False) + "\n")
        listing.append({"code": code, "name": data["name"], "native": data["native"], "color": data["color"]})

    listing.sort(key=lambda l: l["name"])
    (SITE / "languages.json").write_text(json.dumps(listing, indent=2, ensure_ascii=False) + "\n")
    if version != "dev":
        root_sw = SITE / "sw.js"
        root_sw.write_text(stamp(root_sw.read_text(), version))
    print(f"built {len(listing)} languages: {', '.join(l['code'] for l in listing)} ({version})")


main()
