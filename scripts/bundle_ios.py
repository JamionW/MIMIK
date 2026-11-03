"""Copy the phrase files and audio into ios/Generated/ for the iOS app and widget.

ios/Generated/Phrases/ holds languages.json (each language's name, colour, theme accents and
human-recording lists) and <code>.json, a copy of site/<code>/phrases.json; both the app and the
widget bundle it. ios/Generated/Audio/<code>/ holds the clips at the same paths as on the web
(audio/<id>.mp3, audio/f/<id>.mp3, audio-human/...); only the app bundles it.

Clips come from site/<code>/ when the audio has been generated locally. With --fetch URL, any clip
missing locally is downloaded from the deployed site instead (for example
https://jamionw.github.io/MIMIK/), which is how CI gets audio without running edge-tts. A clip
found in neither place is reported, and the app plays that phrase through the device voice.

Usage: python scripts/bundle_ios.py [--fetch URL] [codes ...]
"""
import json
import shutil
import sys
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build import theme_tokens  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / "site"
OUT = ROOT / "ios" / "Generated"


def items(data):
    """Every id with a clip: phrases, regional rows and replies, as app/sw.js lists them."""
    for sec in data["sections"]:
        for p in sec["phrases"]:
            yield p["id"]
            for a in p.get("alt", []):
                yield a["id"]
            for r in p.get("replies", []):
                yield r["id"]


def clip_paths(data, human):
    for i in items(data):
        yield f"audio-human/{i}.m4a" if i in human["m"] else f"audio/{i}.mp3"
        yield f"audio-human/f/{i}.m4a" if i in human["f"] else f"audio/f/{i}.mp3"


def fetch(url, dest):
    try:
        with urllib.request.urlopen(url, timeout=30) as r:
            body = r.read()
    except (urllib.error.URLError, TimeoutError):
        return False
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(body)
    return True


def main():
    args = sys.argv[1:]
    base = None
    if "--fetch" in args:
        i = args.index("--fetch")
        base = args[i + 1].rstrip("/") + "/"
        del args[i:i + 2]
    folders = [p.parent for p in sorted(SITE.glob("*/phrases.json")) if not args or p.parent.name in args]

    phrases_out = OUT / "Phrases"
    shutil.rmtree(phrases_out, ignore_errors=True)
    phrases_out.mkdir(parents=True)
    listing = []
    for folder in folders:
        code = folder.name
        data = json.loads((folder / "phrases.json").read_text())
        # Same rule as scripts/build.py's human.json: a committed .m4a replaces that voice's TTS clip.
        human = {g: sorted(p.stem for p in (folder / "audio-human" / sub).glob("*.m4a")) for g, sub in (("m", ""), ("f", "f"))}
        shutil.copyfile(folder / "phrases.json", phrases_out / f"{code}.json")
        listing.append({
            "code": code, "name": data["name"], "native": data["native"], "color": data["color"],
            "lang": data["lang"], "theme": theme_tokens(data["color"]), "human": human,
        })

        audio_out = OUT / "Audio" / code
        shutil.rmtree(audio_out, ignore_errors=True)
        audio_out.mkdir(parents=True)
        wanted = list(clip_paths(data, {g: set(v) for g, v in human.items()}))
        remote = []
        for rel in wanted:
            src = folder / rel
            if src.exists():
                (audio_out / rel).parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(src, audio_out / rel)
            else:
                remote.append(rel)
        missing = remote
        if base and remote:
            with ThreadPoolExecutor(16) as pool:
                ok = list(pool.map(lambda rel: fetch(f"{base}{code}/{rel}", audio_out / rel), remote))
            missing = [rel for rel, got in zip(remote, ok) if not got]
        print(f"{code}: {len(wanted) - len(missing)}/{len(wanted)} clips"
              + (f", {len(remote) - len(missing)} fetched" if base else "")
              + (f"; missing {', '.join(missing[:5])}{' ...' if len(missing) > 5 else ''}" if missing else ""))

    listing.sort(key=lambda l: l["name"])
    (phrases_out / "languages.json").write_text(json.dumps(listing, indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
