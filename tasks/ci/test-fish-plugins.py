"""Sandboxed chezmoi/Fish tests; Fisher downloads are mocked, never the live HOME."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ".chezmoiscripts/run_onchange_after_21-install-fish-plugins.sh.tmpl"
MANIFEST = "dot_config/fish/fish_plugins"


class FishPluginTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.home = self.root / "home"
        self.source = self.root / "source"
        self.bin = self.home / ".local/bin"
        self.bin.mkdir(parents=True)
        for relative in (SCRIPT, MANIFEST):
            target = self.source / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / "home" / relative, target)
        self.config = self.root / "chezmoi.toml"
        self.config.write_text("")
        self.env = {
            **os.environ,
            "HOME": str(self.home),
            "XDG_CONFIG_HOME": str(self.home / ".config"),
            "XDG_DATA_HOME": str(self.home / ".local/share"),
            "XDG_CACHE_HOME": str(self.home / ".cache"),
        }
        self.curl = self.bin / "curl"
        self.curl.write_text('''#!/bin/sh
if [ -f "$HOME/fail-download" ]; then exit 22; fi
while [ "$#" -gt 0 ]; do
    if [ "$1" = -o ]; then shift; output=$1; fi
    shift
done
cat > "$output" <<'FISH'
function fisher
    echo $argv >> "$HOME/fisher-calls"
    if test -f "$HOME/partial-install"
        echo jorgebucaran/fisher > "$__fish_config_dir/fish_plugins"
    end
    if test -f "$HOME/fail-install"
        return 1
    end
    set --universal _fisher_test_installed yes
end
FISH
''')
        self.curl.chmod(0o755)
        config_dir = self.home / ".config/fish"
        config_dir.mkdir(parents=True)
        (config_dir / "config.fish").write_text(
            'if status is-interactive; touch "$HOME/interactive-config-was-loaded"; end\n'
        )

    def apply(self):
        return subprocess.run(
            [
                "chezmoi", "--no-tty", "--config", str(self.config),
                "--source", str(self.source), "--destination", str(self.home),
                "--persistent-state", str(self.root / "state.boltdb"),
                "--cache", str(self.root / "cache"), "apply",
            ],
            env=self.env,
            text=True,
            capture_output=True,
            check=False,
        )

    def assert_manifest_preserved(self):
        self.assertEqual(
            (self.home / ".config/fish/fish_plugins").read_text(),
            (self.source / MANIFEST).read_text(),
        )

    def test_first_apply_then_noop_then_manifest_change(self):
        for expected_calls in (1, 1):
            result = self.apply()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((self.home / "fisher-calls").read_text().splitlines(),
                             ["update"] * expected_calls)
        self.assertFalse((self.home / "interactive-config-was-loaded").exists())
        persisted = subprocess.run(
            ["fish", "-c", 'test "$_fisher_test_installed" = yes'],
            env=self.env, text=True, capture_output=True, check=False,
        )
        self.assertEqual(persisted.returncode, 0, persisted.stderr)
        self.assert_manifest_preserved()
        with (self.source / MANIFEST).open("a") as manifest:
            manifest.write("example/plugin\n")
        result = self.apply()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.home / "fisher-calls").read_text().splitlines(),
                         ["update", "update"])
        self.assert_manifest_preserved()

    def test_failed_download_retries_on_next_apply(self):
        failure = self.home / "fail-download"
        failure.touch()
        self.assertNotEqual(self.apply().returncode, 0)
        self.assert_manifest_preserved()
        self.assertFalse((self.home / "fisher-calls").exists())
        failure.unlink()
        result = self.apply()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.home / "fisher-calls").exists())

    def test_partial_install_restores_manifest_and_retries(self):
        failure = self.home / "partial-install"
        failure.touch()
        result = self.apply()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("installation incomplete", result.stderr)
        self.assert_manifest_preserved()
        failure.unlink()
        result = self.apply()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.home / "fisher-calls").read_text().splitlines(),
                         ["update", "update"])

    def test_fisher_failure_is_not_recorded_as_success(self):
        (self.home / "fail-install").touch()
        self.assertNotEqual(self.apply().returncode, 0)
        self.assert_manifest_preserved()


if __name__ == "__main__":
    unittest.main()
