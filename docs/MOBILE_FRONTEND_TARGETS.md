# Native frontend target audit

The title, painted campaign map and official six-door character selector now adapt
navigation targets to the actual Godot window-to-canvas transform. This is a
**desktop-window regression contract**, not iPhone points, Android dp, physical
phone acceptance or a signed release claim.

## Measured fixtures

The production canvas is 960×540 with `canvas_items` stretch. Godot 4.6.3 reports:

| Requested window | Rendered canvas | Origin | Original 44-unit action height |
| --- | --- | --- | --- |
| 568×320 | 568×319 | (0, 1) | 25.99 rendered pixels |
| 844×390 | 693×390 | (76, 0) | 31.78 rendered pixels |
| 1280×720 | 1280×720 | (0, 0) | 58.67 rendered pixels |

The regression uses the actual engine transform, including integer rounding and
letterboxing. Each window runs with normal insets and with synthetic 44-pixel
horizontal / 16-pixel vertical **content** insets converted to logical units.
Every tested button has at least 44 rendered desktop pixels in each dimension.

## Changes

- Title options remain beside the original cast painting. A scrolling menu begins
  below the logo rather than shrinking every option into a bottom row. Scroll
  gestures, wheel input and focus following retain access to later options.
- Help, story scenes and reset copy scroll separately from fixed navigation or
  confirmation actions. Scroll cues replace intrusive overlay scrollbars.
- The title offers read-only engine/font Licenses with clean close, Back and focus
  restoration. This is not certification of artwork or music rights.
- Map actions and text scale with the window. World/stage lists keep Close fixed,
  descriptions scroll independently, and the selected card remains returnable
  after deliberate character selection.
- The original six full-body animated characters, ordered doorway row and source
  desktop doorway geometry remain. Small-window action targets enlarge; long
  partner instructions wrap without replacing the official screen.
- Touch ownership rejects canceled, dragged, stale, backgrounded and resized
  contacts. A resize that changes only the letterbox origin is also detected.
  Confirmed party preferences still persist; Cancel does not write draft choices.

## Verification on frozen source

Passed:

- `test_mobile_frontend_targets.gd`: 1,880 checks, six window/inset fixtures.
- `test_campaign_map_integration.gd`: 47 real GUI checks.
- `test_party_selection.gd`: 566 checks, including original doorway geometry and
  all nested list-row checks after scrolling.
- `test_campaign_completion.gd`: 308 synthetic campaign/story/accounting checks.
- `test_campaign_map.gd`: 26 checks.
- `test_map_mobile_targets.gd`: 100 checks.
- `test_save_presentation.gd`: 187 checks.
- `test_title_mobile_layout.gd`: all focused real-input cases pass.

The completion fixture now explicitly uses the 1280×720 desktop window. Godot's
headless default is a 100×100 placeholder; that is not a supported touch-layout
fixture. GUI helpers settle scrolling containers and reveal the requested control
before dispatching the same actual input events. Existing assertions were retained.

Run focused tests with an isolated HOME and XDG data/cache/config directory after
content import, for example:

```sh
godot --headless --path godot --script res://tests/test_mobile_frontend_targets.gd
```

Actual desktop rendering produced 42 post-change captures and passed all three
window-sized renderer runs (640, 642 and 640 checks). Visual review then found a
title scrollbar overlaying text; its narrow hide-scrollbar / below-logo correction
passes the final focused and combined headless suites. A fresh actual-renderer
capture of that final title-only correction is still pending. The selector and map
screens were visually inspected. Physical phones, accessibility usability,
performance and human acceptance remain separate gates.
