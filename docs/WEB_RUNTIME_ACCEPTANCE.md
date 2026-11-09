# Godot Web runtime acceptance

Updated 2026-11-09. This concerns the **new Godot Web export**, not the original
HTML game produced by `scripts/build-web.mjs`. The original browser `bd-save`
and the Godot preview save are separate. Production fixes for Web window-focus notifications and browser-only music
streaming are covered by the separate regressions described below.

## Verified prerequisites

- `python -m unittest discover -s tests -p test_godot_web_compatibility.py -v`:
  **6 static guards pass**. Compatibility rendering, GDScript-only production,
  no native process/thread/socket dependencies, virtual save path/atomic rename,
  one shared input frame, touch cancellation/emulated-mouse filtering and all
  prebuilt audio resources are checked. This is source evidence only.
- `godot --headless --path godot --script
  res://tests/test_web_runtime_foundation.gd`: **91 checks pass**, with no engine
  errors or leaked objects. Uses a fresh writable HOME and XDG directories.
  Checks replace/reopen/corrupt/recover virtual saves, failed destinations,
  independent P1 touch ownership, focus suppression/rearming, reference
  landscape control sizes, packaged audio, crossfade pause/mute and teardown.
  The native dummy mixer is not Web Audio or audible acceptance. Virtual
  filesystem success is not IndexedDB durability.
- `test_web_focus_integration.gd`: **21 checks pass**, with a clean engine
  log. Exact `NOTIFICATION_WM_WINDOW_FOCUS_OUT` pauses real local-P2 gameplay
  and music, clears contacts and freezes physics. Window focus-in does not
  resume gameplay/story. Explicit Resume keeps held keys suppressed until
  neutral input; fresh inputs work afterward. Story and isolated credits
  interruption fixtures also pass. This regression covers the Web
  window-notification fix, not a browser-generated event.
- Existing real-input suites `test_touch_controls.gd` and
  `test_mobile_menu_integration.gd` cover synthetic contacts, steering plus
  jump/fire, cancellation, rotation and explicit pause/resume. They were
  inspected, not rerun as part of the above 91 checks.

Detailed diagnostic logs are retained locally, outside the public repository.
Early test-only runs incorrectly expected an idle spare audio channel to report paused, and
stopped audio before the mixer had processed its startup. The final fixture
uses an actual two-channel crossfade and allows mixer retirement. Those early
fixture failures are not production audio defects.

## Export and shell requirements

1. Use the Compatibility renderer and a single-threaded Web export. Export
   basenames and loader configuration must match. Do not rename individual
   generated files casually. HTTPS and WebGL 2 are required browser baselines.
2. The Godot 4.6.3 generated loader explicitly rejects Safari below 15.2.
   This is only a minimum gate, not a claim that every newer iPhone passes.
3. On Web, `DisplayServer.get_display_safe_area()` does not provide the native
   iOS/Android notch implementation. Bound the canvas with CSS safe-area inset
   values on all four sides. Browser chrome changes and rotation must resize it.
4. The generated loader's canvas resize policy 2 overrides inline top/left and
   sizes from `window.innerWidth/innerHeight`, ignoring a padded parent. A
   shell-managed safe canvas needs policy 0 with explicit backing/CSS dimensions
   and resize handling. Fullscreen must be optional, requested only from a user
   action, and must not defeat safe bounds.
5. Provide a visible tap/keyboard start and browser-audio guidance. Do not
   promise sound before the browser grants user activation. Prevent default
   scrolling, gestures and context menus on the game region, without trapping
   help/error text in an unscrollable panel.
6. Landscape is the playable layout. A 390px-wide portrait letterbox does not
   produce full-size phone controls. Reference 844×390 and 568×320 landscapes
   meet the fixture's 44 CSS-pixel actions. If browser chrome and safe margins
   reduce effective canvas height below about 313px, the smallest 76-unit
   action becomes smaller than 44 CSS pixels. Check the actual target device.
7. Touch is intentionally P1-only. On a phone, recommend Solo or CPU mate.
   Local P2 is labeled keyboard input and requires separate supported input;
   two people sharing phone touches is not implemented or certified.

## Browser-specific storage, lifecycle and audio risks

- `user://native-preview-save.json` uses FileAccess and atomic temporary-file
  replacement. In the browser, lasting storage depends on IndexedDB. A write
  returning OK may only prove in-memory success. `OS.is_userfs_persistent()`
  can give false positives. Warn that storage is best effort, especially in
  private browsing, embedded pages, restricted storage or after browser data
  eviction. Test reload and a separate reopen at the same origin.
- Native notifications already release contacts and pause live game/story.
  The generated Web loader registers canvas focus/blur. Browser visibility,
  app-switch and interruption mapping must be tested in the exported game;
  background script suspension alone does not prove neutral input on return.
- The Godot Web default Sample audio path is different from native Vorbis
  streaming. In the actual exported `index.js`, sample registration allocates
  two Float32 audio channels, then playback duplicates the whole buffer.
  A retained sample buffer costs roughly `8 × sampleRate × seconds` bytes,
  excluding playback copies and temporary decoding buffers. For 60 seconds at
  48kHz this is about22MiB per buffer. Compressed `.res` byte sizes therefore
  do not represent browser audio memory. The score adapter caches requested cues. A separate repair now sets both
  score players to Stream **on Web only**, leaving native defaults and sound
  effects unchanged. The source/engine policy has a separate regression, but browser
  memory/latency still needs measurement.
