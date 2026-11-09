"""Authored map topology and embedded painting identity, no JavaScript execution."""
import importlib.util
import hashlib
import base64
import json
from pathlib import Path
import tempfile
import unittest
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("content_import", ROOT / "scripts/import-godot-content.py")
importer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(importer)

class MapImportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.output = Path(cls.temp.name)
        importer.build(ROOT / "game", cls.output)
        cls.source = (ROOT / "game/index.html").read_text()
        cls.map = json.loads((cls.output / "content/map.json").read_text())
    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()
    def test_map_topology_and_actor_metadata_are_exact(self):
        self.assertEqual(self.map["map"], importer.assignment(self.source, "MAP4"))
        self.assertEqual(self.map["game"], importer.assignment(self.source, "GAME"))
        self.assertEqual(self.map["source_sha256"], hashlib.sha256((ROOT / "game/index.html").read_bytes()).hexdigest())
        self.assertEqual(len(self.map["map"]["islands"]), 6)
        self.assertEqual(len(self.map["game"]["levels"]), 42)
    def test_all_source_map_pictures_are_identical(self):
        source_pictures = importer.assignment(self.source, "IMG")
        self.assertEqual(set(self.map["pictures"]), set(source_pictures))
        self.assertEqual(len(source_pictures), 18)
        for name, original in source_pictures.items():
            expected = base64.b64decode(original.split(",", 1)[1])
            actual = (self.output / self.map["pictures"][name].removeprefix("res://")).read_bytes()
            self.assertEqual(actual, expected, name)
