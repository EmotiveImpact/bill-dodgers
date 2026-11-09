# Supermarket main-scene integration checks

`godot/tests/test_supermarket_integration.gd` instantiates the actual `main.tscn`, disables automatic physics ticks, and drives `main.step` explicitly. On 2026-11-09 it passed **109 checks, zero failures** with Godot 4.6.3 headless. HOME and all XDG paths were isolated under `/tmp`, including native save writes. No deployment or visibility setting was changed.

These are **focused contract fixtures, not a whole-level playthrough**. Some cases place actors at authored coordinates, add a small collision fixture, suppress unrelated waves, or mark prerequisite waves complete. The objective fixture consequently exercises a real clear/save path in an isolated test save without proving that a player can win the preceding encounters. See `PARKING_RUN_VERIFICATION.md` and `test_full_parking_run.gd` for independent traversal evidence and its own limitations.

## Source evidence

Assertions were checked against executable `game/2-1/index.html`, particularly:

- `spawnBot`, `updateBots`, `updateShots`, and `updateCoins` for source hitboxes, ordinary pickups, and encounter order.
- `updatePlay` lines 633–673 for waves/objective before enemy deaths, and all-down resolution after late world hooks.
- `lvStart`, `lvUpdate`, and `lvBot` lines 738–849 for checkpoint, authored coins, trolleys, carts, security, and drone phases.
- `picksStart`/`updatePicks` lines 1077–1092 for fresh receipt instances, strict overlap, and replay rewards.
- `sceneStart`, `lvCamMax`, and `sceneUpdate` lines 1120–1140, plus parking `L.sceneView=300`/`L.sceneLand=420`, for lift gating, landing, camera, and shot clearing.

The imported level contains eleven solo waves with 52 entries, 64 entries with appended two-participant extras, five ordinary crates, thirteen one-way platforms plus ground, three receipts, thirteen coin rows totaling 73 coins, and four trolley batches. The shared source audit and all hazard details remain in `WORLD_TWO_IMPLEMENTATION.md`; low-level module fixtures are documented separately.

## Covered contracts

### Runtime selection and collision routing

- `2-1` uses the World 2 runtime/combat policy and source ability-shot path. W1 retains its existing combat and rooftop controller.
- `2-2`, `2-3`, `2-4`, `2-5`, `2-6`, and `2-S` remain unsupported previews and reject attempted native clear calls.
- Player, ability, and skill floor/landing/wall queries include runtime solids and one-way surfaces. Runtime modifications do not alter imported JSON, and renderer snapshots are detached.
- The W1 checkpoint still supplies its original minimum of two hearts.

### Lift, pause, and run lifecycle

- The top-deck camera cap is `7600 + 300 - 738 = 7162`. Previous unfinished encounters prevent transition, and the trigger is exactly player x7550.
- Wipe begins with zero elapsed time, teleports to `(8020,482)` at 1.43 seconds, sets camera `(7860,0)`, clears velocity and projectiles, and ends at 2.17 seconds.
- Player input, bullets, and gameplay clocks continue during the wipe. Pause and application background freeze the runtime and release held controls.
- The destination checkpoint occurs in the next late update, not before the frame-end teleport.
- Restart, Map, and switching to W1 invalidate stale callbacks. Continue retains the existing wipe, scene, hazards, waves, actors, loose coins, score, and receipt state; fresh replay resets them without accumulating duplicate objects.

### Damage, checkpoint, and pickups

- W2 checkpoint heals to three hearts at camera midpoint7700 exactly once and does not invent a respawn coordinate.
- A lethal hostile bill can be followed by intentional same-frame checkpoint revival with two seconds of protection. Ordinary pickup processing still ignores the dead player before that late revival.
- Without a checkpoint, neither a heart, coin, nor receipt revives/rewards the knocked-out player. Late trolley damage precedes receipt collection.
- Behind-start receipt is recoverable with ordinary left input before camera advance. Rendering uses y−40, and pickup boundaries are strict: horizontal42, feet greater than y−30, body top less than y.
- Source receipt numbers1/2/3 map to native saved indices0/1/2. A replay deliberately presents and rewards each receipt again while deduplicating saved indices. W1 saved-receipt hiding is unchanged.
- Authored coin rows spawn after ordinary pickups, preserve their endpoints/sine arc, spawn once, and reset resting age to two seconds. They survive beyond ordinary eleven-second expiry but still cull behind the camera.

