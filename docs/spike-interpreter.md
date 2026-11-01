# Spike: live interpreter (Feature 9)

Status: **measuring, with a provisional answer.** Open interpretation is a no-go on this phone today. A narrower feature, recognising which of the app's known replies was said, looks like a go and is being confirmed (third run).

## Question

Can the app listen to the person speaking, and show the gist in English, on the phone, offline, fast enough to use mid-conversation? The deliverable is a go or no-go with measurements, not a feature.

## Pass bar

Agreed before measuring. All must hold on the target phone (iPhone 15 Pro, iOS 26.6.2) for a go.

| Criterion | Bar |
| --- | --- |
| Speed | Under 3 s from the speaker stopping to English on screen |
| Download | Under 150 MB per language |
| Accuracy | At least 80% of the reply test set gets an English gist a listener would act on correctly (judged by reading, not by word-match score) |
| Battery | Under 5% for 10 minutes of use; the soak test is back-to-back inference, so it bounds real use from above |
| Offline | Works with no connection once downloaded |

## Desk findings

1. **No separate translation model is needed.** Whisper translates speech straight to English (`task: 'translate'`), the only direction needed. This removes a second model per language. The open question is quality: the small models translate worse than they transcribe, which the benchmark measures.
2. **Whisper large-v3-turbo is excluded.** It was fine-tuned on transcription data only, with translation data left out, and OpenAI does not expect it to translate well.
3. **WebGPU is available.** Safari 26 ships WebGPU enabled by default on iOS, and the target phone runs iOS 26. That makes GPU inference in a web page possible, which was the main blocker when this feature was written.
4. **WebAssembly runs single-threaded here.** Threads need cross-origin isolation headers, which GitHub Pages cannot send (a service-worker workaround exists but is fragile). The WebAssembly configuration is therefore a slow baseline, not a candidate.
5. **The earbud premise is doubtful.** AirPods microphones are tuned to the wearer's voice and suppress others, so the phone's microphone has to do the listening, held out or on the table; earbuds can still deliver the result. When AirPods are connected, iOS routes recording to them by default, so the live test is run both ways.
6. **Bosnian is the expected weak language.** Whisper had far less training audio for it than for the other six, and may confuse it with Croatian or Serbian. Measured, not assumed.
7. **Model sizes are measured, not quoted.** Published sizes for the quantized ONNX exports conflict between sources; the page records the actual bytes downloaded.

Engine: transformers.js 4.3.2 (ONNX Runtime Web), WebGPU with a WebAssembly fallback. whisper.cpp compiled to WebAssembly was considered and dropped: it has no WebGPU path, and without threads it would only be a slower copy of the WebAssembly baseline.

## Method

`site/lab/index.html`, deployed at `/MIMIK/lab/`, separate from the app and not cached offline. On the phone it:

1. **Suite.** For each configuration, downloads the model (recording size and load time), runs one warm-up call (shader compilation, timed separately), then transcribes and translates 56 clips: the first 8 replies in each of the 7 languages, alternating voices. Replies are lines a waiter or clerk actually says, with the text and English already written, so each clip has a reference. Records time per call, the transcript with a character error rate, and the English.
2. **Live.** Hold-to-listen recording from the microphone; times release to English, which includes decoding the recording.
3. **Soak.** Ten minutes of back-to-back translation with the screen held on; battery percentage entered by hand before and after (Safari does not expose it).

Configurations (second version, after the first run; see Results):

| Id | Model | Backend | Precision |
| --- | --- | --- | --- |
| tiny-wasm | whisper-tiny | WebAssembly | 8-bit |
| base-wasm | whisper-base | WebAssembly | 8-bit |
| small-wasm | whisper-small | WebAssembly | 8-bit |
| tiny-webgpu-fp32 | whisper-tiny | WebGPU | fp32 throughout, to separate a broken 4-bit kernel from a broken backend |
| tiny-webgpu | whisper-tiny | WebGPU | encoder fp32, decoder 4-bit |
| base-webgpu | whisper-base | WebGPU | encoder fp32, decoder 4-bit |
| small-webgpu | whisper-small | WebGPU | encoder fp16, decoder 4-bit |

The WebAssembly configurations run twice: on one thread at `/lab/`, and on several at `/lab/?mt`, where the lab's own service worker adds the cross-origin isolation headers that GitHub Pages cannot send (results saved with an `-mt` suffix). A run records the step it has reached as it goes, so a configuration that kills the tab is marked with where it crashed, and the suite moves on.

