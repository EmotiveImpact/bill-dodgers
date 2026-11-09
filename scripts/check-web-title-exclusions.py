#!/usr/bin/env python3
"""Fail-closed audit of an explicit Web-only unused-title exclusion list.

Read-only: never edits presets, assets, imports or source files. Resource-loader
source fingerprints deliberately require review after loader changes; do not
refresh them automatically to suppress a failure. Export integration must invoke
this check before consuming --print-filter. Packed runtime checks remain required.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "scripts/native-web-title-exclusions.json"
LOAD_CALL = re.compile(r"(?<!pre)\bload\s*\(|ResourceLoader\.load\w*\s*\(")
TITLE = re.compile(r"const\s+SRC\s*=\s*\{\s*title:\s*'data:image/jpeg;base64,([^']+)'")
ASSET = re.compile(r"assets/embedded/([0-9a-f]{64})\.jpg")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def exclusion_paths(manifest):
    result = []
    for entry in manifest["excluded_assets"]:
        path = entry["path"]
        match = ASSET.fullmatch(path)
        if not match or match[1] != entry["sha256"]:
            raise ValueError("Only exact content-addressed embedded JPEG paths may be excluded: " + path)
        if path in result:
            raise ValueError("Duplicate exclusion: " + path)
        result.append(path)
    if not result:
        raise ValueError("Empty exclusion manifest")
    return result


def reference_violations(texts, paths):
    """A full hash match also catches references without a res:// prefix."""
    violations = []
    for name, text in texts.items():
        for path in paths:
            if Path(path).stem in text:
                violations.append(f"{name} references excluded asset {path}")
    return violations


def validate(root=ROOT, manifest_path=DEFAULT_MANIFEST):
    project = root / "godot"
    manifest = json.loads(manifest_path.read_text())
    if manifest.get("schema_version") != 1 or not manifest.get("scope", "").startswith("Web Browser Preview only;"):
        raise ValueError("Expected explicit Web-only exclusion scope")
    paths = exclusion_paths(manifest)
    if len(paths) != 36:
        raise ValueError("Audited exclusion set must contain exactly 36 original stage titles")
    required = [project / "content/catalog.json", project / "content/map.json", project / "content/story.json"]
    required += [project / "content/levels" / f"{world}-{stage}.json"
                 for world in range(1, 7) for stage in [1, 2, 3, 4, 5, 6, "S"]]
    if any(not path.is_file() for path in required):
        raise ValueError("Generated runtime content is incomplete; prepare the native project first")
    errors = []
    files = list((project / "src").rglob("*"))
    files += list(project.glob("*.tscn")) + list(project.glob("*.tres")) + [project / "project.godot"]
    files += list((project / "content").rglob("*.json")) + list((project / "assets").rglob("*.json"))
    # The provenance inventory intentionally names every preserved original.
    # It is not read by production. All other generated JSON is checked.
    files = [path for path in files if path.is_file() and path != project / "content/manifest.json"]
    texts = {path.relative_to(project).as_posix(): path.read_text() for path in files}
    errors.extend(reference_violations(texts, paths))
    if any("content/manifest.json" in text for name, text in texts.items() if name.startswith("src/")):
        errors.append("Production now reads the provenance manifest; resource reachability must be re-audited")
    # All nonliteral texture paths were reviewed: META.imgs, map.pictures,
    # selector META.imgs.st0, and fixed sprites/cutscenes/audio/music directories.
    # Fail closed if any of those loaders changes or another loader is added.
    loaders = {path.relative_to(project).as_posix(): digest(path.read_bytes())
               for path in (project / "src").rglob("*.gd") if LOAD_CALL.search(path.read_text())}
    if loaders != manifest["reviewed_resource_loader_sha256"]:
        errors.append("Runtime resource-loader sources changed; manually review reachability and refresh audited fingerprints before export")
    if any(("embedded/" in text or re.search(r'''["']embedded["']''', text))
           for name, text in texts.items() if name.startswith("src/")):
        errors.append("Production constructs or names the embedded directory; re-audit dynamic resource paths")

    title_sources = {}
    for path in sorted((root / "game").glob("*/index.html")):
        match = TITLE.search(path.read_text())
        if match:
            data = base64.b64decode(match[1], validate=True)
            uri = "assets/embedded/" + digest(data) + ".jpg"
            title_sources.setdefault(uri, []).append(path.relative_to(root).as_posix())
    if set(title_sources) != set(paths) or sum(map(len, title_sources.values())) != 42:
        errors.append("Exclusion list no longer matches exactly the 42 source stages' 36 distinct SRC.title JPEGs")
    imported_bytes = 0
    for entry in manifest["excluded_assets"]:
        path = project / entry["path"]
        if not path.is_file() or digest(path.read_bytes()) != entry["sha256"]:
            errors.append("Missing or modified preserved source asset: " + entry["path"])
        if entry["source_stage_titles"] != title_sources.get(entry["path"], []):
            errors.append("Stage-title provenance changed: " + entry["path"])
        sidecar = Path(str(path) + ".import")
        if not sidecar.is_file():
            errors.append("Missing texture import: " + entry["path"])
            continue
        imported = re.search(r'^path="res://([^"]+\.ctex)"$', sidecar.read_text(), re.MULTILINE)
        if not imported or not (project / imported[1]).is_file():
            errors.append("Missing imported payload: " + entry["path"])
        else:
            imported_bytes += (project / imported[1]).stat().st_size
    # Protect the native title and exact source selector background explicitly.
    if not (project / "assets/title.jpg").is_file():
        errors.append("Native title painting is missing")
    selector = json.loads((project / "content/levels/1-1.json").read_text())["imgs"]["st0"]
    if selector.removeprefix("res://") in paths or not (project / selector.removeprefix("res://")).is_file():
        errors.append("Original selector backdrop would be missing")
    if errors:
        raise ValueError("\n".join(errors))
    return {"validated_count": len(paths), "imported_payload_bytes": imported_bytes,
            "excluded_source_paths": paths, "filter": ",".join(paths),
            "scope": "Web only; all source/import files retained; rerun packed runtime after export"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--print-filter", action="store_true")
    args = parser.parse_args()
    try:
        report = validate(manifest_path=args.manifest)
    except (ValueError, KeyError, OSError) as error:
        parser.exit(1, "Web title exclusion validation failed:\n" + str(error) + "\n")
    print(report["filter"] if args.print_filter else json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
