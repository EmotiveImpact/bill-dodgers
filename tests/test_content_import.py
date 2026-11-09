"""Content extraction contract, fidelity and byte-for-byte determinism tests."""
import base64
import importlib.util
import json
import re
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("content_import", ROOT / "scripts/import-godot-content.py")
importer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(importer)


class ContentImportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.output = Path(cls.temp.name)
        cls.manifest = importer.build(ROOT / "game", cls.output)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def test_catalog_has_all_levels_and_worlds(self):
        catalog = json.loads((self.output / "content/catalog.json").read_text())
        self.assertEqual([row["id"] for row in catalog["levels"]], importer.IDS)
        self.assertEqual([row["id"] for row in catalog["worlds"]], list(range(1, 7)))
        for row in catalog["levels"]:
            self.assertTrue(row["title"])
            self.assertTrue((self.output / row["path"].removeprefix("res://")).is_file())

    def test_exact_metadata_and_embedded_asset_bytes(self):
        def compare(source, imported):
            if isinstance(source, dict):
                self.assertEqual(set(source), set(imported))
                for key in source:
                    compare(source[key], imported[key])
            elif isinstance(source, list):
                self.assertEqual(len(source), len(imported))
                for left, right in zip(source, imported):
                    compare(left, right)
            elif isinstance(source, str) and source.startswith("data:"):
                self.assertTrue(imported.startswith("res://assets/embedded/"))
                actual = (self.output / imported.removeprefix("res://")).read_bytes()
                self.assertEqual(base64.b64decode(source.split(",", 1)[1]), actual)
            else:
                self.assertEqual(source, imported)
        for level_id in importer.IDS:
            original = (ROOT / "game" / level_id / "index.html").read_text()
            data = json.loads((self.output / f"content/levels/{level_id}.json").read_text())
            compare(importer.assignment(original, "META"), data)
            self.assertNotIn("data:image/", json.dumps(data))

    def test_assets_and_source_hashes(self):
        for uri, item in self.manifest["assets"].items():
            data = (self.output / uri.removeprefix("res://")).read_bytes()
            self.assertEqual(importer.digest(data), item["sha256"])
            self.assertEqual(len(data), item["bytes"])
        for source, sha in self.manifest["sources"].items():
            self.assertEqual(importer.digest((ROOT / "game" / source).read_bytes()), sha)
        self.assertEqual((self.output / "assets/title.jpg").read_bytes(), (ROOT / "game/title.jpg").read_bytes())
        self.assertEqual((self.output / "content/reference/cutscenes.js.txt").read_bytes(), (ROOT / "game/cutscenes/cs.js").read_bytes())
        self.assertLess(self.manifest["stats"]["unique_embedded_assets"], self.manifest["stats"]["source_embedded_references"])

    def test_every_source_embedded_image_is_retained(self):
        count = 0
        for path in sorted((ROOT / "game").rglob("*")):
            if path.suffix.lower() not in {".html", ".js"}:
                continue
            relative = path.relative_to(ROOT / "game").as_posix()
            # Independent scan detects unsupported MIME types too.
            matches = re.findall(r"data:image/[^;\s]+;base64,[A-Za-z0-9+/=]+", path.read_text())
            for url in matches:
                count += 1
                uri = self.manifest["embedded_images"][relative][importer.digest(url.encode())]
                self.assertIn(uri, self.manifest["assets"])
                self.assertEqual(base64.b64decode(url.split(",", 1)[1]),
                                 (self.output / uri.removeprefix("res://")).read_bytes())
        self.assertEqual(count, self.manifest["stats"]["source_embedded_references"])
        self.assertGreater(count, self.manifest["stats"]["embedded_references"])

    def test_rebuild_is_deterministic_and_preserves_other_files(self):
        def snapshot():
            return {p.relative_to(self.output).as_posix(): importer.digest(p.read_bytes())
                    for p in self.output.rglob("*") if p.is_file()}
        marker = self.output / "project.godot"
        marker.write_text("do not touch")
        before = snapshot()
        self.assertEqual(importer.build(ROOT / "game", self.output), self.manifest)
        self.assertEqual(before, snapshot())

    def test_invalid_json_is_rejected_not_executed(self):
        with self.assertRaises(ValueError):
            importer.assignment("const META = alert('unsafe')", "META")
        with self.assertRaises(ValueError):
            importer.assignment("const OTHER = {}", "META")


if __name__ == "__main__":
    unittest.main()
