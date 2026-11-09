# Bill Dodgers

The Bill Dodgers platform game: Jean Phil and the housemates chase the robots that took the house kitty, across six worlds.
On the web it plays at **ourcommune.io/arcade/bill-dodgers/**. Worlds 1 and 2 are free for everyone; Worlds 3 to 6 are for Commune members.

## What is here

| Path | What it is |
| --- | --- |
| `game/` | The full game, all six worlds, exactly as the lead game build makes it (`map4/build_full.py` in the project files). Replace it wholesale when the game is rebuilt. |
| `web/lock.js` | The members lock added to the web version: Play on a level in Worlds 3 to 6 opens a "Members only" card, and the map card's button reads "Members". |
| `web/404.html` | Sends a missing or locked level address back to the map (with the members card for Worlds 3 to 6). |
| `scripts/build-web.mjs` | Builds `dist/` from `game/`. |
| `vercel.json` | The Vercel project builds `dist/` with the script above. |

## Building

```
node scripts/build-web.mjs          # web version: Worlds 1 and 2, members lock on 3 to 6
node scripts/build-web.mjs --all    # every world, no lock (the members' version, for the Commune app later)
```

Node 18 or newer, no packages to install. The web build leaves the level folders of Worlds 3 to 6 out of `dist/`, so their files are never public. The repository itself stays private for the same reason.

## How it reaches ourcommune.io

This repository deploys as its own Vercel project. The website (`web/vercel.json` in the Commune repository) proxies `/arcade/bill-dodgers/` to this project's address, so players see one site, and a game update never touches the website or the app.

The build also rewrites links that end in `index.html` to end in a slash, because the website removes `index.html` from addresses, which would otherwise cut a level off from its shared files (`../polish.js`, `../cutscenes/`).

## Updating the game

1. Rebuild the full game with `map4/build_full.py <folder>`.
2. Replace `game/` with that folder's contents and commit. Vercel redeploys on push to `main`.
