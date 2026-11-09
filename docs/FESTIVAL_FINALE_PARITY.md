# Ticket Tout finale hooks

`festival_finale.gd` implements the two levelUpdate hooks needed by stage3-6, while the existing `festival_boss.gd` retains actual attacks, numeric stage0, helper thresholds, down state and jar physics. Original executable anchors are `game/3-6/index.html`1320 (main trigger),1324 (jar attraction),1350–1395 (boss),1396 onward (painted move selector), and618–622 (shared jar physics/pickup).

## Runtime integration

- Native support selects the World3 combat/runtime, immutable3-6 metadata and dedicated Tout painter. No preview gains an artificial clear.
- Main encounter begins after all three approach waves are done and camera reaches world width minus viewport minus2, including the equality boundary. Source width4400 and viewport738 mean trigger3660 and lock3662. The actual config is160 solo/220 pair HP, `kind=tout`, non-mini. There is no independent “boss already beaten” boolean: the source boss object remains through down/jar state.
- Stage0 is the sole platform `[4040,4290,354,{base:482,style:cases}]`. Zero is a numeric index, not a false boolean. Existing combat binds that exact live surface. Generic boss tests already cover ascent, timed stage throws, return hop/slam and low-health hops, but those unit fixtures alone do not prove a real-main route.
- `after_mini_trigger(dt,host,runtime)` is called after the shared mini trigger, before boss and jar ticks. It starts the main encounter if eligible and applies attraction only to an existing, uncollected jar whose **previous** age is strictly greater than1.4seconds. Attraction chooses the nearest living horizontal position, ignoring height, and moves no more than120pixels/second without overshooting. It does not collect or clear.
- The boss creates the jar only when its down clock is strictly greater than1.5seconds. Existing jar physics subsequently age it and allow collection only when horizontal distance is strictly below50 and age strictly exceeds0.6seconds. Defeating the boss, reaching the end or merely spawning a jar is insufficient. Actual collection calls the main exactly-once settlement/save path.
- Native pause and run-generation invalidation freeze late hooks. Continue retains encounter state. Fresh stage reset creates fresh live surfaces and no boss.

## Pure painted movement snapshots

Source `toutMove` updates `moved`, previous x and sampled time only once for each distinct `levelT`; entering/charging still chooses walk independently. Native `sync_visuals` captures the same strict `abs(x-previous_x)>0.05` predicate after actual boss motion, once per distinct runtime level time. Repeated rendering does not advance that state or consume RNG. The first sample has no invented movement. The painter selects original move-strip frames from state, not a substituted thief animation. Draw the jar after bots and before players.

## Verification boundary

`godot/tests/test_festival_finale.gd` passes23 isolated assertions on the trigger, exact config/stage metadata, no repeated start, unsupported ordinary-distance end, first/repeated/new movement samples, strict movement threshold, previous-age attraction, horizontal nearest selection, no overshoot, collected/no-player/pause/generation guards and immutable source metadata. The isolation adapter enables3-6 only to exercise hooks; it does not replace production collision or boss logic. Main integration, complete input routes, campaign progression and resource packaging are separate acceptance work. No device, visual-fidelity, export or deployment claim is made here.
