# Jar Thief: source parity

`godot/src/jar_thief.gd` ports the original `game/1-1/index.html` encounter, not a redesigned boss. Source locations in the readable stripped copy: start/update/down/jar at lines 583–623, shot hit rules at 541–543, rendering at 944–953. The ability extension at 1225 onward does not override this boss update; the sceneBossUpdate hook has no definition in this stage.

## Integration contract

- Instantiate the RefCounted script. Call `reset(world_width, view_width, ground_y, player_count=1, random_seed=1)` when the encounter starts. `rng` is public and can be replaced with a supplied RandomNumberGenerator after reset.
- Call `tick(dt, players: Array[Dictionary])` at the original frame cadence or a fixed physics step. Seconds and absolute world pixels are used. Each player has `position: Vector2` (feet) and `alive: bool`; array indices identify hurt/pickup recipients. Integrate the bill projectiles outside this module.
- Call `hit(shot_position, damage=1)` from shot collision handling. It returns whether the shot was consumed. Hit/down effects are queued until the next tick. `damage` deliberately does not alter base source damage.
- Public `state` contains x, fy, hp, max, state, t, face, flash, dizzy, waves, next, pending_throw, called, dz and jar. Jar is an empty Dictionary until spawned; thereafter x/y/vx/vy/t/got and, after pickup, by (player index). Wave entries contain x/vx/t.
- Returned events have `type`: warning; bill (position/velocity/gravity/big); stomp (shake); spawn_bot (side `l`/`r`, kind); backup; dizzy; hurt_player (player_index/source_x); hit (position); drop_coins (position/count); kill_bots; down (shake/bus_delay); jar_spawn; clear (player_index).
- Host must enforce player invulnerability in hurt_player, spawn and integrate bots/bills/coins, play sounds/particles, and on clear collect outstanding coins, revive downed players with one heart, start victory animation/card/music, and enable progression. These are scene effects rather than hidden dependencies here.

## Source constants retained

Health 70 solo/90 multiplayer. Enter speed 300 px/s, walk 90, initial attack delay 1.6s, later delay 1.3–2.5s, throw probability .55. Attacks fire at 320ms and recover at 640ms. Throws are three big bills at feet minus 230, horizontal speed clamped ±600, vertical speeds -700/-780/-860, gravity 1600 px/s². Stomp waves travel ±420 and hurt within strictly 24px horizontally while feet are above ground minus 30 in screen coordinates. Boss contact is strictly 62px horizontally without a height check. Shots hit strictly within 70px and ground minus 250 through ground, for one damage or two while dizzy, with 80ms flash.

Backup triggers strictly below .66 and .33; the second adds an extra throw bot in multiplayer. Strictly below .5 starts a once-only 2.6s dizzy spell. Knockout clears waves, drops 16 coins, kills remaining bots and schedules bus movement in 1.5s. Jar spawns strictly after 1.5s with -900 vertical/-120 horizontal speed and gravity 2400, bounces at ground minus 30 with .4 restitution above 200px/s, halving horizontal speed. Pickup is strictly within 50px after 600ms, with no height requirement.

## Original inconsistencies and deliberate boundaries

1. Original startBoss omits `fy`, although abilities later use `boss.fy`. We expose `fy=ground` for rendering; we do not invent ability behavior in this module.
2. Original updateShots ignores `s.dmg` for this boss. Even hit(..., 999) deals one point (two dizzy). Kept deliberately.
3. The source clamps x to arena bounds even during entry: the first live-player update jumps from world+160 to at most world-90. Kept deliberately.
4. Dizzy does not reset t and contact still hurts; timers continue during dizziness. Kept deliberately.
5. Jar pickup ignores height. The source can call stageClear twice if both players qualify in one update. This port emits exactly one clear event and chooses the first qualifying player to avoid duplicate scene transitions.
6. Godot's seeded RNG is deterministic but is not the JavaScript Math.random sequence. Integration is explicit Euler as in source; arbitrary giant dt steps are not equivalent to many small steps.

## Verification

Godot 4.6.3 headless: `XDG_DATA_HOME=/tmp/bd-boss-data XDG_CACHE_HOME=/tmp/bd-boss-cache godot --headless --path godot --script res://tests/test_jar_thief.gd`.

29 checks pass: HP, entry immunity/clamp/completion, attack timing/count/velocities/gravity/recovery, strict hit bounds, ignored damage, backup one-shot thresholds and duo bonus, dizzy double damage, defeat effects, delayed jar, collection and exactly-once clear, stomp waves and ground collision.
