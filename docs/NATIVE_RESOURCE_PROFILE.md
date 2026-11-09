# Native resource and loading profile

Measured 2026-11-09 using the existing Godot 4.6.3 Linux binary, the six-world
`mobile/godot-foundation` source checkpoint and generated original artwork. The
production changes from this audit are scene-end texture release in
`godot/src/story_player.gd` and Web-only streaming for long-form score playback in
`godot/src/original_score.gd`. No artwork was resized, re-encoded, removed or
reimported, and no software was installed. No commit, upload or deployment was
performed by this audit.

## What the measurements mean

- **Engine allocations:** `OS.get_static_memory_usage()`, not complete process or
  GPU memory. Linux RSS is reported separately from `/proc/self/status`.
- **RGBA8 estimate:** unique texture width × height × 4. This is a useful storage
  estimate, not measured graphics memory. RGB textures, backend conversion,
  decode buffers and device drivers can differ.
- **Loading time:** synchronous `load_level()`/startup time on this cloud Linux
  CPU with existing imports. Repeated passes benefit from the filesystem cache.
  These are not iPhone/Safari times, GPU timings, frame-rate or battery results.
- **Story sweep:** asks the actual story texture loader for the backgrounds,
  sprites and props referenced by every resolved shot, then ends each scene.
  This deliberately exercises demand/retention without claiming that a headless
  renderer played or visually verified all shots.
- Tests were serialized, with one Godot process at a time and isolated writable
  HOME/XDG directories. Nothing uses the player's real save.

## Packaging inventory

The existing `bill-dodgers-native-party-ui.pck`, created before this change,
contains 1,316 entries and is **292,024,592 bytes / 278.5 MiB**. It is a resource
pack, not an APK/IPA, and these numbers are not an inspection of a later Web export.

| Payload | Count | MiB |
| --- | ---: | ---: |
| Imported textures | 521 | 259.2 |
| Compressed original music resources | 18 | 14.1 |
| Procedural effects and two fallback music resources | 22 | 2.8 |
| Scripts, content, font/import metadata and other data | 755 | 2.3 |

All 521 texture imports use lossless compression mode 0, no mipmaps and no size
limit. Lossless **disk** compression does not mean GPU block compression. The
source image files total 116.7 MiB, while their imported texture payload is
259.2 MiB. The complete art inventory would be about 907.8 MiB in RGBA8, but the
game does **not** load that whole inventory simultaneously.

The export's `all_resources` filter ships art even if runtime loading is lazy.
The current exclusions correctly keep tests, build tools, original reference
JavaScript, raw WAV/OGG intermediates and the composer manifest out of the native
pack. Generated content JSON and native audio resources are included.

The inventory identifies **36 embedded textures / 30.4 MiB imported** with no
direct reference in generated level/map/story JSON. These are candidates for a
future explicit runtime export manifest, not proof that arbitrary source art can
be deleted. Dynamic and source-preservation references must be checked and the
asset-free packed runtime rerun before excluding anything. Originals stay intact.

### Verified Web-only exclusion follow-up

The 36 candidates were subsequently traced to the original web pages' independent
`SRC.title` JPEGs, outside their `META.imgs`: 42 source stages use 36 distinct
images because World 6 shares one title. Every candidate is absent from current
runtime level/map/story/catalog JSON and production code. The native title and
credits use retained `assets/title.jpg`; the full-body selector uses retained
`content/levels/1-1.json:imgs.st0`. Dynamic loaders were reviewed: stage/map keys
come from checked JSON, while other asset paths use fixed sprites, cutscenes,
fonts, music or effects directories. None constructs an embedded-image path.

`scripts/native-web-title-exclusions.json` lists the exact 36 paths, original
SHA-256 values, all source-stage provenance and seven reviewed loader fingerprints.
`scripts/check-web-title-exclusions.py --print-filter` validates the current
project and emits an exact comma-separated exclusion string. Export integration
must run that check first and apply its result **only to the Web preset**. It
fails if a runtime source/JSON references an excluded hash, a reviewed loader
changes, another dynamic loader appears, an asset changes or required generated
content is absent. Fingerprints require a deliberate new reachability review,
not automatic refreshing. Six regression tests pass, including future reference,
wildcard, identity and duplicate rejection.

