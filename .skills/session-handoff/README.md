# session-handoff (portable, multi-platform)

A single-source **portable** skill for checking agent context usage and writing a
structured session-handoff summary so work can continue in a fresh session.
Runs on **Claude Code**, **OpenCode**, and **Codex**, in **any project** and on
**any machine**, from **user-global or project** installs.

The tree is **self-locating**: every path (project dir, session id, transcript root,
handoff root, config) is derived at runtime from `$PWD`, `$HOME`, XDG dirs, platform
env vars, and hook JSON in `lib/paths.sh`. **No absolute paths are baked in** — you
can copy this folder anywhere and it works.

## Layout

```
session-handoff/
├── SKILL.md             # frontmatter + workflow (how the agent uses it)
├── lib/paths.sh         # the ONLY path/environment resolution (self-locating)
├── bin/
│   ├── context-monitor.sh        # prints context-use percent (0-100) or nothing
│   ├── context-autohandoff.sh    # writes the mechanical snapshot + transcript symlink
│   ├── context-prompt-hook.sh    # Claude UserPromptSubmit hook (block at blockPercent)
│   ├── context-precompact-hook.sh# Claude PreCompact hook (snapshot only)
│   ├── context-statusline.sh     # context percent for Claude statusline / rate
│   ├── opencode-plugin.js        # OpenCode plugin glue (compaction/server-connect snapshot)
│   └── codex-skill-invoke.sh     # Codex glue (also usable standalone)
├── context-monitor.json  # defaults (merged with user/project overrides)
└── README.md             # this file
```

## Install (user-global vs project) × platform

Materialize a copy into the platform's own discovery slot. Copies are bytes-identical,
so any slot works. The repo harness (`sync-local-agents.sh --sync skills`) does this
automatically; manual commands:

| Platform | User-global | Project |
|---|---|---|
| Claude | `cp -r session-handoff ~/.claude/skills/` | `cp -r session-handoff <project>/.claude/skills/` |
| OpenCode | `cp -r session-handoff ~/.config/opencode/skills/` | `cp -r session-handoff <project>/.config/opencode/skills/` |
| Codex | `cp -r session-handoff ~/.agents/skills/` | `cp -r session-handoff <repo>/.agents/skills/` |
| Codex (legacy) | — | `cp -r session-handoff <project>/.codex/skills/` |

Codex discovers skills at `<project>/.agents/skills` walking up to the repo root, and at
`~/.agents/skills` for all users.

## Quick start

From inside the skill directory:

```bash
bash bin/context-monitor.sh       # → integer percent or nothing
bash bin/context-autohandoff.sh   # → writes mechanical snapshot + transcript symlink
```

## Configuration

`context-monitor.json` holds defaults. Overrides are merged (precedence, later wins):

1. skill defaults (`context-monitor.json`)
2. `$SESSION_HANDOFF_CONFIG` (explicit file path)
3. `$HOME/.config/session-handoff/context-monitor.json`
4. `<project>/.claude/session-handoff.json`

Merge rules: deep merge, scalar/array replaces. The merged config is cached at
`$HOME/.local/state/session-handoff/config/context-monitor.merged.json`.
Keys: `contextWindow`, `warnPercent`, `criticalPercent`, `blockPercent`,
`autoHandoffEnabled`, `modelToWindowHint`.

## Environment variables

| Variable | Meaning |
|---|---|
| `SESSION_HANDOFF_PLATFORM` | force `claude`/`opencode`/`codex` |
| `SESSION_HANDOFF_PROJECT_DIR` | override the project dir |
| `SESSION_HANDOFF_CONFIG` | explicit config file to merge |
| `CLAUDE_CODE_SESSION_ID` | Claude active session id |
| `CLAUDE_PROJECTS_DIR` | override `~/.claude/projects` (transcript root) |
| `OPENCODE_SESSION_ID` | OpenCode session id (plugin context is primary) |
| `CODEX_SESSION_ID` / `CODEX_CONVERSATION_ID` | Codex session id |
| `XDG_STATE_HOME`, `XDG_DATA_HOME` | user state/data roots |

## Activation (hooks / plugin / skill)

The repo harness auto-wires (backup-first, idempotent; `--no-wire` to skip):

- **Claude**: `hooks.UserPromptSubmit` → `bin/context-prompt-hook.sh`,
  `hooks.PreCompact` → `bin/context-precompact-hook.sh` in `settings.json`;
  optional statusline percent via `bin/context-statusline.sh`.
- **OpenCode**: `session-handoff` plugin in the `plugin` array of `opencode.json`
  (snapshots on `server.connected` / `session.compacted` / `experimental.session.compacting`).
- **Codex**: the skill auto-loads from `.agents/skills`/`~/.agents/skills`; the model
  triggers it when context is full per the `description`.

---

## Platform activation

### Claude Code

**Statusline** — add a `statusLine.command` to your Claude settings that
invokes the statusline helper; it prints a short `%` string (e.g. `ctx 45%`)
or nothing when usage is unknown. It accepts the same `workspace.current_dir`
stdin JSON as the hooks, so it can run from project or user-global installs:

```bash
# ~/.claude/settings.json  or  <project>/.claude/settings.json
"statusLine": {
  "type": "command",
  "command": "bash \"~/.claude/skills/session-handoff/bin/context-statusline.sh\""
}
```

**Hooks** — the skill ships two hook scripts:

- `bin/context-prompt-hook.sh` — `UserPromptSubmit`. Reads the
  `workspace.current_dir` from stdin JSON, computes the context percent, and
  when it is at/above `blockPercent` prints a suppression directive so Claude
  blocks the submission and the user can start a fresh session.
