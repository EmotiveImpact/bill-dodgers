# Edit Bill Dodgers on another computer

The native game is a real Godot project at `godot/project.godot`. It is not a
WebView. Keep the **whole repository**, not just the `godot/` folder: the original
art, sprites, fonts and story are stored in `game/` and imported locally.

## Get the project

Use the native development branch, `mobile/godot-foundation`. `main` remains the
existing web release until a separate merge/deployment decision.

With Git installed:

```sh
git clone --branch mobile/godot-foundation https://github.com/EmotiveImpact/bill-dodgers.git
cd bill-dodgers
```

Alternatively, select that branch in GitHub, choose **Code → Download ZIP**, and
extract the complete folder. A ZIP is editable but does not preserve Git history
or provide `git pull`/push. GitHub Desktop can clone and switch the branch without
typing the Git commands.

## Prepare once, then open Godot

Install these normal development tools from their official sites:

- [Godot 4.6.3 standard edition](https://godotengine.org/download/archive/4.6.3-stable/).
  This project uses GDScript, so the .NET edition is not needed.
- [Python 3](https://www.python.org/downloads/), tested here with Python 3.12.
- [Node.js 18 or newer](https://nodejs.org/en/download), tested here with Node 24.

No npm/pip packages, online asset service, music generator, account keys, Rive
installation or paid service are needed to open the native project.

From the repository root on macOS/Linux:

```sh
python3 scripts/prepare-native.py --godot /path/to/godot
```

For a usual macOS application installation:

```sh
python3 scripts/prepare-native.py --godot /Applications/Godot.app/Contents/MacOS/Godot
```

On Windows, in PowerShell:

```powershell
py -3 scripts/prepare-native.py --godot "C:\Tools\Godot\Godot_v4.6.3-stable_win64.exe"
```

Replace the executable path with the one you installed. If Godot is already on
PATH as `godot`, omit `--godot`. `--check` checks prerequisites without generating
content. The helper does not download/install tools, publish anything or launch
gameplay. It extracts original content/story, builds source sound effects, then
asks Godot to import the assets. The first import is heavier than later opens.

In Godot's Project Manager choose **Import**, select `godot/project.godot`, then
open it. Press **F5** (Run Project) to play from the title/menu. No Android/iOS SDK
is needed for editing or desktop playtesting.

## Where to edit

| Area | Canonical files |
|---|---|
| Main Godot scene and settings | `godot/main.tscn`, `godot/project.godot` |
| Gameplay, controls, menus and renderers | `godot/src/*.gd` |
| Original authored levels | `game/<level>/index.html`, including its `META` data |
| Original sprites and animation rectangles | `game/sprites/*-sheet.png` and matching JSON |
| Original title and story assets | `game/title.jpg`, `game/cutscenes/` |
| Original map/story definitions | `game/index.html`, `game/cutscenes/cs.js` |
| Replaceable prototype native score | `godot/assets/music/*.res`; provenance in `docs/ORIGINAL_SOUNDTRACK.md` |
| Regression tests | `godot/tests/`, `tests/` |
| Export setup and release limitations | `godot/export_presets.cfg`, `docs/NATIVE_BUILD_ROUTES.md` |

Most gameplay/world rendering is code-driven, rather than a set of hand-placed
Godot TileMap scenes. The generated `godot/content/`, most `godot/assets/`, and
Godot's `.godot/` cache are intentionally ignored by Git. Do not make your only
copy of an edit in these generated folders: preparation can replace it. Change
the canonical source above, or deliberately add a new native asset and its
tracked source/reference before relying on it.

The repository includes all original inputs needed to regenerate the game. It
does not need the external historic `map4/build_full.py` generator merely to run
the native project. Do not blindly regenerate/replace `game/`: that would erase
the authorized web continuity and boss-targeting repairs.

## Save and share changes

Commit work to a feature branch, inspect the diff, then push that branch and use
a draft pull request. Do not commit `.godot/`, exported APK/IPA/PCK builds,
developer certificates, signing keys, passwords or credentials. Keep unrelated
experiments separate. Raw validation logs/reports also stay local; the test
source and concise results summaries are committed. The current native branch explicitly disables automatic
Vercel deployment for **that exact branch only**; other new branches need their
own deployment decision/guard before pushing. `main` still has its original web
deployment behavior.

For an existing Git checkout, commit or otherwise safely preserve local edits
before pulling. Then `git pull --ff-only` and rerun preparation if source assets,
story or audio definitions changed. Do not use a reset/clean command to discard
another computer's unsaved work.

## Validate changes

On macOS/Linux or a Bash-capable development environment:

```sh
bash scripts/verify-native.sh
bash scripts/verify-party.sh
```

The full solo/CPU route matrices are extensive automated progression tests and
use declared assistance. They are not a claim of physical-device, normal-health
difficulty or real two-person acceptance. Focused tests can also be run directly
with Godot using the commands in their parity/acceptance documents.

Editing on Windows/macOS is supported by the project/tooling design; the fresh
checkout preparation proof recorded for this checkpoint is on Linux. Actual
Android/iPhone export, signing and device testing are separate steps. Opening
the editor does not mean an app has been installed or submitted to a store.
