# Separate Godot browser demo

The `Web Demo` preset exports the actual Godot game, with all six worlds and
42 stages. It does not run `scripts/build-web.mjs`, replace `game/`, change the
original web deployment, or migrate its browser saves. Publishing the result
is a separate step, not a side effect of this helper.

## Reproduce the export

1. Prepare the complete checkout using `scripts/prepare-native.py` as described
   in [editing on another computer](EDITING_ON_ANOTHER_COMPUTER.md).
2. Obtain the official **Godot 4.6.3 standard export templates**, not the Mono
   package. Verify the archive against its official checksum. Extract its
   `templates/` folder outside the repository.
3. Export into a new, empty directory:

```sh
python3 scripts/export-native-web.py \
  --templates-dir /path/to/templates \
  --output-dir /path/to/empty-web-demo
```

The helper uses isolated temporary settings and template directories. It does
not modify a user's installed editor settings, install packages, publish files,
read signing keys, or overwrite a previous export. `--check` verifies prerequisites
without exporting. The output includes a size/hash manifest.

The archive used here was `Godot_v4.6.3-stable_export_templates.tpz` from the
[official Godot release](https://github.com/godotengine/godot-builds/releases/tag/4.6.3-stable).
Its complete SHA512 matched the release checksum:

`da606b61c10157844f8300172df374472665f95015495cb1a7cd132c40ede404faa96cc1016a4b9662db9909ddea69632c4948b2cd11163438dad4808881fb68`

## Deliberate settings

- Single-threaded WebAssembly with no extensions. This avoids requiring
  cross-origin isolation, which also makes a later arcade embed easier.
- Compatibility renderer / WebGL2. No change to the original painted artwork.
- Lossless textures. Mobile VRAM compression is disabled because the project
  has no ETC2 importer configured; enabling that export option alone makes
  Godot reject the export. This does not prevent mobile browsers using the
  existing lossless textures.
- No PWA/service worker or automatic offline caching in the first demo.
- Source data, all levels, runtime-referenced original artwork, fonts/notices and prebuilt audio
  are included. Tests, raw audio intermediates and source-reference scripts
  are excluded just as in the native presets.
- Only long music uses Web streaming playback. Short effects keep their
  default low-latency path; native music behavior is unchanged.
- Window/canvas focus loss pauses the game and releases contacts. Returning
  focus does not resume gameplay until the user chooses Resume.

## Hosting and phone requirements

Serve the complete export over HTTPS, keeping the generated filenames together.
Do not open the HTML with `file://`. A hosting wrapper may split large binary
assets into streamed, byte-identical chunks to meet a per-file limit. Such a
wrapper must preserve MIME types, length, errors and aborts, and must not retain
another complete copy of the game pack unnecessarily.

The current export contains **260,165,440 bytes of game data plus 37,700,666 bytes
of WebAssembly**, about 284.4 MiB with the smaller support files, before HTTP
content encoding. Recommend Wi-Fi and show size and download progress before
the user starts. This is a full-content development demo, not a small first-level
download.

### Exclude unused titles without changing the game

The initial export also bundled 36 original web stage-title JPEG imports that
the native runtime never uses. The native Bill Dodgers title, official selector,
all stage paintings, sprites and cutscenes remain included. The exact Web-only
list is `scripts/native-web-title-exclusions.json`. No source/import files are
deleted, and the Android/iOS presets are unchanged.

`check-web-title-exclusions.py` verifies original bytes/provenance, every current
runtime data reference, and the reviewed dynamic resource loaders. The export
helper invokes it automatically and requires the exact preset list. A future
reference, changed loader or changed original blocks export until reviewed; do
not refresh fingerprints blindly to hide a failure.
Direct editor exports do not invoke this Python helper. Run the checker first
if exporting through the GUI, then rerun the packed-runtime checks.

The reduced pack removed only 36 textures and their 36 import remaps. All 1,243
retained payloads have identical SHA256 to the preceding export; the generated
UID index changes to reflect the removals. All 304 packed-runtime checks pass
again. The official hosting archive measures **265,837,541 bytes / 253.5224 MiB**,
below its 256 MiB input limit by 2,597,915 bytes. This margin must be rechecked
after changes. No artwork quality, gameplay or story content was reduced.

The mobile shell needs an explicit start gesture for audio, landscape/rotation
guidance, CSS safe-area bounds applied to the actual canvas, and no browser
scroll/zoom stealing game touches. Solo or CPU companion is the phone-touch
choice; local player 2 requires the second keyboard/controller input, not a
second on-screen joystick. Save persistence depends on browser IndexedDB and
storage policy. Private browsing, eviction and embedded third-party restrictions
can prevent durable saves. Do not promise persistence from a single API probe.

Godot's loader requires Safari 15.2 or later and WebGL2. Two preserved artwork
strips are 5,591 pixels wide, so the target's texture-size limit also matters.
This minimum is an engine capability requirement, not proof that every supported
iPhone has acceptable performance.

## Evidence and remaining acceptance

The release export and its file headers/hashes were verified locally. New
export helper tests (6), exact title-exclusion guards (6), Web source guards (6), native Web-foundation checks
(91), and real-main window-focus checks (21) pass. Story texture release and
Web audio policy have separate regressions documented in
[the resource profile](NATIVE_RESOURCE_PROFILE.md).

Run the isolated prerequisites with `bash scripts/verify-web-foundation.sh`.
The final exported Web PCK also passed all 304 asset-free packed-runtime checks,
including all 42 stage loads. That gate runs the resource pack with the native
engine; it is not a WebGL rendering or browser-performance test.

The available cloud Chromium has WebGL and OpenGL disabled. Its actual browser
test verifies the start gate, unsupported-renderer error and retry presentation,
not game rendering. No browser flags/security settings were changed to hide
that limit. Physical iPhone Safari loading, play, touch, audio, saves, background
recovery, memory and performance still require a real device. See
[Web runtime acceptance](WEB_RUNTIME_ACCEPTANCE.md) for the precise test scope.

Reference: [Godot 4.6 Web export documentation](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_web.html).
