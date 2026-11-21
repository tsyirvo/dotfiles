"""Read-only updater regression tests: all package-manager calls are mocked."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
TOOL = "npm:@earendil-works/pi-coding-agent"


class PiUpdateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.home = self.root / "home"
        self.bin = self.root / "bin"
        self.project = self.root / "project"
        self.harness = self.home / "projects/argentic/pi-harness"
        for directory in (self.home, self.bin, self.project, self.harness):
            directory.mkdir(parents=True, exist_ok=True)
        (self.harness / "package.json").write_text("{}")
        self.log = self.root / "calls"
        self.env = {
            **os.environ,
            "HOME": str(self.home),
            "PATH": f"{self.bin}:/usr/bin:/bin",
            "CALL_LOG": str(self.log),
            "CANONICAL_PI": str(self.root / "canonical pi"),
        }
        for key in ("PI_HARNESS_DIR", "PI_BIN"):
            self.env.pop(key, None)
        for name in ("pi-update", "update-ai-tools"):
            target = self.bin / name
            shutil.copyfile(ROOT / f"home/bin/executable_{name}", target)
            target.chmod(0o755)
        self.mock("mise", '''printf '%s|%s|PI_BIN=%s\n' "$PWD" "$*" "${PI_BIN:-}" >> "$CALL_LOG"
case "$*" in
    *where*) exit "${WHERE_STATUS:-0}" ;;
    upgrade*) exit "${UPGRADE_STATUS:-0}" ;;
    which*) printf '%s\n' "$CANONICAL_PI" ;;
    *pi:sync) exit "${SYNC_STATUS:-0}" ;;
esac
''')
        # A stale pi on PATH must never be used, including for extension updates.
        self.mock("pi", 'echo "STALE PI" >> "$CALL_LOG"; exit 99\n')
        self.mock("brew", "exit 1\n")
        for name in ("claude", "droid"):
            self.mock(name, "exit 0\n")

    def mock(self, name, body):
        target = self.bin / name
        target.write_text("#!/bin/sh\n" + body)
        target.chmod(0o755)

    def run_updater(self, name="pi-update", *args):
        return subprocess.run(
            [str(self.bin / name), *args],
            cwd=self.project,
            env=self.env,
            text=True,
            capture_output=True,
            check=False,
        )

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_sync_uses_canonical_pi_and_bun_with_node_26_from_home(self):
        self.env["PI_BIN"] = "stale override"
        result = self.run_updater()
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls()
        self.assertEqual(len(calls), 6)
        self.assertIn(f"|upgrade {TOOL}|", calls[1])
        self.assertIn(f"|which pi --tool {TOOL}|", calls[2])
        self.assertIn(f"exec node@26 bun -- bun run --cwd {self.harness} pi:sync", calls[3])
        self.assertIn(f"PI_BIN={self.env['CANONICAL_PI']}", calls[3])
        self.assertIn("update --extensions", calls[4])
        self.assertIn("update --models", calls[5])
        self.assertTrue(all(call.startswith(f"{self.home}|") for call in calls))
        self.assertNotIn("STALE PI", "\n".join(calls))
        self.assertNotIn("pi:update-globals", "\n".join(calls))

    def test_relative_harness_override(self):
        harness = self.project / "custom harness"
        harness.mkdir()
        (harness / "package.json").write_text("{}")
        self.env["PI_HARNESS_DIR"] = "custom harness"
        self.assertEqual(self.run_updater().returncode, 0)
        self.assertIn(f"--cwd {harness} pi:sync", self.calls()[3])

    def test_missing_harness_skips_sync_but_updates_packages(self):
        self.env["PI_HARNESS_DIR"] = str(self.root / "missing")
        result = self.run_updater()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("skip: pi-harness SDK sync", result.stdout)
        self.assertEqual(len(self.calls()), 5)
        self.assertIn("update --models", self.calls()[-1])

    def test_failures_stop_subsequent_steps(self):
        for variable, count in (("WHERE_STATUS", 1), ("UPGRADE_STATUS", 2), ("SYNC_STATUS", 4)):
            with self.subTest(variable=variable):
                self.log.unlink(missing_ok=True)
                self.env[variable] = "1"
                result = self.run_updater()
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(len(self.calls()), count)
                self.env.pop(variable)

    def test_arguments_are_rejected_without_updates(self):
        self.assertEqual(self.run_updater("pi-update", "--all").returncode, 2)
        self.assertEqual(self.calls(), [])

    def use_stow_updater(self):
        shutil.copyfile(ROOT / "bin/pi-update", self.bin / "pi-update")

    def test_stow_updater_uses_bun_with_node_26_for_both_steps(self):
        self.use_stow_updater()
        result = self.run_updater()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [
            f"{self.harness}|exec node@26 bun -- bun run pi:update-globals|PI_BIN=",
            f"{self.harness}|exec node@26 bun -- bun run pi:sync|PI_BIN=",
        ])

    def test_stow_failure_stops_before_sync(self):
        self.use_stow_updater()
        self.mock("mise", 'echo "$*" >> "$CALL_LOG"; exit 1\n')
        self.assertNotEqual(self.run_updater().returncode, 0)
        self.assertEqual(len(self.calls()), 1)

    def test_stow_missing_harness_stops_without_updates(self):
        self.use_stow_updater()
        self.env["PI_HARNESS_DIR"] = str(self.root / "missing")
        self.assertNotEqual(self.run_updater().returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_update_ai_tools_delegates_to_sibling_updater(self):
        result = self.run_updater("update-ai-tools")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = "\n".join(self.calls())
        self.assertIn(f"upgrade {TOOL}", calls)
        self.assertIn("pi:sync", calls)
        self.assertNotIn("update --all", calls)
        self.assertNotIn("STALE PI", calls)


if __name__ == "__main__":
    unittest.main()
