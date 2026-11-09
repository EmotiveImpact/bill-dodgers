#!/usr/bin/env python3
"""Deterministically extract source content, not JavaScript behavior, for Godot 4.

Run from any directory. No network access or third-party dependencies required.
Only generated content/assets trees are written. Source SHA-256 values retain an
identity for every original HTML implementation; these hashes do not imply parity.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
IDS = [f"{world}-{stage}" for world in range(1, 7) for stage in [1, 2, 3, 4, 5, 6, "S"]]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def assignment(text, name):
    match = re.search(r"(?:const\s+|window\.)" + re.escape(name) + r"\s*=\s*", text)
    if not match:
        raise ValueError(f"Missing JSON assignment: {name}")
    return json.JSONDecoder().raw_decode(text[match.end():])[0]


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def build(source, output):
    source, output = Path(source), Path(output)
    sources, assets = {}, {}
    embedded_count = 0
    embedded_inventory = {}

    def read(path):
        data = path.read_bytes()
        sources[path.relative_to(source).as_posix()] = digest(data)
        return data

    def asset(data, relative):
        path = output / "assets" / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        if not path.exists() or path.read_bytes() != data:
            path.write_bytes(data)
        uri = "res://assets/" + relative
        assets[uri] = {"sha256": digest(data), "bytes": len(data)}
        return uri

    def portable(value):
        nonlocal embedded_count
        if isinstance(value, dict):
            return {key: portable(item) for key, item in value.items()}
        if isinstance(value, list):
            return [portable(item) for item in value]
        if isinstance(value, str) and value.startswith("data:"):
            match = re.fullmatch(r"data:image/(png|jpeg|webp);base64,(.*)", value, re.DOTALL)
            if not match:
                raise ValueError("Unsupported embedded asset MIME/encoding")
            data = base64.b64decode(match[2], validate=True)
            embedded_count += 1
            ext = {"jpeg": "jpg", "png": "png", "webp": "webp"}[match[1]]
            return asset(data, f"embedded/{digest(data)}.{ext}")
        return value

    # Inventory every embedded image in source HTML/JS, including map art and
    # scripts outside META. Keys hash the URL itself; asset names hash its bytes.
    image_pattern = re.compile(r"data:image/(?:png|jpeg|webp);base64,[A-Za-z0-9+/=]+")
    for source_path in sorted(source.rglob("*")):
        if source_path.suffix.lower() not in {".html", ".js"}:
            continue
        source_text = read(source_path).decode("utf-8")
        found = {}
        for match in image_pattern.finditer(source_text):
            url = match.group(0)
            found[digest(url.encode("utf-8"))] = portable(url)
        if found:
            embedded_inventory[source_path.relative_to(source).as_posix()] = found
    inventory_references = embedded_count
    embedded_count = 0
    menu_text = read(source / "index.html").decode("utf-8")
    menu = assignment(menu_text, "GAME")
    map_data = assignment(menu_text, "MAP4")
    # Native map uses the authored geometry, artwork, actor frames and copy.
    # Images share content-addressed assets already imported above; no web edits.
    write_json(output / "content/map.json", {
        "schema_version": 1, "source_sha256": sources["index.html"],
        "map": map_data, "game": menu, "pictures": portable(assignment(menu_text, "IMG")),
    })
    worlds = [{"id": island["n"], "name": island["name"]} for island in map_data["islands"]]
    levels = []
    for level_id in IDS:
        path = source / level_id / "index.html"
        original = read(path).decode("utf-8")
        meta = portable(assignment(original, "META"))
        relative = f"content/levels/{level_id}.json"
        write_json(output / relative, meta)
        descriptor = menu["levels"][level_id]
        levels.append({"id": level_id, "title": meta.get("text", {}).get("title", descriptor["name"]), "world": int(level_id[0]),
                       "path": "res://" + relative, "kind": descriptor.get("kindName", ""),
                       "description": descriptor.get("text", ""),
                       "source": f"{level_id}/index.html", "source_sha256": sources[f"{level_id}/index.html"]})
    for path in sorted((source / "sprites").glob("*")):
        if path.suffix in {".png", ".json"}:
            asset(read(path), "sprites/" + path.name)
    for path in sorted(source.rglob("*")):
        if path.suffix.lower() in {".woff", ".woff2", ".ttf", ".otf"}:
            asset(read(path), "fonts/" + path.name)
    # Keep story JS verbatim as a reference only. Do not evaluate it in Python.
    story_path = source / "cutscenes/cs.js"
    story = read(story_path)
    reference = output / "content/reference/cutscenes.js.txt"
    reference.parent.mkdir(parents=True, exist_ok=True)
    reference.write_bytes(story)
    for path in sorted((source / "cutscenes/img").glob("*")):
        if path.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"}:
            asset(read(path), "cutscenes/" + path.name)
    if (source / "title.jpg").is_file():
        asset(read(source / "title.jpg"), "title.jpg")
    write_json(output / "content/catalog.json", {"schema_version": 1, "worlds": worlds, "levels": levels})
    manifest = {"schema_version": 1, "sources": sources, "assets": assets,
                "embedded_images": embedded_inventory,
                "stats": {"levels": len(levels), "worlds": len(worlds), "embedded_references": embedded_count,
                          "source_embedded_references": inventory_references,
                          "unique_embedded_assets": sum("/embedded/" in uri for uri in assets),
                          "asset_files": len(assets), "asset_bytes": sum(item["bytes"] for item in assets.values())},
                "story_reference": "res://content/reference/cutscenes.js.txt",
                "limitations": ["This imports data and assets, not the per-level JavaScript gameplay implementations.",
                                "Source HTML gameplay is identified by SHA-256 and remains in game/<id>/index.html.",
                                "Story JavaScript is preserved verbatim for reference, not converted or executable in Godot.",
                                "WOFF/WOFF2 fonts are preserved but may require conversion for Godot font rendering."]}
    write_json(output / "content/manifest.json", manifest)
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT / "game")
    parser.add_argument("--output", type=Path, default=ROOT / "godot")
    args = parser.parse_args()
    print(json.dumps(build(args.source, args.output)["stats"], sort_keys=True))


if __name__ == "__main__":
    main()
