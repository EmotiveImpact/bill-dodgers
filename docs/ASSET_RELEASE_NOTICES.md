# Asset and font release notices

Audit date: 2026-11-09. Scope: supplied web assets, their deterministic native
copies, bundled fonts and the notice-delivery requirements of the current
Godot project. This is a release checklist, not a legal opinion or a certificate
that every game asset is commercially cleared.

## What is verified

- The user has authorized adaptation of the supplied game, source art and all
  six worlds. This audit does not revoke or narrow that development permission.
- `scripts/import-godot-content.py` records source and asset SHA-256 values in
  `godot/content/manifest.json`. At audit time it inventories 531 asset files:
  435 embedded images, 77 cutscene images, 16 sprite image/data files, two fonts
  and the title image. The catalog contains six worlds and 42 stages.
- The two native WOFF2 files are byte-identical to their counterparts under
  `game/cutscenes/img/` and the existing `dist/cutscenes/img/`. No font binary was
  changed in this audit. Hashes establish identity, not ownership or permission.
- FreeType's existing `FT_Get_Sfnt_Name` API identifies the actual local fonts.
  Their family names, copyright records and OFL URL agree with the official
  upstream metadata and license files listed below.
- No root game license, asset license/notice file, or art/audio rights schedule
  was found in the supplied source. A bounded search of `game/**/*.html`,
  `game/**/*.js` and `game/**/*.json` found no copyright/license/attribution
  declarations. This absence does not establish that the user lacks rights.

## Verified bundled fonts

### Silkscreen

- Native file: `godot/assets/fonts/silk.woff2`; source:
  `game/cutscenes/img/silk.woff2`.
- Size: 3,528 bytes.
- SHA-256: `17bb6d80eeea10c69887aa64a1b48e70a3f540de50480da9ec933fac1996bf97`.
- Embedded family/style: Silkscreen / Regular. Name ID 5:
  `Version 1.001; ttfautohint (v1.8.4.7-5d5b)`.
- Embedded copyright: Copyright 2001 The Silkscreen Project Authors
  (`https://github.com/googlefonts/silkscreen`). Name ID 14:
  `https://scripts.sil.org/OFL`.
