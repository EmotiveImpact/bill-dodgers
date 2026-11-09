import copy
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("web_titles", ROOT / "scripts/check-web-title-exclusions.py")
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)


class WebTitleExclusionTests(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads(CHECK.DEFAULT_MANIFEST.read_text())
        self.paths = CHECK.exclusion_paths(self.manifest)

    def test_exact_web_only_paths(self):
        self.assertEqual(len(self.paths), 36)
        self.assertTrue(self.manifest["scope"].startswith("Web Browser Preview only;"))
        self.assertNotIn("assets/title.jpg", self.paths)
        self.assertTrue(all(path.startswith("assets/embedded/") for path in self.paths))

    def test_no_broad_glob_or_nonembedded_asset_allowed(self):
        for bad in ["assets/embedded/*", "assets/title.jpg", "assets/sprites/jp-sheet.png", "../game/title.jpg"]:
            manifest = copy.deepcopy(self.manifest)
            manifest["excluded_assets"][0]["path"] = bad
            with self.assertRaises(ValueError):
                CHECK.exclusion_paths(manifest)

    def test_any_future_hash_reference_blocks_exclusion(self):
        path = self.paths[0]
        for value in ["res://" + path, path, Path(path).name, Path(path).stem]:
            violations = CHECK.reference_violations({"content/levels/6-6.json": json.dumps({"imgs": {"new_art": value}})}, self.paths)
            self.assertEqual(len(violations), 1)
            self.assertIn("references excluded asset", violations[0])

    def test_duplicate_or_changed_identity_rejected(self):
        manifest = copy.deepcopy(self.manifest)
        manifest["excluded_assets"].append(manifest["excluded_assets"][0])
        with self.assertRaises(ValueError):
            CHECK.exclusion_paths(manifest)
        manifest = copy.deepcopy(self.manifest)
        manifest["excluded_assets"][0]["sha256"] = "0" * 64
        with self.assertRaises(ValueError):
            CHECK.exclusion_paths(manifest)

    def test_new_dynamic_loader_detected(self):
        for text in ['var image = load(path)', 'ResourceLoader.load_threaded_request(path)', 'ResourceLoader.load(path)']:
            self.assertIsNotNone(CHECK.LOAD_CALL.search(text))
        self.assertIsNone(CHECK.LOAD_CALL.search('const Script = preload("res://src/main.gd")'))

    @unittest.skipUnless((ROOT / "godot/content/catalog.json").exists(), "Run native preparation for generated-content audit")
    def test_all_generated_runtime_content_and_original_titles(self):
        report = CHECK.validate()
        self.assertEqual(report["validated_count"], 36)
        self.assertGreater(report["imported_payload_bytes"], 30_000_000)
        self.assertEqual(report["filter"].split(","), self.paths)


if __name__ == "__main__":
    unittest.main()
