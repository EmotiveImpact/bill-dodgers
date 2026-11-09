# Six-world solo progression checkpoint

Verified 2026-11-09 with Godot 4.6.3. This checkpoint is a recoverable native solo baseline, not a finished mobile release.

## Verified

- `bash scripts/verify-native.sh` finished with exit 0 and its final success marker. The strict runner found no script errors, parse errors, engine errors or leaked objects.
- All 42 stages across all six housemates: 252 full input-driven progression routes, with explicit invulnerability assists to isolate mechanics from difficulty. Original waves, objective conditions, boss phases, jar pickup and clear/save paths are asserted by each family's suites. These are not unassisted playthroughs.
- World 5 full routes include all three receipts; its separate collectible suite has 2,370 checks. World 6 has 2,580 collectible checks, but the full input-driven routes do not collect every optional receipt.
- Original credits, all 36 main-stage route transitions and 19 campaign cutscenes are covered by 237 synthetic UI/story/accounting checks. Synthetic clear fixtures do not replace the gameplay routes.
- Source audio: 154 checks. Provisional score: 141 technical checks and 186 actual-host lifecycle checks. The prototype score remains artistically unapproved and replaceable.

Aggregate log SHA-256: `acc50747e243478264bb23b25249a89aa24ae81a392f34d61c9bc582fd0ca0e1`.

## Packed baseline

The same frozen baseline was successfully exported and checked on 2026-11-09.
`bill-dodgers-six-worlds-solo.pck` is 291,734,084 bytes, SHA-256
`064ebf04a04979ec7a04c846ea7ed1ab3b03239f107336d5dc57d7457b786fe8`.
An asset-free harness passed 265 packaged-runtime checks and 154 audio checks;
the separate self-contained music pack passed 92 checks. A prior attempt was
killed under memory pressure; this later complete run supersedes that failure.
This is a resource pack for a Godot runtime, not an APK/IPA or phone build.

## Deliberately separate live work

This baseline predates the newer painted map, joystick-default correction, additional particle/loot/mirroring polish, CPU/P2 integration and authorized original-web continuity changes. Those working-tree improvements have their own focused verification and are not silently included in this checkpoint's full aggregate claim.

## Release limits

No APK, IPA, signed distribution, physical-phone screenshot, controller acceptance, mobile performance/battery measurement, final music approval, store submission, public deployment or remote push is certified. Godot resource packs are game data, not installable mobile applications. Existing native export presets require the documented Android/iOS toolchain and signing setup. Rights/notices, Commune membership and the future Godot web/App integration remain release work.