Measured against the full Web `index.pck` of 292,026,016 bytes, the exclusions
target 72 actual pack entries: **31,849,509 payload bytes plus 10,656 directory
bytes**. Estimated PCK size is 260,165,851 bytes before packing alignment changes.
Independent level-9 compression of the CTEX payloads totals 31,849,553 bytes,
suggesting enough archive saving for the 256 MiB hosting cap, but **the regenerated
archive size and full packed-runtime gate must still be measured**. This audit
does not edit the preset or export helper itself. No original/import file is
removed and no used art is resized or re-encoded.

## What loads and when

- Title startup eagerly loads all six housemate sheets plus bot/thief sheets:
  eight textures, 70.3 MiB RGBA8 estimate. It also loads fonts, the title painting,
  scripts and title cue. All other level art is lazy.
- Opening the painted map loads its 18 pictures: 119.6 MiB RGBA8 estimate. The map
  includes full-body selector art. Its UI and pictures are freed after leaving
  the map and draining queued frees. It is rebuilt on return.
- A stage loads its `meta.imgs` synchronously. Largest unique stage image sets
  are 5-2 at 30.9 MiB, 1-1 at 29.2 MiB and 5-3 at 25.1 MiB RGBA8 estimate.
- Stage transitions clear the old image dictionary and renderer texture wrapper
  caches. Weak-reference tests across **all 42 stages twice** found zero retained
  old unique stage textures and zero retained old unique map textures.
- Returning from a stage to the preview menu does not clear the last stage
  images. The final 6-S fixture retains five unique textures / 3.7 MiB. This is
  bounded by the previous stage, not an accumulation across the campaign.
- Effects are loaded on first use and cached in a bounded 20-name set; playback
  uses a fixed 24-player pool. Two prebuilt fallback music resources are available
  but are not eagerly synthesized. Original score resources are lazy and retained
  by cue, capped by the fixed 18-name list. Shutdown clears both caches.

## Fixed: story textures accumulated after every scene

Previously `StoryPlayer.textures` was never cleared when a scene completed or
was skipped. After the full scene-demand sweep, **41 textures / 230.3 MiB RGBA8
estimate remained referenced** although no story was playing.

`_finish()` now clears that cache after hiding the scene and **before** emitting
`finished`. Repeated shots within one scene still reuse textures; later replay
reloads original art. Clearing before the signal is important because a listener
may immediately start the next scene. Pause does not discard the active scene,
and an invalid scene request leaves it unchanged.

Paired runs using the same inventory and sequence:

| Observation | Before | After |
| --- | ---: | ---: |
| Title engine allocations | 124.4 MiB | 124.4 MiB |
| Map engine allocations | 257.3 MiB | 257.3 MiB |
| After all stories stopped | 349.3 MiB | **154.9 MiB** |
| Retained story textures after final stop | 41 | **0** |
| All score/effect cues requested | 356.6 MiB | **162.2 MiB** |
| Maximum tracked engine allocation | 356.7 MiB | **280.4 MiB** |
| Highest sampled Linux RSS | 468.4 MiB | **407.2 MiB** |

The fix releases about **194.4 MiB of live engine allocations** after the sweep.
RSS does not fall by the same amount because allocators retain previously
reserved memory. It is incorrect to call retained allocator pages a stage-texture
leak, or to infer that a phone will use these same totals.

Baseline synchronous stage-loading medians were 47.5 ms and 40.3 ms over the two
passes; the slowest observed call was 226.8 ms. Title setup took 1.90 seconds and
map setup 0.58 seconds in that baseline. Later warm runs varied substantially;
the story fix is not presented as a startup speed improvement. Blocking loads
may visibly stall slower devices and should eventually have an explicit loading
presentation or a carefully validated staged loader.

