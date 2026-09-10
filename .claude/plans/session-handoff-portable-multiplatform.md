# Portable, Multi-Platform Session-Handoff Skill — Implementation Plan

## 1. Situation & Goal

The `.skills/session-handoff/` skill was authored in a sandbox (path `/home/claude/workspace`)
and is not yet consumable by this repo's harness or portable across machines/projects/platforms.

Current defects:

| Defect | Evidence |
|---|---|
| **Hard-coded absolute paths** | `CONFIG_PATH`, `MONITOR_PATH`, `HANDOFF_PROJECT_PATH`, `PROJECTS_PATH` all bake in `/home/claude/workspace` and `/home/claude/.claude`. |
| **Runs only Claude-skewed assumptions** | reads `CLAUDE_CODE_SESSION_ID`, transcripts from `~/.claude/projects`, session id from `~/.claude/sessions/7.json`; skips OpenCode/Codex entirely. |
| **Not installed as a real skill** | lives only in `.skills/session-handoff/`; the repo's real skills live in `.claude/skills/<name>/SKILL.md` and are synced via `sync-local-agents.sh`. |
| **No automatic activation** | skill description tells the agent to run `bash .../context-monitor.sh` by absolute path; nothing wires it to Claude hooks, a statusline, or platform lifecycles. |
| **Config / state scattered** | `.claude/context-monitor.json` and `~/.claude/...` paths are assumed; no user-vs-project split, no per-platform store. |

Goal:

1. **Portable** — resolves everything from the *current* working directory, `$HOME`,
   `$XDG_CONFIG_HOME`, and env vars; `set -euo pipefail`; zero hard-coded repo paths.
   Works across machines, containers (different users/home dirs), and projects.
2. **Transferable between agents/environments/projects** — one canonical skill tree,
   installable either per-user (global) or per-project; verified by a parity test harness.
3. **Cross-platform** — Claude Code, OpenCode, Codex each get a native activation
   path (hooks / plugin event / skill auto-load).
4. **Optional installs** — available (a) as the payload of this repo so
   `sync-local-agents.sh --sync skills` ships it to all three platforms, and
   (b) standalone copy commands for user-local (`~/.claude/skills`, `~/.agents/skills`) or
   project-local (`<repo>/.claude/skills`, `<repo>/.agents/skills`).
5. **Fit the harness** — the repo is a single-source-of-truth harness with a canonical
   skill sync flow (`sync-local-agents.sh`), an existing `docs/plans/*.md` convention
   (checklist-based, sub-agent-executed), and a `tests/` regression suite. We preserve
   those conventions and extend (not fork) them.

### Verified platform facts (today)

- **Claude**: skills are directories with a `SKILL.md` (YAML frontmatter + body), located in
  project `.claude/skills/<name>/` or user `~/.claude/skills/<name>/`. The runtime transcript
  tree is `<state>/.claude/projects/<slug>/<sessionId>.jsonl`; project slug = workspace path
  with `/`→`-` (confirmed: `-home-claude-workspace` on this machine). Relevant Claude hooks:
  `UserPromptSubmit`, `PreCompact`, plus `statusLine.command`. The statusline-command gives us
  the current workspace dir (`workspace.current_dir` in JSON on stdin).
- **OpenCode** (v1.18.x installed): config is `opencode.json`; **no Claude-style hooks.json**.
  The model is a **plugin API** with events (`session.created`, `session.compacted`,
  `experimental.session.compacting`, `server.connected`, `tool.execute.before`, …). Plugins
  load from `.opencode/plugins/`, `~/.config/opencode/plugins/`, or npm packages in the
  `"plugin"` array of `opencode.json`. Skills are packageable as plugins. Confirmed by the
  installed binary's config/plugin schema and by upstream docs. So the OpenCode activation is
  a **plugin** that runs the same self-locating handoff script on `session.compacted` /
  `experimental.session.compacting` / `server.connected`, plus a statusline-style
  `bootstrap` script that can be hooked via `tui`/keybind explicitly.
