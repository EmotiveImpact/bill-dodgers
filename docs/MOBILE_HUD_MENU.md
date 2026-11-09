# Mobile game menu and graphical action HUD

Implemented 2026-11-09. This is native Godot presentation and input work, not a Rive integration, physical-device certification, or a changed game release.

## Playing

- One Menu button sits below the source 69-unit header in solo, P2 and CPU modes. It never replaces or covers either player's portrait, hearts, coins, weapon countdown or special meter. The shared Kitty remains centered. The header now draws against the actual logical viewport width.
- Opening Menu pauses gameplay and audio, releases steering/fire/action contacts and presents Resume, Story, Sound On/Off and Level map. Sound stays paused while toggling. Story enters synchronously without a gameplay tick, then follows its existing return-to-play behavior when finished/skipped. Focus loss during story returns to the story only after explicit Resume. Returning to the map cannot be undone by a stale Resume signal.
- There are no character/party selectors in gameplay. Those choices remain on the level-selection screen. Story launched outside gameplay supports the same pause panel without adding a stray gameplay launcher afterward.
- Menu taps use native ScreenTouch capture, not solely Godot's single-finger mouse emulation. A third finger can open Menu while movement and fire remain held. Emulated duplicate clicks are suppressed. Dragging away, cancellation, focus loss and resize cancel pending activation.
- Jump is an original arrow/ground icon; Shoot is an original crosshair; earned Dash is a double chevron. Special is an original bolt with the character-coloured ring showing actual charge or active remaining time, with a filled ready state. No third-party game artwork or new downloaded assets were used.
- The selected joystick remains the default. Circular artwork does not shrink the rectangular touch targets or change movement, firing, special abilities, party simulation, progression or earned-card rules.

## Sizing

The normal Menu target is 96×48 logical units. The pause panel and fonts compensate when the production 960×540 canvas scales into a smaller window. Compensation is bounded by available safe space: a tiny/headless 64×64 window cannot create an enormous invisible button over gameplay, and is not claimed to be playable.

Jump remains 76×76 and Shoot 86×86. Special is now 106×76, raised from `height − safe.y − 170` to `height − safe.y − 184`, leaving eight logical units above Shoot. Dash is 86×76. Their layouts remain separate from one another and the joystick. In tested 844×390 and 568×320 desktop windows, all four action hitboxes and all menu targets remain at least 44 rendered screen pixels on each axis. Rendered pixels are not a claim about physical-device points, DPI, thumb comfort, safe-area APIs or accessibility sizing.

Development/QA status text remains visible at y132. Source central stage/skill/warning messages and their mechanics remain intact. No screenshot removes the development warning to suggest a finished phone build.

## Verification

Isolated save/cache/config directories were used throughout. Final focused results:

| Suite | Passed |
| --- | ---: |
| `test_mobile_controls.gd` | 446 |
| `test_mobile_menu_integration.gd` | 264 |
| `test_touch_controls.gd` | 175 |
| `test_party_hud.gd` | 50 |
| `test_player_hud.gd` | 152 |
| `smoke.gd` | PASS, zero failures |

The module suite tests actual GUI touch dispatch at logical 960×540, 1170×540, 844×390, 568×320 and 540×960, normal/notch margins, scaled-window targets, cancellation/drag/rotation, no-overlap and all six characters' charge/ready/active drawing commands. The actual-main suite covers solo/P2/CPU at three landscape ratios, simultaneous movement/fire while opening Menu, rectangular action-edge hits, Escape, focus interruption, sound, story, map exit and stale callbacks. These are bounded fixtures, not unassisted full-game playthroughs.

Logs are in `docs/validation/mobile-hud-2026-11-09/`. Both new suites are registered with the native and party launchers. The full aggregate is a separate gate; these results do not claim that every native suite has passed.

## Actual renderer captures

`godot/tools/capture_mobile_hud.gd` refuses the headless renderer. It produced eight genuine GL Compatibility viewport PNGs with eight successful GUI Menu/Resume touch taps. The final run was 2026-11-09 at approximately 15:22 UTC, using Mesa llvmpipe and silent audio. This is desktop native rendering, not phone hardware or audio listening evidence.

Artifacts are outside the source repository under `native-artifacts/screenshots/mobile-hud/` in the parent workspace:

- `mobile-hud-solo-charge.png` and its `-menu` partner: 1280×720, solo at half charge.
- `mobile-hud-p2-ready.png` and its `-menu` partner: 1280×720, separate P2 state and ready P1 special.
- `mobile-hud-cpu-active-wide.png` and its `-menu` partner: 1170×540, CPU partner and active special countdown.
- `mobile-hud-p2-phone.png` and its `-menu` partner: an 844×390 desktop window retaining the production 960×540 logical canvas. Godot's letterboxed viewport capture is 693×390, not a cropped 844×390 image or a phone screenshot.

Actor positions, hearts, coins and special states are intentionally seeded fixtures. Source art is rendered by the game, not composited. The final solo, pair-ready and phone-sized captures were visually inspected for clear P2 health/power, visible charged-special artwork, readable menu, safe margins and retained development warnings. Physical iPhone/Android testing, native build/signing, device performance and human ergonomic acceptance remain open.