## Web/iPhone demo risks to check

1. **Full-pack download and copies.** Each complete copy of the existing pack is
   278.5 MiB. Keeping chunk buffers, an assembled buffer and an engine filesystem
   copy alive can multiply peak memory before WASM, decoded art and audio are
   counted. This is a copy-budget calculation, not a browser measurement. Prefer
   the engine's ordinary fetch/preload route and avoid unnecessary retained
   copies. Releasing chunks only after building a final buffer does not remove
   their temporary overlap. Confirm actual export sizes and inspect real Safari.
2. **Web audio decode mode.** Native score resources are compressed, but Web
   Sample playback can require complete decoded audio buffers. The existing
   manifest contains 868.9 seconds of stereo 44.1 kHz score: if all 18 cues were
   retained as Float32 samples, audio alone would be about **292.3 MiB** (title
   19.6 MiB, map 18.6 MiB). This is a conditional estimate, not observed browser
   retention. The score adapter now explicitly selects
   `AudioServer.PLAYBACK_TYPE_STREAM` for its two music players on Web only,
   including both sides of every crossfade. Native playback and all 24 SFX
   players retain Default. This avoids deliberately selecting full-song Sample
   playback for music, but streaming has CPU/latency tradeoffs. Actual exported
   browser decoding, autoplay, mixing and Safari compatibility still need testing;
   no measured browser memory saving is claimed by the native policy regression.
3. **Painted map and eager cast.** Map art plus eight resident gameplay sheets is
   already about 189.9 MiB RGBA8 equivalent. A possible later optimization is
   demand-loading cast sheets while preserving all six selection animations;
   another is a bounded map/selector lifecycle. Neither was changed here.
4. **Large image limits.** Two preserved artwork strips are 5,591 pixels wide.
   Confirm the target WebGL/device texture limit rather than silently resizing.
5. **Rendering is unmeasured.** Headless tests cannot certify texture upload,
   canvas draw-call cost, shader support, GPU residency, thermal behavior,
   stutter during stage switches, autoplay unlocking or iOS background recovery.

## Validation and reproduction

Passed:

- New `test_story_resource_lifecycle.gd`: 23 checks covering cache reuse, pause,
  invalid scene, skip, normal finish, replay, repeated stop, attract-style stop,
  scene replacement and reentrant signal handlers. Its unknown-scene warning is
  intentional.
- Existing `test_story.gd`: shot resolution, World 1 story lifecycle and pause.
- Existing `test_campaign_map_integration.gd`: 47 checks, including real title
  attract creation, background pause and touch cancellation.
- Paired `profile_native_resources.gd`: all 84 transitions, correct image counts,
  zero old unique stage/map resource retention, clean game teardown.
- Four Python tests for the inventory and binary-index parser.
- New `test_score_web_playback.gd`: 11 checks for platform selection, preserved
  native/SFX defaults, both streaming crossfade voices, pause and shutdown. This
  runs both policies on real native players; it is not browser audio validation.
- Existing `test_original_score.gd`: 141 checks. Existing
  `test_original_score_integration.gd`: 187 actual-main audio lifecycle checks.

After preparing the generated project, inspect without launching Godot:

```sh
python3 scripts/profile-native-resources.py --pack /path/to/existing.pck --output /tmp/resource-inventory.json
python3 -m unittest discover -s tests -p test_native_resource_profile.py -v
```

With an exclusive Godot window, run a fresh isolated CPU/resource profile:

```sh
python3 scripts/profile-native-resources.py --run --output /tmp/resource-profile.json
```

The helper uses only Python's standard library. It reads imported CTEX headers
and the PCK directory without loading their payloads, runs no import or export,
and preserves the raw runtime log in its JSON result. `--runtime-log FILE` can
summarize an existing run instead. The diagnostic profile is deliberately not a
phone-performance pass/fail gate; physical browser/device validation remains open.
