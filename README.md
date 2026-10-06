# Mimik

Time-of-day Portuguese (Portugal) phrases with audio. A single-page offline PWA.

- `site/phrases.json`: all phrases. Edit here; everything else derives from it.
- `scripts/gen_audio.py`: generates `site/audio/<id>.mp3` with edge-tts (voice set in the JSON).
- `.github/workflows/deploy.yml`: on push to `main`, generates audio and deploys `site/` to GitHub Pages.

Missing clips fall back to the device voice (Joana on iOS).

## Setup

1. Make the repo public, then Settings > Pages > Source: **GitHub Actions**.
2. Merge to `main`; the workflow deploys to `https://jamionw.github.io/MIMIK/`.
3. On the iPhone: open that URL in Safari, wait a few seconds for it to cache, then Share > Add to Home Screen.
4. Test offline: airplane mode, open from the home screen, play a few phrases.

## Local

    python3 -m http.server -d site 8000
