# Rive HUD assessment

Verified 9 November 2026. Scope: Bill Dodgers HUD only. No gameplay, characters, worlds, menu, production configuration, dependency, or export changes were made by this assessment.

## Recommendation

Keep the shipping HUD in Godot while evaluating **one isolated special-charge widget** in Rive. Rive is useful when authored vector motion, reactive states, and designer iteration justify another toolchain. It is not necessary for a polished charge meter, buttons, hearts, counters, or transitions. The existing Godot HUD already reads authoritative ability state and has per-housemate colour, a fill/remaining-duration meter, ready feedback, and paired-player layouts.

A convincing standalone Rive result would prove that a visual can be authored and played, not that the Godot iOS, Android, and web integration is solved. Do not replace the rest of the game with Rive.

## Verified integration and license findings

- **Official runtimes:** Rive lists Apple, Android, web, C++, and several supported engine/framework integrations. Its own comparison explicitly says it has no official Godot runtime listed. Native Apple/Android support is not evidence that their runtimes plug into a Godot export. Sources: [runtime list](https://rive.app/runtimes), [official runtime guide](https://rive.app/docs/runtimes/getting-started), [Rive's Godot comparison](https://rive.app/rive-vs-spine).
- **Community Godot candidate:** `kibble-cabal/godot-rive` calls itself alpha, targets Godot 4.1+, says build instructions were tested only on M1 macOS, and requests help with Android, iOS, Linux, Windows, and web. Its sample extension descriptor lists macOS libraries only. This is not verified support for our installed Godot **4.6.3.stable.official.7d41c59c4** or any phone/web export. Sources: [maintainer README](https://github.com/kibble-cabal/godot-rive), [extension descriptor](https://github.com/kibble-cabal/godot-rive/blob/main/demo/rive.gdextension).
- **Candidate renderer:** Its source allocates a Skia raster surface and copies the rendered pixels into a Godot byte array. Do not assume it uses today's Rive GPU renderer or inherits that renderer's feature/performance claims. Benchmark any replacement integration on actual devices. Source: [Skia implementation](https://github.com/kibble-cabal/godot-rive/blob/main/src/skia_instance.hpp).
- **Runtime license:** Official Rive runtimes are MIT-licensed, including commercial use. Keep applicable copyright/license notices and inspect bundled third-party notices. This does not license the Editor/CLI or someone else's art. Source: [runtime licensing](https://rive.app/docs/runtimes/getting-started#licensing).
- **Plugin license:** The candidate's open issue #21 reports no license file, and the inspected root had no license file. Treat redistribution rights as unresolved; the upstream Rive MIT license does not automatically license the integration code. Source: [maintainer issue](https://github.com/kibble-cabal/godot-rive/issues/21).
- **Authoring terms:** Rive authoring is offered under vendor terms, distinct from the runtime MIT licenses. The pricing page currently advertises free exports with a Rive splash screen and paid splash removal. Do not assume old paid-export restrictions or quote a subscription price without checking billing cadence. No subscription was purchased. Sources: [pricing](https://rive.app/pricing), [terms, updated 20 May 2026](https://rive.app/docs/legal/terms-of-service).

## Renderer and export boundary

The current project selects `gl_compatibility` for desktop and mobile. Godot 4.6's web export uses WebGL 2 and Compatibility, not Forward+/Mobile. A GDExtension needs its own web compilation, extension support, and cross-origin isolation setup. A native macOS library is not portable to a web export. The existing web game in `game/` is a separate JavaScript implementation, not a verified Godot web build. Source: [Godot 4.6 web export](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_web.html).

For official Rive web usage, `@rive-app/webgl2` uses the Rive Renderer; `@rive-app/canvas` uses Canvas2D; `canvas-lite` deliberately omits features. Apple and Android Compose use the Rive Renderer. Features vary by runtime and renderer. Vector feathering needs the Rive Renderer; layer masks need GPU Canvas. A successful web preview does not verify the community Godot/Skia path. Sources: [renderer choices](https://rive.app/docs/runtimes/choose-a-renderer/overview), [feature support](https://rive.app/docs/feature-support).

## Native Godot comparison

Use `Control` for safe-area layout, focus/navigation, and hit targets; `CanvasItem` or the existing command renderer for the art; `Tween`/`AnimationPlayer` for a ready pulse and pressed response; and a small Compatibility-tested canvas shader only when it materially improves the result. The game retains one renderer, lifecycle, input route, and export toolchain. Rive earns its cost if the visual design needs substantially richer stateful vector motion and an author wants to iterate in its tools. Neither choice guarantees better frame time, smaller downloads, or lower battery use without measurements.

References: [Control](https://docs.godotengine.org/en/4.6/classes/class_control.html), [Tween](https://docs.godotengine.org/en/4.6/classes/class_tween.html), [CanvasItem shaders](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/canvas_item_shader.html).

## Isolated concept: special-charge capsule

One compact capsule combines the character-colour charge bar with a small ability emblem. The gameplay area stays visually quiet. A ready state gets a single arrival pop, then a restrained breathing outline. Activation changes the fill to remaining duration, with a short outward accent. No whole-screen effect or UI-driven damage.

### State contract

The existing source of truth is `PlayerHUD.special_state(member)` in `godot/src/player_hud.gd`. Preserve its exact semantics:

- `charging`: no active ability and `meter < 1`; fill is the actual charge ratio.
- `ready`: no active ability and `meter >= 1`; fill is one. Use a readable ready label, not colour alone.
- `active`: ability is active and remaining time is positive; fill is `remaining / duration`, clamped to `[0, 1]`.
- `unavailable`: a presentation/input overlay for pause, story, death or another host lock. Do not invent a cooldown or change the underlying ability state.

The current reset starts the meter at `0.5`. It charges over time and from defeated enemies under the existing rules. Activation clears the meter; an active special shows duration remaining; charging resumes afterward. The display must not substitute its own timer or charge rules.

### Adapter boundary

A proposed presentation snapshot contains `actor_slot`, `character`, `ability_name`, `accent_rgba`, `fill_01`, `phase`, `can_activate`, `is_cpu`, `input_hint`, `paused`, and `reduced_motion`.

The game constructs snapshots. A native view or a future Rive adapter consumes them. Both implementations are replaceable behind the same view boundary. The UI never writes meter, duration, damage, coins, or active ability state.

A visual button may emit `activation_requested(actor_slot)`. The existing game input system validates player ownership, readiness and play state, then calls its normal special-input path. Animation events must never trigger gameplay effects. CPU slots show status only. Paired slots remain independent. Text remains unmirrored when the second bar fills from right to left.

Entry effects are edge-triggered once per phase transition, not once per frame. Restart/retry, character change, or loading a new scene rebinds and clears presentation history. Pausing/backgrounding freezes decorative animation and releases any pressed state. A reduced-motion version retains text and fill while removing looping pulses.

### Acceptance before any production adoption

1. Compare charging, just-ready, active, exhausted, paused, and reset snapshots against the existing native HUD, for all six characters and paired actors.
2. Repeated taps, held presses, cancelled touches, focus loss, pause/resume, and actor switching must never cause duplicate activations.
3. Verify safe-area layout, small-screen legibility, gamepad focus, readable labels, and non-colour state cues.
4. Validate real iOS and Android builds plus the intended web route, including renderer/features, extension artifacts, loading/error fallback, and context loss where applicable.
5. Measure baseline vs Rive frame time, memory, startup/package size, and battery on target devices. Keep native fallback if the integration or asset fails.
6. Clear plugin/runtime/art/font licensing. Pin and test actual authoring, runtime, and integration versions together.

## Genuine Rive preview feasibility

The official **Rive CLI** can compile editable `scene.rml` plus `rive.yaml` into a real runtime `.riv`. The online command reference listed `--once` for an unsigned file, but the verified v1.9.2 executable rejects it as removed. `--verify`, `inspect`, and `--screenshot` work locally; actual `.riv` export now requires login through `--publish`. Local creation, compilation and capture do not require login. A `.riv` is a runtime asset, not the Editor source format: `.rev` export or push to the Editor requires login. No account is needed to keep editing the RML locally.

A custom preview should use RML shapes, timelines, state-machine/data bindings, and no scripts. Official docs say unsigned scripts are rejected by web runtimes, while files without scripts are unaffected. Do not describe hand-drawn HTML/SVG or a generic sample as a custom Rive HUD. Sources: [getting started](https://rive.app/docs/cli/getting-started), [command reference](https://rive.app/docs/cli/reference/commands), [RML](https://rive.app/docs/runtimes/advanced-topic/rml).

Metadata checked on 9 November 2026:

- CLI `1.9.2`, Linux x64, from `https://releases.rive.app/cli/v1.9.2/rive-linux-x64.tar.gz`.
- Tarball SHA-256 in both official manifest and official Homebrew cask: `e606530230ad8ddc4869d1ade4de10c5ffb3e74e44745339c227018e65eabb0b`.
- [Official cask metadata](https://github.com/rive-app/homebrew-tap/blob/main/Casks/rive-cli.rb), [manifest](https://releases.rive.app/cli/latest/manifest.json), [installer](https://releases.rive.app/cli/install.sh).
- Before approval, the installer text was downloaded and read only. It supports `RIVE_HOME` for a workspace-local installation, pins with `RIVE_VERSION`, checks the manifest SHA, and does not need sudo or shell-profile edits.
- CLI analytics can be disabled from the first invocation using the documented `RIVE_ANALYTICS=off` and `DO_NOT_TRACK=1` variables. Avoid login, publish, remote push, account creation, paid options, and persistent credentials.

## Executed preview update

The user approved downloading and running the official Rive tool after its terms were disclosed. The official v1.9.2 archive passed its SHA-256 check and was installed in an isolated workspace, without a global installation or shell-profile edits. The executable reports `rive 1.9.2`; executable SHA-256 is `a6349a9fab0b39951e6500b84494425d5b7d1f0a8ae56b0aaa93296b518e02a1`.

The loader initially lacked `libGLESv2.so.2`. Debian `libgles2` 1.7.0-1+b2 was extracted locally after the official repository's signed Release and package checksum were verified. Package SHA-256: `e12c18aa77939d122ee1dea520ba0440b97dc19200b7396e03dff03a3ece74c1`. Its library path is applied to Rive processes only; no system installation occurred.

A custom RML charge HUD now passes official CLI verification with zero errors/warnings and inspection with no problems. Genuine Rive captures demonstrate Charging, Ready, and Active. Editable RML and an eight-second rendered video are the deliverables. The displayed values are simulated and accelerated, not connected to gameplay. No scripts, account, payment, remote upload, or deployment were used. Rive authoring terms apply: https://rive.app/docs/legal/terms-of-service .

**Export remains blocked by the no-account scope.** The actual executable says `--once` was removed and requires login plus `--publish` to write a `.riv`. No `.riv` or Editor `.rev` was exported, and no workaround was attempted. This corrects the initially documented unsigned-export path. No native-device or Godot-Rive integration claim is made.