- [Official Google Fonts metadata](https://github.com/google/fonts/blob/main/ofl/silkscreen/METADATA.pb)
  identifies the family as OFL, designer Jason Kottke, and upstream source commit
  `206ccf3f5234c281461e63ecc59cbc6b0563472b`.
- [Pinned upstream license](https://github.com/googlefonts/silkscreen/blob/206ccf3f5234c281461e63ecc59cbc6b0563472b/OFL.txt)
  and [Google Fonts license copy](https://github.com/google/fonts/blob/main/ofl/silkscreen/OFL.txt)
  contain the matching copyright and SIL Open Font License 1.1.
- Complete local notice: `godot/legal/Silkscreen-OFL.txt`.

### Pixelify Sans

- Native file: `godot/assets/fonts/pixelify.woff2`; source:
  `game/cutscenes/img/pixelify.woff2`.
- Size: 12,008 bytes.
- SHA-256: `0f2216c1b7bf13b775e7b825c15e1c8414f3899cbd4120f275cdc96001a053a0`.
- Embedded family/style: Pixelify Sans / Regular. Name ID 5: `Version 1.000`.
  Fontconfig also exposes weight instances Regular, Medium, SemiBold and Bold.
- Embedded copyright: Copyright 2021 The Pixelify Sans Project Authors
  (`https://github.com/eifetx/Pixelify-Sans`). Name ID 14:
  `https://scripts.sil.org/OFL`.
- [Official Google Fonts metadata](https://github.com/google/fonts/blob/main/ofl/pixelifysans/METADATA.pb)
  identifies the family as OFL, designer Stefie Justprince, weight axis 400-700,
  and upstream source commit `39df74aba80df8157546034b878e8be1eb565ced`.
- [Pinned upstream license](https://github.com/eifetx/Pixelify-Sans/blob/39df74aba80df8157546034b878e8be1eb565ced/OFL.txt)
  and [Google Fonts license copy](https://github.com/google/fonts/blob/main/ofl/pixelifysans/OFL.txt)
  contain the matching copyright and SIL Open Font License 1.1.
- Complete local notice: `godot/legal/PixelifySans-OFL.txt`.

The upstream source commits are the references reported by Google Fonts, not a
claim that these particular web subsets were built from those commits. The
original download URLs and exact WOFF2 conversion/subsetting history are not
recorded in this repository. This audit verifies the fonts' embedded attribution
against official sources and unchanged source/native bytes; it does not claim a
byte-for-byte comparison with a newly downloaded upstream font distribution.

Both license texts permit bundled use under their conditions, including retention
of the copyright and full license. The font software remains under OFL; this does
not impose OFL on the game. Neither inspected copyright header declares a
Reserved Font Name. No game-wide license or third-party art rights were inferred
from the font licenses.

The local OFL files preserve all wording, including the complete copyright,
conditions, termination and disclaimer. Only whitespace/paragraph layout was
normalized from the official rendered files. Each was checked against both the
pinned upstream text and Google Fonts copy with whitespace normalized. The
following are hashes of our checked-in notice files, not upstream raw-byte hashes:

- `Silkscreen-OFL.txt`: `21a059f6c87163c98015ff1fea9445f30f26d7ce322cfc520c27d80485d5fb4f`.
- `PixelifySans-OFL.txt`: `17316b6c90639d1043ba74a80905fcf935e662a4c66ce9a3384d0e2d0aa0b13e`.
- `godot/legal/FONT_NOTICES.txt` is the human-readable index to these licenses.

## Packaging and readable notices

Godot's `all_resources` export setting does not automatically include ordinary
text files. Both Android and iOS presets must explicitly include `legal/*.txt`
in their `include_filter`. This is separate from the existing JSON/audio rules.
See [Godot 4.6 non-resource export filters](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_projects.html).

Both current development presets include `legal/*.txt`. Exported-pack assertions
are a separate integration check. Before release, inspect the actual output and read each of the three notice files
from the mounted pack. Source-file existence is not proof of export inclusion.
The same notice requirement applies if the web build is distributed: its build
must copy the relevant notices into that distribution. This audit makes no web
build edits and does not publish anything.

Provide a practical way for mobile players to read these notices. PCK inclusion
alone is not evidence that users can access them on a phone. The standalone view
described below is implemented, but title/main integration and physical-device
validation are separate gates. The source cast credits remain unchanged.

## Godot runtime notices: use the official APIs

Godot exposes the engine and its component notices directly. Do not manually
recreate them or assume the project must maintain a second static copy.

- [`Engine.get_license_text() -> String`](https://docs.godotengine.org/en/4.6/classes/class_engine.html#class-engine-method-get-license-text):
  complete engine license text.
- [`Engine.get_license_info() -> Dictionary`](https://docs.godotengine.org/en/4.6/classes/class_engine.html#class-engine-method-get-license-info):
  license-name keys mapped to full texts for engine/third-party licenses.
- [`Engine.get_copyright_info() -> Array[Dictionary]`](https://docs.godotengine.org/en/4.6/classes/class_engine.html#class-engine-method-get-copyright-info):
  component records with `name` and `parts`. Each part has `copyright` (Array),
  `files` (Array) and `license` (String). Preserve the license expression as given;
  do not assume every expression is a single dictionary key.

A read-only isolated probe passed on installed Godot
`4.6.3.stable.official.7d41c59c4`: 1,149 engine-license characters, 19 license-map
entries, 99 copyright components and 103 parts. These are observed desktop-engine
values, not expected constants for mobile templates. Obtain the notices from the
running release binary and test those APIs in each final mobile export.

### Standalone view and remaining host integration

`godot/src/legal_notices.gd` implements a standalone read-only `Control`:

- `build_text(engine_license, components, licenses, font_texts)` is a static pure
  formatter. It has no filesystem, Engine API, node, network or save side effects.
- `configure(source_font = null, safe = Vector2(18, 14))` accepts a font and
  logical safe-area padding before or after entering the tree. Null uses the
  engine's fallback font.
- `open()` reads the three bundled font files and the exact Engine APIs above.
  Missing/empty font notices are reported in the displayed text and the public
  `missing_notice_paths` array rather than silently discarded.
- `close()` hides silently for host replacement. User Close, Escape and Android
  Back hide and emit `close_requested` once. The host decides where to return.
- The view owns viewport-resize layout, touch scrolling, direct scrollbar
  scrubbing for long notices, and canceled-contact
  handling. Close and the scrollbar retain at least 44 screen-pixel targets for
  the tested phone/window sizes. It remains usable while the host tree is paused.
- The selectable `RichTextLabel` has BBCode disabled, preserves complete font and
  engine text, and contains no network navigation or saved-game writes.

`godot/tests/test_legal_notices.gd` passes 602 checks on Godot 4.6.3, covering every
runtime copyright/source-path/license entry, all full font texts, deterministic
formatting and unchanged inputs, literal BBCode-like text, scroll overflow/native
touch drag/scrollbar scrub, canceled/dragged-out/focus-interrupted/resized touches, repeated open,
Close/Escape/Android Back idempotence, pause behavior, and portrait/landscape resize
from 568x320 to 1280x720. These are focused headless checks, not physical-device
visual or accessibility acceptance.

Six actual desktop OpenGL framebuffer captures also show the beginning and end
of the notice text with a fixed heading/Close control. The 960x540 and small
568x319 rendered images were visually inspected; Close measures approximately
112x48 screen pixels and the text remains readable. A requested 390x844 desktop
window produced a letterboxed 390x219 viewport under the project's aspect rules,
so that capture is not evidence of a portrait phone layout. These local audit
images are named `native-artifacts/legal-notices-desktop-*.png` outside the
repository, with `legal-notices-render.log` alongside them. The only renderer
warning was the existing llvmpipe V-Sync limitation. No physical phone is claimed.

Remaining host integration recommendation:

1. Add a read-only Licenses entry to the ordinary title/menu, available before
   completing the game. Keep the source cast credits unchanged.
2. Instantiate the standalone view under the host's screen-space UI, configure its
   font/safe padding, add it to the active tree and call `open()`. Connect
   `close_requested` to restore the previous menu without changing saved progress.
   Ensure host input/navigation does not also handle the same Back request.
3. Keep complete texts in the view rather than substituting network links. The
   formatter includes all returned license-map entries and preserves composite
   component license expressions without trying to parse them as map keys.
4. Verify long scrolling, text selection, touch targets and readable text on
   iPhone and Android, plus reopening after pause/background. Recheck packed
   notices and actual mobile Engine API output in the final release export.

[Godot's licensing guidance](https://docs.godotengine.org/en/4.6/about/complying_with_licenses.html)
recommends engine/component notices and explains user-accessible delivery options.
The font notices do not replace these engine notices.

## Remaining release decisions and evidence

1. **User-provided art/story/source audio provenance.** Keep the already-authorized
   adaptation. Before certifying store/commercial release clearance, record the
   publisher's authority to distribute the supplied sprite sheets, backgrounds,
   title/cutscene art, story and source audio, along with any third-party creator
   attribution or terms. Use the manifest to identify exact assets. Ownership,
   commissioned-work permission, or applicable generation/service terms may be
   relevant depending on their actual origin. No such origin is invented here.
   Replace only assets shown to lack needed permission, not all supplied art by
   default. Keeping a repository public is not itself an asset license.
2. **Prototype score approval.** `godot/assets/music/score_manifest.json` describes
   18 locally synthesized cues; `scripts/compose_soundtrack.py` provides their
   reproducible construction. This is project provenance, not a blanket originality
   or copyright-exclusivity guarantee. `docs/ORIGINAL_SOUNDTRACK.md` records that
   much of the set was rejected creatively. The first title audition's reception
   does not approve the full set for release. Final track selection/listening,
   mixing and release approval remain required; no paid service rights or terms
   are claimed. New auditions outside native assets are not silently approved.
3. **Notice integration and export validation.** Verify the filter, packed full
   texts and accessible mobile view, including runtime engine/component notices.
   A headless file/API check cannot close physical-device readability testing.
4. **Web redistribution.** Before another web release, include the two OFL texts
   with the bundled WOFF2 fonts and expose appropriate notices. Existing `dist/`
   font copies were inspected, but this audit does not modify or deploy `dist/`.

This work adds the three font notice files, this document, the standalone notices
view and its focused test. It does not integrate into title/main yet, relicense the
game, assert unknown art/music rights, modify gameplay/source art, change repository
visibility, push commits or submit an app-store build.
