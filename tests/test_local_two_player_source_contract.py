"""Source basis for local-two-human native fixtures, not device certification.

This checks executable original source from each world family. Full event-route
evidence is produced separately by test_local_two_player_routes.gd.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class LocalTwoPlayerSourceContract(unittest.TestCase):
    def test_source_patched_keyboard_and_camera_roster_across_six_worlds(self):
        for world in range(1, 7):
            with self.subTest(world=world):
                source = (ROOT / f"game/{world}-1/index.html").read_text()
                for fragment in (
                    "{ jump: ['KeyG'], aim: ['KeyW'], fire: ['KeyF', 'KeyE'] }",
                    "const K = p.slot === 0 ? P1K : P2K, t = p.slot === 0 ? touch : {}",
                    "players.filter((p) => !p.cpu && !p.remote && !p.out)",
                    "Math.min(front - WV * 0.45, back - 60)",
                ):
                    self.assertIn(fragment, source)

    def test_source_down_rescue_and_clear_across_six_worlds(self):
        for world in range(1, 7):
            with self.subTest(world=world):
                source = (ROOT / f"game/{world}-1/index.html").read_text()
                for fragment in (
                    "Math.abs(o.x - p.x) < 80 && Math.abs(o.y - p.y) < 70",
                    "p.revive > 1400",
                    "p.hearts = 2; p.inv = 2200; p.lock = 600",
                    "players.every((p) => p.down)",
                    "if (p.down) { p.down = false; p.hearts = 1; }",
                ):
                    self.assertIn(fragment, source)

    def test_first_two_human_pad_is_possible_but_legacy_pilot_reserve_is_not(self):
        source = (ROOT / "game/2-2/index.html").read_text()
        self.assertIn("players.length > 1 && !players.some((p) => p.cpu) ? 2600 : 5200", source)
        # Gate0 x2500, pressure pad x1900, source speed270px/s. Exit target
        # x2580 leaves0.0815s after nominal travel, not a0.35s pilot reserve.
        travel = (2500 + 80 - 1900) / 270
        self.assertLess(travel + 0.04, 2.6)
        self.assertGreater(travel + 0.35, 2.6)

    def test_event_driver_has_one_native_poll_and_no_per_actor_world_step(self):
        driver = (ROOT / "godot/tests/local_two_player_input.gd").read_text()
        routes = (ROOT / "godot/tests/test_local_two_player_routes.gd").read_text()
        self.assertEqual(driver.count("game._physics_process(dt)"), 1)
        self.assertNotIn("game.step(", routes)
        self.assertNotIn("session.step(", routes)
        self.assertNotIn("session.bind(", routes)
        self.assertIn("Input.parse_input_event(event)", driver)
        for forbidden in (".player =", ".hearts =", ".mark_down(", "._complete_level(", ".done =", ".hp ="):
            self.assertNotIn(forbidden, routes)


if __name__ == "__main__":
    unittest.main()
