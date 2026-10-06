"""Generate one MP3 per phrase in site/phrases.json using edge-tts.

Usage: python scripts/gen_audio.py [--dry-run] [--force]
Existing clips are skipped unless --force. Failures are reported but not fatal:
the app falls back to the device voice for any missing clip.
"""
import asyncio
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "site"
OUT = ROOT / "audio"


def items(data):
    for sec in data["sections"]:
        for p in sec["phrases"]:
            yield p
            yield from p.get("alt", [])


async def generate(voice, item, force):
    import edge_tts

    dest = OUT / f"{item['id']}.mp3"
    if dest.exists() and dest.stat().st_size and not force:
        return True
    text = item.get("say") or item["pt"]
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
    print(f"::warning::audio failed for {item['id']}: {err}")
    return False


async def main():
    data = json.loads((ROOT / "phrases.json").read_text())
    all_items = list(items(data))
    ids = [i["id"] for i in all_items]
    dupes = {i for i in ids if ids.count(i) > 1}
    if dupes:
        sys.exit(f"duplicate phrase ids: {sorted(dupes)}")
    if "--dry-run" in sys.argv:
        for i in all_items:
            print(f"{i['id']:20} {i.get('say') or i['pt']}")
        return
    OUT.mkdir(exist_ok=True)
    force = "--force" in sys.argv
    sem = asyncio.Semaphore(4)

    async def run(i):
        async with sem:
            return await generate(data["voice"], i, force)

    ok = await asyncio.gather(*(run(i) for i in all_items))
    print(f"{sum(ok)}/{len(ok)} clips ready")


asyncio.run(main())
