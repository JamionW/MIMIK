# Mimik

A pocket phrasebook that surfaces the phrases you're likely to need at the current hour, with audio you can play quietly through earbuds. Each language is a single static page installed to the home screen, and it works offline once loaded.

Live at https://jamionw.github.io/MIMIK/

| Folder | Language | Voices | Icon |
| --- | --- | --- | --- |
| `bs/` | Bosnian | Goran / Vesna | gold |
| `de/` | German | Conrad / Katja | petrol |
| `es/` | Spanish (Mexico) | Jorge / Dalia | purple |
| `fr/` | French (France) | Henri / Denise | navy |
| `ja/` | Japanese | Keita / Nanami | red |
| `nl/` | Dutch | Maarten / Fenna | orange |
| `pt/` | Portuguese (Portugal) | Duarte / Raquel | green |

Each language has its own colour: the tilde icon sits on it, and the page's buttons, phonetics and tags take it on, so it is obvious which language is open. The build derives the light- and dark-mode shades from the one `color` in `phrases.json`, darkening or lightening it where needed to keep text readable. The root picker keeps the original blue and shows each language's colour as a stripe.

The root page is a picker. It forwards to the last language used unless opened as `?pick`, and the language name in each page's header links back to it.

## What it shows

The clock picks one of four sections (Morning, Lunch, Afternoon, Evening, with hours set per language to match local meal times), and two sections stay below it at all times (Always, Getting around). Tapping another time tab browses it; the app returns to following the clock when the hour bucket changes.

Each card carries the English, the phrase, a romanization where the script needs one (Japanese), a phonetic respelling (stressed syllable in capitals; Japanese has no stress, so it stays lowercase), a play button, and a slow button at 0.7x speed. Where regions differ (Lisbon and Porto, Bavaria and Berlin), the regional forms appear as tagged rows with their own audio.

Tapping the text of a card (or of a regional row) opens show mode: the phrase alone, as large as fits the screen, with the screen kept awake, for turning the phone toward a waiter or clerk when pronunciation fails. A tap or swipe closes it.

The He / She toggle switches gendered forms (obrigado, obrigada) and the voice. The choice persists on the device and carries across languages.

## Installing on an iPhone

1. Open the language's page in Safari (for example https://jamionw.github.io/MIMIK/es/), then Share > Add to Home Screen, with "Open as Web App" left on. It installs as "Mimik ES" and holds only that language.
2. Open it from the home screen while online and leave it up until the header's saving count changes to "Offline ready!" (it hides a few seconds later). The home-screen app keeps its own storage, separate from Safari's, so this is the visit that caches the page and both voice sets.
3. Confirm by switching to airplane mode, reopening, and playing a few phrases.

iOS may clear a web app's storage after a few weeks unused. The header then shows how many clips are left (`Offline: 40/98 saved`), and opening it once online refills everything. When nothing is missing, the header shows nothing. The count covers both voices and leaves out clips the deploy failed to generate, since those play through the device voice anyway. The home-screen icon is captured at install, so an icon change requires deleting and re-adding the shortcut.

An install made before the language folders (from the root URL) keeps working: on its first online launch after the update it moves itself to `pt/`, and from then on opens straight into Portuguese. Switching it to another language from the header link works too, but that language is cached offline only after it has been opened once inside the app.

## Editing phrases

Each language's content lives in `site/<code>/phrases.json`, and a push to `main` regenerates the audio and redeploys. The file starts with the language's details:

```json
{
  "name": "Portuguese",
  "native": "Português",
  "color": "#046a38",
  "lang": "pt-PT",
  "voices": { "m": "pt-PT-DuarteNeural", "f": "pt-PT-RaquelNeural" },
  "deviceVoice": "Joana",
  "deviceLangs": ["optional fallback locales for the device voice, e.g. hr-HR for Bosnian"],
  "sections": [ ... ]
}
```

and a phrase looks like this:

```json
{
  "id": "obrigado",
  "en": "Thank you",
  "text": "Obrigado",
  "rom": "optional romanization, shown under text",
  "ph": "oh-bree-GAH-doo",
  "f": { "text": "Obrigada", "ph": "oh-bree-GAH-duh" },
  "say": "optional text for the audio when text contains slashes or ellipses",
  "note": "optional muted footnote",
  "alt": [{ "id": "...", "tag": "Lisbon", "text": "...", "ph": "..." }]
}
```

Ids must be unique within a language, since they name the audio clips; the generator refuses to run on duplicates. A section with `hours: [start, end]` is time-bound, and a range like `[19, 5]` wraps past midnight. A section without `hours` always shows.

Open the app once online after a deploy so it picks up the new version.

To add a language, create `site/<code>/phrases.json` (any edge-tts locale works; `edge-tts --list-voices` lists them), then run `python3 scripts/gen_icons.py` (needs `pip install pillow`) to draw its icons from `color`. The icons are committed; the build picks up the folder and adds it to the picker.

## How the build works

The app shell is shared: `app/index.html` and `app/sw.js`. `scripts/build.py` copies them into every `site/<code>/` folder and writes that folder's `manifest.webmanifest`, plus `site/languages.json` for the picker. All of these are build output and stay out of git.

Each language folder has its own service worker scoped to that folder, so a phone that installs Spanish downloads only Spanish. The root has a small worker of its own that keeps the picker available offline. Cache Storage is shared across the whole site, so every worker names its caches `mimik-<code>-<version>` and only ever deletes its own; updating one language never touches another's audio.

## How the audio works

`scripts/gen_audio.py` renders every phrase in both voices through edge-tts, writing `site/<code>/audio/<id>.mp3` and `site/<code>/audio/f/<id>.mp3`. The clips are build output and stay out of git. A clip that fails to generate produces a warning in the Actions log without failing the build, and the app covers the gap with the phone's built-in voice, which sounds noticeably more robotic.

Each language's worker caches its page and every clip at install, and it answers Safari's range requests for audio so playback works offline. The page asks its worker for a count of cached clips to drive the header's offline badge; when the count is short and the phone is online, the worker refetches what is missing. The deploy stamps the commit SHA into the workers, which is what triggers a refresh on the next online launch.

## Running locally

```sh
python3 scripts/build.py
python3 -m http.server -d site 8000
```

Rerun the build after editing anything in `app/` or adding a language. Audio requires generating clips first (`pip install edge-tts`, then `python3 scripts/gen_audio.py`, optionally followed by language codes such as `es ja`); without them the page falls back to the device voice. `python3 scripts/gen_audio.py --dry-run` lists every phrase and its feminine form without touching the network.

## Deployment

`.github/workflows/deploy.yml` runs on every push to `main` and on manual dispatch, building the language folders, generating audio and publishing `site/` to GitHub Pages. The `github-pages` environment allows deploys from `main` only.
