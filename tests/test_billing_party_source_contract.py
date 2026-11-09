"""World 6 executable party blocks are shared by all seven authored pages.

This is a source contract check, not native route/device acceptance. It never
executes the embedded image assets or changes the original HTML.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
STAGES = ('6-1', '6-2', '6-3', '6-4', '6-5', '6-6', '6-S')
BLOCKS = (
    ('function mkPlayer(', 'function say('),
    ('const alive =', 'function shakeIt('),
    ('function updatePlayer(', 'function updateCPU('),
    ('function updateCPU(', 'function updateBots('),
    ('function updatePlay(', 'const waveActive ='),
    ('let fliers =', '// ================= World 6 art:'),
    ('/* bd-abilities */', '/* bd-fixes */'),
    ('/* bd-fixes */', '/* bd-flow */'),
)

def block(text, start, end):
    return text[text.index(start):text.index(end, text.index(start))]

class BillingPartySourceContract(unittest.TestCase):
    def test_all_seven_pages_share_executable_party_contract(self):
        pages = {stage: (ROOT / 'game' / stage / 'index.html').read_text() for stage in STAGES}
        for start, end in BLOCKS:
            reference = block(pages['6-1'], start, end)
            for stage, page in pages.items():
                with self.subTest(stage=stage, block=start):
                    self.assertEqual(reference, block(page, start, end))

    def test_source_identity_and_per_victim_rules_are_present(self):
        text = (ROOT / 'game/6-1/index.html').read_text()
        for rule in (
            'if (s.owner) s.owner.pops++',
            'if (by) by.pops += 5',
            's.owner.bossHits = (s.owner.bossHits || 0) + 1',
            "hazards = LV.hazards.map((h) => ({ x: h[0], kind: h[1], hit: new Set() }))",
            'p.x = p.px = d.to + 80 + i * 70',
            'if (p.coins > 0) { p.coins--; kitty = Math.max(0, kitty - 1)',
            '!bots.some((o) => o.latch === q)',
            'players[0].coins += bonus',
            'const lowF = Math.max(...al.map((p) => GROUND + p.y)), hiF = Math.min(...al.map((p) => GROUND + p.y))',
            'tp = al[Math.floor(Math.random() * al.length)]',
            "if (use('dash') && !p.cpu)",
            'if (diag && !p.cpu)',
            "if (p.cpu || p.down || state !== 'play' || p.lock > 0 || !p.onG)",
        ):
            with self.subTest(rule=rule):
                self.assertIn(rule, text)

if __name__ == '__main__':
    unittest.main()
