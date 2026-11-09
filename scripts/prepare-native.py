#!/usr/bin/env python3
"""Prepare a fresh checkout for Godot, using only installed local tools.

No downloads, package installation, credentials, deployment or gameplay run.
Generated assets are rebuilt from the original files already in this repository.
"""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
TESTED_GODOT = "4.6.3"


def locate(command):
    candidate = Path(command).expanduser()
    if candidate.is_file():
        return str(candidate.resolve())
    found = shutil.which(command)
    if found:
        return found
    raise RuntimeError(f"Cannot find {command!r}. Install it yourself or pass its executable path.")


def commands(root, python, node, godot):
    project = str(root / "godot")
    return [
        [python, str(root / "scripts/import-godot-content.py")],
        [node, str(root / "scripts/extract-story.mjs")],
        [godot, "--headless", "--path", project, "--script", "res://tools/build_audio.gd"],
        [godot, "--headless", "--path", project, "--editor", "--import"],
    ]


def source_requirements(root):
    required = ["game/index.html", "game/title.jpg", "game/cutscenes/cs.js", "godot/project.godot"]
    required += [f"game/{world}-{stage}/index.html" for world in range(1, 7) for stage in [1, 2, 3, 4, 5, 6, "S"]]
    required += [f"game/sprites/{actor}-sheet.{suffix}" for actor in ["jp", "maya", "ama", "leo", "theo", "mei", "bot", "thief"] for suffix in ["png", "json"]]
    missing = [name for name in required if not (root / name).is_file()]
    if missing:
        raise RuntimeError("Incomplete checkout. Missing: " + ", ".join(missing))
    # The prototype score is intentionally committed as self-contained resources.
    if len(list((root / "godot/assets/music").glob("*.res"))) != 18:
        raise RuntimeError("Expected 18 committed prototype score resources. Restore godot/assets/music from Git.")


def version(command, env):
    result = subprocess.run([command, "--version"], capture_output=True, text=True, check=True, env=env)
    return result.stdout.strip()


def validate_versions(godot_version, node_version):
    if not godot_version.startswith(TESTED_GODOT + "."):
        raise RuntimeError(f"Use Godot {TESTED_GODOT} for this checkpoint; found {godot_version!r}. No tool was installed or changed.")
    match = re.match(r"v?(\d+)\.", node_version)
    if not match or int(match[1]) < 18:
        raise RuntimeError(f"Node.js 18 or newer is required; found {node_version!r}.")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"), help="Godot 4.6.3 executable path or command")
    parser.add_argument("--node", default="node", help="Node.js 18+ executable path or command")
    parser.add_argument("--check", action="store_true", help="Check checkout/tools only; do not generate content")
    options = parser.parse_args(argv)
    try:
        source_requirements(ROOT)
        node, godot = locate(options.node), locate(options.godot)
        with tempfile.TemporaryDirectory(prefix="bill-dodgers-prepare-") as temporary:
            env = os.environ.copy()
            # Linux cloud/CI can have a read-only home. Preparation never needs a
            # player's actual game saves, editor settings or authentication.
            for name, folder in [("HOME", "home"), ("XDG_DATA_HOME", "data"), ("XDG_CACHE_HOME", "cache"), ("XDG_CONFIG_HOME", "config")]:
                path = Path(temporary) / folder
                path.mkdir()
                env[name] = str(path)
            gv, nv = version(godot, env), version(node, env)
            validate_versions(gv, nv)
            print(f"Local tools verified: Godot {gv}; Node {nv}; Python {sys.version.split()[0]}", flush=True)
            if options.check:
                print("Checkout is complete. No content generated, game run or download performed.")
                return 0
            for command in commands(ROOT, sys.executable, node, godot):
                print("Running: " + " ".join(command), flush=True)
                result = subprocess.run(command, cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
                print(result.stdout, end="", flush=True)
                if result.returncode or re.search(r"SCRIPT ERROR|Parse Error|^ERROR:|ObjectDB instances leaked", result.stdout, re.MULTILINE):
                    raise RuntimeError("Preparation stopped at the command above. Keep its error output when asking for help.")
        print(f"Ready to edit: import {ROOT / 'godot/project.godot'} in Godot {TESTED_GODOT}, then press F5 (Run Project).")
        print("This prepared the editor project. It did not run the full tests, export a phone app or deploy anything.")
        return 0
    except (RuntimeError, OSError, subprocess.CalledProcessError) as error:
        print(f"Preparation failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
