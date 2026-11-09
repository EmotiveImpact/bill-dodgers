# Native audio parity

`godot/src/game_audio.gd` ports the **procedural** audio definitions in `game/1-1/index.html` (the `tone`, `noise`, `SFX`, `BASS`, `BPAT`, `LEAD`, and `musicTick` definitions). It generates mono 44,100 Hz, signed 16-bit `AudioStreamWAV` data locally. No downloads, codecs, licensed replacement tracks, or external audio services are involved.

## Integration API

Add the script as a Node before playback (its `_ready` creates one music player and 24 reusable effect players).

- `play_effect(name: String)` plays a named source effect, unless disabled or paused.
- `set_enabled(value: bool)` controls all audio. Existing streams freeze while disabled; new effects are ignored.
- `set_paused(value: bool)` freezes all audio; resuming restores playback position.
- `start_music(boss: bool = false)` starts the source fallback loop. Repeated calls for the same mode do not restart it; switching modes restarts the phrase.
- `stop_music()` stops music only.
- `effect_stream(name)` and `music_stream(boss)` expose cached generated WAVs for inspection/testing.

All 19 source names are supported: coin, flower, bubble, plane, ball, sweet, pick, hitBot, pop, hurt, jump, throw, stomp, power, warn, win, select, honk, revive. The first six are the six character projectile sounds. `pickup` aliases `pick`, `hit_bot`/`hit` alias `hitBot`, and `boss` aliases `warn`. Unknown names return no sound rather than a fabricated replacement.

## What matches the source

Effects retain oscillator waveform, start/end frequencies, exponential frequency sweep, exponential amplitude envelope down to 0.001, 20 ms oscillator/noise tail, individual volumes, layered sounds, and delayed notes. Master gain is 0.5. Noise uses the source's half-second reusable white-noise buffer, with a bandpass filter and default Q of 1.

The complete eight-bar original C / A minor / F / G fallback loop is ported, including the source bass pattern, all eight lead phrases/rests, kick, hi-hat and snare events. Normal tempo is 138 BPM. Boss tempo is 150 BPM and bass/lead shift down one semitone. The music gain is 0.22 in addition to master gain. Rendering wraps any note tails into the loop boundary.

## Known differences and omissions

- Source Web Audio square/sawtooth oscillators are browser-bandlimited. Native synthesis here uses analytic sampled waveforms, so upper harmonics can alias and exact timbre is not sample-identical. Triangle/sine also cannot promise identical browser implementation details.
- Noise is deterministically seeded for repeatable tests instead of using a different random buffer at each browser launch. The filter uses the standard RBJ constant-peak bandpass calculation; browser floating-point implementations may differ.
- The fallback loop is cached PCM. Browser scheduling jitter is absent; the source's initial 50 ms scheduling lead-in is omitted. Boss transition restarts the eight-bar phrase instead of changing scheduling tempo mid-phrase.
- Muting freezes playback instead of letting Web Audio continue under zero master gain. Global native pause intentionally freezes audio.
- Polyphony is capped at 24 concurrent effects; when full the first voice is replaced. Browser SFX had no explicit cap.
- The source also tries `../audio/<slot>.mp3` for world/boss/victory slots. The repository has no `game/audio` assets. Those recordings are **not ported or replaced**. The native music is the real procedural fallback from source, not a claim to have recovered the missing tracks. The source `win` arpeggio is available separately.

## Verification

Run from the repository root:

    HOME=/tmp/bd-godot-home XDG_DATA_HOME=/tmp/bd-godot-data XDG_CONFIG_HOME=/tmp/bd-godot-config XDG_CACHE_HOME=/tmp/bd-godot-cache godot --headless --path godot --script res://tests/test_audio.gd

The test checks all 19 effects, PCM format and nonzero/unclipped peaks, cache reuse, unknown-name handling, effect duration/delayed notes, both eight-bar loop lengths, playback flags, disabled-effect suppression, pause/resume, and stop. These are generated-data and headless state checks, **not audible listening, audio latency, Android/iOS speaker, or device performance QA**.

### Teardown and mixer timing

`shutdown()` is idempotent and is also called from `_exit_tree()`. It resumes paused voices before stopping them, clears every player's stream reference, and clears generated-stream caches. `stop_music()` also detaches its stream. Normal game scene cleanup therefore needs no separate manual stream management.

