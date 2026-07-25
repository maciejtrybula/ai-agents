# Playwright MCP Config Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a repo-managed Playwright MCP server for Claude,
OpenCode, and Codex, plus the docs and regression coverage needed
to keep config sync accurate.

**Architecture:** Reuse the repository's existing repo-managed MCP
config flow. Add a `playwright` entry to each platform config, add
Claude permission projection through `.config/shared-permissions.json`,
and verify the merged outputs through the existing config sync
regression test.

**Tech Stack:** JSON, TOML, Bash, Markdown,
`sync-local-agents.sh`, Playwright MCP via
`npx @playwright/mcp@latest --headless --isolated`

---

## Task 1: Add the failing regression assertions first

**Files:**

- Modify: `tests/sync-local-agents-config.test.sh`
- Test: `tests/sync-local-agents-config.test.sh`

- [ ] **Step 1: Write the failing test assertions**

```bash
assert_file_contains "$claude_target" 'mcp__playwright__*'

assert_file_contains "$opencode_target" '"playwright"'
assert_file_contains "$opencode_target" '@playwright/mcp@latest'
assert_file_contains "$opencode_target" '"--headless"'
assert_file_contains "$opencode_target" '"--isolated"'

assert_file_contains "$codex_target" '[mcp_servers.playwright]'
assert_file_contains "$codex_target" '@playwright/mcp@latest'
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/sync-local-agents-config.test.sh`
Expected: failure because the synced target configs do not yet
contain the Playwright MCP entries.

- [ ] **Step 3: Commit**

Do not commit unless the user explicitly asks for one.

## Task 2: Add repo-managed Playwright MCP config entries

**Files:**

- Modify: `.claude/settings.json`
- Modify: `.config/opencode/opencode.json`
- Modify: `.codex/config.toml`
- Modify: `.config/shared-permissions.json`
- Test: `tests/sync-local-agents-config.test.sh`

- [ ] **Step 1: Add the Claude MCP server entry**

```json
"playwright": {
  "command": "npx",
  "args": [
    "@playwright/mcp@latest",
    "--headless",
    "--isolated"
  ]
}
```

- [ ] **Step 2: Add the Claude permission namespace source**

```json
"mcpAllow": [
  "github",
  "linear-server",
  "blender",
  "stitch",
  "playwright"
]
```

- [ ] **Step 3: Add the OpenCode MCP entry**

```json
"playwright": {
  "type": "local",
  "command": [
    "npx",
    "@playwright/mcp@latest",
    "--headless",
    "--isolated"
  ],
  "enabled": true
}
```

- [ ] **Step 4: Add the Codex MCP table**

```toml
[mcp_servers.playwright]
command = "npx"
args = ["@playwright/mcp@latest", "--headless", "--isolated"]
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash tests/sync-local-agents-config.test.sh`
Expected: pass, confirming merged configs now contain the
Playwright server on all three platforms.

- [ ] **Step 6: Commit**

Do not commit unless the user explicitly asks for one.

## Task 3: Update repository documentation

**Files:**

- Modify: `README.md`
- Test: `README.md`

- [ ] **Step 1: Update the managed MCP inventory**

```md
- `playwright` across Claude, OpenCode, and Codex via
  `npx @playwright/mcp@latest --headless --isolated`
```

- [ ] **Step 2: Add a short Playwright setup note**

```md
### Playwright MCP Setup

Playwright MCP is configured for headless, isolated local browser automation.

- Transport: local `npx @playwright/mcp@latest --headless --isolated`
- Local requirement: Node.js and `npx` available on your PATH
- No repo-managed API key is required for this baseline setup
```

- [ ] **Step 3: Keep restart guidance unchanged except for the**
  **newly documented MCP inventory**

No behavioral changes are required here; only ensure the docs
stay consistent with the config files.

- [ ] **Step 4: Run markdown lint**

Run: `markdownlint "**/*.md"`
Expected: pass with no Markdown formatting errors.

- [ ] **Step 5: Commit**

Do not commit unless the user explicitly asks for one.

## Task 4: Final verification

**Files:**

- Verify: `.claude/settings.json`
- Verify: `.config/opencode/opencode.json`
- Verify: `.codex/config.toml`
- Verify: `.config/shared-permissions.json`
- Verify: `README.md`
- Verify: `tests/sync-local-agents-config.test.sh`

- [ ] **Step 1: Run config sync regression test again**

Run: `bash tests/sync-local-agents-config.test.sh`
Expected: `Config sync checks passed.`

- [ ] **Step 2: Run markdown lint again**

Run: `markdownlint "**/*.md"`
Expected: exit code 0.

- [ ] **Step 3: Inspect the diff**

Run: `git diff -- .claude/settings.json .config/opencode/opencode.json \
.codex/config.toml .config/shared-permissions.json README.md \
tests/sync-local-agents-config.test.sh \
docs/superpowers/specs/2026-07-25-playwright-mcp-config-design.md \
docs/superpowers/plans/2026-07-25-playwright-mcp-config.md`
Expected: only the planned Playwright MCP config, docs, and test
changes are present.

- [ ] **Step 4: Commit**

Do not commit unless the user explicitly asks for one.
