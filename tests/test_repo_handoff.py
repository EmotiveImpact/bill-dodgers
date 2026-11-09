import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RepoHandoffTests(unittest.TestCase):
    def test_native_branch_cannot_auto_deploy(self):
        configuration = json.loads((ROOT / "vercel.json").read_text())
        self.assertEqual(configuration["git"]["deploymentEnabled"], {"mobile/godot-foundation": False})
        self.assertEqual(configuration["buildCommand"], "node scripts/build-web.mjs")
        self.assertEqual(configuration["outputDirectory"], "dist")
        self.assertEqual(len(configuration["headers"]), 2)

    def test_real_project_and_canonical_assets_are_separate(self):
        self.assertTrue((ROOT / "godot/project.godot").is_file())
        self.assertTrue((ROOT / "godot/main.tscn").is_file())
        self.assertTrue((ROOT / "game/title.jpg").is_file())
        self.assertTrue((ROOT / "game/sprites/jp-sheet.png").is_file())
        ignored = (ROOT / ".gitignore").read_text()
        self.assertIn("godot/.godot/", ignored)
        self.assertIn("godot/builds/", ignored)
        self.assertIn("!godot/assets/music/*.res", ignored)
        self.assertIn("*.godot-export-credentials", ignored)

    def test_setup_documents_generated_asset_boundary(self):
        text = (ROOT / "docs/EDITING_ON_ANOTHER_COMPUTER.md").read_text()
        for phrase in ["prepare-native.py", "project.godot", "PowerShell", "macOS", "generated", "not just", "physical-device"]:
            self.assertIn(phrase, text)

    def test_binary_resources_do_not_receive_line_endings(self):
        text = (ROOT / ".gitattributes").read_text()
        self.assertIn("*.res binary", text)
        self.assertIn("*.png binary", text)
        self.assertIn("*.html text eol=lf", text)


if __name__ == "__main__":
    unittest.main()
