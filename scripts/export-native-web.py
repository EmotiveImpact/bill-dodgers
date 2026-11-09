#!/usr/bin/env python3
"""Export the separate Godot Web demo from prepared local content.

Uses already downloaded official 4.6.3 templates. Does not download, install,
publish, change the original web build, or read a player's saves/settings.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = "4.6.3.stable"
TEMPLATES = ("web_nothreads_debug.zip", "web_nothreads_release.zip")


def validate_templates(directory):
    if (directory / "version.txt").read_text().strip() != VERSION:
        raise RuntimeError("Template version must be exactly " + VERSION)
    for name in TEMPLATES:
        with zipfile.ZipFile(directory / name) as archive:
            names = set(archive.namelist())
            if not {"godot.html", "godot.js", "godot.wasm"}.issubset(names):
                raise RuntimeError("Incomplete official Web template: " + name)
            if archive.testzip():
                raise RuntimeError("Corrupt Web template: " + name)


def template_locations(temporary):
    # Only temporary per-process data locations, never real user settings.
    return [temporary / "data/godot/export_templates" / VERSION,
            temporary / "home/Library/Application Support/Godot/export_templates" / VERSION,
            temporary / "roaming/Godot/export_templates" / VERSION]


def validate_export(directory):
    for name in ("index.html", "index.js", "index.wasm", "index.pck"):
        path = directory / name
        if not path.is_file() or path.stat().st_size == 0:
            raise RuntimeError("Missing or empty exported file: " + name)
    for name, magic in (("index.wasm", b"\0asm"), ("index.pck", b"GDPC")):
        with (directory / name).open("rb") as file:
            if file.read(4) != magic:
                raise RuntimeError("Invalid export header: " + name)
    html = (directory / "index.html").read_text()
    if "const GODOT_THREADS_ENABLED = false" not in html:
        raise RuntimeError("Expected single-threaded HTML export")
    files = []
    for path in sorted(directory.iterdir()):
        if not path.is_file() or path.name == "export-manifest.json":
            continue
        digest = hashlib.sha256()
        with path.open("rb") as file:
            for chunk in iter(lambda: file.read(1024 * 1024), b""):
                digest.update(chunk)
        files.append({"name": path.name, "bytes": path.stat().st_size, "sha256": digest.hexdigest()})
    return files


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--templates-dir", required=True, type=Path)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "godot/builds/web-demo")
    parser.add_argument("--check", action="store_true")
    options = parser.parse_args(argv)
    try:
        templates = options.templates_dir.resolve()
        validate_templates(templates)
        godot = shutil.which(options.godot) or str(Path(options.godot).resolve())
        output = options.output_dir.resolve()
        # Never export into/over the original web source or deployment output.
        for protected in (ROOT / "game", ROOT / "dist"):
            if output == protected or protected in output.parents:
                raise RuntimeError("Output must be separate from original web game/dist")
        if output.exists() and any(output.iterdir()):
            raise RuntimeError("Output directory must be empty; choose a new path")
        if not (ROOT / "godot/content/levels/1-1.json").is_file():
            raise RuntimeError("Run scripts/prepare-native.py before exporting")
        with tempfile.TemporaryDirectory(prefix="bill-dodgers-web-") as work:
            temporary = Path(work)
            env = os.environ.copy()
            for name, folder in (("HOME", "home"), ("XDG_DATA_HOME", "data"),
                                 ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache"),
                                 ("APPDATA", "roaming"), ("LOCALAPPDATA", "local")):
                path = temporary / folder
                path.mkdir(parents=True, exist_ok=True)
                env[name] = str(path)
            version = subprocess.check_output([godot, "--version"], text=True, env=env).strip()
            if not version.startswith(VERSION + "."):
                raise RuntimeError("Use Godot " + VERSION + "; found " + version)
            if options.check:
                print("Web export prerequisites pass. No export or publication performed.")
                return 0
            for location in template_locations(temporary):
                location.mkdir(parents=True)
                for name in TEMPLATES:
                    shutil.copyfile(templates / name, location / name)
            output.mkdir(parents=True, exist_ok=True)
            command = [godot, "--headless", "--path", str(ROOT / "godot"),
                       "--export-release", "Web Demo", str(output / "index.html")]
            result = subprocess.run(command, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            print(result.stdout, end="", flush=True)
            if result.returncode or re.search(r"SCRIPT ERROR|Parse Error|^ERROR:|ObjectDB instances leaked", result.stdout, re.MULTILINE):
                raise RuntimeError("Web export failed; no deployment attempted")
        manifest = validate_export(output)
        (output / "export-manifest.json").write_text(json.dumps({"engine": VERSION, "single_threaded": True,
            "files": manifest, "device_verified": False}, indent=2) + "\n")
        print("Web files exported locally:", output)
        print("Not hosted or iPhone-tested. Serve via HTTP(S), not file://.")
        return 0
    except (OSError, RuntimeError, subprocess.CalledProcessError, zipfile.BadZipFile) as error:
        print("Web export blocked:", error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
