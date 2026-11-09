# Queue jump host integration

The supported 3-2 path uses the shared World 3 surfaces, combat, abilities and receipt rules, a small queue controller, and its dedicated renderer. It does not reuse the supermarket trolley camera or invent a required enemy-clear gate.

## Verified host seams

`test_festival_queue_integration.gd` passes 147 real-main assertions. These are explicit placement/clock/actor fixtures, not full input routes.

- Exact 15 source waves/51 solo entries, 47 solid surfaces and three original receipt centers; native selection and returning to 3-1 or World 2.
- Strict 1.8-second auto warmup, 140 pixels/second thereafter, no follow recurrence during warmup or wipes, unchanged camera-velocity state and previous-frame camera clamping.
- Actual controller-shaped living/down bosses gate auto correctly. The single final lethal base frame still advances horizontal auto before global knockout; vertical follow remains living-only.
- All six housemates are physically carried by all five solid crowds at 120 pixels/second. Real standing damage and safe crouching are tested at every low banner. Strict airborne bounds and Maya's shield are separate checks.
- Squash delegates the real fall-recovery path, clears ordinary invulnerability and applies damage without restarting progress. The host now caches World 3's base control lock before squash/fall, matching source `updatePlayer`: a newly hurt frame can still perform its already-authorized base jump/fire/pose. Later ability and skill wrappers see the new lock, and the following base frame is hurt-locked. World 1 and World 2 ordering is unchanged.
- Busy waves do not block an auto iris. At 1.43 seconds the camera and player x translate, while airborne y/vy remain unchanged apart from ordinary gravity. The next late phase displays the actual Crowd surf notice. Pause, knockout, Continue and fresh replay preserve or reset state as appropriate.
- The source distance ending can start with incomplete waves and a live robot. Auto freezes during the ending, the strict 2.6-second delay settles once, and the runner clock includes the final base frame. Post-clear calls cannot bank twice.

The generic skill fixture now uses the live runtime geometry rather than mutating only authored metadata. The 3-1 rendering probe is retained in the renderer-selection slot so switching through the new stage does not discard its test instrumentation.

## Progression and limits

`test_full_festival_queue_run.gd` independently completes all six input-only routes with explicit invulnerability. It records exact coin seeds, all three actual receipts, all gaps/banners/crowd carries, actual waves, checkpoint/scene/ending and disk reload. There are no route falls or banner collisions. Other contact overlap is explicitly recorded and masked by invulnerability, so these are not unassisted survival proofs. See `FESTIVAL_QUEUE_RUN_VERIFICATION.md`.

Authored event banner/subtitle content is visible in native status text. The original animated shared banner/HUD presentation remains unfinished. The jar runner is presentation only and never grants a jar inventory or boss objective. There is no device, framebuffer, export/signing or six-world completion claim.

The complete clean Queue jump checkpoint passes eight Python tests, 60 Godot suites including 96 stage/housemate routes, 118 asset-free packed-runtime checks and 140 prebuilt-audio checks.
