#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
temp_root="$(mktemp -d)"
trap 'rm -rf "$temp_root"' EXIT

home_dir="$temp_root/home"
interactive_target="$temp_root/interactive-target"
noninteractive_target="$temp_root/noninteractive-target"
mkdir -p "$home_dir"

python3 - "$repo_root" "$home_dir" "$interactive_target" <<'PY'
import errno
import json
import os
import pty
import re
import select
import subprocess
import sys
import time
from pathlib import Path

repo_root = Path(sys.argv[1])
home_dir = Path(sys.argv[2])
target_dir = Path(sys.argv[3])
command = [
    "bash",
    str(repo_root / "sync-local-agents.sh"),
    "--interactive",
    "--platform",
    "opencode",
    "--target-dir",
    str(target_dir),
]
environment = os.environ.copy()
environment["HOME"] = str(home_dir)
for key_name in ("NVIDIA_NIM_API_KEY", "STITCH_API_KEY", "CONTEXT7_API_KEY"):
    environment.pop(key_name, None)

master_fd, slave_fd = pty.openpty()
process = subprocess.Popen(
    command,
    cwd=repo_root,
    env=environment,
    stdin=slave_fd,
    stdout=slave_fd,
    stderr=slave_fd,
    close_fds=True,
)
os.close(slave_fd)
output = bytearray()


def read_until(marker: str, timeout: float = 10.0) -> None:
    marker_bytes = marker.encode()
    deadline = time.monotonic() + timeout
    while marker_bytes not in output:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise AssertionError(
                f"Timed out waiting for {marker!r}. Output so far:\n"
                f"{output.decode(errors='replace')}"
            )
        readable, _, _ = select.select([master_fd], [], [], remaining)
        if not readable:
            continue
        try:
            chunk = os.read(master_fd, 4096)
        except OSError as error:
            if error.errno == errno.EIO:
                break
            raise
        if not chunk:
            break
        output.extend(chunk)
    if marker_bytes not in output:
        raise AssertionError(
            f"Process exited before {marker!r}. Output:\n"
            f"{output.decode(errors='replace')}"
        )


def send(value: str) -> None:
    os.write(master_fd, (value + "\n").encode())


try:
    read_until("What do you want to sync?")
    if "config/mcp/all" not in output.decode(errors="replace"):
        raise AssertionError(
            "Interactive scope prompt does not advertise the direct MCP choice:\n"
            f"{output.decode(errors='replace')}"
        )
    send("mcp")

    read_until("Where should files be copied?")
    send("")
    read_until("MCP sync for opencode")
    read_until("Sync all MCP servers for opencode? [Y/n]:")

    server_match = re.search(r"\[(\d+)\]\s+stitch", output.decode(errors="replace"))
    if server_match is None:
        raise AssertionError(
            "OpenCode MCP selection does not list Stitch:\n"
            f"{output.decode(errors='replace')}"
        )
    send("n")

    read_until("Enter comma-separated numbers to sync")
    send(server_match.group(1))
    read_until("Configure API keys now? [Y/n]:")
    send("y")
    read_until("Enter Stitch MCP API Key (input hidden):")

    prompt_output = output.decode(errors="replace")
    if "Enter Stitch MCP API Key (input hidden):" not in prompt_output:
        raise AssertionError(f"Stitch key prompt missing:\n{prompt_output}")
    for unrelated_prompt in (
        "Enter NVIDIA NIM API Key (input hidden):",
        "Enter Context7 MCP API Key (input hidden):",
    ):
        if unrelated_prompt in prompt_output:
            raise AssertionError(
                f"Unselected key prompt {unrelated_prompt!r} was shown:\n{prompt_output}"
            )

    send("AQ.test-stitch-key")
    read_until("Confirm Stitch MCP API Key (type again):")
    send("AQ.test-stitch-key")
    read_until("Synced selected MCP servers for opencode")
    return_code = process.wait(timeout=10)
    if return_code != 0:
        raise AssertionError(
            f"Interactive MCP sync exited with {return_code}:\n"
            f"{output.decode(errors='replace')}"
        )
finally:
    if process.poll() is None:
        process.kill()
        process.wait()
    os.close(master_fd)

config_path = target_dir / ".opencode" / "opencode.json"
with config_path.open(encoding="utf-8") as config_file:
    config = json.load(config_file)
servers = config["mcp"]["servers"]
if set(servers) != {"stitch"}:
    raise AssertionError(f"Expected only the selected Stitch server, got {sorted(servers)}")
stitch = servers["stitch"]
if stitch["url"] != "https://stitch.googleapis.com/mcp":
    raise AssertionError(f"Unexpected Stitch MCP URL: {stitch['url']!r}")
if stitch["headers"].get("X-Goog-Api-Key") != "AQ.test-stitch-key":
    raise AssertionError("Interactive Stitch key was not applied to the server config")
PY

HOME="$home_dir" bash "$repo_root/sync-local-agents.sh" \
  --sync mcp --platform opencode --target-dir "$noninteractive_target" >/dev/null
python3 - "$noninteractive_target/.opencode/opencode.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as config_file:
    servers = json.load(config_file)["mcp"]["servers"]

stitch = servers["stitch"]
assert stitch["url"] == "https://stitch.googleapis.com/mcp"
assert stitch["headers"]["X-Goog-Api-Key"] == "{env:STITCH_API_KEY}"
assert "context7" in servers, "Non-interactive MCP scope must sync all MCP servers"
PY

printf 'Interactive Stitch MCP sync checks passed.\n'
