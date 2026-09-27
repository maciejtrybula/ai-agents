import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SOURCE = Path(__file__).resolve().parents[1] / "scripts" / "sdlc.py"
POLICY = {
    "eligibleWorkItem": "explicit-ready-state",
    "planApproval": "every-implementation-plan",
    "deliveryBoundary": "green-change-request",
    "mergeApproval": "human",
    "productionDeployment": "out-of-scope",
}


class SdlcCliTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.scripts = self.root / "scripts"
        self.scripts.mkdir()
        shutil.copyfile(SOURCE, self.scripts / "sdlc.py")
        self.config_path = self.root / "sdlc.json"
        self.write_config([self.check("default", [sys.executable, "-c", "pass"])])

    def tearDown(self):
        self.temp.cleanup()

    @staticmethod
    def check(name, command, stage="test"):
        return {"name": name, "stage": stage, "command": command}

    def write_config(self, checks, workflow=None, version=1):
        self.config_path.write_text(json.dumps({
            "version": version,
            "workflow": POLICY if workflow is None else workflow,
            "checks": checks,
        }), encoding="utf-8")

    def run_cli(self, *args):
        return subprocess.run(
            [sys.executable, str(self.scripts / "sdlc.py"), *args],
            cwd=self.root, text=True, capture_output=True, check=False,
        )

    def test_doctor_accepts_valid_config_and_rejects_invalid_config(self):
        result = self.run_cli("doctor")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("valid", result.stdout)

        invalid_configs = [
            ([], POLICY, 1),
            ([self.check("same", ["true"]), self.check("same", ["true"])], POLICY, 1),
            ([self.check("bad-stage", ["true"], "deploy")], POLICY, 1),
            ([self.check("bad-command", [])], POLICY, 1),
            ([self.check("bad-command", ["ok", ""])], POLICY, 1),
            ([self.check("valid", ["true"])], {**POLICY, "mergeApproval": "automatic"}, 1),
            ([self.check("valid", ["true"])], POLICY, True),
            ([self.check("valid", ["true"])], POLICY, 2),
        ]
        for checks, workflow, version in invalid_configs:
            with self.subTest(checks=checks, workflow=workflow, version=version):
                self.write_config(checks, workflow, version)
                result = self.run_cli("doctor")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("error:", result.stderr)

    def test_verify_filters_stage_and_rejects_unknown_or_empty_stage(self):
        marker = self.root / "ran.txt"
        command = [sys.executable, "-c", "from pathlib import Path; Path('ran.txt').write_text('yes')"]
        self.write_config([
            self.check("lint check", command, "lint"),
            self.check("test check", [sys.executable, "-c", "pass"], "test"),
        ])
        result = self.run_cli("verify", "lint")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(marker.exists())
        self.assertIn("PASS lint check", result.stdout)
        self.assertNotIn("test check", result.stdout)

        missing = self.run_cli("verify", "build")
        self.assertNotEqual(missing.returncode, 0)
        self.assertIn("no checks configured", missing.stderr)
        unknown = self.run_cli("verify", "deploy")
        self.assertNotEqual(unknown.returncode, 0)
        self.assertIn("unknown stage", unknown.stderr)

    def test_failing_check_stops_later_checks_and_returns_exit_code(self):
        marker = self.root / "later.txt"
        later_command = [sys.executable, "-c", "from pathlib import Path; Path('later.txt').touch()"]
        self.write_config([
            self.check("fails", [sys.executable, "-c", "raise SystemExit(7)"]),
            self.check("must not run", later_command),
        ])
        result = self.run_cli("verify")
        self.assertEqual(result.returncode, 7)
        self.assertIn("FAIL fails (exit 7)", result.stdout)
        self.assertFalse(marker.exists())

    def test_command_argument_is_literal_and_not_shell_expanded(self):
        command = [sys.executable, "-c", "from pathlib import Path; Path('literal.txt').write_text('$HOME; echo unsafe')"]
        self.write_config([self.check("literal argument", command)])
        result = self.run_cli("verify")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / "literal.txt").read_text(), "$HOME; echo unsafe")

    def init_git(self):
        def git(*args):
            return subprocess.run(["git", *args], cwd=self.root, text=True,
                                  capture_output=True, check=True)

        git("init", "-q")
        git("config", "user.email", "test@example.invalid")
        git("config", "user.name", "Test")
        (self.root / "tracked.txt").write_text("base", encoding="utf-8")
        git("add", "tracked.txt")
        git("commit", "-qm", "chore: base")
        git("branch", "base")
        return git

    def test_commit_range_accepts_conventional_subject_and_empty_range(self):
        git = self.init_git()
        result = self.run_cli("commit-range", "refs/heads/base")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("no commits", result.stdout)

        (self.root / "tracked.txt").write_text("feature", encoding="utf-8")
        git("commit", "-qam", "feat(parser)!: support syntax")
        result = self.run_cli("commit-range", "base")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("valid", result.stdout)

    def test_commit_range_reports_bad_subject_and_invalid_ref(self):
        git = self.init_git()
        (self.root / "tracked.txt").write_text("bad", encoding="utf-8")
        git("commit", "-qam", "Added a feature")
        result = self.run_cli("commit-range", "base")
        self.assertEqual(result.returncode, 1)
        self.assertIn("Added a feature", result.stdout)

        invalid = self.run_cli("commit-range", "missing-ref")
        self.assertEqual(invalid.returncode, 2)
        self.assertIn("does not resolve", invalid.stderr)


if __name__ == "__main__":
    unittest.main()
