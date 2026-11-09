"""Lightweight source/content audit: no artwork import or game launch required."""
import collections
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
IDS = [f"{world}-{stage}" for world in range(1, 7) for stage in [1, 2, 3, 4, 5, 6, "S"]]
EXPECTED_COINS = [0, 0, 0, 0, 0, 0, 312, 73, 70, 40, 243, 46, 25, 128,
                  29, 80, 15, 20, 0, 0, 179, 0, 0, 0, 0, 0, 0, 258,
                  0, 0, 0, 0, 0, 0, 484, 95, 72, 111, 165, 28, 12, 139]
EXPECTED_CRATES = [6, 6, 0, 5, 3, 2, 1, 5, 5, 5, 0, 5, 3, 1,
                   7, 5, 6, 5, 0, 3, 0, 4, 3, 2, 0, 0, 3, 0,
                   3, 0, 2, 3, 0, 2, 0, 5, 5, 6, 0, 0, 3, 2]
CARDS = {"1-4": [8497, 442, "slide"], "2-5": [8850, 232, "double-jump"],
         "3-4": [5700, -358, "ground-pound"], "4-4": [11710, 342, "dash"],
         "5-4": [3560, 482, "wall-jump"], "6-4": [369, -5632, "super"]}


def source_meta(level_id):
    text = (ROOT / "game" / level_id / "index.html").read_text()
    start = re.search(r"const\s+META\s*=\s*", text).end()
    return text, json.JSONDecoder().raw_decode(text[start:])[0]


def authored_coin_count(level_id, level):
    world = int(level_id[0])
    if level_id == "1-S":
        # The source streams 8-coin patterns until the last camera boundary.
        return len(range(700, level["w"] + 120, 560)) * 8
    if world == 2:
        return sum(row[4] for row in level.get("hz", []) if row[0] == "coins")
    if world == 3:
        return sum(row[3] for row in level.get("coinRows", []))
    if world == 4:
        return len(level.get("cfg", {}).get("dash", {}).get("coins", []))
    if world == 5:
        return len(level.get("coins", []))
    return len(level.get("coinRows", [])) if world == 6 else 0


class PickupSourceInventory(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = {level_id: source_meta(level_id) for level_id in IDS}

    def test_all_42_authored_loot_counts_and_imported_coordinates(self):
        totals = collections.Counter()
        for index, level_id in enumerate(IDS):
            with self.subTest(stage=level_id):
                _, meta = self.source[level_id]
                source = meta["level"]
                imported = json.loads((ROOT / f"godot/content/levels/{level_id}.json").read_text())["level"]
                # Read untouched source, independently of the importer. Check
                # every coordinate and content key the native pickup paths use.
                for key in ["crates", "receipts", "card", "skill", "coinRows", "coins", "hz", "cfg"]:
                    self.assertEqual(source.get(key), imported.get(key), (level_id, key))
                self.assertEqual(len(source.get("crates", [])), EXPECTED_CRATES[index])
                totals.update(row[2] for row in source.get("crates", []))
                self.assertEqual(len(source["receipts"]), 3)
                self.assertEqual(authored_coin_count(level_id, source), EXPECTED_COINS[index])
        self.assertEqual(totals, {"heart": 52, "split": 41, "debit": 20, "wellies": 3})
        self.assertEqual(sum(EXPECTED_COINS), 2624)

    def test_all_authored_crates_have_floor_support_before_fall_plane(self):
        for level_id, (_, meta) in self.source.items():
            level = meta["level"]
            surfaces = level.get("solids", []) + level.get("plats", [])
            for x, y, give in level.get("crates", []):
                with self.subTest(stage=level_id, x=x, give=give):
                    floors = [row[2] for row in surfaces if row[0] <= x <= row[1] and row[2] >= y - 2]
                    self.assertTrue(floors)
                    self.assertLess(min(floors), level["fall"])
                    self.assertGreaterEqual(x, 0)
                    self.assertLessEqual(x, level["w"])

    def test_six_cards_match_source_and_native_registry(self):
        native = (ROOT / "godot/src/movement_skills.gd").read_text()
        found = {}
        for level_id, (_, meta) in self.source.items():
            level = meta["level"]
            if level.get("skill"):
                found[level_id] = level["skill"]
            elif level.get("card"):
                found[level_id] = level["card"] + [CARDS[level_id][2]]
        self.assertEqual(found, CARDS)
        for level_id, (x, y, skill) in CARDS.items():
            self.assertIn(f'"{level_id}": {{"skill": "{skill}", "p": Vector2({x}, {y})}}', native)

    def test_original_shared_rules_present_in_every_stage(self):
        for level_id, (text, _) in self.source.items():
            with self.subTest(stage=level_id):
                self.assertIn("p.hearts = Math.min(3, p.hearts + 1)", text)
                self.assertIn("p.powerT = 12000", text)
                self.assertIn("Math.abs(p.x - it.x) < 40 && it.t > 300", text)
                self.assertIn("Math.abs(dx) < 30 && Math.abs(dy) < charH(p.k) * 0.6 && c.t > 250", text)
                self.assertIn("c.x > cam - 60", text)
                self.assertIn("c.t < 11000", text)
                self.assertIn("items.push({ x: c.x, y: c.fy - 40, vy: -0.6, give: c.give, t: 0 })", text)


if __name__ == "__main__":
    unittest.main()
