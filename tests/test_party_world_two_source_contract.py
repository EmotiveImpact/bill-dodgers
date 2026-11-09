"""Audit executable W2 source shared by the native party scene adapters.

These are source-contract checks, not a browser simulation or device evidence.
Runtime behavior is exercised with the real PartyCombat bridge by
res://tests/test_party_world_two.gd.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
IDS = ["2-1", "2-2", "2-3", "2-4", "2-5", "2-6", "2-S"]


def function(source, name):
    start = source.index(f"function {name}(")
    return source[start:source.index("\n}", start) + 2]


class WorldTwoPartySourceContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sources = {stage: (ROOT / "game" / stage / "index.html").read_text()
                       for stage in IDS}

    def test_shared_simulation_is_identical_in_all_seven_stages(self):
        for name in ("lvAuto", "lvMove", "lvUpdate", "sceneUpdate", "lvCPU"):
            reference = function(self.sources["2-1"], name)
            for stage in IDS:
                with self.subTest(function=name, stage=stage):
                    self.assertEqual(function(self.sources[stage], name), reference)

    def test_scene_identity_stagger_and_revival(self):
        scene = function(self.sources["2-1"], "sceneUpdate")
        for fragment in (
            "for (const p of players) if (p.x > s[0])",
            "p.px = Math.min(p.px, s[0])",
            "Math.max(...al.map((p) => p.x)) < s[0] - 50",
            "players.forEach((p, i)",
            "p.x = p.px = x0 + (L.sceneLand < 100 ? -i * 70 : i * 70)",
            "below(p.x, L.landY !== undefined ? L.landY : -9999)",
            "if (p.down) { p.down = false; p.hearts = 3; }",
        ):
            self.assertIn(fragment, scene)
        self.assertNotIn("p.safe =", scene)
        self.assertNotIn("p.inv =", scene)
        self.assertNotIn("p.onPlat =", scene)
        self.assertIn("sceneView: 120, sceneLand: 0, sceneCam: 200, landY: GROUND - 6",
                      self.sources["2-3"])

    def test_late_scene_phase_order_and_roster_rules(self):
        late = function(self.sources["2-1"], "lvUpdate")
        phases = (
            "LVS.timer += dt; sceneUpdate(dt)",
            "for (const b of bots)",
            "if (LV.check && !LVS.cp",
            "HZ.forEach((h, i) => { if (h[0] === 'coins'",
            "for (const pl of LVS.plates)",
            "for (const e of LVS.ents) if (e.k === 'tspawn')",
            "// things that fall from the top shelves",
            "// flames from the bakery ovens",
            "for (const b of bots) if (b.state === 'cart'",
            "for (const b of bots) if (b.state === 'drone')",
            "updatePicks(dt)",
            "LVS.ents = LVS.ents.filter",
            "if (L.update) L.update(dt)",
        )
        indices = [late.index(phase) for phase in phases]
        self.assertEqual(indices, sorted(indices))
        self.assertIn("players.length > 1 && !players.some((p) => p.cpu) ? 2600 : 5200", late)
        self.assertIn("for (const p of players) { if (p.down) { p.down = false; p.inv = 2000; } p.hearts = 3", late)
        self.assertIn("for (const p of alive()) if (Math.abs(p.x - e.x) < 46", late)

    def test_actor_ice_is_not_shared_and_auto_clock_is_shared(self):
        move = function(self.sources["2-1"], "lvMove")
        self.assertIn("LVS.iv.get(p)", move)
        self.assertIn("LVS.iv.set(p, iv)", move)
        self.assertIn("!p.onG && LVS.iv.has(p)", move)
        self.assertIn("Math.min(1, dt / 900)", move)
        auto = function(self.sources["2-1"], "lvAuto")
        self.assertIn("Math.max(...al.map((p) => p.x))", auto)
        self.assertIn("LVS.spd += (want - LVS.spd)", auto)

    def test_base_order_cpu_then_players_and_single_world(self):
        base = function(self.sources["2-1"], "updatePlay")
        self.assertLess(base.index("if (p.cpu) updateCPU"), base.index("updatePlayer(p, dt)"))
        self.assertEqual(base.count("lvUpdate(dt)"), 1)
        self.assertIn("updateBots(dt); updateShots(dt); updateCoins(dt); lvUpdate(dt);", base)
        self.assertLess(base.index("updateJar(dt)"), base.index("players.every((p) => p.down)"))

    def test_checkout_owner_bag_and_crate_contract(self):
        source = self.sources["2-6"]
        start = source.index("L.readyEnd = () =>")
        boss = source[start:source.index("L.mid = () =>", start)]
        self.assertIn("hp: players.length > 1 ? 90 : 70", boss)
        self.assertIn("const m = mash; mash = 0", boss)
        self.assertIn("p.cpu ? 0 : m * 160", boss)
        self.assertIn("c.by = p; p.crate = c", boss)
        self.assertIn("if (!p || p.down || p.out)", boss)
        self.assertEqual(boss.count("s.owner.bossHits = (s.owner.bossHits || 0) + 1"), 2)
        self.assertIn("for (const q of alive()) if (q.x > tillLeft() - 10)", boss)

    def test_pair_input_drivers_are_verbatim_original_normal_controls(self):
        copied = (ROOT / "godot/tests/party_world_two_drivers.gd").read_text()
        cases = [("Parking", "parking", "controls_for"),
                 ("Aisle", "aisle", "walk_toward"),
                 ("Stockroom", "stockroom", "walk_toward"),
                 ("Bakery", "bakery", "walk_toward"),
                 ("Trolley", "trolley_dash", "controls_for"),
                 ("Checkout", "checkout", "walk"),
                 ("Shopping", "shopping_bonus", "controls_for")]
        for index, (name, stem, first) in enumerate(cases):
            source = (ROOT / f"godot/tests/test_full_{stem}_run.gd").read_text()
            expected = source[source.index("\n") + 1:source.index("func _initialize()")]
            expected += source[source.index(f"func {first}("):]
            if name == "Aisle":
                expected = expected.replace("ice_velocity.get(game.get_instance_id(), 0.0)",
                                            "ice_velocity.get(game.combat_owner_slot(), 0.0)")
            begin = copied.index(f"class {name} extends RefCounted:\n") + len(f"class {name} extends RefCounted:\n")
            end = copied.index("\nclass ", begin) if index < len(cases) - 1 else len(copied)
            actual = "".join(line[1:] if line.startswith("\t") else line
                             for line in copied[begin:end].splitlines(keepends=True))
            with self.subTest(driver=name):
                self.assertEqual(actual, expected)

    def test_shared_polish_focus_uses_living_roster_average(self):
        polish = (ROOT / "game/polish.js").read_text()
        self.assertIn("ps.filter((p) => !p.down && !p.out)", polish)
        self.assertIn("q.reduce((a, p) => a + p.x, 0) / q.length", polish)


if __name__ == "__main__":
    unittest.main()
