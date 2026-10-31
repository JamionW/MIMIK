# Feature list

Planned enhancements, in priority order. Work from the top unless there is a reason not to. When a feature ships, change its status and add the commit or PR; when priorities change, reorder the list in place rather than starting a new one.

Status values: `planned`, `in progress`, `done`, `dropped`.

| # | Feature | Status |
| --- | --- | --- |
| 1 | Offline-ready indicator | done (branch `claude/stoic-cori-vgqowh`) |
| 2 | Show mode | done (branch `claude/stoic-cori-vgqowh`) |
| 3 | Lock-screen and earbud controls | done (branch `claude/stoic-cori-vgqowh`) |
| 4 | "What you'll hear" replies | planned |
| 5 | Search across sections | planned |
| 6 | Phrase linter in CI | planned |
| 7 | Human recordings override TTS | planned |
| 8 | Numbers and prices | planned |
| 9 | Live earbud interpreter (research spike) | planned |

## 1. Offline-ready indicator

The install steps ask the user to leave the app open for ten seconds and then test in airplane mode. Have the service worker report how many of the language's clips are cached and show it in the header (`Offline ready: 112/112`), with a warning when iOS has evicted storage and a refill is needed.

Touches: `app/sw.js` (count entries in `mimik-<code>-<version>`, answer a `postMessage` query), `app/index.html` (header badge).

## 2. Show mode

Tap a card to show the native text full screen at large size, with a Screen Wake Lock held while it is open, so the phone can be turned toward a waiter or ticket clerk when pronunciation fails. Tap or swipe to dismiss.

Touches: `app/index.html` only.

## 3. Lock-screen and earbud controls

Use the Media Session API so the last-played phrase can be replayed, or replayed slow, from the lock screen and from earbud taps, without taking the phone out. Set metadata (English and native text) so the lock screen shows what is playing.

Touches: `app/index.html` (`play()`), with a check that Safari's range-request handling in `app/sw.js` still holds.

## 4. "What you'll hear" replies

The app covers only the user's half of each exchange. Add an optional `replies` array to a phrase, each entry being a likely response from the other person with its English gloss and audio, for example after "Um café, por favor": "Para cá ou para levar?" (For here or to take away?). Show replies collapsed under the card.

Touches: `phrases.json` schema (and the README's phrase format section), `scripts/gen_audio.py` (render reply clips; reply ids share the language's id namespace), `app/index.html`, `app/sw.js` precache list.

## 5. Search across sections

A search field that matches English, native text and romanization across every section, so a phrase can be found without guessing which time tab holds it.

Touches: `app/index.html` only.

## 6. Phrase linter in CI

Extend the duplicate-id check into a linter that fails the build on: phonetics with no stressed capital (except Japanese), a `/` or ellipsis in `text` with no `say`, a gendered phrase missing its `f` form where its siblings have one, `alt` entries without `tag`, and sections with malformed `hours`. Run it in `deploy.yml` before audio generation.

Touches: new `scripts/lint_phrases.py`, `.github/workflows/deploy.yml`.

## 7. Human recordings override TTS

If `site/<code>/audio-human/<id>.m4a` (and `audio-human/f/<id>.m4a`) exists, the build and the app use it in place of the edge-tts clip. Lets a native speaker record the phrases used most, where the TTS sounds worst. Unlike the TTS clips, these are source files and are committed.

Touches: `scripts/build.py` or `scripts/gen_audio.py` (copy or prefer human clips), `app/index.html` (clip path), `app/sw.js` (precache), README audio section.

## 8. Numbers and prices

Render 0 to 100 plus currency words ("euros", "cents", "e") as clips and concatenate them at runtime to speak any price. Add a listening drill: the app speaks a random price and the user types what they heard. Hearing totals at the till is a common failure point.

Touches: a numbers block per language in `phrases.json` (number grammar differs per language; Japanese and German need care), `scripts/gen_audio.py`, `app/index.html`.

## 9. Live earbud interpreter (research spike)

The app listens to the person speaking, transcribes and translates on device, shows the gist, and suggests which card to play in response. Candidate stack: Whisper tiny or base via WASM or WebGPU plus a small translation model. Open questions before any build: model download size per language, latency and battery on an iPhone, Safari WebGPU support, and the ethics of recording bystanders. The deliverable is a written go or no-go with measurements, not a feature.
