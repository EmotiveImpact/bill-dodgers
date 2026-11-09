"""Exact source-backed story export, asset and isolation checks."""
import hashlib
import json
from pathlib import Path
import subprocess
import unittest
ROOT = Path(__file__).resolve().parents[1]
class StoryExtraction(unittest.TestCase):
    def test_exact_export_and_source_hash(self):
        subprocess.run(['node', 'scripts/extract-story.mjs', '--check'], cwd=ROOT, check=True)
        data = json.loads((ROOT / 'godot/content/story.json').read_text())
        source = (ROOT / 'game/cutscenes/cs.js').read_bytes()
        self.assertEqual(data['source_sha256'], hashlib.sha256(source).hexdigest())
        self.assertEqual(len(data['worlds']), 6)
        self.assertEqual(len(data['scenes']), 21)
        self.assertEqual(sum(len(s['shots']) for s in data['scenes'].values()), 193)
        for world in data['worlds']:
            for scene in world['scenes']:
                self.assertIn(scene, data['scenes'])
        self.assertEqual(data['scenes']['1-clue']['shots'][1]['insert']['lines'][0], 'Beans x 40|£28.00')
        for scene in data['scenes'].values():
            for shot in scene['shots']:
                for prefix, key, suffix in [('bg-', shot.get('bg'), '.webp')]:
                    if key:
                        self.assertTrue((ROOT / 'godot/assets/cutscenes' / (prefix + key + suffix)).is_file())
    def test_runtime_boundary_is_excluded(self):
        source = (ROOT / 'game/cutscenes/cs.js').read_text()
        prefix = source.split('/* Bill Dodgers cutscene player.')[0]
        self.assertNotIn('document.', prefix)
        self.assertTrue(prefix.rstrip().endswith('})();'))
        # The extractor itself must expose neither require nor host objects in VM.
        script = (ROOT / 'scripts/extract-story.mjs').read_text()
        self.assertIn('vm.createContext(Object.create(null)', script)
        self.assertIn('strings: false, wasm: false', script)
if __name__ == '__main__': unittest.main()
