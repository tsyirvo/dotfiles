"""Apply Hex settings with real chezmoi in temporary home directories."""

import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
TARGET = "Library/Application Support/hex/settings.json"
SOURCE = "private_Library/private_Application Support/hex/modify_settings.json"


class HexSettingsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.home = self.root / "home"
        self.home.mkdir()
        self.source = self.root / "source"
        for relative in (SOURCE, ".chezmoidata/hex.json", ".chezmoiignore"):
            target = self.source / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / "home" / relative, target)
        self.expected = json.loads(
            (self.source / ".chezmoidata/hex.json").read_text()
        )["hex"]
        self.target = self.home / TARGET
        self.config = self.root / "chezmoi.toml"
        self.set_role("macbook")

    def set_role(self, role):
        flags = {
            "isMacbook": role == "macbook",
            "isDarwin": role == "macbook",
            "isDevbox": role == "devbox",
            "isHeadless": role == "devbox",
            "isOmarchy": role == "omarchy",
        }
        self.config.write_text(
            "[data]\n" + "\n".join(
                f"{key} = {str(value).lower()}" for key, value in flags.items()
            ) + "\n"
        )

    def chezmoi(self, *args):
        result = subprocess.run(
            [
                "chezmoi", "--no-tty", "--force", "--config", str(self.config),
                "--source", str(self.source), "--destination", str(self.home),
                "--persistent-state", str(self.root / "state.boltdb"),
                "--cache", str(self.root / "cache"), *args,
            ],
            text=True, capture_output=True, check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def test_fresh_install_restores_modes_and_vocabulary(self):
        self.chezmoi("apply", "--parent-dirs", str(self.target))
        self.assertEqual(json.loads(self.target.read_text()), self.expected)
        self.chezmoi("verify", str(self.target))
        first = self.target.read_bytes()
        self.chezmoi("apply", str(self.target))
        self.assertEqual(self.target.read_bytes(), first)

    def test_existing_preferences_and_state_survive(self):
        existing = {
            "sound_effects": False,
            "microphone": "My microphone",
            "capture": {"enabled": False, "routing": {"delivery": "steer"}},
            "migrations": ["existing-migration"],
            "dictation_processing": {"modes": []},
            "vocabulary": ["Old term"],
        }
        self.target.parent.mkdir(parents=True)
        self.target.write_text(json.dumps(existing))
        rendered = json.loads(self.chezmoi("cat", str(self.target)))
        self.assertEqual(rendered, {**existing, **self.expected})
        self.chezmoi("apply", str(self.target))
        self.assertEqual(json.loads(self.target.read_text()), rendered)
        self.chezmoi("verify", str(self.target))

    def test_only_settings_file_is_managed_on_macbook(self):
        unrelated = self.source / "private_Library/private_Application Support/hex/history.json"
        unrelated.write_text("{}\n")
        managed = self.chezmoi("managed").splitlines()
        self.assertIn(TARGET, managed)
        self.assertNotIn("Library/Application Support/hex/history.json", managed)

    def test_linux_roles_do_not_restore_hex_settings(self):
        for role in ("omarchy", "devbox"):
            with self.subTest(role=role):
                self.set_role(role)
                self.assertNotIn(TARGET, self.chezmoi("managed").splitlines())
                self.chezmoi("apply")
                self.assertFalse(self.target.exists())


if __name__ == "__main__":
    unittest.main()
