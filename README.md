# Bill Dodgers

## Open or edit the Godot project

The native project is `godot/project.godot` on the `mobile/godot-foundation` branch.
Keep the full repository: its original `game/` assets are imported locally. See
[editing on another computer](docs/EDITING_ON_ANOTHER_COMPUTER.md) for the one-command
preparation, Windows/macOS instructions and what is safe to edit/commit.

## Native iPhone and Android port

A Godot 4 native-engine port in progress now lives in [`godot/`](godot/README.md).
It preserves all six worlds, 42 stages, six housemates, source artwork and story.
Dedicated solo runtimes are integrated for all six worlds. The complete solo
aggregate passes all 252 character/stage combinations with explicit
invulnerability assists to isolate progression. Every stage also has assisted CPU-partner
route evidence for all six CPU identities. The painted map, original full-body
character-selection screen, persistent choices, joystick controls, graphical action
buttons and a consolidated mobile menu are integrated. Native credits and a
replaceable, artistically unapproved prototype score remain separate.

This is not yet a finished or signed phone release. Human difficulty, complete
presentation, device performance, physical two-player input and store readiness remain open. Local web
continuity and boss-feet fixes are implemented and tested; the deployed site has not been changed. Native development is kept on a separate
feature branch, with automatic deployment disabled for that exact branch. See the [port plan](docs/NATIVE_PORT_PLAN.md)
and [native instructions](godot/README.md).

The Bill Dodgers platform game: Jean Phil and the housemates chase the robots that took the house kitty, across six worlds.
On the web it plays at **ourcommune.io/arcade/bill-dodgers/**. Worlds 1 and 2 are free for everyone; Worlds 3 to 6 are for Commune members.

## What is here

| Path | What it is |
| --- | --- |
| `game/` | The full six-world Canvas game, plus local continuity and boss-targeting repairs. Preserve the repair patches when regenerating from the external `map4/build_full.py` source. |
| `web/lock.js` | The members lock added to the web version: Play on a level in Worlds 3 to 6 opens a "Members only" card, and the map card's button reads "Members". |
| `web/404.html` | Sends a missing or locked level address back to the map (with the members card for Worlds 3 to 6). |
| `scripts/build-web.mjs` | Builds `dist/` from `game/`. |
| `vercel.json` | The Vercel project builds `dist/` with the script above. |

## Building

```
node scripts/build-web.mjs          # web version: Worlds 1 and 2, members lock on 3 to 6
node scripts/build-web.mjs --all    # every world, no lock (the members' version, for the Commune app later)
```

Node 18 or newer, no packages to install. The default web build leaves the level folders of Worlds 3 to 6 out of `dist/`. The source repository is currently public by the owner's choice, so this deployment filter does not make the source content private. Repository visibility is unchanged by the native port.

## How it reaches ourcommune.io

This repository deploys as its own Vercel project. The website (`web/vercel.json` in the Commune repository) proxies `/arcade/bill-dodgers/` to this project's address, so players see one site, and a game update never touches the website or the app.

The build also rewrites links that end in `index.html` to end in a slash, because the website removes `index.html` from addresses, which would otherwise cut a level off from its shared files (`../polish.js`, `../cutscenes/`).

## Updating the game

1. Rebuild the full game with `map4/build_full.py <folder>`.
2. Merge the regenerated content while retaining the shared `party.js` helper and stage/map integrations documented in `docs/WEB_PARTY_CONTINUITY.md` and `docs/WEB_BOSS_FEET_REPAIRS.md`. A blind replacement loses these fixes.
3. Run `node tests/test_web_party.mjs`, `node tests/test_web_runtime.mjs`, `node tests/test_web_boss_feet.mjs` and both web builds before a reviewed commit. Vercel redeploys on push to `main`. The native feature branch has an exact-branch deployment guard; saving it is not permission to merge or deploy.
