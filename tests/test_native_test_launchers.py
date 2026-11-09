"""Validate launcher isolation/dispatch, not game behavior or device acceptance."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class PartyLauncher(unittest.TestCase):
    def invoke(self, arguments=(), failure=""):
        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
            engine = temp / "godot-fixture"
            engine.write_text(
                "#!/usr/bin/env python3\n"
                "import json,os,sys\n"
                "with open(os.environ['FAKE_ENGINE_LOG'],'a') as f:\n"
                " f.write(json.dumps({'args':sys.argv[1:],'data':os.environ.get('XDG_DATA_HOME')})+'\\n')\n"
                "print(os.environ.get('FAKE_FAILURE','') or 'Fixture engine only')\n"
            )
            engine.chmod(0o755)
            trace = temp / "trace.jsonl"
            env = dict(os.environ, GODOT=str(engine), FAKE_ENGINE_LOG=str(trace),
                       FAKE_FAILURE=failure, BD_PARTY_LOG_DIR=str(temp / "logs"))
            result = subprocess.run(
                ["bash", "scripts/verify-party.sh", *arguments], cwd=ROOT,
                env=env, capture_output=True, text=True, timeout=20,
            )
            rows = [json.loads(line) for line in trace.read_text().splitlines()] if trace.exists() else []
            return result, rows

    def test_default_is_quick_and_every_suite_has_an_isolated_save_directory(self):
        result, rows = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(rows), 36)
        self.assertEqual(len({row["data"] for row in rows}), 33)
        suites = [row["args"][row["args"].index("--script") + 1] for row in rows]
        self.assertIn("res://tests/test_party_selection.gd", suites)
        self.assertIn("res://tests/test_party_cpu_skills.gd", suites)
        self.assertFalse(any("full_runs" in suite for suite in suites))
        selection = [row for row in rows if "res://tests/test_party_selection.gd" in row["args"]]
        self.assertEqual(len(selection), 4)
        self.assertEqual(len({row["data"] for row in selection}), 1)
        self.assertEqual([row["args"][-1] for row in selection[1:]], ["p2", "cpu", "solo"])

    def test_world_five_routes_cover_every_cpu_identity_without_quick_suite(self):
        result, rows = self.invoke(["--routes-only", "--world=5"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(rows), 6)
        for row, mate in zip(rows, ["jp", "maya", "ama", "leo", "theo", "mei"]):
            self.assertIn("res://tests/test_full_moving_day_party_runs.gd", row["args"])
            self.assertIn("--mate=" + mate, row["args"])
            self.assertIn("--mode=cpu", row["args"])

    def test_runtime_errors_and_leaks_cannot_masquerade_as_zero_exit_success(self):
        for failure in ["SCRIPT ERROR: fixture", "ERROR: fixture", "ObjectDB instances leaked", "FAIL: fixture"]:
            with self.subTest(failure=failure):
                result, rows = self.invoke(failure=failure)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(len(rows), 1)

    def test_invalid_world_is_rejected_without_starting_engine(self):
        result, rows = self.invoke(["--world=7"])
        self.assertEqual(result.returncode, 2)
        self.assertEqual(rows, [])


if __name__ == "__main__":
    unittest.main()