The clips are synthetic voices: cleaner than a café, so the suite flatters accuracy. The live test is the check against real speech and noise.

Results persist in the page's storage, so a tab killed for memory resumes where it stopped.

## Running it (on the phone)

1. On Wi-Fi, open https://jamionw.github.io/MIMIK/lab/ in Safari. Disconnect AirPods for now.
2. **Run all remaining.** Keep the screen on and Safari in front. If the tab reloads mid-run, that configuration crashed; tap Run all remaining again and it continues with the next.
3. Open **threaded mode** from the link on the page (`/lab/?mt`) and Run all remaining again; this runs the WebAssembly configurations on several cores.
4. **Live:** pick the fastest configuration that finished, load it, and have someone say a few lines in one or two languages (or play them from a video). Then connect AirPods and repeat a couple, with the phone held towards the speaker.
5. **Soak:** unplug, note the battery, start with the configuration you would choose, enter the battery after 10 minutes, Save.
6. **Copy results** (or Share) and paste the JSON into the conversation.

## Results

### First run (page version 1, 1 November 2026)

| Config | Download | Load | Clips | Translate median / p90 | Transcript error rate (median) |
| --- | --- | --- | --- | --- | --- |
| tiny-webgpu | | | crashed | | |
| base-webgpu | | | crashed | | |
| small-webgpu | | | crashed | | |
| base-wasm (one thread) | 80 MB | 3.1 s | 18 of 56 (partial) | 2477 / 5455 ms | 8% |

All three WebGPU configurations killed the tab; version 1 recorded nothing before a model finished loading, so where they crashed is unknown. Since whisper-tiny with a 4-bit decoder is a few tens of MB on an 8 GB phone, plain memory exhaustion is unlikely; a WebGPU or 4-bit kernel failure in ONNX Runtime Web on Safari is the leading suspect. Version 2 records the crash step and adds an fp32-only WebGPU configuration to tell the two apart.

The single-threaded WebAssembly result is the first real signal: transcription accuracy is good (8% character error rate on the median clip), and the median nearly meets the 3 s bar, but the p90 does not, for clips of only 1 to 3 seconds. Threads are the obvious lever, hence threaded mode.

### Second run (page version 2, 1 November 2026)

Safari reports 4 cores to the page and the page was not cross-origin isolated (plain mode only; threaded mode was not run).

| Config | Download | Load | Result |
| --- | --- | --- | --- |
| tiny-wasm (one thread) | 44 MB | 2.7 s (+2.5 s warm-up) | 56 of 56 clips |
| base-wasm | | | crashed during download, straight after tiny-wasm in the same page |
| small-wasm | 252 MB | 10.0 s | crashed at the first inference |
| tiny-webgpu-fp32 | 154 MB | | crashed at model setup |
| tiny-webgpu | 122 MB | | crashed at model setup |
| base-webgpu | 209 MB | | crashed at model setup |
| small-webgpu | 765 MB | | crashed during download |

**WebGPU is out, for this engine on iOS 26.6.** Every WebGPU configuration killed the tab at model setup, including the fp32-only one, so the cause is the backend, not the 4-bit kernels. Not worth more time unless ONNX Runtime Web or Safari changes.

**base-wasm's crash is probably memory left over, not base itself.** It ran 18 clips in a fresh tab in the first run, and crashed here only when started in the same page after tiny-wasm; WebAssembly memory does not shrink within a page. small-wasm crashing at its first inference in a fresh page looks like a real memory limit.

**tiny-wasm, one thread:**

| Measure | Result | Bar |
| --- | --- | --- |
| Transcribe | about 1.2 to 1.4 s per 2 s clip (one outlier: 5.9 s, a runaway "gegege..." loop on a Dutch clip) | under 3 s: **pass** |
| Translate | about 1.2 to 1.4 s | **pass** |
| Download | 44 MB, shared by all languages | under 150 MB: **pass** |
| Transcript error rate (median) | 11% overall; Spanish and German near 0, French about 24% | |
| Whisper's own translation | about 8 of 56 a listener could act on ("Inside or outside.", "Big or small?"); most are wrong ("Fresca ou natural?" became "Friska Natural.", "Pequena ou grande?" "Who is the great one?") | 80%: **fail, badly** |

