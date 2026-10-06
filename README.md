# Mimik

A pocket phrasebook for European Portuguese that surfaces the phrases you're likely to need at the current hour, with audio you can play quietly through earbuds. It's a single static page installed to the home screen, and it works offline once loaded.

Live at https://jamionw.github.io/MIMIK/

## What it shows

The clock picks one of four sections (Morning 05:00, Lunch 12:00, Afternoon 15:00, Evening 19:00), and two sections stay below it at all times (Always, Getting around). Tapping another time tab browses it; the app returns to following the clock when the hour bucket changes.

Each card carries the English, the Portuguese, a phonetic respelling (stressed syllable in capitals), a play button, and a slow button at 0.7x speed. Where Lisbon and Porto differ, the regional forms appear as tagged rows with their own audio.

The He / She toggle switches gendered forms (obrigado, obrigada) and the voice. Male clips use Duarte and female clips use Raquel, both neural voices for Portugal. The choice persists on the device.

## Installing on an iPhone

1. Open the live URL in Safari, then Share > Add to Home Screen, with "Open as Web App" left on.
2. Open it from the home screen while online and leave it up for about ten seconds. The home-screen app keeps its own storage, separate from Safari's, so this is the visit that caches the page and both voice sets.
3. Confirm by switching to airplane mode, reopening, and playing a few phrases.

iOS may clear a web app's storage after a few weeks unused; opening it once online refills everything. The home-screen icon is captured at install, so an icon change requires deleting and re-adding the shortcut.

## Editing phrases

All content lives in `site/phrases.json`, and a push to `main` regenerates the audio and redeploys. A phrase looks like this:

```json
{
  "id": "obrigado",
  "en": "Thank you",
  "pt": "Obrigado",
  "ph": "oh-bree-GAH-doo",
  "f": { "pt": "Obrigada", "ph": "oh-bree-GAH-duh" },
  "say": "optional text for the audio when pt contains slashes or ellipses",
  "note": "optional muted footnote",
  "alt": [{ "id": "...", "tag": "Lisbon", "pt": "...", "ph": "..." }]
}
```

Ids must be unique across the file, since they name the audio clips; the generator refuses to run on duplicates. A section with `hours: [start, end]` is time-bound, and a range like `[19, 5]` wraps past midnight. A section without `hours` always shows.

Open the app once online after a deploy so it picks up the new version.

## How the audio works

`scripts/gen_audio.py` renders every phrase in both voices through edge-tts, writing `site/audio/<id>.mp3` and `site/audio/f/<id>.mp3`. The clips are build output and stay out of git. A clip that fails to generate produces a warning in the Actions log without failing the build, and the app covers the gap with the phone's built-in voice (Joana on iOS), which sounds noticeably more robotic.

The service worker (`site/sw.js`) caches the page and every clip at install, and it answers Safari's range requests for audio so playback works offline. The deploy stamps the commit SHA into the worker, which is what triggers a refresh on the next online launch.

## Running locally

```sh
python3 -m http.server -d site 8000
```

Audio requires generating clips first (`pip install edge-tts`, then `python3 scripts/gen_audio.py`); without them the page falls back to the device voice. `python3 scripts/gen_audio.py --dry-run` lists every phrase and its feminine form without touching the network.

## Deployment

`.github/workflows/deploy.yml` runs on every push to `main` and on manual dispatch, generating audio and publishing `site/` to GitHub Pages. The `github-pages` environment allows deploys from `main` only.