- `bin/context-precompact-hook.sh` — `PreCompact`. Writes a fresh mechanical
  snapshot right before a context compact so no work is lost.

Both are wired by `lib/wire-settings.sh` (below). A PreCompact run writes a
handoff with the same structure as the standalone CLI (`context-autohandoff.sh`),
so `--no-wire` installs still get the standalone behavior.

### The `wire-settings.sh` helper

`lib/wire-settings.sh` is a pure-bash, self-locating library (no repo-path
hard-coding; uses the same `BASH_SOURCE[0]` ancestor walk as `lib/paths.sh`).
It is meant to be **sourced**, and defines:

- `backup_file <path>` — copies `<path>` to `<path>.bak-<ts>` once per run
  (only if the file exists and hasn't been backed up already this process).
- `merge_json <base_files...> <out>` — deep-merges JSON config files onto the
  output with python3 (the same temp-file approach as `lib/paths.sh`):
  later files win, dictionaries merge recursively, scalars/arrays replace, and
  keys that already exist in `<out>` but are absent from the base files are
  **preserved** (never deleted). On failure the original `<out>` is untouched.
- `ensure_claude_hooks <settings_json> <command-prefix>` — idempotently adds the
  `UserPromptSubmit` → `<command-prefix>/bin/context-prompt-hook.sh` and
  `PreCompact` → `<command-prefix>/bin/context-precompact-hook.sh` blocks ONLY
  when those exact entries are absent; pre-existing hooks are kept as-is.
- `wire_claude_settings <cwd_for_project_detection> <repo_root> [...]` — decides
  project vs user-global target settings file (when cwd is inside the writable
  repo → `<repo>/.claude/settings.json`, else `~/.claude/settings.json`), backs
  up and deep-merges the optional trailing JSON file args, ensures hooks, and
  prints a one-line summary: `# wired hooks into <path>` or
  `# skipped (no write-able target)`.

The harness normally drives this. Manual usage:

```bash
source .skills/session-handoff/lib/wire-settings.sh
wire_claude_settings "$PWD" "$PWD"            # no extra base files
```

**`--dry-run` / `--no-wire` semantics.** The harness exposes two flags when
wiring the skill:

- `--dry-run` prints what *would* be written (`# would wire hooks into <path>`)
  without touching any file (this includes the backup + merge + hook steps).
- `--no-wire` skips the settings wiring entirely and only copies the skill
  tree into the platform slot (so `context-statusline.sh` and the standalone
  CLI still work, but no hooks/statusline/plugin array is added).

### OpenCode

OpenCode has no hooks API, so activation is a **plugin**. Copy the skill tree
(including `bin/opencode-plugin.js`) into your plugin slot, then list it in the
`plugin` array of `opencode.json`:

```bash
# <project>/.config/opencode/opencode.json  or  ~/.config/opencode/opencode.json
"plugin": [ "..." , "./plugins/session-handoff/opencode-plugin.js" ]
```

The plugin is a dependency-free, CommonJS-exporting module (it also exposes
`.default` so Bun's dynamic `import()` — what OpenCode uses — resolves the
plugin factory the same way). On `session.compacted`,
`experimental.session.compacting`, or `server.connected` it spawns
`bin/context-autohandoff.sh` with:

- `SESSION_HANDOFF_PLATFORM=opencode`
- `OPENCODE_SESSION_ID` from the ctx/event when exposed (otherwise the
  lib/paths.sh fallback scan of the opencode session store)
- `SESSION_HANDOFF_PROJECT_DIR` set to the resolved ctx cwd

It never throws and never blocks the main process (everything is in
try/catch, the child is `detached:false` and `.unref()`ed, and all console
output goes to stderr only when `SESSION_HANDOFF_DEBUG` is set). A
spawn-race guard skips the spawn when there is no session id *and* no opencode
session store yet (nothing to snapshot).

The harness wires the plugin path into the `plugin` array during
`--sync skills --platform opencode` (Phase 5); the plugin file itself is part
of the skill tree so it is copied automatically.

### Codex

Codex (OpenAI CLI) has no hooks API either. The skill auto-loads from
`.agents/skills`/`~/.agents/skills` (the repo discovery and the user-global
slot; frontmatter needs only `name` + `description`). When the model decides
context is full (or the user asks), it runs:

```bash
bash bin/codex-skill-invoke.sh
```

`bin/codex-skill-invoke.sh` is a thin executable wrapper: it sources
`lib/paths.sh` (so `CODEX_SESSION_ID` / `CODEX_CONVERSATION_ID` resolve
against `$CODEX_SESSIONS_DIR` or `~/.codex/sessions`), then `exec`s
`context-autohandoff.sh`. It works identically from the skill body and as a
standalone CLI. No config wiring is required — Codex enables/disables skills
itself via `[skills.x]` blocks in `~/.codex/config.toml`.

### Testing

```bash
bash tests/session-handoff-portable.test.sh                 # Phase-1 portability suite
bash -n .skills/session-handoff/bin/*.sh .skills/session-handoff/lib/*.sh
node --check .skills/session-handoff/bin/opencode-plugin.js
```

Plugin smoke (no OpenCode needed):

```bash
node --input-type=module -e '
  const m = await import("file://$PWD/.skills/session-handoff/bin/opencode-plugin.js");
  const handler = await m.default({ cwd: "/tmp", workspace: { current_dir: "/tmp" } });
  await handler.event({ event: { type: "server.connected" } });
'
