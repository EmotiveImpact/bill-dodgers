"""Static portability guard, not a browser/device or exported-payload test."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "godot" / "src"


def code(path):
    return "\n".join(line.split("#", 1)[0] for line in path.read_text().splitlines())


class GodotWebCompatibility(unittest.TestCase):
    def test_compatibility_renderer_and_gdscript(self):
        project = (ROOT / "godot/project.godot").read_text()
        self.assertIn('renderer/rendering_method="gl_compatibility"', project)
        self.assertIn('renderer/rendering_method.mobile="gl_compatibility"', project)
        self.assertFalse(list(SRC.rglob("*.cs")), "Godot4 Web cannot export C#")
        self.assertFalse(list(SRC.rglob("*.gdextension")))

    def test_no_unguarded_native_process_thread_or_socket_dependencies(self):
        # Intentionally conservative. Introducing one requires a reviewed Web
        # alternate path and an update of this guard, not a claim it now works.
        forbidden = re.compile(
            r"\b(?:OS\.(?:execute|create_process|kill|shell_open)|"
            r"Thread\.new|WorkerThreadPool\.|TCPServer\.new|"
            r"StreamPeerTCP\.new|PacketPeerUDP\.new|UDPServer\.new|"
            r"ENetMultiplayerPeer\.new|AudioStreamGenerator\.new)\s*\("
        )
        hits = []
        for path in SRC.rglob("*.gd"):
            for number, line in enumerate(code(path).splitlines(), 1):
                if forbidden.search(line):
                    hits.append(f"{path.relative_to(ROOT)}:{number}: {line.strip()}")
        self.assertEqual(hits, [], "Review native-only dependencies:\n" + "\n".join(hits))

    def test_save_virtual_path_and_atomic_replacement(self):
        source = code(SRC / "save_store.gd")
        self.assertIn('const PATH := "user://native-preview-save.json"', source)
        self.assertIn('var temp := path + ".tmp"', source)
        self.assertIn('FileAccess.open(temp, FileAccess.WRITE)', source)
        self.assertIn('return DirAccess.rename_absolute(temp, path)', source)
        self.assertLess(source.index("file.close()"), source.index("DirAccess.rename_absolute"))
        self.assertNotIn("localStorage", source)
        self.assertNotIn("bd-save", source)

    def test_one_world_input_frame_and_explicit_focus_pause(self):
        source = code(SRC / "main.gd")
        physics = source.split("func _physics_process(", 1)[1].split("\nfunc ", 1)[0]
        self.assertEqual(physics.count("party_session.step("), 1)
        self.assertIn('party_session.input.read(0, party_session.runtime.mode, touch)', physics)
        self.assertIn('party_session.input.read(1, party_session.runtime.mode)', physics)
        notification = source.split("func _notification(", 1)[1].split("\nfunc ", 1)[0]
        self.assertIn("NOTIFICATION_APPLICATION_FOCUS_OUT", notification)
        self.assertIn("NOTIFICATION_WM_WINDOW_FOCUS_OUT", notification)
        self.assertIn("NOTIFICATION_WM_WINDOW_FOCUS_IN", notification)
        self.assertIn("_release_input()", notification)
        self.assertIn("_pause()", notification)
        release = source.split("func _release_input(", 1)[1].split("\nfunc ", 1)[0]
        for contact in ["touches", "gameplay_contacts", "joystick_contacts"]:
            self.assertIn(contact + ".clear()", release)

    def test_touch_cancellation_and_mouse_emulation_not_double_counted(self):
        source = code(SRC / "main.gd")
        self.assertIn("not event.pressed or event.canceled", source)
        self.assertIn("event.device != InputEvent.DEVICE_ID_EMULATION", source)
        self.assertIn('var touch_control_style := "joystick"', source)
        self.assertIn('"p2":"Mate: player 2 (keys)"', code(SRC / "character_select.gd"))

    def test_prebuilt_audio_exists_without_web_api_side_effects(self):
        audio = code(SRC / "game_audio.gd")
        score = code(SRC / "original_score.gd")
        names = re.search(r"const EFFECT_NAMES := (\[[^\n]+\])", audio).group(1)
        effects = re.findall(r'"([^"]+)"', names)
        names = re.search(r"const CUES := (\[[^\n]+\])", score).group(1)
        cues = re.findall(r'"([^"]+)"', names)
        self.assertEqual(len(effects), 20)
        self.assertEqual(len(cues), 18)
        for folder, names in [("audio", effects), ("music", cues)]:
            for name in names:
                path = ROOT / "godot/assets" / folder / (name + ".res")
                self.assertTrue(path.is_file(), str(path))
                self.assertGreater(path.stat().st_size, 100)
        self.assertNotIn("AudioStreamGenerator", audio + score)
        self.assertNotIn("AudioEffect", audio + score)


if __name__ == "__main__":
    unittest.main()
