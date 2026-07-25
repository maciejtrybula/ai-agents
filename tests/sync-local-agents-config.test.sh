#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

assert_file_contains() {
  local file_path="$1"
  local needle="$2"

  if ! grep -Fq "$needle" "$file_path"; then
    printf 'Expected %s to contain: %s\n' "$file_path" "$needle" >&2
    printf 'Actual contents:\n' >&2
    cat "$file_path" >&2
    exit 1
  fi
}

temp_home="$(mktemp -d)"
backup_dir="$(mktemp -d)"
claude_env_file="$repo_root/.claude.local.env"

cleanup() {
  if [[ -f "$backup_dir/.claude.local.env" ]]; then
    mv "$backup_dir/.claude.local.env" "$claude_env_file"
  else
    rm -f "$claude_env_file"
  fi

  rm -rf "$temp_home" "$backup_dir"
}

trap cleanup EXIT

if [[ -f "$claude_env_file" ]]; then
  cp "$claude_env_file" "$backup_dir/.claude.local.env"
fi

cat >"$claude_env_file" <<EOF
CLAUDE_MODEL=anthropic/opus
CLAUDE_STATUSLINE_COMMAND_PATH=$temp_home/.claude/statusline-command.sh
EOF

mkdir -p "$temp_home/.claude" "$temp_home/.config/opencode" "$temp_home/.codex"

cat >"$temp_home/.claude/settings.json" <<'EOF'
{
  "_disabledHooks": {
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "node /tmp/local-only-hook.mjs"
          }
        ]
      }
    ]
  },
  "statusLine": {
    "type": "command",
    "command": "bash /tmp/old-statusline.sh"
  }
}
EOF

cat >"$temp_home/.config/opencode/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": [
    "superpowers@git+https://github.com/obra/superpowers.git"
  ],
  "provider": {
    "nvidia-nim": {
      "options": {
        "apiKey": "nvapi-existing"
      }
    }
  },
  "mcp": {
    "stitch": {
      "headers": {
        "X-Goog-Api-Key": "AQ.existing"
      }
    },
    "context7": {
      "headers": {
        "CONTEXT7_API_KEY": "ctx7sk-existing"
      }
    }
  }
}
EOF

cat >"$temp_home/.codex/config.toml" <<'EOF'
model = "gpt-5.3-codex"

[projects."/Users/maciejtrybula/Projects/ai-agents"]
trust_level = "trusted"
EOF

HOME="$temp_home" bash "$repo_root/sync-local-agents.sh" --sync config --platform claude
printf 'n\n' | HOME="$temp_home" bash "$repo_root/sync-local-agents.sh" --sync config --platform opencode
HOME="$temp_home" bash "$repo_root/sync-local-agents.sh" --sync config --platform codex

claude_target="$temp_home/.claude/settings.json"
opencode_target="$temp_home/.config/opencode/opencode.json"
codex_target="$temp_home/.codex/config.toml"
claude_statusline_script="$temp_home/.claude/statusline-command.sh"

assert_file_contains "$claude_target" '"_disabledHooks"'
assert_file_contains "$claude_target" 'node /tmp/local-only-hook.mjs'
assert_file_contains "$claude_target" '"model": "opus"'
assert_file_contains "$claude_target" '"command": "bash \"'
assert_file_contains "$claude_target" "$claude_statusline_script"
assert_file_contains "$claude_target" '"enabledPlugins"'
assert_file_contains "$claude_target" '"agentPushNotifEnabled": true'
assert_file_contains "$claude_target" 'Bash(git log *)'
assert_file_contains "$claude_target" 'mcp__github__*'
assert_file_contains "$claude_target" 'mcp__stitch__*'
assert_file_contains "$claude_target" 'mcp__playwright__*'

assert_file_contains "$claude_statusline_script" 'basename_dir="$(basename "$current_dir")"'

assert_file_contains "$opencode_target" '"plugin"'
assert_file_contains "$opencode_target" 'superpowers@git+https://github.com/obra/superpowers.git'
assert_file_contains "$opencode_target" '"apiKey": "nvapi-existing"'
assert_file_contains "$opencode_target" '"X-Goog-Api-Key": "AQ.existing"'
assert_file_contains "$opencode_target" '"CONTEXT7_API_KEY": "ctx7sk-existing"'
assert_file_contains "$opencode_target" '"permission"'
assert_file_contains "$opencode_target" '"bash"'
assert_file_contains "$opencode_target" '"*": "ask"'
assert_file_contains "$opencode_target" '"git log *": "allow"'
assert_file_contains "$opencode_target" '"pnpm test*": "allow"'
assert_file_contains "$opencode_target" '"pnpm mobile:lint*": "allow"'
assert_file_contains "$opencode_target" '"playwright"'
assert_file_contains "$opencode_target" '@playwright/mcp@latest'
assert_file_contains "$opencode_target" '"--headless"'
assert_file_contains "$opencode_target" '"--isolated"'

assert_file_contains "$codex_target" 'model = "gpt-5.3-codex"'
assert_file_contains "$codex_target" '[projects."/Users/maciejtrybula/Projects/ai-agents"]'
assert_file_contains "$codex_target" 'default_permissions = "repo-workspace"'
assert_file_contains "$codex_target" '[permissions.repo-workspace]'
assert_file_contains "$codex_target" 'extends = ":workspace"'
assert_file_contains "$codex_target" '[mcp_servers.github]'
assert_file_contains "$codex_target" '[mcp_servers.playwright]'
assert_file_contains "$codex_target" '@playwright/mcp@latest'

printf 'Config sync checks passed.\n'