- **Codex** (OpenAI CLI) skills: directory with `SKILL.md`; repo skills discovered by walking
  up from `$CWD` to repo root: `$CWD/.agents/skills`, `../.agents/skills`, `$REPO_ROOT/.agents/skills`;
  **user** skills at `$HOME/.agents/skills`; frontmatter = `name` + `description`
  (+ optional `agents/openai.yaml` for `allow_implicit_invocation: false` etc.). No hooks API;
  activation is a description-driven skill (`session-handoff`) that the model invokes when
  context is full, and the skill itself runs the portable scripts. Codex has `config.toml`
  with `[skills.xyz]` blocks (enable/disable), but no per-turn hook; validation must come
  from the skills directory / syntax check.

### Key design decisions (confirmed with user)

- Keep **one canonical script tree** that self-locates at runtime (no `.env` baked paths).
- A single **shared bash core** (`lib/` + `bin/`) with thin per-platform activation layers
  (hooks, plugin, skill body). Platform diffs stay as *glue*, not logic.
- **Storage split** (user chose **Project-local store**):
  - Transcripts: platform's own state dir (Claude `~/.claude/projects`, OpenCode
    `~/.local/share/opencode/...`, Codex session storage under state) — **read-only**.
  - Handoff outputs: **project-local** `<project>/.claude/handoff/<slug>/session-handoffs/<sid>.md`
    (matches today's behavior) — with a **fallback** to the user-global store
    `$HOME/.local/state/session-handoff/handoffs/<platform>/<slug>/...` when the current dir
    is not inside a git repo / has no writable `.claude/` (e.g. Claude user-global skill run
    from an arbitrary cwd). A `.gitignore` rule keeps the project store out of version control.
- **Auto-wiring**: user chose **Fully auto-wire on sync**. `sync-local-agents.sh` will, on
  `--sync skills` (per platform), also:
  - **Claude**: merge `hooks.UserPromptSubmit` + `hooks.PreCompact` (and optional statusline
    percent) into `~/.claude/settings.json` (backup-first merge, non-destructive; respects an
    existing `hooks` block by appending/merging keys, never deleting user keys).
  - **Codex**: mirror the skill to `$HOME/.agents/skills/session-handoff` (user-global repo
    discovery) and to the active project's `.agents/skills/session-handoff`; add a
    `[[skills.config]]`-style enable entry to `~/.codex/config.toml` if one is needed for
    discovery (backup-first merge; opencode/codex `--dry-run` previews the diff).
  - **OpenCode**: add `"session-handoff"` plugin to the `"plugin"` array in the generated
    `opencode.json` (and to `~/.config/opencode/opencode.json` on target-dir-less sync),
    backup-first merge.
  - A new `--no-wire` flag disables all config mutation; `--dry-run` previews every
    proposed edit. All user-config edits write a timestamped `.bak` before merging.
- **Config**: `context-monitor.json` lives next to the skill (defaults) with an optional
  user/project override merge (deep), env-var overrides (`SESSION_HANDOFF_*`).
- **Paths** resolved by `dirname $(readlink -f "$0")` → skill root; project dir from
  `$(pwd)`, `workspace.current_dir`, or `cwd` in hook JSON; session id from platform env
  (`CLAUDE_CODE_SESSION_ID`, `OPENCODE_*`/plugin ctx, `CODEX_*`), falling back to
  `~/.local/state/session-handoff/active-session.json`.
- **Auto-activation targets** (all optional, per platform):
  - Claude: `UserPromptSubmit` + `PreCompact` hooks (as today) and/or statusline percent.
  - OpenCode: plugin subscribed to `server.connected` / `session.compacted` /
    `experimental.session.compacting` (best-effort, does NOT block).
  - Codex: description-driven skill auto-load plus explicit `session-handoff` instruction.
- **Repo integration**: place canonical skill under `.claude/skills/session-handoff/` (the
  repo convention), keep a thin polyglot README at `.skills/session-handoff/` that routes to
  platform locations, wire it into `sync-local-agents.sh` skills flow (it rsyncs
  `.claude/skills/` → all three platform skill dirs already), and preserve the existing
  `.claude/statusline-command.sh` convention.

## 2. Proposed File Layout (portable skill, canonical)

**Canonical location is platform-neutral: `.skills/session-handoff/`** (same pattern as
`.agents/` = canonical agents). Platforms never read that folder directly; `sync-local-agents.sh`
**materializes identical copies** into each platform's own discovery slot, so there is exactly
ONE authoring home and NO per-agent/per-env path scripts. One self-locating `lib/paths.sh`
inside the tree makes every copy work identically wherever it lands.

```
@repo root (this harness)
├── .skills/session-handoff/                      # CANONICAL skill tree (single source of truth)
│   ├── SKILL.md                                  # frontmatter name/description + workflow
│   ├── lib/
│   │   └── paths.sh                              # self-locating path/env resolution (the ONLY place paths are derived)
│   ├── bin/
│   │   ├── context-monitor.sh                    # prints percent (portable core, no hard-coded paths)
│   │   ├── context-autohandoff.sh                # mechanical snapshot writer (transportable)
│   │   ├── context-prompt-hook.sh                # Claude hooks glue (UserPromptSubmit)
│   │   ├── context-precompact-hook.sh            # Claude PreCompact glue
│   │   ├── context-statusline.sh                 # statusline percent for Claude / rate
│   │   ├── opencode-plugin.js                    # OpenCode plugin glue → runs autohandoff on events
│   │   └── codex-skill-invoke.sh                 # Codex skill glue (also usable standalone)
│   ├── context-monitor.json                      # defaults (portable, merged with user/project overrides)
│   └── README.md                                 # install/user-vs-project/per-platform + copy commands
└── tests/
    └── session-handoff-portable.test.sh          # parity/portability regression tests

Materialized copies (generated by sync-local-agents.sh, NOT hand-edited):
  .claude/skills/session-handoff/                 # Claude project discovery
  .config/opencode/skills/session-handoff/        # OpenCode project discovery
  .codex/skills/session-handoff/                  # Codex-ish project discovery (best-effort)
  .agents/skills/session-handoff/                 # Codex repo discovery ($CWD → REPO_ROOT walk)
  (user-global)  ~/.claude/skills/session-handoff/          # Claude user
                 ~/.config/opencode/skills/session-handoff/ # OpenCode user
                 ~/.agents/skills/session-handoff/          # Codex user
```

### Runtime location rules (all resolved from the skill root / env / cwd, never hard-coded)

The resolved `SKILL_ROOT` = whichever materialized copy executed (e.g. project
`<project>/.claude/skills/session-handoff`, user `~/.claude/skills/session-handoff`, Codex
`.agents/skills/session-handoff`, or the canonical `.skills/session-handoff`). All copies are
bytes-identical (sync-generated), so path resolution is identical.

| What | User-global install | Project install |
|---|---|---|
| Skill root | `$HOME/.claude/skills/session-handoff` | `<project>/.claude/skills/session-handoff` |
| Handoff store | `$HOME/.local/state/session-handoff/handoffs/<platform>/<slug>/session-handoffs/<sid>.md` (fallback) | `<project>/.claude/handoff/<slug>/session-handoffs/<sid>.md` (preferred, matches today) |
| Transcript (Claude) | resolve under `$HOME/.claude/projects/<slug>/` (existing tree) | same (state is user-global) |
| Override config | `$HOME/.config/session-handoff/context-monitor.json` | `<project>/.claude/session-handoff.json` (optional) |
| Active session pointer | `$HOME/.local/state/session-handoff/active-session.json` (opencode/codex fallback) | — |

Mode selection: if `$PWD` (or hook `cwd`) is inside a writable git work tree,
project-local store wins; otherwise the user-global store is used.

### Paths currently hard-coded and how each is made portable

| File: line | Hard-coded | Portable resolution |
|---|---|---|
| `context-autohandoff.sh:9-10` | `/home/claude/workspace/.claude/...` | skill root via `BASH_SOURCE` walk → `lib/paths.sh` |
| `context-autohandoff.sh:50` | `TRANSCRIPT_PROJECT_PATH=/home/claude/.claude/projects` | `$HOME/.claude/projects` (or `$CLAUDE_STATE_DIR`) |
| `context-autohandoff.sh:15-16` | `/home/claude/.claude/sessions/7.json` | only as last-resort fallback (kept) |
| `context-monitor.sh:10-11` | `CONFIG_PATH`, `/home/claude/.claude/projects` | from skill root + `$HOME` |
| `context-monitor.sh:38` | `/home/claude/.claude/sessions/7.json` | kept as fallback only |
| `context-prompt-hook.sh:8-10` | all three paths | from skill root + `$HOME` |
| `context-precompact-hook.sh:7` | `AUTOHANDOFF_PATH` | from skill root |
| `context-monitor.json:7-8` | transcript/handoff root paths | move to env-computed (not JSON values) |

### Canonical→platform mapping (sync responsibility, single source of truth)

| Target platform | Discovery slot(s) filled by sync | Consumer |
|---|---|---|
| Claude (project) | `<project>/.claude/skills/session-handoff/` | Claude Code |
| Claude (user) | `~/.claude/skills/session-handoff/` | Claude Code |
| OpenCode (project) | `<project>/.config/opencode/skills/session-handoff/` | OpenCode |
| OpenCode (user) | `~/.config/opencode/skills/session-handoff/` | OpenCode |
| Codex (repo) | `<repo>/.agents/skills/session-handoff/` (CWD→root walk) | Codex CLI |
| Codex (user) | `~/.agents/skills/session-handoff/` | Codex CLI |
| Codex (legacy project) | `<project>/.codex/skills/session-handoff/` (best-effort) | Codex CLI (older) |

### Session id resolution per platform

| Platform | Primary | Fallbacks |
|---|---|---|
| Claude | `CLAUDE_CODE_SESSION_ID` | latest `.jsonl` in `~/.claude/projects/<slug>/` |
| OpenCode | plugin context (`session.id` passed to event handler) | newest file under `~/.local/share/opencode/` … / session store |
| Codex | `CODEX_SESSION_ID` if present | newest `.jsonl` under Codex session/state dir |

Each fallback opens the most recent matching transcript only to prove existence (for the
symlink pointer); the handoff filename uses the resolved sid.

## 3. Planned Changes (by repo area)

### A. Canonical portable skill (single source of truth at `.skills/session-handoff/`)

1. **`lib/paths.sh`** — exports `SKILL_ROOT`, `PROJECT_DIR` (from `$PWD` /
   `workspace.current_dir` / hook `cwd`), `PLATFORM`, `SESSION_ID`, `STATE_HOME`
   (`$HOME/.local/state/session-handoff`), `HANDOFF_ROOT` (user or project per install),
   `CONFIG_FILE` (skill + override).

2. **`bin/context-monitor.sh`** — refactor of today's; sources `lib/*.sh`; percent =
   `<model?>` tokens/sum of last `usage.input_tokens` over `contextWindow` from merged config.
   No absolute paths. Prints integer or nothing.

3. **`bin/context-autohandoff.sh`** — refactor of today's; uses `paths.sh`; writes
   handoff markdown + transcript symlink under the resolved `HANDOFF_ROOT`; still silent.

4. **`bin/context-prompt-hook.sh`** — Claude `UserPromptSubmit`; block at
   `blockPercent`, snapshot+warn at `warnPercent`; all paths from `lib/paths.sh`.

5. **`bin/context-precompact-hook.sh`** — Claude `PreCompact`; snapshot only.

6. **`bin/context-statusline.sh`** — outputs current percent for Claude statusline;
   encodes active handoff existence for reuse by the skill body /
   `.claude/statusline-command.sh` conventions.

7. **`bin/opencode-plugin.js`** — OpenCode plugin; on `server.connected` and
   `session.compacted`/`experimental.session.compacting`, runs
   `context-autohandoff.sh` with `cwd` from event ctx; returns promptly, never throws.

8. **`bin/codex-skill-invoke.sh`** — self-contained glue that `paths.sh`-resolves and
   runs `context-autohandoff.sh` (used by Codex skill body; can also be invoked by
   opencode/agents or by the operator).

9. **`context-monitor.json`** — defaults only (no absolute paths): `contextWindow`,
   `warnPercent`, `criticalPercent`, `blockPercent`, `autoHandoffEnabled`, plus
   `modelToWindowHint` (maps model to context window when transcripts lack it).

10. **`SKILL.md`** — frontmatter `name: session-handoff`, description telling the model
    WHEN to invoke; body = steps: run `context-monitor.sh` (via `bin`), decide warn/critical,
    gather summary sections, write to resolved `HANDOFF_ROOT`, report. No absolute paths.

11. **`README.md`** — install matrix (user vs project × claude/opencode/codex) with
    copy/rsync/sync commands; env-var reference (`SESSION_HANDOFF_*`,
    `CLAUDE_CODE_SESSION_ID`, etc.); hook wiring examples per platform.

### B. Canonical tree modernization (this IS the single source, replacing old hard-coded scripts)

- The old sandbox scripts (hard-coded paths) move out: their functionality becomes the new
  `lib/paths.sh` + `bin/*` in the canonical `.skills/session-handoff/` tree. It is safe to
  keep a short placeholder README at the old location of any moved files if referenced
  anywhere, but the canonical tree is authoritative.

### C. Harness wiring (shared skills sync + auto-wiring)

`sync-local-agents.sh` already rsyncs `.claude/skills/` → all three platform skill dirs.
Add (small, scoped), per the confirmed **fully auto-wire** decision:

- **Canonical → platform materialization**: source the canonical tree from `.skills/session-handoff/`
  (NOT `.claude/skills/`) and rsync identical copies into `.claude/skills/`,
  `.config/opencode/skills/`, `.codex/skills/` (project) and user slots
  (`~/.claude/skills`, `~/.config/opencode/skills`, `~/.agents/skills`).
- **Codex**: mirror the skill to the platform's auto-load locations
  (`$REPO_ROOT/.agents/skills/session-handoff` and user `$HOME/.agents/skills/session-handoff`),
  since Codex discovers skills from those paths; add a
  `[[skills.config]]`-style enable entry to `~/.codex/config.toml` if required for discovery.
- **OpenCode**: add the `session-handoff` plugin to the `"plugin"` array in the generated
  `opencode.json` (and `~/.config/opencode/opencode.json`), so the plugin activates.
- **Claude**: merge `hooks.UserPromptSubmit` + `hooks.PreCompact` blocks (and optional
  statusline percent) into the target `settings.json` — project `.claude/settings.json` or
  user `~/.claude/settings.json` per install — **backup-first merge**, never clobbering
  existing keys. A new `--no-wire` flag and `--dry-run` previews make it non-destructive.
- All user-config mutations write `<file>.bak-<ts>` before merging and are covered by
  `tests/session-handoff-wire.test.sh` (backup creation, key-preservation, idempotency).
- Add `tests/session-handoff-portable.test.sh` asserting:
  1. No hard-coded `/home/...` or `/Users/...` paths in `stdout`, handoff markdown, or config.
  2. Running `context-monitor.sh` with a mocked/empty env prints only a number or nothing,
     and exit code 0.
  3. `context-autohandoff.sh` writes under the resolved `HANDOFF_ROOT` and a transcript
     symlink when a matching transcript exists (using a temp `HOME`/`TMPDIR`).
  4. Path resolution is relative to the skill root (rename/move the tree → still works).
  5. Config merge: override file beats skill defaults.
  6. Cross-platform marker files exist: `opencode-plugin.js` parses under node, and the
     skill dir exists in the codex-repo/user skill locations after sync.
  7. (Wire test) settings/opencode/codex edits are backup-first, idempotent, and
     `--dry-run` makes no changes.

### D. Documentation

- Update `AGENTS.md` / `README.md` skills list to include session-handoff.
- Update `docs/plans/2026-08-13-single-source-of-truth.md` "Follow-ups" to mark skills
  single-sourcing picked up here (partial).
- Add a "How new skills are installed user-vs-project on each platform" section to the
  repo README so future skills follow the same pattern.

## 4. Phased Tasks (checklist-style, sub-agent-executed)

### Phase 1 — Portable core (Claude-first, no platform glue yet)

- [ ] **P1.1** Create `.skills/session-handoff/lib/paths.sh` (self-locate, env,
  install-mode detection user vs project, platform & sid resolution helpers).
- [ ] **P1.2** Refactor `.skills/session-handoff/bin/context-monitor.sh` onto `lib/`;
  no absolute paths; defaults from `context-monitor.json` (skill dir) + override merge.
- [ ] **P1.3** Refactor `.skills/session-handoff/bin/context-autohandoff.sh` onto `lib/`;
  handoff + transcript symlink under resolved roots; remove all `/home/claude/workspace`
  literals.
- [ ] **P1.4** Refresh `context-monitor.json` (defaults only), `SKILL.md`, `README.md`.
- [ ] **P1.5** Add `tests/session-handoff-portable.test.sh` (checks 1–5 above).
- [ ] **P1.6** Verify: `bash tests/session-handoff-portable.test.sh` passes; manual run in
  an isolated `TMPDIR`/temp `HOME` shows percent or empty, handoff lands under
  `$HOME/.local/state/session-handoff/handoffs/...`.

### Phase 2 — Claude activation

- [ ] **P2.1** Add `bin/context-statusline.sh`; wire into the repo's statusline docs
  (keep `.claude/statusline-command.sh` convention; add optional percent).
- [ ] **P2.2** Verify `context-prompt-hook.sh`/`context-precompact-hook.sh` use
  `lib/paths.sh`; dry-run against a real `~/.claude/projects/<slug>/<sid>.jsonl` in temp HOME.
- [ ] **P2.3** Implement the settings-merge helper (`lib/wire-settings.sh` owning
  backup-first hooks/statusline merging); wire hook blocks into project
  `.claude/settings.json` or user `~/.claude/settings.json` per install on `--sync skills`.

### Phase 3 — Codex support

- [ ] **P3.1** Ensure canonical tree is mirrored to `.agents/skills/session-handoff/`
  (Codex repo discovery) and documented `@ $HOME/.agents/skills/session-handoff` (user).
- [ ] **P3.2** Add `bin/codex-skill-invoke.sh`; ensure `SKILL.md` body is Codex-compatible
  frontmatter (`name`, `description`) with no Claude-only phrasing.
- [ ] **P3.3** Test: `CODEX_SESSION_ID`-style invocation + temp HOME produces a handoff.

### Phase 4 — OpenCode support

- [ ] **P4.1** Add `bin/opencode-plugin.js` (reads `$OPENCODE`/`ctx`; runs autohandoff on
  `server.connected` + `session.compacted`/`experimental.session.compacting`).
- [ ] **P4.2** Wire plugin into generated `opencode.json` `"plugin"` array on `--sync`
  (backup-first merge; `--no-wire` skips).
- [ ] **P4.3** Test: `node --check` parses; running with a mocked ctx writes a handoff.

### Phase 5 — Harness glue & final verification

- [ ] **P5.1** Extend `sync-local-agents.sh` skills flow for codex `.agents/skills`
  (+ user `$HOME/.agents/skills`), opencode plugin wiring, and the Claude
  hooks/statusline settings merge; add `--no-wire` flag and keep `--dry-run` safe.
- [ ] **P5.2** Update `.gitignore` so runtime handoff state and `$HOME/.local/state/...`
  are not tracked if generated in-repo (add `.claude/handoff/` if not present, and
  document the user-global store is out-of-repo).
- [ ] **P5.3** Update `AGENTS.md`, `README.md`, and the old skills plan doc.
- [ ] **P5.4** Run full regression suite:
  - `bash tests/session-handoff-portable.test.sh`
  - `bash tests/session-handoff-wire.test.sh` (backup-first merge, idempotency, `--dry-run`)
  - any existing `tests/sync-local-agents*.sh` that touch skills
  - `bash -n` on all new/changed scripts; `node --check` on the plugin
- [ ] **P5.5** Manual smoke: pretend a new machine — `python3 -m venv`-style temp `HOME`,
  run CLI skill from the winded tree, confirm handoff is written and restartable.

## 5. Follow-ups / explicit non-goals (this iteration)

- **Non-goal:** non-reversible user-config edits. Auto-wiring is always backup-first
  (`.bak-<ts>`), previewable via `--dry-run`, and skippable via `--no-wire`.
- **Non-goal:** publishing as a plugin/npm/skill package to marketplaces. We ship the
  canonical tree in-repo and let `sync-local-agents.sh` (incl. `--target-dir`) distribute it.
- **Stretch (optional, separate PR):** full skill single-sourcing per
  `.agents/skills` canonical for ALL skills (the plan-doc follow-up), generalizing what this
  skill does for `session-handoff` specifically.
- **OpenCode statusline/autoblock**: current opencode lacks a per-prompt block hook; we use
  passive snapshot on compaction/server-connect only. Revisit when `hooks.json` or a
  per-prompt event ships upstream.

## 6. Risks / Assumptions

- **Assumption:** Claude transcript location (`$HOME/.claude/projects/<slug>/`) is stable
  (verified on this machine); if a future Claude uses `$CLAUDE_STATE_DIR`, `lib/paths.sh`
  hints it and the tests only require the resolved value be used consistently.
- **Assumption:** Codex user skills dir `$HOME/.agents/skills` per upstream docs (verified);
  repo-level `.agents/skills` discovery likewise.
- **Risk (low):** OpenCode plugin event names may shift across the 1.x line; we pin the two
  documented events and degrade gracefully (`try { ... } catch {}`), zero crash-on-missing.
- **Risk (low):** `source ~/.claude/settings.json` may not yet support `hooks` for the CLI
  in older versions; we hook via `UserPromptSubmit`/`PreCompact` which are documented,
  and always leave the manual skill invocation path working.
- **Testing constraint:** no OpenCode UI automation available in-sandbox; plugin verified by
  `node --check` + mocked-ctx run, not live UI.

## 7. Verification matrix (what to run to consider this done)

| # | Command | Pass criteria |
|---|---|---|
| 1 | `bash tests/session-handoff-portable.test.sh` | all asserts green |
| 2 | `bash -n .skills/session-handoff/bin/*.sh .skills/session-handoff/lib/*.sh` | no syntax errors |
| 3 | `node --check .skills/session-handoff/bin/opencode-plugin.js` | ok |
| 4 | `HOME=$(mktemp -d) bash .skills/session-handoff/bin/context-monitor.sh` | prints integer or nothing, exit 0 |
| 5 | `HOME=$(mktemp -d) bash .skills/session-handoff/bin/context-autohandoff.sh` + inspect | handoff under `$HOME/.local/state/session-handoff/handoffs/...`; no `/home/claude/workspace` literal anywhere |
| 6 | `grep -rn '/home/claude/workspace' .skills/session-handoff tests/session-handoff-portable.test.sh` | no matches (canonical tree) |
| 7 | `./sync-local-agents.sh --dry-run --sync skills` | session-handoff materialized to all platform slots (`.claude/skills`, `.config/opencode/skills`, `.codex/skills`, `.agents/skills`) + codex `.agents/skills` mirror |

The `.skills/session-handoff/` tree is the shell to modernize in-place. The old
`scripts/*.sh` (hard-coded) are superseded by the new `lib/` + `bin/`.
