# Capabilities & Limitations

This document records features that are reconstructed, or that a public-API /
unsigned-build limitation prevents from being 100% faithful, plus the fallback
used in each case.

## Onboarding (first launch)

The exact original onboarding screens were **not captured in the crawl**, so the
first-launch flow in `lib/features/onboarding/onboarding_flow.dart` is a
**faithful reconstruction** of a speaker-cleaner app's standard scenario:
welcome → how it works → Premium subscribe offer. It is shown **only on the
first launch** — the `settings.onboarding_complete` flag is persisted with
`shared_preferences` and gated by `LaunchGate` on the `/` route, so it never
reappears during normal use.

## Premium benefit screens

The original's dedicated Premium-benefit screens were **not captured in the
crawl**, so `lib/features/premium/premium_benefits.dart` is a faithful
equivalent that mirrors the same mechanic (the full tone range, the frequency
sweep, the Channel Test, the Sound-Level Meter, ad-free). It is surfaced at the
right moments: the final onboarding step (first launch) and whenever a free user
opens a Premium-gated feature (Channel Test, Sound-Level Meter, a premium tone).

## Tone Generator — real generated sines

The Tone Generator (`lib/features/0012`) plays **honest sine waves at their
labelled frequencies**. `tool/generate_tones.py` writes the tone bank as 16-bit
PCM WAVs straight from `sin(2*pi*f*t)` at 44.1 kHz — `tone_1000.wav` really is
1000 Hz — for 63, 125, 250, 500 Hz and 1, 2, 4, 8, 16 kHz, plus a single 12 s
logarithmic **20 Hz → 20 kHz** chirp (`sweep_20_20000.wav`). Each tone's length
is snapped to a whole number of cycles near 2 s, so `ReleaseMode.loop` repeats
it without a click and "continuous" really is continuous. The clip is selected
by frequency (`ToneBank.assetFor`), so what the screen prints is always what the
speaker plays.

Why bundled WAVs rather than a live oscillator: the app's whole audio path is
`audioplayers`, which plays assets and exposes volume/balance but no PCM
callback, and Flutter ships no sample-level audio output. Generating the exact
same signal ahead of time gives bit-identical output without swapping the engine
(and without a new dependency). The only practical cost is that frequencies
between the nine labelled steps are not offered.

### Waveform display

`audioplayers` still exposes no live analyser tap. For these clips it does not
need one: a pure sine has a **flat loudness envelope**, so an envelope-based
visualiser would draw a straight line. Because the app generated the signal
itself, `ToneWaveform` / `SweepWaveform` (`lib/core/audio/waveform_source.dart`)
draw the **signal's own waveform** — `sin(2*pi*f*t)` for a tone, and the sweep's
closed-form instantaneous phase for the chirp — sampled at the player's REAL
reported position. The bars are therefore the actual signal, not motion invented
from a formula, and they stop the moment playback stops. It behaves like an
*untriggered* oscilloscope, so a very high tone visibly shimmers as its phase
races past the screen's frame rate.

### Phase test — no polarity inversion (limitation + fallback)

A textbook phase check plays a tone with one channel's **polarity inverted**.
That is not reachable through the current engine: `audioplayers` plays bundled
files and exposes volume, not per-channel polarity, and the bundled tones carry
each channel in phase. The app therefore does **not** synthesise an out-of-phase
signal.

Fallback (`lib/features/0012/phase_test_screen.dart`, and step 4 of the
Headphone Checkup): the closest thing the engine allows — the 500 Hz sine A/B'd
between **both channels in phase** (the mono clip) and **each side alone** (the
`_l` / `_r` stereo variants), switchable live so the ear can compare with only a
momentary gap. The screen states plainly that it cannot flip polarity and describes what a
genuinely out-of-phase pair sounds like (thin, hollow, impossible to place)
against the in-phase reference (centred and full), so the user can recognise the
fault on their own gear. No UI claims an inversion is being produced.

### Headphone Checkup — the user's ears are the instrument

The guided checkup (`lib/features/checkup/headphone_checkup_screen.dart`) drives
the left / right / balance / phase / sweep steps through the same
`ChannelAudio` + tone bank. The device has no way to *hear* the headphones
plugged into it, so the app never claims to have measured them: each step says
what a healthy result sounds like and the **listener records their own verdict**,
which the summary reports back as listening notes. Nothing is scored or
"detected" automatically.

