import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("prepare_native", ROOT / "scripts/prepare-native.py")
PREPARE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PREPARE)


class PrepareNativeTests(unittest.TestCase):
    def test_repository_has_every_source(self):
        PREPARE.source_requirements(ROOT)

    def test_tested_tool_versions(self):
        PREPARE.validate_versions("4.6.3.stable.official.7d41c59c4", "v18.0.0")
        PREPARE.validate_versions("4.6.3.stable.official.7d41c59c4", "v22.1.0")

    def test_rejects_incompatible_tools(self):
        for godot, node in [("4.5.1.stable.official", "v22.0.0"), ("4.6.3.stable.official", "v16.2.0"), ("4.6.3.stable.official", "unknown")]:
            with self.assertRaises(RuntimeError):
                PREPARE.validate_versions(godot, node)

    def test_plan_uses_argument_lists_and_no_install_or_game_run(self):
        root = Path("/path with spaces/Bill Dodgers")
        plan = PREPARE.commands(root, "python3", "node", "/apps/Godot app")
        self.assertEqual(len(plan), 4)
        self.assertEqual(plan[0], ["python3", str(root / "scripts/import-godot-content.py")])
        self.assertEqual(plan[1], ["node", str(root / "scripts/extract-story.mjs")])
        self.assertIn("res://tools/build_audio.gd", plan[2])
        self.assertEqual(plan[3][-2:], ["--editor", "--import"])
        self.assertNotIn("--export-release", sum(plan, []))


if __name__ == "__main__":
    unittest.main()
