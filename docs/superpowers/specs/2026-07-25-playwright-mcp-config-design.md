# Playwright MCP Config Design

## Goal

Add a repo-managed Playwright MCP configuration for Claude,
OpenCode, and Codex so local sync can install a consistent browser
automation server definition across all three tools.

## Scope

In scope:

- Add `playwright` MCP entries to the repo-managed config files
  for Claude, OpenCode, and Codex.
- Extend repo-managed Claude MCP permissions so synced Claude
  configs can call Playwright MCP tools.
- Update repository documentation describing repo-managed MCP
  coverage and local runtime requirements.
- Extend config sync regression coverage so Playwright entries are
  verified in merged target configs.

Out of scope:

- Adding Playwright-specific secrets or token handling.
- Adding custom Playwright capabilities, network policy, file
  access overrides, or browser persistence configuration.
- Changing sync architecture or adding new sync modes.

## Chosen Approach

Use the existing repo-managed config ownership model already used
for GitHub, Linear, Blender, Stitch, and Context7.

The repository will define a `playwright` MCP server in:

- `.claude/settings.json`
- `.config/opencode/opencode.json`
- `.codex/config.toml`

The server runtime will be the same across platforms:

`npx @playwright/mcp@latest --headless --isolated`

This keeps the default setup deterministic and conservative:

- `--headless` avoids requiring an interactive desktop browser session.
- `--isolated` prevents profile reuse across sessions and avoids
  state conflicts between clients in the same workspace.

## Configuration Design

### Claude

Add a new `playwright` entry under `mcpServers` using:

- `command: "npx"`
- `args: ["@playwright/mcp@latest", "--headless", "--isolated"]`

Claude permissions are generated during sync from
`.config/shared-permissions.json`. Add `playwright` to the managed
Claude `mcpAllow` list so the synced settings include
`mcp__playwright__*`.

### OpenCode

Add a new `playwright` entry under `mcp` using:

- `type: "local"`
- `command: ["npx", "@playwright/mcp@latest", "--headless", "--isolated"]`
- `enabled: true`

No additional secret handling is required because Playwright MCP
does not require API keys for this baseline setup.

### Codex

Add a new `[mcp_servers.playwright]` table using:

- `command = "npx"`
- `args = ["@playwright/mcp@latest", "--headless", "--isolated"]`

This remains compatible with the existing TOML merge path that
already syncs repo-managed MCP tables into `~/.codex/config.toml`.

## Data Flow

1. Repo-managed config files define the `playwright` MCP server.
2. `sync-local-agents.sh` merges repo-managed config sections into
   each local tool config.
3. For Claude, `prepare_claude_settings_source()` derives MCP allow
   rules from `.config/shared-permissions.json`, so adding
   `playwright` there causes synced Claude settings to include
   `mcp__playwright__*`.
4. The config sync regression test confirms the Playwright entry is
   present after merge for Claude, OpenCode, and Codex.

No changes are required to the sync script logic itself because the
repository already merges MCP entries generically by key.

## Error Handling And Constraints

Constraints:

- Keep the Playwright server definition minimal and consistent
  across tools.
- Do not add `--allow-unrestricted-file-access`, origin allowlists,
  browser capability flags, or persistent profile paths without an
  explicit follow-up request.
- Do not introduce placeholder-backed environment variables or API
  key prompts.

Operational expectations:

- Config sync should still succeed even if Playwright is not
  installed locally.
- Runtime startup will fail only when the user invokes the server
  on a machine where `npx` cannot resolve `@playwright/mcp`.
- OpenCode still requires restart after syncing `opencode.json`,
  and Claude/Codex still require restart after syncing their config
  files.

## Testing Strategy

Primary regression coverage will remain in
`tests/sync-local-agents-config.test.sh`.

The test should assert that:

- synced Claude settings include `mcp__playwright__*`
- synced OpenCode config includes the `playwright` MCP entry and
  its command arguments
- synced Codex config includes `[mcp_servers.playwright]`

Repository verification for this change:

- `bash tests/sync-local-agents-config.test.sh`
- `markdownlint "**/*.md"`

## Risks

- If a future Playwright MCP CLI changes its invocation shape, all
  three repo-managed configs would need to be updated together.
- Users without Node/npm available on `PATH` will have a valid
  synced config that cannot launch Playwright until their local
  runtime is installed.

## Implementation Notes

The sync script already supports MCP-only sync by reading
platform-specific MCP root keys:

- Claude: `mcpServers`
- OpenCode: `mcp`
- Codex: `mcp_servers`

Because of that, adding a new `playwright` server entry is a
content change, not a sync-engine change.