### Water eject

Speaker maintenance keeps using the original bundled low-frequency clip
(`assets/audio/tone_water.mp3`) — it is not a labelled frequency, so it makes no
claim the tone bank would have to back. `tone_vibrate.mp3` / `tone_air.mp3`
backed the removed "cleaning modes" and are no longer referenced by any screen.

## dB Meter — real microphone

The dB Meter (`lib/features/0013`) uses the **real microphone**:
`permission_handler` triggers the actual iOS microphone permission dialog on the
first **Start** tap, and `noise_meter` streams live decibel readings. It never
auto-starts — the screen opens idle and only measures after an explicit Start;
Stop fully stops the stream. `NSMicrophoneUsageDescription` is declared in
`ios_permissions.json`. On a platform without microphone support (e.g. the
headless web preview) the screen stays idle and shows an honest "microphone
unavailable" notice instead of faking a signal.

### dB scale — calibration & limitation

`noise_meter` does not return dBFS. It computes
`meanDecibel = 20 * log10(2^15 * meanAmplitude)`, so its zero point is an
amplitude of one quantisation step — digital silence, which a microphone never
produces. Its value is therefore "dB above the quantisation floor": a quiet room
lands near 50 and the bottom of the scale is unreachable. It is **not** absolute
SPL, and no public iOS API exposes a calibrated SPL figure. Two consequences are
handled explicitly:

* The reading is converted with **one calibration offset**, derived from the
  package's own zero point rather than picked to look right:
  `_calibrationOffset = 20*log10(32768) − 70 ≈ 20 dB`, i.e. the package's
  *practical* floor — the iOS input's own self-noise with the microphone
  covered, about 70 dB below the clipping point. Subtracting it makes covering
  the microphone read near 0, a quiet room read in the low tens rather than
  mid-scale, and everyday rooms sit in the familiar 40–60 band. The same
  transform feeds the live reading and the Lowest / Average / Peak tiles, so
  they always agree, and the Calm / Moderate / Loud edges (40 / 62) are anchored
  to this calibrated scale, not to the package's raw one. An uncalibrated phone
  microphone has no reference level and iOS applies its own gain, so this is an
  **approximate sound level**, never certified SPL — the on-screen explainer
  says exactly that rather than implying an instrument-grade measurement.
* The displayed range starts at **0 dB, not at a comfortable ambient floor**.
  An earlier build clamped every reading into 30–100 dB, so a quiet room could
  never read below 30 no matter how silent it was; the bottom of the range is no
  longer clamped away, and covering the microphone visibly drops the number.

Until the first reading arrives the gauge and the session Lowest / Average /
Peak tiles show a **placeholder ("—")**, never a stand-in number — there are no
statistics before there is data.

## Waveform visualiser — per-sound amplitude envelopes

The bars in `lib/ui/components/waveform_visualizer.dart` are driven by real
audio data, never by a decorative formula.

