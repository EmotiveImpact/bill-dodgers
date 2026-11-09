"""Executable-source audit for native W5 party phase/roster contracts.

This is source evidence, not a browser simulation or full-route certification.
The real bridge and host tests are test_moving_day_party{,_host}.gd.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
IDS = ["5-1", "5-2", "5-3", "5-4", "5-5", "5-6", "5-S"]


def region(source, start, end):
    i = source.index(start)
    return source[i:source.index(end, i)]


class MovingDayPartySourceContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sources = {s: (ROOT / "game" / s / "index.html").read_text() for s in IDS}

    def test_base_simulation_identical_across_all_stages(self):
        for begin, end in [
            ("function mkPlayer(", "function spawnBot("),
            ("function updatePlayer(", "function updateCPU("),
            ("function updateCPU(", "function updateBots("),
            ("function updateShots(", "function updateCoins("),
            ("function updatePlay(", "const waveActive"),
            ("function LEVEL_WAVES(", "function drawCrate("),
        ]:
            expected = region(self.sources["5-1"], begin, end)
            for stage in IDS:
                with self.subTest(stage=stage, begin=begin):
                    self.assertEqual(region(self.sources[stage], begin, end), expected)

    def test_world_variation_is_only_unused_sofa_render_height(self):
        begin, end = "const W5 = (() => {", "// music slots:"
        expected = region(self.sources["5-2"], begin, end)
        for stage in IDS:
            actual = region(self.sources[stage], begin, end)
            actual = actual.replace("(carrierH * 0.8);", "(carrierH * 0.28);  // held at hand height between the two of them, not above their heads")
            with self.subTest(stage=stage):
                self.assertEqual(actual, expected)
        import json
        for stage in IDS:
            level = json.loads((ROOT / "godot/content/levels" / f"{stage}.json").read_text())["level"]
            self.assertEqual("sofa" in level, stage == "5-2")

    def test_once_shared_phase_order(self):
        source = region(self.sources["5-1"], "function updatePlay(", "const waveActive")
        phases = ["levelT += dt", "if (p.cpu) updateCPU", "updatePlayer(p, dt)",
                  "W5.update(dt)", "const al = alive()", "for (const w of waves)",
                  "W5.atEnd()", "updateBots(dt)", "updateShots(dt)", "updateCoins(dt)",
                  "updateBoss(dt)", "updateJar(dt)", "players.every((p) => p.down)"]
        positions = [source.index(p) for p in phases]
        self.assertEqual(positions, sorted(positions))
        self.assertEqual(source.count("W5.update(dt)"), 1)
        actor = region(self.sources["5-1"], "function updatePlayer(", "function updateCPU(")
        self.assertIn("(p.carry ? 0.78 : 1)", actor)
        self.assertLess(actor.index("wallClamp("), actor.index("st.push || st.vx"))
        self.assertLess(actor.index("st.push || st.vx"), actor.index("const f0 = GROUND + p.y"))

    def test_all_roster_checkpoint_wipe_and_actor_carry(self):
        source = self.sources["5-1"]
        scene = region(source, "  function sceneChange(", "  function start(")
        self.assertIn("players.forEach((p, i)", scene)
        self.assertIn("p.x = p.px = s.to + i * 60", scene)
        self.assertNotIn("p.safe =", scene)
        self.assertNotIn("p.hearts =", scene)
        self.assertNotIn("p.onPlat =", scene)
        self.assertIn("for (const o of players) { if (o.down) o.down = false; o.hearts = 3; o.inv = 1200; }", source)
        sofa = region(source, "  function updateSofa(", "  function sofaRect(")
        self.assertIn("for (const p of players) p.carry = false", sofa)
        self.assertIn("for (const p of near) p.carry = true", sofa)
        self.assertIn("inputFor(p).d", sofa)
        self.assertIn("s.tipT > 450", sofa)
        lift = region(source, "  function updateLift(", "  function drawLift(")
        self.assertIn("const riders = alive().filter", lift)
        self.assertIn("if (dy) for (const p of riders) p.y += dy", lift)

    def test_party_human_driver_keeps_original_normal_inputs(self):
        original = (ROOT / "godot/tests/test_full_moving_day_runs.gd").read_text()
        expected = original[original.index("func controls("):original.index("func check(")]
        expected += original[original.index("func observe("):]
        copied = (ROOT / "godot/tests/moving_day_party_route_controls.gd").read_text()
        self.assertEqual(copied[copied.index("func controls("):], expected)

    def test_owner_scaling_and_king_rules(self):
        source = self.sources["5-1"]
        shots = region(source, "function updateShots(", "function updateCoins(")
        self.assertIn("s.t === 0 && s.owner ? s.owner.x : s.x", shots)
        self.assertIn("killBot(b, s.owner)", shots)
        self.assertIn("s.owner.bossHits = (s.owner.bossHits || 0) + 1", shots)
        self.assertIn("players.length > 1 ? 34 : 26", source)
        self.assertIn("const n = players.length > 1 ? 3 : 2", source)
        self.assertIn("players.length > 1 ? 1.3 : 1", source)
        self.assertIn("const n = (players.length > 1 ? 3 : 2) + b.phase", source)
        self.assertIn("w.g.length % 2 ? 'l' : 'r', 'rush'", source)


if __name__ == "__main__":
    unittest.main()
