import configparser
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("native_web_export", ROOT / "scripts/export-native-web.py")
exporter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(exporter)


class NativeWebExportTests(unittest.TestCase):
    def test_separate_single_threaded_preset(self):
        presets = configparser.ConfigParser(interpolation=None)
        presets.read(ROOT / "godot/export_presets.cfg")
        self.assertEqual(presets["preset.2"]["name"], '"Web Demo"')
        self.assertEqual(presets["preset.2"]["export_path"], '"builds/web-demo/index.html"')
        for option in ("variant/thread_support", "variant/extensions_support", "progressive_web_app/enabled",
                       "progressive_web_app/ensure_cross_origin_isolation_headers"):
            self.assertFalse(presets["preset.2.options"].getboolean(option))
        self.assertEqual(presets["preset.2"]["include_filter"], presets["preset.0"]["include_filter"])
        self.assertEqual(presets["preset.2"]["exclude_filter"], presets["preset.0"]["exclude_filter"])
        original_web = json.loads((ROOT / "vercel.json").read_text())
        self.assertEqual(original_web["buildCommand"], "node scripts/build-web.mjs")
        self.assertEqual(original_web["outputDirectory"], "dist")

    def make_templates(self, root):
        (root / "version.txt").write_text(exporter.VERSION)
        for name in exporter.TEMPLATES:
            with zipfile.ZipFile(root / name, "w") as archive:
                for member in ("godot.html", "godot.js", "godot.wasm"):
                    archive.writestr(member, "test fixture only")

    def test_template_validation_and_wrong_version(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            self.make_templates(root)
            exporter.validate_templates(root)
            (root / "version.txt").write_text("4.5.stable")
            with self.assertRaises(RuntimeError):
                exporter.validate_templates(root)

    def test_incomplete_template_rejected(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            self.make_templates(root)
            with zipfile.ZipFile(root / exporter.TEMPLATES[0], "w") as archive:
                archive.writestr("unrelated.txt", "x")
            with self.assertRaises(RuntimeError):
                exporter.validate_templates(root)

    def make_export(self, root):
        (root / "index.html").write_text("const GODOT_THREADS_ENABLED = false;")
        (root / "index.js").write_text("test fixture only")
        (root / "index.wasm").write_bytes(b"\0asmfixture")
        (root / "index.pck").write_bytes(b"GDPCfixture")

    def test_export_inventory_and_headers(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            self.make_export(root)
            result = exporter.validate_export(root)
            self.assertEqual(len(result), 4)
            self.assertTrue(all(len(row["sha256"]) == 64 for row in result))
            (root / "index.pck").write_bytes(b"bad")
            with self.assertRaises(RuntimeError):
                exporter.validate_export(root)

    def test_threaded_or_empty_export_rejected(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            self.make_export(root)
            (root / "index.html").write_text("const GODOT_THREADS_ENABLED = true;")
            with self.assertRaises(RuntimeError):
                exporter.validate_export(root)
            (root / "index.wasm").write_bytes(b"")
            with self.assertRaises(RuntimeError):
                exporter.validate_export(root)

    def test_template_locations_are_inside_process_sandbox(self):
        root = Path("/tmp/isolated-test")
        paths = exporter.template_locations(root)
        self.assertEqual(len(paths), 3)
        self.assertTrue(all(root in path.parents and path.name == exporter.VERSION for path in paths))


if __name__ == "__main__":
    unittest.main()