The headless test deliberately yields to the mixer between starting playback and changing playback controls. Godot 4.6.3 can retain a WAV/playback pair when a synthetic test starts, pauses, resumes and stops playback within a single engine frame. Waiting only **after** destruction did not resolve this in the reproduction. Allowing 100 ms after music starts and one process frame after effect playback, then explicitly shutting down and waiting 100 ms for deferred mixer release produced a clean verbose exit. This tests real lifecycle timing rather than suppressing ObjectDB warnings. The audio suite passes with a clean exit; gameplay tests that fast-forward many simulation steps without yielding must also allow mixer time before audio control/teardown.


## Offline audio build (recommended for mobile exports)

From the repository root, before editor import and export:

    HOME=/tmp/bd-godot-home XDG_DATA_HOME=/tmp/bd-godot-data XDG_CONFIG_HOME=/tmp/bd-godot-config XDG_CACHE_HOME=/tmp/bd-godot-cache godot --headless --path godot --script res://tools/build_audio.gd

`godot/tools/build_audio.gd` synthesizes the same 19 effects and two complete music loops, then calls `ResourceSaver.save` to write 21 native `AudioStreamWAV` `.res` resources under `godot/assets/audio/` (about 2.8 MiB). That generated directory is already covered by the repository's `godot/assets/` ignore rule. The builder requires no imported assets and always sets `force_synthesis = true`, so old generated files cannot override changed sound definitions. Rebuild after any audio synthesis change. Only after each native resource is saved successfully, the builder removes that exact name's legacy generated `.wav` and `.wav.import` files. No original game assets are modified.

Runtime loads native resources through `ResourceLoader.exists/load`, retaining exact 16-bit PCM, 44,100 Hz sample rate and stored loop points. It validates format and loop metadata. Missing/invalid resources fall back to source synthesis. Setting `force_synthesis = true` bypasses generated files and uses a separate cache namespace even if a prebuilt stream was already loaded.

**Packaging requirement:** use `export_filter="all_resources"` and include `assets/audio/*.res` in each export preset's existing `include_filter`. Exclude `assets/audio/*.wav` as a safeguard against stale generated files. Run the builder before editor import, then perform the normal export. Include `.res` audio resources when constructing a runnable source archive.

### Why native resources, not raw WAVs

An earlier WAV-only implementation passed workspace tests but failed actual PCK verification: Godot exported recognized WAV assets as imported `.sample` resources/remaps, not the raw bytes requested by `FileAccess`. The WAV importer also defaulted to compression mode 2. Adding a raw WAV include filter did not correct that. Native `.res` resources bypass that importer and preserve exact PCM in the exported pack. Runtime no longer uses raw WAV loading. Missing prebuilt audio must not be mistaken for successful packaging simply because synthesis fallback still produces sound.

### Verification, including exported PCK

The test supports `--require-prebuilt` to require all 21 native resources and assert that the runtime instance did not initialize its synthesis/noise buffer when loading them. A separate forced-synthesis instance compares every resource's PCM byte-for-byte. Normal workspace invocation:

    godot --headless --path godot --script res://tests/test_audio.gd -- --require-prebuilt

For an actual pack test, export a PCK, then run the test from a clean temporary project containing only `project.godot`, a copy of `src/game_audio.gd`, and a copy of `tests/test_audio.gd`, **no audio assets**:

    godot --headless --path /tmp/bd-audio-no-assets --script res://tests/test_audio.gd -- --pack=/tmp/bd-native-audio-res.pck --require-prebuilt

`--pack` mounts the exported pack with `ProjectSettings.load_resource_pack`. In this clean harness, prebuilt resources can only come from the PCK, not the workspace. Use the writable HOME/XDG environment above if required. The existing test script itself is excluded from production exports; it is supplied by the clean harness.

Verified with Godot 4.6.3: the actual exported Android-preview PCK passed **140 assertions**, with all 21 packaged native resources matching forced-synthesis PCM exactly, correct loop points, and no runtime synthesis fallback. Repeated native builds produced identical resource SHA-256 hashes. The standard test also supports missing generated assets and exercises fallback synthesis when `--require-prebuilt` is omitted. No device latency or speaker-quality claims are made.