**The finding that changes the plan:** the transcripts are much better than the translations, and the replies the app already holds give a closed list to match against. Matching each tiny-wasm transcript to the nearest known reply in its language (20 to 23 candidates, comparing letters after dropping case, accents and punctuation) picks the right reply for **52 of 56** clips, every language at 6 of 8 or better (Spanish, German, Dutch and Japanese 8 of 8). The reply's stored English is then correct by construction. With a similarity cutoff of 0.5, 51 answers are shown, 50 of them right, and 5 come back as "not sure" rather than a wrong answer; the one confident miss was "Quer canela?" heard as "Quer que não é?" and matched to "Em que nome?".

Caveats: the clips are clean synthetic voices; matching only knows the lines in the app, so anything else must come back as "not sure", which is untested; and the cutoff was tuned on the same 56 clips it is scored on.

### Third run, one thread (page version 3, 1 November 2026)

Each configuration ran in a fresh page. Reply matching at the 0.5 cutoff; "top match" counts the closest reply whether or not it cleared the cutoff.

| Config | Download | Transcribe median / p90 (max) | Transcript error rate, median | Reply match: right / wrong / not sure | Top match right |
| --- | --- | --- | --- | --- | --- |
| tiny-wasm | 44 MB | 1.23 / 1.36 s (1.42) | 11% | 51 / 1 / 4 | 52 of 56 |
| base-wasm | 80 MB | 3.05 / 3.19 s (4.72) | 8% | 54 / 0 / 2 | 56 of 56 |
| small-wasm | 252 MB | | | crashed at model setup, in a fresh page | |

- **base-wasm runs in a fresh page,** confirming the run 2 crash was memory left by the previous model. small-wasm crashing in a fresh page confirms it does not fit.
- **base is the more accurate recogniser**: every clip's top match was right, no wrong answer was shown, and its two "not sure" were right but low-scoring ("Loopt u maar mee." heard as "Lope to my me."). tiny gave one confident wrong answer ("Quer canela?" heard as "quer que não é", shown as "Em que nome?"); base heard "Quer que nela?" and matched it.
- **base misses the speed bar on one thread, narrowly**: 3.05 s median against a 3 s bar, for 2-second clips. tiny is well inside it.
- **Whisper's own translation is better in base but still far from the bar**: roughly 20 of 56 usable ("Do you have reservation?", "In or out?", "2 adults"), against about 8 for tiny. It confirms the no-go for open interpretation.
- The 64-token cap held: no runaway loops (worst clip 4.7 s, the first one after warm-up).

### Third run, threaded: not possible here

On the phone, `/lab/?mt` stayed un-isolated (`crossOriginIsolated` false), although the same lab service worker isolates the page in Chromium. Safari does not appear to accept the isolation headers when a service worker supplies them, and GitHub Pages cannot send them itself, so WebAssembly threads are unavailable to this site on iOS. The app is hosted the same way, so a shipped feature would run on one thread too: **the one-thread numbers above are the realistic ones.** Threads would need a host that can set response headers (Cloudflare Pages or Netlify, for example), which is a hosting decision, not something to resolve in this spike.

Still pending: the live test with real voices (including lines that are not in the app, and with AirPods connected) and the battery soak, both on one thread.

## Decision

Provisional:

- **Open interpreter (translate anything said): no-go.** The only models that run on the phone, tiny and, probably, base on WebAssembly, translate too poorly to act on, and the models that might translate well enough do not fit.
- **Reply recognition (tell the user which expected reply they just heard, with its English): likely go**, pending the live test. It reuses the "What you'll hear" data, needs one model for all languages, and can say "not sure" instead of guessing. On synthetic clips, tiny (44 MB) answers in about 1.2 s with 51 of 56 right and 1 wrong; base (80 MB) answers in about 3 s on one thread with 54 right and none wrong. Threads are not available on this hosting (see the threaded run), so the choice is between base, about 3 s and no wrong answers, and tiny, about 1.2 s and one wrong answer; the live test decides it.

Whatever the outcome, any go is conditional on push-to-listen (never always-on listening), audio processed on the phone and discarded once transcribed, and nothing stored or sent, which addresses most of the bystander concern and also limits battery use.

Card suggestion follows from reply recognition: a recognised reply belongs to a known card, so the app knows which exchange is under way and can surface the natural next card. That is a product decision on top of the measurement, not something to benchmark.
