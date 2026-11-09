# Separate mobile browser preview wrapper

This optional tooling prepares the **actual Godot Web export** for a separate
static host. It does not publish, create an account/project, configure access,
charge for hosting or alter the original Canvas website. Owner-only access is a
hosting setting, not protection supplied by these files. Do not infer privacy
from `noindex`, `_headers`, a filename or the generated README.

## Prepare and verify

Use a current Node.js LTS runtime (Node 22+; verified with Node 24). No npm packages
are needed. First create the export with `scripts/export-native-web.py`, as
explained in [the Web demo guide](../../docs/GODOT_WEB_DEMO.md). Use a new output
directory outside the game repository; do not point this at the existing site.

```sh
node scripts/web-preview/prepare-site.mjs /path/to/web-export /path/to/new-preview
node scripts/web-preview/test-chunk-fetch.mjs
node scripts/web-preview/test-gzip-fetch.mjs
node scripts/web-preview/verify-site.mjs /path/to/new-preview
node scripts/web-preview/test-mobile-shell.mjs /path/to/new-preview
node scripts/web-preview/test-preloader-recovery.mjs /path/to/new-preview
node scripts/web-preview/test-export-streams.mjs /path/to/new-preview
```

Preparation rejects an existing `dist` directory. It reads the Godot export,
creates `dist`, a byte inventory and a descriptive README. It keeps the generated
engine/audio JavaScript unchanged and replaces only its HTML shell. It splits
large PCK/WASM binaries into 19 MiB source parts, stores explicit lossless `.gz`
files, and emits a manifest-backed streaming fetch adapter. The result requires
Safari 16.4+ (native `DecompressionStream`) and WebGL 2. The source artwork requires
MAX_TEXTURE_SIZE of at least 5,591 pixels; the shell checks before downloading.

The full-content preview downloads about 254 MiB compressed and reconstructs
about 284 MiB of assets. Recheck individual file, total archive **and expanded
archive** limits for the chosen host. These limits are separate. The successful
2026-11-09 archive has only about 2.2 MiB of expanded-size headroom under 256 MiB.

## Verified behavior and limits

- Every decoded PCK/WASM byte and hash matches the export. Other engine/audio
  files remain identical. No artwork quality, stages or cutscenes are removed.
- One chunk reader is active at a time. HTTP errors, unexpected HTML, wrong
  lengths, corrupted/truncated gzip and aborts reach recovery handling.
- Auto-decoded HTTP responses are distinguished from stored gzip using the
  recorded raw prefix and content headers; the adapter avoids double decoding.
- A separate error event exposes Reload and retry for mid-body failures even
  when Godot's unchanged progress wrapper leaves its startup promise pending.
- The shell prevents repeated starts, reserves safe-area/storage-warning space,
  releases canvas focus on backgrounding, and does not resume automatically.
- The first download tap is not a sound-unlock promise. Tap the loaded game to
  enable sound. One phone's touch controls are P1-only; use Solo or a CPU mate.
- Browser saves remain best effort and separate from the original web save.

The full-stream test uses the exact exported Godot progress wrapper and the
Node WebAssembly compiler. It is **not** a browser rendering test. Godot still
buffers the complete pack; no end-to-end zero-copy or iPhone memory guarantee
is implied. Physical Safari touch/audio/storage/performance acceptance remains
open. Never disable browser security to turn a blocked test into a pass.

Generated binary chunks, export inventories, hosting credentials/configuration,
service state and deployment logs do not belong in this source directory.