### Combat and ordering

The suite instruments subclasses that delegate to the real implementation, verifying this main-scene phase trace:

`ability pre → waves → objective → enemies → bubbles → friendly/hostile projectiles → ordinary pickups → world late → carts → drones → ability effects → finish_frame`

W1 after-motion/camera/crumble/chimney/pickup, flyer/Bailiff, and bus hooks must not appear in that trace. Additional collision fixtures verify:

- Numeric spawns retain their world x and arrival state. Security uses24HP solo/34HP with two participants and the58×186 source hitbox, without a W1 Bailiff attack policy.
- Two-participant wave extras are appended, never sorted. In particular the6880 wave retains delays `[0,2500,4500,6500,3500]`. This is schema coverage, not multiplayer implementation.
- Friendly shot collision is ordinary bot → runtime intercept → ordinary crate → solid cleanup. All friendly shots resolve before hostile bills, even when a hostile bill appears first in the storage array. Crates lose one HP regardless of projectile damage.
- Cart contact uses its pre-late-motion position. Drone collision uses pre-bob feet; new sticker bills remain at the muzzle until the next projectile pass.
- Held bubbles skip AI/cleanup, then reinsert after ordinary bots before current-frame shots. Release stings go through physical shot ordering.
- Ama's Bubble Trap cancels overlapping hostile bills before same-frame contact. Maya's last shield frame cancels those bills even when the special expires before combat.
- Theo cannot kick a crate during hurt-lock; an actual authored-crate fixture verifies kicking resumes when unlocked.
- Theo's late effects enqueue ghosts for the next collision pass. Source ghost expiry follows collision/effects at strictly more than70ms.

### Objective and persistence

- Reaching the exit alone cannot clear, spawn a fake boss, or bypass any of the eleven waves.
- A final enemy killed after the objective phase releases its wave/end timer only on the next frame.
- The actual objective starts at one millisecond and requires strictly more than2.6 seconds before clear/save.
- Repeated objective, clear, and Continue calls cannot bank completion twice.
- Save reload preserves supported parking/W1 completion and strips forged unsupported World 2 clears through the shared capability registry.

## Reproduction

```sh
work="$(mktemp -d /tmp/bd-supermarket-integration.XXXXXX)"
mkdir -p "$work/home" "$work/cache" "$work/config" "$work/data"
HOME="$work/home" \
XDG_CACHE_HOME="$work/cache" \
XDG_CONFIG_HOME="$work/config" \
XDG_DATA_HOME="$work/data" \
godot --headless --path godot --script res://tests/test_supermarket_integration.gd
```

The final line should report `Supermarket main integration: 109 checks, 0 failures (focused fixtures, not full-run proof)`. Treat any `SCRIPT ERROR`, `Parse Error`, `ERROR:`, or leaked-object diagnostic as a failed run even if the process exits successfully. Run the aggregate native and packed-runtime suites separately before packaging.

## Not established by this suite

- It does not establish full-run difficulty, all six characters' traversal, all receipt routes, or all52 encounters beaten by normal input.
- It does not certify rendered alignment, touch ergonomics, audio fidelity, mobile lifecycle behavior on a device, Android/iOS exports, co-op, CPU partners, or the remaining World 2 stages.
- Headless collision fixtures do not replace rendered screenshots or real-device playtests. Scene timing here verifies the intentional simulation-clock implementation, including pause/cancellation, rather than reproducing the web renderer's wall-clock callback mechanism.
