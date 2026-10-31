"""Generate one MP3 per phrase and voice in each site/<code>/phrases.json using edge-tts.

Masculine clips go to site/<code>/audio/<id>.mp3, feminine to site/<code>/audio/f/<id>.mp3;
a phrase's "f" object overrides its text for the feminine voice.

Usage: python scripts/gen_audio.py [--dry-run] [--force] [code ...]
With language codes (pt es ...) only those languages are generated.
Existing clips are skipped unless --force. Failures are reported but not fatal:
the app falls back to the device voice for any missing clip.
"""
import asyncio
import json
import sys
from pathlib import Path

SITE = Path(__file__).resolve().parent.parent / "site"


def items(data):
    for sec in data["sections"]:
        for p in sec["phrases"]:
            yield p
            yield from p.get("alt", [])


async def generate(out, voice, item, force, gender):
    import edge_tts

    if gender == "f":
        item = {**item, **item.get("f", {})}
    dest = (out / "f" if gender == "f" else out) / f"{item['id']}.mp3"
    if dest.exists() and dest.stat().st_size and not force:
        return True
    text = item.get("say") or item["text"]
    err = "empty file"
    for attempt in range(3):
        try:
            await edge_tts.Communicate(text, voice).save(str(dest))
            if dest.stat().st_size:
                return True
        except Exception as e:
            err = e
            await asyncio.sleep(2 ** attempt)
    dest.unlink(missing_ok=True)
    print(f"::warning::audio failed for {out.parent.name}/{gender}/{item['id']}: {err}")
    return False


async def main():
    codes = [a for a in sys.argv[1:] if not a.startswith("--")]
    langs = {}
    for path in sorted(SITE.glob("*/phrases.json")):
        if codes and path.parent.name not in codes:
            continue
        data = json.loads(path.read_text())
        all_items = list(items(data))
        ids = [i["id"] for i in all_items]
        dupes = {i for i in ids if ids.count(i) > 1}
        if dupes:
            sys.exit(f"{path.parent.name}: duplicate phrase ids: {sorted(dupes)}")
        langs[path.parent] = (data, all_items)
    if not langs:
        sys.exit(f"no languages matched {codes}")
    if "--dry-run" in sys.argv:
        for folder, (data, all_items) in langs.items():
            print(f"== {folder.name}  {data['voices']['m']} / {data['voices']['f']}")
            for i in all_items:
                f = {**i, **i.get("f", {})}
                print(f"{i['id']:20} {i.get('say') or i['text']}  |  {f.get('say') or f['text']}")
        return
    force = "--force" in sys.argv
    sem = asyncio.Semaphore(4)

    async def run(out, data, i, g):
        async with sem:
            return await generate(out, data["voices"][g], i, force, g)

    jobs = []
    for folder, (data, all_items) in langs.items():
        out = folder / "audio"
        (out / "f").mkdir(parents=True, exist_ok=True)
        jobs += [run(out, data, i, g) for g in ("m", "f") for i in all_items]
    ok = await asyncio.gather(*jobs)
    print(f"{sum(ok)}/{len(ok)} clips ready")


asyncio.run(main())
