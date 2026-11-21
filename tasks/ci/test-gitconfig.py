import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class GitConfigTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.home = self.root / "home"
        self.home.mkdir()
        self.source = self.root / "source"
        self.source.mkdir()
        shutil.copyfile(
            ROOT / "home/dot_gitconfig.tmpl", self.source / "dot_gitconfig.tmpl"
        )
        config = self.root / "chezmoi.toml"
        config.write_text('[data]\nisDarwin = true\ngitName = "Test"\ngitEmail = "test@example.com"\n')
        self.env = {
            **os.environ,
            "HOME": str(self.home),
            "XDG_CONFIG_HOME": str(self.home / ".config"),
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": str(self.home / ".gitconfig"),
            "GIT_TERMINAL_PROMPT": "0",
        }
        self.run_command(
            "chezmoi", "--no-tty", "--force", "--config", str(config),
            "--source", str(self.source), "--destination", str(self.home),
            "--persistent-state", str(self.root / "state.boltdb"),
            "--cache", str(self.root / "cache"),
            "apply", str(self.home / ".gitconfig"),
        )
        self.remote = self.root / "remote.git"
        self.repo = self.root / "repo"
        self.run_command("git", "init", "--bare", str(self.remote))
        self.run_command("git", "init", str(self.repo))
        self.git("commit", "--allow-empty", "-m", "Initial")
        self.git("remote", "add", "origin", str(self.remote))
        self.git("push", "-u", "origin", "main")

    def run_command(self, *args, cwd=None, input=None, check=True):
        result = subprocess.run(
            args, cwd=cwd, env=self.env, input=input,
            text=True, capture_output=True, check=False,
        )
        if check:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def git(self, *args, **kwargs):
        return self.run_command("git", *args, cwd=self.repo, **kwargs)

    def add_gone_branches(self):
        for branch in ("feature/one", "feature/two"):
            self.git("switch", "-c", branch, "main")
            self.git("commit", "--allow-empty", "-m", branch)
            self.git("push", "-u", "origin", branch)
            self.git("push", "origin", "--delete", branch)
        self.git("switch", "main")

    def branches(self):
        return self.git("for-each-ref", "--format=%(refname:short)", "refs/heads").stdout.splitlines()

    def test_confirmed_settings(self):
        for key, value in (
            ("rerere.enabled", "true"),
            ("push.default", "simple"),
            ("init.defaultBranch", "main"),
        ):
            with self.subTest(key=key):
                self.assertEqual(self.git("config", "--get", key).stdout.strip(), value)

    def test_no_candidates_does_not_prompt(self):
        result = self.git("gone", input="")
        self.assertIn("No branches to delete.", result.stdout)
        self.assertNotIn("Type yes", result.stdout)
        self.assertEqual(self.branches(), ["main"])

    def test_decline_empty_input_and_eof_preserve_branches(self):
        self.add_gone_branches()
        for answer in ("no\n", "\n", "", "y\n", "YES\n"):
            with self.subTest(answer=answer):
                result = self.git("gone", input=answer)
                self.assertIn("Cancelled.", result.stdout)
                self.assertIn("feature/one\nfeature/two\nType yes", result.stdout)
                self.assertEqual(self.branches(), ["feature/one", "feature/two", "main"])

    def test_yes_deletes_only_listed_branches(self):
        self.add_gone_branches()
        self.git("branch", "keep-local")
        result = self.git("gone", input="yes\n")
        self.assertIn("including unmerged commits", result.stdout)
        self.assertIn("feature/one\nfeature/two\nType yes", result.stdout)
        self.assertEqual(self.branches(), ["keep-local", "main"])

    def test_fetch_failure_does_not_prompt_or_delete(self):
        self.add_gone_branches()
        self.git("fetch", "--prune")
        self.git("remote", "set-url", "origin", str(self.root / "missing.git"))
        result = self.git("gone", input="yes\n", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("Type yes", result.stdout)
        self.assertEqual(self.branches(), ["feature/one", "feature/two", "main"])


if __name__ == "__main__":
    unittest.main()
