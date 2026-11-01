# Spike: live interpreter (Feature 9)

Status: **measuring.** The benchmark page is built; results and the decision are pending a run on the target phone.

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

### Second run

Pending.

## Decision

Pending. Whatever the outcome, any go is conditional on push-to-listen (never always-on listening), audio processed on the phone and discarded once transcribed, and nothing stored or sent, which addresses most of the bystander concern and also limits battery use.

Card suggestion (matching the English gist to a card to play back) is left out of the measurements: once there is an English gist it is text matching over the English the phrase files already hold, and gets a paragraph here if the answer is go.
