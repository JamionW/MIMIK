"""Assemble each language folder in site/ from the shared app shell in app/.

Every folder site/<code>/ holding a phrases.json is a language. Into each one this writes
index.html and sw.js from app/, plus a manifest.webmanifest naming the language, and it
writes site/languages.json for the root picker. All of these are build output.

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
VERSION_LINE = re.compile(r"^const VERSION = '[^']*';$", re.M)
LANG_LINE = re.compile(r"^const LANG = '[^']*';$", re.M)


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
        (folder / "index.html").write_text(shell.replace("{{TITLE}}", title).replace("{{NAME}}", data["name"]))
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
                {"src": "../icon-180.png", "sizes": "180x180", "type": "image/png"},
                {"src": "../icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any maskable"},
            ],
        }
        (folder / "manifest.webmanifest").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
        listing.append({"code": code, "name": data["name"], "native": data["native"]})

    listing.sort(key=lambda l: l["name"])
    (SITE / "languages.json").write_text(json.dumps(listing, indent=2, ensure_ascii=False) + "\n")
    if version != "dev":
        root_sw = SITE / "sw.js"
        root_sw.write_text(stamp(root_sw.read_text(), version))
    print(f"built {len(listing)} languages: {', '.join(l['code'] for l in listing)} ({version})")


main()