- Small effects retain low-latency sample playback. Browser-only Stream music
  avoids the full-track Sample registration path but trades it for audio
  processing/latency risk. Actual browser listening remains unverified.
- The first Load tap precedes a large asynchronous download and is **not**
  an audio-unlock guarantee. The final loader registers synchronous canvas
  touchstart/touchend, mouse-button and keyboard callbacks. Matching Godot
  4.6.3 engine code resumes audio from those callbacks, including touchend;
  the final loader calls `AudioContext.resume()` when its context is not
  running. A fresh post-load game/title tap therefore has the intended
  activation path. A separate DOM button is unnecessary and would not itself
  reach the canvas listeners. Use “After loading, tap the game to enable sound”
  rather than asserting the download tap unlocked it. This is source evidence,
  not verified Safari audio output or a guarantee against device interruptions.
- The audited export is approximately278.5MiB PCK plus35.9MiB WASM. The pack
  is mostly texture payload. Chunked hosting must stream without retaining
  another concatenated pack copy, preserve `application/wasm`, propagate
  errors/cancellation and verify the assembled bytes. Loading and GPU texture
  memory still require measurement on the target iPhone.

## Actual browser observations and blocker

The final preview entry page was opened in the desktop browser at the local
preview server. Its visible final state shows Work
in progress, the approximately314MiB first-download warning, Solo/CPU phone
advice, audio interaction advice and storage caveat. At1180×757 CSS pixels,
frame and canvas bounds match; the Start control is50px high. DOM observation
confirms game touch-action:none and a scrollable gate with pan-y. These are
desktop shell observations, not iPhone safe-area values.

Clicking Load and play in the available cloud Chrome reports missing WebGL2
and offers Reload and retry. Desktop inspection confirms that the desktop
Chromium is the same browser instance. Its read-only `chrome://gpu` page shows
WebGL and OpenGL disabled. No browser flags, security settings or sandbox were
changed. This is an execution-environment capability blocker, not a game crash.
**No actual Web game rendering, physics, audio or durable storage was observed.**
The final entry screen was reloaded after the preliminary assets were replaced
with the final export. GPU capability still prevents proceeding beyond the gate.

The initial full export manifest recorded PCK SHA256
`91d854a970e18f252421e91f3e4b8cb5f629f1a1e5b51941d34ba6dc8c8825e1`
and WASM SHA256
`26b61ce95247012ab3dca3ff51e96d1cdbff44ee91a8c20a83e150afca83f1b6`.
Local packaging independently validates chunk reassembly; this browser does not.

The smaller complete-game export excludes only 36 unused original web stage-title
textures and their import remaps. Its PCK is 260,165,440 bytes with SHA256
`647de4318d26edf61e4b7cbb1312166a2428871e4f04b99366a0ecd9a12605fd`.
The WASM is unchanged. All 1,243 retained payloads are SHA256-identical to the
preceding export, and all 304 packed-runtime checks pass. The revised first
download is about 284.4 MiB before HTTP encoding, not the initial 314 MiB notice
described above. Shell text is generated from its actual export inventory.

## Actual browser/device acceptance still required

- Successful first load and retry with real exported assets, no engine/JS
  exceptions, no missing chunks, no swallowed permanent loading screen.
- Tap start, title, story, character/CPU choice, stage load and visible gameplay.
- Steering plus jump/fire; release, drag off controls, cancellation and menu.
- Background while steering/firing, return, explicit resume and neutral input.
- Landscape rotation, browser chrome, notch/home indicator and portrait advice.
- Sound only after interaction; menu sound toggle, pause/resume and no doubled
  or stuck crossfade playback. Actual listening and iPhone output remain open.
- Save a visible preference/progress through UI, reload, then reopen the same
  origin; test unavailable storage warning without falsely claiming durability.
- Long-session memory, frame pacing, audio latency and WebGL context recovery.

A successful desktop/cloud Chrome run will not certify iPhone Safari, hardware
multitouch, gamepads, normal-health campaign difficulty or App Store readiness.

## Source basis

- [Godot4.6 Web export](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_web.html)
- [Godot4.6 DisplayServer safe area](https://docs.godotengine.org/en/4.6/classes/class_displayserver.html#class-displayserver-method-get-display-safe-area)
- Production `main.gd`, `party_input.gd`, `touch_controls.gd`, `save_store.gd`,
  `game_audio.gd`, `original_score.gd`, `character_select.gd`, `title_menu.gd`.
- Generated Godot4.6.3 `index.js` in the separately prepared Web export: canvas
  updateSize, display notification callbacks, audio sample registration and
  Sample buffer duplication. Loader internals were inspected read-only.
- Matching official Godot4.6.3 source:
  [display input callbacks](https://github.com/godotengine/godot/blob/4.6.3-stable/platform/web/display_server_web.cpp#L670-L717),
  [OS audio forwarding](https://github.com/godotengine/godot/blob/4.6.3-stable/platform/web/os_web.cpp#L62-L64),
  [audio driver resume](https://github.com/godotengine/godot/blob/4.6.3-stable/platform/web/audio_driver_web.cpp#L152-L156).
