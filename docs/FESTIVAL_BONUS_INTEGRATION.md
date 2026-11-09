# Festival bonus 3-S: native host integration verification

Verified 2026-11-09 against Godot 4.6.3 headless. `res://tests/test_festival_bonus_integration.gd` passes **182 checks** against the real `main.tscn` host and production bonus capability, dispatch, completion and save paths. Imported source metadata and public repository settings are unchanged by this test work. No push, deployment, export or device test was performed.

This is an explicitly isolated seam suite, not input-playthrough evidence. It places the player, chooses clocks and coin inventories, supplies a lethal projectile, and seeds campaign prerequisites where needed. Full input routes are separately documented in [FESTIVAL_BONUS_RUN_VERIFICATION.md](FESTIVAL_BONUS_RUN_VERIFICATION.md). The isolated bonus/raster-command suites and source-function probes are documented in [FESTIVAL_BONUS_PARITY.md](FESTIVAL_BONUS_PARITY.md).

## Instrumentation and boundaries

The scene is instantiated normally. A subclass overrides only `_save_progress`, counts calls, and then calls the unchanged production implementation, including its actual disk write. A FestivalCombat subclass records phase entry and delegates every phase to production. A FestivalBonusRenderer subclass records draw command submission and delegates every command to production. Tests use silent/logged audio rather than claiming audio output fidelity.

No support registry override or forced host clear substitutes for a successful objective fixture. `_complete_level` is called explicitly only to verify a duplicate clear is rejected and an explicit unknown-level fixture cannot bank or save. Isolated fixtures may manipulate clocks and actors; this is not how the full-route suite works.

## Verified native seams

- **Routing and seeding:** 3-S is native-supported, selects WorldThree and FestivalBonusRenderer, exposes the actual bonus snapshot in `stage_data`, and begins with no coins. The first update does not falsely clear an empty fresh stage. Its earlier pickup pass cannot collect the 179 coins seeded late with age0.3, stay/rest true and zero velocity. A following actual pickup pass can collect one. Imported metadata remains unchanged.
- **Early empty inventory order:** Finds run first, including immediate persistence of an actual receipt. With no surviving stay coin, the source “All collected!” branch clears before authored seeding, cheer/tie countdown and the late timer. At89.99seconds, a20ms frame therefore preserves89.99 rather than producing a timeout. A remaining loose coin is swept by the host. The banner captures the old£7 while completion banks£8. This fixture records exactly two save calls: the receipt and the clear. Repeated clear/step attempts do not add a third.
- **Late inclusive timer order:**89.99seconds remains play; the next10ms reaches90 and clears. The final pickup callback sees the old timer and live inventory. Boss and jar callbacks see the resulting clear state, new timer and emptied inventory. The host banks all179 distant surviving coins, stops music, celebrates and calls real persistence once, while the banner retains£0.
- **Final lethal frame:** A real hostile projectile takes the final heart during the frame that reaches90seconds. The source late timeout still runs before global knockout, clears, revives to one heart for celebration and banks the surviving inventory. This is not a direct synthetic clear.
- **No width ending and honest culls:** Placing the player at the right edge does not start the ordinary2.6-second ending. Actual shared pickup filtering removes169 behind-camera authored coins without paying them, leaving10 stay coins and continued play. A later explicitly supplied last behind-camera stay coin is culled; the source empty branch then clears with£0, without advancing the late timer or resurrecting deleted money.
- **Lifecycle:** Actual pause/resume freezes/resumes clock, player and coins; actual hurt/knockout and Continue preserve clock/inventory and revive in place. Fresh replay resets timer, completion state, receipt state, inventory and generation. An older-generation extension, a foreign host and a menu-invalidated run cannot consume a late callback.
- **All six receipt fixtures:** All three authored receipts, at(2000,182),(5600,182),(7400,182), use the real host find path for every character. Horizontal distance exactly42 and the exact upper-body boundary are excluded. Overlap collects immediately and awards no money. Every receipt persists once, duplicates are suppressed, saved receipts can be collected again on replay, and no skill is awarded.
- **HUD and original art dispatch:** The real SceneOverlay and main CanvasItem callbacks submit bonus timer and original sign commands. Timer text starts90s at logical(480,98), size22; it rounds upward from the actual bonus clock, ignores unrelated host/world clocks, and turns source pink at10s. Production painter queries expose all four “Partner stall” signs. Repeated actual draw callbacks leave simulation, coin inventory, metadata and saved data unchanged. Menu stops the active timer draw. This is command/callback evidence, not screenshot equivalence.
- **Campaign:** The actual map rejects3-S before3-3 is cleared, then permits it without a receipt quota or invented intro. Normal bonus clear persists without a fabricated story scene. Settlement returns to3-4 when it is next. With all World3 main stages cleared, settlement identifies4-1 and stops at the honest unsupported boundary. Preview4-1 cannot start as native campaign gameplay or bank a clear.

## Reproduction

Run from the repository root in an isolated, writable HOME/XDG directory. Reject a run on a nonzero exit **or** any `SCRIPT ERROR`, `Parse Error`, line beginning `ERROR:`, `ObjectDB instances leaked`, or failed assertion, including when Godot exits0.

```sh
run_root=$(mktemp -d /tmp/festival-bonus-integration.XXXXXX)
mkdir -p "$run_root/home" "$run_root/data" "$run_root/cache"
HOME="$run_root/home" XDG_DATA_HOME="$run_root/data" \
XDG_CACHE_HOME="$run_root/cache" /usr/local/bin/godot --headless \
  --path godot --script res://tests/test_festival_bonus_integration.gd \
  > "$run_root/test.log" 2>&1
status=$?
cat "$run_root/test.log"
if grep -Eq 'SCRIPT ERROR|Parse Error|^ERROR:|ObjectDB instances leaked|FAIL' "$run_root/test.log"; then exit 1; fi
exit "$status"
```

Observed final output: `Festival bonus actual-main integration: PASS checks=182 failures=0`.

Not certified here: physical touch controls, handset performance, screenshot/framebuffer parity, multiplayer/CPU, a signed export, World4–6 gameplay or a complete-game release.
