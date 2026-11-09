"""Replay actual source recovery functions against observed native CPU states.

This is not a source full-game simulation. It isolates the forced damage and
downed catch-up rules responsible for Queue Rush's surviving-leader clears.
The sampled Ama/JP states have no active damage-blocking ability.
"""
import json
from pathlib import Path
import re
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]


def source_function(text, name):
    start = re.search(r"function " + name + r"\([^)]*\)\s*\{", text)
    if start is None:
        raise AssertionError(f"Missing source function {name}")
    # These inspected functions have balanced code braces and no brace literals
    # in strings/comments. Fail loudly if a source edit changes that contract.
    index, depth = start.end(), 1
    while depth:
        depth += (text[index] == "{") - (text[index] == "}")
        index += 1
    return text[start.start():index]


class FestivalSourceRecovery(unittest.TestCase):
    def test_w3_cpu_never_aims_and_w3_cards_cannot_grant_dash(self):
        for path in sorted((ROOT / "game").glob("3-*/index.html")):
            with self.subTest(stage=path.parent.name):
                cpu = source_function(path.read_text(), "updateCPU")
                # The chained neutral reset is the only assignment to aim.
                self.assertEqual(re.findall(r"\binp\.u\s*=\s*([^;]+)", cpu), ["false"])
                meta = json.loads((ROOT / "godot/content/levels" / (path.parent.name + ".json")).read_text())
                self.assertEqual(meta["level"].get("skill"),
                                 [5700, -358, "ground-pound"] if path.parent.name == "3-4" else None)

    def test_same_cpu_and_recovery_rules_in_all_seven_stages(self):
        sources = [p.read_text() for p in sorted((ROOT / "game").glob("3-*/index.html"))]
        self.assertEqual(len(sources), 7)
        for name in ["updateCPU", "fellOff", "squash"]:
            with self.subTest(function=name):
                self.assertEqual(len({source_function(s, name) for s in sources}), 1)

    def test_observed_queue_falls_and_squash_match_source(self):
        source = (ROOT / "game/3-2/index.html").read_text()
        meta = json.loads((ROOT / "godot/content/levels/3-2.json").read_text())
        bodies = "\n".join(source_function(source, name) for name in [
            "below", "wallClamp", "hurtPlayer", "fellOff", "squash", "updateCPU"
        ])
        inside = re.search(r"^const insideWall = .*;$", source, re.M).group()
        script = """
const META = %s, LV = META.level, GROUND = META.ground, WV = 960 / 1.3;
const SURF = LV.solids.map(q => ({ x0:q[0], x1:q[1], top:q[2], plat:false, ...(q[3] || {}) }));
let cam = 0, camY = 0, state = 'play', players = [], floats = [];
const viewTop = () => camY + 540 - 540 / 1.3;
const charH = k => META.heights[k], CH = { ama:{name:'Ama'}, jp:{name:'JP'} };
const shakeIt = () => {}, puff = () => {}, say = () => {}, SFX = {hurt:()=>{}};
%s
%s
const results = [];
function player(k, x, feet, safeX, hearts) {
  return { k, x, px:x, y:feet-GROUND, face:1, safe:{x:safeX}, hearts,
    inv:999000, down:false, vx:0, vy:1.5, onG:false, onPlat:false,
    cpuIn:{}, ai:{jumpCd:-100,far:2000} };
}
function snapshot(p) { return { x:p.x, feet:GROUND+p.y, hearts:p.hearts, down:p.down, inv:p.inv }; }
// Actual native trace: Ama falls into the first gap, frame1159.
cam = 2452.333;
let p = player('ama',2617,784.1458,2371.345,3);
fellOff(p); results.push(snapshot(p));
// Actual native trace: Ama's final post-checkpoint gap, frame6712.
cam = 16419.86;
p = player('ama',16681.9,784.1458,16456.9,1);
fellOff(p); results.push(snapshot(p));
// Actual native trace: JP CPU is clamped inside barrier5490..5570,
// frame2448. Run the source wall/camera clamp and squash, not a replica.
cam = 5460.038; camY = -0.30432;
p = player('jp',5487.705,482,5399.032,1); p.onG = true;
p.x = Math.max(cam+30, Math.min(cam+WV-30, wallClamp(p.px,p.x,GROUND+p.y)));
p.px = p.x; squash(p); results.push(snapshot(p));
// Downed updateCPU returns before its normally overdue catch-up teleport.
players = [{x:5783.982,y:0,onG:true,down:false,face:1},p];
const before = snapshot(p); updateCPU(p,1000/60);
results.push({before,after:snapshot(p),jumpCd:p.ai.jumpCd,far:p.ai.far});
process.stdout.write(JSON.stringify(results));
""" % (json.dumps(meta), inside, bodies)
        run = subprocess.run(["node", "-e", script], cwd=ROOT, text=True,
                             capture_output=True, check=True, timeout=15)
        results = json.loads(run.stdout)
        for index, expected in enumerate([
            (2662.333, 482, 2, False),
            (16489.86, 482, 0, True),
            (5530.038, 372, 0, True),
        ]):
            with self.subTest(recovery=index):
                actual = results[index]
                self.assertAlmostEqual(actual["x"], expected[0], places=3)
                self.assertEqual((actual["feet"], actual["hearts"], actual["down"]), expected[1:])
                self.assertEqual(actual["inv"], 1500)
        self.assertEqual(results[3]["before"], results[3]["after"])
        self.assertEqual((results[3]["jumpCd"], results[3]["far"]), (-100, 2000))


if __name__ == "__main__":
    unittest.main()
