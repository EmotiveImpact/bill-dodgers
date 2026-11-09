#!/usr/bin/env python3
"""Inventory imported native resources and optionally run the headless profile.

No installs, exports, cache deletion, asset edits or imports. Run prepare-native.py
first if imported textures are missing. Coordinate exclusive Godot use before
--run. All byte estimates are CPU/disk or explicitly hypothetical RGBA8 storage;
they are not browser/iPhone/GPU measurements.
"""
import argparse
from collections import Counter
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def ctex_dimensions(path):
    with path.open("rb") as stream:
        magic, version, width, height = struct.unpack("<4sIII", stream.read(16))
    if magic != b"GST2" or version != 1:
        raise ValueError(f"Unsupported imported texture header: {path}")
    return width, height


def resource_paths(value):
    if isinstance(value, str) and value.startswith("res://assets/"):
        yield value
    elif isinstance(value, dict):
        for child in value.values():
            yield from resource_paths(child)
    elif isinstance(value, list):
        for child in value:
            yield from resource_paths(child)


def inventory(project):
    textures = {}
    modes = Counter()
    for sidecar in sorted((project / "assets").rglob("*.import")):
        text = sidecar.read_text()
        if 'importer="texture"' not in text:
            continue
        target = re.search(r'^path="res://([^"]+)"$', text, re.MULTILINE)
        if not target:
            raise ValueError(f"Missing imported texture destination: {sidecar}")
        imported = project / target[1]
        width, height = ctex_dimensions(imported)
        mode = re.search(r"^compress/mode=(\d+)$", text, re.MULTILINE)
        mipmaps = "mipmaps/generate=true" in text
        source = sidecar.with_suffix("")
        uri = "res://" + source.relative_to(project).as_posix()
        textures[uri] = {"width": width, "height": height,
                         "source_bytes": source.stat().st_size,
                         "imported_bytes": imported.stat().st_size,
                         "rgba8_estimate_bytes": width * height * 4,
                         "compress_mode": int(mode[1]) if mode else None,
                         "mipmaps": mipmaps}
        modes[str(textures[uri]["compress_mode"])] += 1

    def summarize(paths):
        chosen = sorted(set(paths) & textures.keys())
        return {"count": len(chosen),
                **{field: sum(textures[path][field] for path in chosen)
                   for field in ("source_bytes", "imported_bytes", "rgba8_estimate_bytes")}}

    references = set()
    for path in (project / "content").rglob("*.json"):
        if path.name != "manifest.json":
            references.update(resource_paths(json.loads(path.read_text())))
    levels = {}
    for path in sorted((project / "content/levels").glob("*.json")):
        levels[path.stem] = summarize(json.loads(path.read_text())["imgs"].values())
    pictures = json.loads((project / "content/map.json").read_text())["pictures"]
    unreferenced = sorted(path for path in textures if "/embedded/" in path and path not in references)
    return {"textures": textures, "total": summarize(textures), "compress_modes": dict(modes),
            "sprite_sheets": summarize(path for path in textures if "/sprites/" in path),
            "story_directory": summarize(path for path in textures if "/cutscenes/" in path),
            "map": summarize(pictures.values()), "levels": levels,
            "embedded_without_direct_content_reference": {**summarize(unreferenced), "paths": unreferenced},
            "unreferenced_warning": "Candidate inventory only. Verify dynamic references and exported runtime before exclusion."}


def pack_inventory(path):
    """Read only the directory of Godot 4.6 PCK v3, never the asset payload."""
    groups = Counter()
    counts = Counter()
    with path.open("rb") as stream:
        magic, version, major, minor, patch, flags, base, directory = struct.unpack("<6I2Q", stream.read(40))
        if magic != 0x43504447 or version != 3 or flags & 1:
            raise ValueError("Expected an unencrypted Godot PCK v3")
        stream.seek(directory)
        count, = struct.unpack("<I", stream.read(4))
        for _ in range(count):
            length, = struct.unpack("<I", stream.read(4))
            name = stream.read(length).rstrip(b"\0").decode("utf-8")
            offset, size = struct.unpack("<2Q", stream.read(16))
            stream.read(20)  # MD5 plus flags.
            category = ("textures" if name.endswith(".ctex") else
                        "music" if name.startswith("assets/music/") else
                        "effects_and_fallback_music" if name.startswith("assets/audio/") else "other")
            groups[category] += size
            counts[category] += 1
    return {"file_bytes": path.stat().st_size, "entry_count": count,
            "engine": f"{major}.{minor}.{patch}", "payload_bytes_by_category": dict(groups),
            "entries_by_category": dict(counts), "pack_file_base": base}


def profile_rows(text):
    return [json.loads(line.removeprefix("RESOURCE_PROFILE "))
            for line in text.splitlines() if line.startswith("RESOURCE_PROFILE ")]


def run_profile(godot):
    with tempfile.TemporaryDirectory(prefix="bd-resource-profile-") as work:
        env = os.environ.copy()
        for key, directory in (("HOME", "home"), ("XDG_CACHE_HOME", "cache"),
                               ("XDG_CONFIG_HOME", "config"), ("XDG_DATA_HOME", "data")):
            folder = Path(work) / directory
            folder.mkdir()
            env[key] = str(folder)
        result = subprocess.run([godot, "--headless", "--path", str(ROOT / "godot"),
                                 "--script", "res://tests/profile_native_resources.gd"],
                                env=env, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=180, check=False)
        if result.returncode or any(marker in result.stdout for marker in
                                   ("SCRIPT ERROR", "Parse Error", "\nERROR:", "ObjectDB instances leaked")):
            raise RuntimeError(result.stdout)
        return result.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="JSON report; otherwise prints to stdout")
    parser.add_argument("--pack", type=Path, help="Existing PCK to inspect, no export")
    parser.add_argument("--runtime-log", type=Path, help="Summarize a previously saved profile log")
    parser.add_argument("--run", action="store_true", help="Run one isolated headless profile; coordinate exclusive Godot use")
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    if args.run and args.runtime_log:
        parser.error("Choose --run or --runtime-log, not both")
    report = {"limitations": "Headless CPU/resource benchmark, not browser/device FPS, GPU memory, audio decoding or installation validation.",
              "inventory": inventory(ROOT / "godot")}
    if args.pack:
        report["pack"] = pack_inventory(args.pack)
    if args.run or args.runtime_log:
        log = run_profile(args.godot) if args.run else args.runtime_log.read_text()
        report["runtime"] = profile_rows(log)
        if not report["runtime"] or report["runtime"][-1]["label"] != "game_freed":
            raise ValueError("Incomplete resource profile")
        report["runtime_log"] = log
    output = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.write_text(output)
        print(f"Resource profile written to {args.output}")
    else:
        print(output, end="")


if __name__ == "__main__":
    main()
