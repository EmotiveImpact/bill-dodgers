# Festival night firework audio

## Source and interface

The World 3 night event in `game/3-3/index.html:1316` calls:

```js
tone(200, 60, 0.4, 'sine', 0.3);
noise(0.4, 0.15, 900, 0.05);
```

The definitions at lines 129–141 establish that the fourth `noise` argument is **when**, a start delay in seconds. It is neither end volume nor resonance. The noise starts 50ms after the sine. Both envelopes decay exponentially to 0.001 at their respective 0.4s marks, then keep the source's 20ms stop tail. The bandpass uses the unchanged helper's default Q=1. The overall sound ends at 0.47s and includes the source master gain of 0.5.

`GameAudio.effect_stream("firework")` and `play_effect("firework")` use these two exact event tuples:

```text
["sine", 200, 60, 0.4, 0.3, 0]
["noise", 900, 900, 0.4, 0.15, 0.05]
```

The gameplay caller should use the existing `sfx("firework")` adapter when the night event fires. This audio change does not itself modify that caller.

## Offline generation and compatibility

`godot/tools/build_audio.gd` builds 20 effects and two music loops, for **22 native PCM resources**. The new file is `godot/assets/audio/firework.res`. The generated asset directory is ignored by Git and must be rebuilt before export. Both export presets already include `assets/audio/*.res`; no export configuration changes are needed.

Normal play loads the native resource and caches it without synthesizing on the gameplay thread. Missing resources retain the existing synthesis fallback for development. The mandatory `--require-prebuilt` test disallows that fallback in release verification. The shared renderer, seeded noise, original 19 effect definitions, aliases, and two music loops were not changed. SHA-256 checks after rebuilding confirmed all 21 pre-existing `.res` files were byte-for-byte unchanged.

This preserves the existing port's synthesis approach. It is source-parameter faithful, not a claim of browser bit-identical PCM: the original browser creates random white noise, while the port uses deterministic seeded noise.

## Verification

Using Godot 4.6.3, with HOME and all XDG paths isolated under `/tmp`:

- Offline audio builder: **22 resources, 0 failures**.
- Full audio test suite with `--require-prebuilt`: **154 assertions, 0 failures**, 22/22 resources checked.
- Full audio test suite in a separate minimal project with no prebuilt resources: **108 assertions, 0 failures**, 0/22 resources found, exercising fallback without removing shared build assets.
- All original 21 resource SHA-256 checks passed.
- Logs were checked for `SCRIPT ERROR`, `Parse Error`, `ERROR:`, and leaks, including successful-exit runs. None were present.

New regression checks cover exact source event arguments, 20-effect inventory, 0.47s duration, master gain, the sine-only first 50ms, a silent noise prefix, the noise-only tail after the sine stops, and nonzero delayed tail samples. Standard per-effect checks additionally validate audible non-clipping PCM, cache reuse, prebuilt/synth equality, and disabled looping.

The existing packed verification script copies this same audio harness, so its `--require-prebuilt` run now requires all 22 resources automatically. The parent integration run must verify the current complete pack and gameplay event wiring. This report does not claim audible listening, speaker/headphone, Android, or iPhone QA.
