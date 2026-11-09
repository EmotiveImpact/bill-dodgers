import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("resource_profile", ROOT / "scripts/profile-native-resources.py")
PROFILE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PROFILE)


class NativeResourceProfileTests(unittest.TestCase):
    def test_resource_paths_are_distinct_from_arbitrary_text(self):
        value = {"imgs": ["res://assets/x.png", {"path": "res://assets/y.webp"}], "text": "assets/x.png"}
        self.assertEqual(list(PROFILE.resource_paths(value)), ["res://assets/x.png", "res://assets/y.webp"])

    def test_ctex_header(self):
        with tempfile.TemporaryDirectory() as work:
            file = Path(work) / "sample.ctex"
            file.write_bytes(struct.pack("<4sIII", b"GST2", 1, 1440, 2430))
            self.assertEqual(PROFILE.ctex_dimensions(file), (1440, 2430))
            file.write_bytes(struct.pack("<4sIII", b"NOPE", 1, 1440, 2430))
            with self.assertRaises(ValueError):
                PROFILE.ctex_dimensions(file)

    def test_pack_directory(self):
        with tempfile.TemporaryDirectory() as work:
            file = Path(work) / "sample.pck"
            entries = [(".godot/imported/art.ctex", 100), ("assets/music/title.res", 40),
                       ("assets/audio/pop.res", 10), ("content/catalog.json", 3)]
            blob = struct.pack("<6I2Q", 0x43504447, 3, 4, 6, 3, 2, 40, 40)
            blob += struct.pack("<I", len(entries))
            for name, size in entries:
                encoded = name.encode() + b"\0"
                blob += struct.pack("<I", len(encoded)) + encoded + struct.pack("<2Q", 0, size) + bytes(20)
            file.write_bytes(blob)
            actual = PROFILE.pack_inventory(file)
            self.assertEqual(actual["entry_count"], 4)
            self.assertEqual(actual["payload_bytes_by_category"],
                             {"textures": 100, "music": 40, "effects_and_fallback_music": 10, "other": 3})

    def test_log_rows(self):
        self.assertEqual(PROFILE.profile_rows('Godot\nRESOURCE_PROFILE {"label":"title_ready"}\n'),
                         [{"label": "title_ready"}])


if __name__ == "__main__":
    unittest.main()