**Limitation.** `audioplayers` (the app's audio stack) exposes no real-time
amplitude or FFT tap, so a live analyser of the playing signal is not available
without replacing the audio stack. Flutter also ships no MP3 decoder, so the
clip's PCM samples are not available to the app either. **Fallback:** every
bundled clip carries its own **amplitude envelope** — 64 levels (0..1) describing
how loud that clip is across its length, **measured from the audio file itself**:
`lib/core/audio/mp3_envelope.dart` reads the clip out of the asset bundle and
walks its MP3 bitstream, taking the `global_gain` the encoder wrote for every
granule (the quantiser scale that slice of audio needed) as the loudness of that
slice, then normalises the result to the clip's own peak over a 48 dB range.
That is a coarser measure than full-decode RMS — it follows the encoded gain
contour rather than the sample-accurate waveform — but it is read from the real
audio data of that exact file. `lib/core/audio/sound_envelope.dart` measures the
bundled clips once in `main()` before the first frame and caches them by file
name in `assets/audio/`. The numbers are therefore the
real shape of each clip: a given sound draws the same waveform every time it
plays, and no two sounds animate alike. A clip with no measured entry draws the
resting bars — a missing envelope is never replaced with an invented one.

`lib/core/audio/waveform_source.dart` binds the bars to that data:

* **`PlaybackWaveform`** follows the real `AudioPlayer` — its reported duration,
  position and play/stop state — and reads the envelope at the current playback
  position (extrapolated between the player's position events so the bars glide
  at frame rate). The bars therefore scroll in step with what is heard and
  **freeze when playback stops**. Used by the cleaning run (0008) and the Stereo
  Mixer (0002).
* **`StaticWaveform`** draws a clip's whole envelope as a still track preview.
  Used by the Modes hero (0012), where no sound is playing — picking a different
  mode redraws it with that mode's tone.
* **`LiveLevelWaveform`** is a rolling history of the dB Meter's actual
  microphone readings (0013).

Without a source the visualiser stays in its resting state (short, calm bars) —
it never invents motion.

## Channel Test — channel routing

Real per-channel playback routes through **true stereo assets**, not a runtime
pan. `audioplayers`' `setBalance()` is a documented **no-op on iOS**
(`audioplayers_darwin`: "setBalance is not currently implemented on iOS"), so a
panned mono clip plays centred on both drivers there and every left/right test
would silently fail. Each signal is therefore bundled three times and
`ChannelAudio` (`lib/core/audio/cleaning_audio.dart`) picks the file:

* **Left Speaker** → `tone_<hz>_l.wav` / `sweep_20_20000_l.wav` — stereo, signal
  in the LEFT channel, digital silence in the right
* **Right Speaker** → `tone_<hz>_r.wav` / `sweep_20_20000_r.wav` — silence left,
  signal right
* **Left + Right together** / **Auto Balance** → the base mono
  `tone_<hz>.wav` / `sweep_20_20000.wav` (both channels)

The effective channel is an explicitly requested `SpeakerChannel`, or, when the
caller passes `auto` with a hard-panned balance (the tone generator, the phase
A/B and the Headphone Checkup do), the side that balance implies: `<= -0.5`
left, `>= 0.5` right, otherwise both. Changing sides mid-tone re-plays the other
variant — a brief restart, which is the cost of separation that is real on every
platform. `setBalance()` is still applied alongside it: harmless on iOS, and
still genuine panning on Android.

Channel separation only has an audible effect on devices / headsets that expose
**independent left and right drivers**.

### Earpiece routing — limitation & fallback

Routing to the top **earpiece / receiver** is attempted via the public iOS audio
session: the earpiece player switches to the `playAndRecord` category (with no
`defaultToSpeaker` option), which is the documented public way to make iOS pick
the receiver as the default output. This requires the microphone entitlement
(declared in `ios_permissions.json`) and is applied only when the user selects
Earpiece and plays. Because forcing the receiver depends on the device audio
route and OS policy, this is **best-effort**: if the OS can't honour it the
player falls back to normal **loud-speaker** output. There is no fully reliable
public API to force arbitrary audio to the receiver on all devices.

## Sound playback / audio session

Test tones and the completion chime are configured with the iOS `playback`
audio-session category (`AppAudioContext`, set globally in `main()` and per
player before play), so tones play at full output through the loudspeaker **even
when the hardware mute (silent) switch is on** — required for a speaker-cleaning
app. Nothing plays until the user taps Play / Start.

## Purchases — Apphud (StoreKit sandbox)

Purchases go through **real Apphud** (`apphud` Flutter SDK); there is no local
"unlocked" flag anywhere in the app:

* `Apphud.start(apiKey: …)` in `main()` with the `sdk_key` from
  `apphud_config.json` (guarded, and an empty key short-circuits).
* The paywall (screen 0001) loads `Apphud.placements()`, picks the
  `main_speaker-cleaner` placement and renders **its paywall's products** —
  every title and price comes from the store product Apphud attaches
  (`skProduct` / `productDetails`), never hardcoded.
* `Apphud.paywallShown(paywall)` fires as soon as the paywall is on screen, so
  impressions / conversion / A-B data are recorded.
* Trial wording is gated on the introductory offer the store attaches to the
  selected product (`skProduct.introductoryPrice` on iOS,
  `productDetails` offer details on Android), so a product without a trial is
  never advertised as one. **Limitation:** the `apphud` Flutter package (2.7.x)
  exposes no per-user `checkEligibilityForIntroductoryOffer` call, so the
  *per-user* eligibility Apple applies at checkout cannot be queried from Dart;
  the offer attached to the store product is the closest available signal.
* Buy = `Apphud.purchase(product: …)`, restore = `Apphud.restorePurchases()`.
* **`Apphud.hasPremiumAccess()` is the single source of truth** for Pro. It is
  re-checked at launch, on every app resume (`didChangeAppLifecycleState`) and
  after every purchase/restore; `AppState.isPro` only caches that answer for
  gating (`isFeatureLocked`).
* If the placement resolves to no products (offline / dashboard not configured)
  the paywall shows a readable "plans unavailable" card with a Retry action —
  never a blank screen — and the free tools stay usable.

Apphud auto-detects **StoreKit sandbox vs production**, so the full buy /
restore / unlock scenario is testable in the sandbox **without a live App Store
link**. Loading products still requires the product ids to exist in App Store
Connect; on an unsigned build without them the empty state above is what shows.

## Attribution — Tenjin (measurement only)

`lib/core/attribution/attribution_service.dart` reports installs, sessions and
subscription revenue to **Tenjin** (key mirrored from `attribution_config.json`
into `lib/core/attribution_config.dart`). This is **measurement only** — no ad
SDK and no ad widget ships, and no ad network / campaign / creative / tracking
link is hardcoded: traffic sources are wired in the Tenjin dashboard.

Launch order, run from `main.dart` in an `addPostFrameCallback` — Apple only
presents the ATT dialog while the app is visible, so it cannot run pre-`runApp`:

1. `AppTrackingTransparency.requestTrackingAuthorization()` — the **real** iOS
   system dialog (`NSUserTrackingUsageDescription` is in `ios_permissions.json`).
2. `TenjinSDK.instance.initialize(sdkKey: …)`.
3. `optIn()` when ATT was authorized, `optOut()` otherwise.
4. `TenjinSDK.instance.connect()` — Tenjin requires initialize + connect on
   **every** launch, so this stays on the normal startup path.
5. On grant, the IDFA from `getAdvertisingIdentifier()` goes to
   `Apphud.setAdvertisingIdentifier(...)`, tying the subscription to the
   acquiring campaign. The all-zero placeholder IDFA is never forwarded.
6. `Apphud.collectSearchAdsAttribution()` (Apple Search Ads).

Revenue is reported with
`TenjinSDK.instance.subscriptionWithStoreKit(productId, currencyCode, unitPrice)`
**exactly once per successful purchase**, from the paywall's purchase-result
handler in `lib/features/0001/0001_screen.dart` only — never at launch, never
from a `hasPremiumAccess()` check, never on restore and never from a rebuild
(repeat sends would inflate revenue and corrupt ROAS). The id, price and
currency are read off the Apphud product that was actually bought, so the amount
always matches what the store charged; if the wrapper exposes no numeric price
the event is skipped rather than sent with an invented amount.

**Limitations.** ATT and the IDFA are iOS-only concepts, and both plugins have no
web implementation — in the `/#/screen/<id>` web preview the whole sequence
short-circuits (`kIsWeb`) and the app runs with attribution off. An empty
`sdk_key` disables it the same way. Every step is individually guarded, so a
missing plugin never blocks the UI or breaks launch. On the simulator/unsigned
builds Apple returns the all-zero IDFA even after a grant, so no identifier is
forwarded there.

## Freemium gates

* **Free**: the free bass test tone and the water-eject maintenance run.
* **Premium (Pro Audio Tools — price and billing period come from the store
  product, see below)**: the full tone range, the frequency sweep, the Channel
  Test, the Sound-Level Meter, and ad-free.

Every screen that quotes the subscription price (paywall 0001, the premium lock
screens, the onboarding offer) reads it from the SAME Apphud placement product
via `lib/core/state/store_pricing.dart` — there is no price literal anywhere in
`lib/`. Until the store answers, those screens print the sentence **without** a
price rather than a fixed one, so the app can never contradict the checkout.

These are enforced everywhere by `AppState.isFeatureLocked(...)`; a free user who
taps a gated feature sees the Premium benefits / paywall, not the feature.

## Ads

This clone ships **ad-free**. All ad slots / banners / "loading ads" states from
the original have been removed and the layouts reflow to fill the gap.
