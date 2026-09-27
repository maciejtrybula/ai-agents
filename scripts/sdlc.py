#!/usr/bin/env python3
"""Validate and run the repository's provider-neutral SDLC workflow."""

import json
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "sdlc.json"
STAGES = {"lint", "test", "security", "e2e", "build", "smoke"}
WORKFLOW_POLICY = {
    "eligibleWorkItem": "explicit-ready-state",
    "planApproval": "every-implementation-plan",
    "deliveryBoundary": "green-change-request",
    "mergeApproval": "human",
    "productionDeployment": "out-of-scope",
}
COMMIT_SUBJECT = re.compile(
    r"^(?:feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)"
    r"(?:\([^()\r\n]+\))?!?: .+$"
)


class ConfigError(ValueError):
    pass


def load_config():
    try:
        with CONFIG.open(encoding="utf-8") as config_file:
            config = json.load(config_file)
    except FileNotFoundError as error:
        raise ConfigError(f"configuration file not found: {CONFIG}") from error
    except (OSError, json.JSONDecodeError) as error:
        raise ConfigError(f"cannot read valid JSON from {CONFIG}: {error}") from error

    if not isinstance(config, dict):
        raise ConfigError("configuration must be a JSON object")
    version = config.get("version")
    if not isinstance(version, int) or isinstance(version, bool) or version != 1:
        raise ConfigError("version must be 1")
    workflow = config.get("workflow")
    if not isinstance(workflow, dict) or workflow != WORKFLOW_POLICY:
        raise ConfigError(
            "workflow must use the required policy keys and values: "
            + ", ".join(f"{key}={value}" for key, value in WORKFLOW_POLICY.items())
        )

    checks = config.get("checks")
    if not isinstance(checks, list) or not checks:
        raise ConfigError("checks must be a nonempty list")
    names = set()
    for index, check in enumerate(checks, 1):
        where = f"checks[{index - 1}]"
        if not isinstance(check, dict):
            raise ConfigError(f"{where} must be an object")
        name = check.get("name")
        if not isinstance(name, str) or not name.strip():
            raise ConfigError(f"{where}.name must be a nonempty string")
        if name in names:
            raise ConfigError(f"duplicate check name: {name!r}")
        names.add(name)
        stage = check.get("stage")
        if not isinstance(stage, str) or stage not in STAGES:
            raise ConfigError(f"{where}.stage must be one of: {', '.join(sorted(STAGES))}")
        command = check.get("command")
        if (not isinstance(command, list) or not command
                or any(not isinstance(arg, str) or not arg for arg in command)):
            raise ConfigError(f"{where}.command must be a nonempty list of nonempty strings")
    return checks


def doctor():
    load_config()
    print("SDLC configuration: valid")
    return 0


def verify(stage=None):
    if stage is not None and stage not in STAGES:
        print(f"error: unknown stage {stage!r}; expected one of: {', '.join(sorted(STAGES))}", file=sys.stderr)
        return 2
    checks = load_config()
    selected = [check for check in checks if stage is None or check["stage"] == stage]
    if not selected:
        print(f"error: no checks configured for stage {stage!r}", file=sys.stderr)
        return 1

    for check in selected:
        try:
            result = subprocess.run(
                check["command"], cwd=ROOT, shell=False,
                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL, check=False,
            )
        except OSError as error:
            print(f"FAIL {check['name']} (could not start command: {error.strerror})")
            return 127
        if result.returncode == 0:
            print(f"PASS {check['name']}")
        else:
            print(f"FAIL {check['name']} (exit {result.returncode})")
            return result.returncode if result.returncode > 0 else 128 - result.returncode
    return 0


def git(*args):
    try:
        return subprocess.run(
            ["git", *args], cwd=ROOT, shell=False, stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, check=False,
        )
    except OSError as error:
        raise RuntimeError("git is unavailable; install Git and ensure it is on PATH") from error


def commit_range(base_ref):
    resolved = git("rev-parse", "--verify", "--quiet", "--end-of-options", f"{base_ref}^{{commit}}")
    if resolved.returncode:
        print(f"error: base ref {base_ref!r} does not resolve to a local commit", file=sys.stderr)
        return 2
    merge_base = git("merge-base", "HEAD", resolved.stdout.strip())
    if merge_base.returncode:
        print(f"error: cannot find a merge base for HEAD and {base_ref!r}", file=sys.stderr)
        return 2
    subjects = git("log", "--no-merges", "--format=%s", f"{merge_base.stdout.strip()}..HEAD")
    if subjects.returncode:
        print("error: could not read commit subjects; ensure this is a valid Git repository", file=sys.stderr)
        return 2

    invalid = [subject for subject in subjects.stdout.splitlines() if not COMMIT_SUBJECT.fullmatch(subject)]
    if invalid:
        print("Invalid Conventional Commit subject(s):")
        for subject in invalid:
            print(f"  {subject}")
        return 1
    print("Commit subjects: valid" if subjects.stdout.strip() else "Commit range: no commits")
    return 0


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if argv == ["doctor"]:
        try:
            return doctor()
        except ConfigError as error:
            print(f"error: {error}", file=sys.stderr)
            return 2
    if argv == ["verify"] or (len(argv) == 2 and argv[0] == "verify"):
        try:
            return verify(argv[1] if len(argv) == 2 else None)
        except ConfigError as error:
            print(f"error: {error}", file=sys.stderr)
            return 2
    if len(argv) == 2 and argv[0] == "commit-range":
        try:
            return commit_range(argv[1])
        except RuntimeError as error:
            print(f"error: {error}", file=sys.stderr)
            return 2
    print("usage: sdlc.py doctor | verify [STAGE] | commit-range BASE_REF", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
