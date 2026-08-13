# Single Source of Truth for Agents — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the canonical agent definition the single source of
truth and stop hand-syncing the same agent body across three
platform directories. A generator materializes each platform's
per-agent file (with platform-specific frontmatter) so the real
consumers — user-local configs, and any `--target-dir` destination —
get consistent, drift-free agents.

**Architecture:**
- New canonical directory holds one file per agent: the markdown
  body plus shared frontmatter (`name`, `description`, `color`).
  The per-platform `model`/`temperature` stay as platform-specific
  overrides (via the existing model-override machinery and
  `.config/model-catalog.json`).
- A small generator (`generate-agents.sh`) renders the three
  per-platform outputs into **git-ignored** staging dirs under
  `.claude/agents`, `.codex/agents`, `.config/opencode/agents`.
- The existing `sync-local-agents.sh` flow continues to consume
  those staging dirs and rsync them to user-local dirs
  (`$HOME/.claude`, `$HOME/.codex`, `$HOME/.config/opencode`),
  applying model overrides as today.
- Add `--target-dir <path>` so the same generated output can be
  written to an arbitrary destination (e.g. a project's `.claude/`).
- Regression tests assert generated parity between the three outputs
  and the canonical source.

**Scope:** All agents (the 18 shared + `native-mobile-engineer`).
**Pilot (done):** `it-task-master`. **Out of scope:** skills.

**Tech Stack:** Bash, Markdown, YAML-frontmatter parsing,
`sync-local-agents.sh`, `tests/` regression tests.

---

## Migration audit (facts verified, 2026-08-13)

- **18 shared agents** have **byte-identical bodies** across `.claude/`,
  `.codex/`, `.config/opencode/`. Ideal canonical source.
- **`native-mobile-engineer`** exists only in Codex + OpenCode (not
  Claude). Body is identical on the two platforms it appears on.
- **Per-agent model deviations from the platform default exist**:
  - Claude default `sonnet`: `backend-architect`→`opus`,
    `frontend-architect`→`opus`, `ux-ui-architect`→`opus`,
    `content-writer`→`haiku`, `principal-engineer`→`haiku`,
    `staff-engineer`→`haiku`, `team-manager`→`haiku`.
  - OpenCode default `openai/gpt-5.6-luna`:
    `backend-architect`→`gpt-5.6-sol`, `frontend-architect`→`gpt-5.6-sol`,
    `ux-ui-architect`→`gpt-5.6-sol`.
  - Codex default `openai/gpt-5.4`: `backend-architect`→`gpt-5.3-codex`,
    `backend-engineer`→`gpt-5.3-codex`, `devops-engineer`→`gpt-5.3-codex`,
    `e2e-test-engineer`→`gpt-5.3-codex`, `frontend-architect`→`gpt-5.3-codex`,
    `frontend-engineer`→`gpt-5.3-codex`, `secops-auditor`→`gpt-5.3-codex`.
  - `3d-modeling-artist` has no `model:` on Claude/Codex today (only
    OpenCode); it will inherit the platform default after migration.
- **Description divergence is minimal**: only `backend-engineer`
  (Claude short vs Codex/OpenCode long with `\n\nExamples:`) and
  `3d-modeling-artist` (a single trailing space). Both preserve the
  platform divergence, so migration is byte-stable.
- **`native-mobile-engineer` also carries `mode`/`permission`
  frontmatter** (and no `color` on OpenCode). The generator already
  copies unknown frontmatter lines verbatim, so these survive.

### Canonical source selection

The canonical `.agents/<slug>.md` body is taken from the **Claude**
copy (identical to the others). The canonical description is also the
Claude (shared short) description, EXCEPT `backend-engineer`, where
the Claude short description becomes canonical. For both shared and
exclusive agents, per-platform `model`/`temperature` come from
`.config/agent-platforms.json` (+ the new per-agent override map) and
`color`/`temperature` rules are unchanged from the pilot.

---

## Task 1: Add per-agent model overrides to the platform config

**Files:**
- Modify: `.config/agent-platforms.json`
- Test: `tests/sync-local-agents-single-source.test.sh`

- [ ] **Step 1: Add an `agents` map keyed by agent slug**

Mirror the existing `platforms.<name>.model` defaults but allow a
per-agent override. Structure:

```jsonc
{
  "version": 1,
  "platforms": {
    "claude":  { "dir": ".claude/agents", "model": "sonnet", "color": true,
                 "agents": { "backend-architect": "opus", "frontend-architect": "opus", ... } },
    "codex":   { "dir": ".codex/agents", "model": "openai/gpt-5.4", "temperature": 0.4, "color": true,
                 "agents": { "backend-architect": "openai/gpt-5.3-codex", ... } },
    "opencode":{ "dir": ".config/opencode/agents", "projectDir": ".opencode/agents",
                 "model": "openai/gpt-5.6-luna", "temperature": 0.4, "color": false,
                 "agents": { "backend-architect": "openai/gpt-5.6-sol", ... } }
  }
}
```

The `agents` map holds every deviation captured in the audit above.
Agents absent from a platform's `agents` map fall back to that
platform's `model` default.

- [ ] **Step 2: Add platform-inclusion for exclusive agents**

Add a `includePlatforms` (or `platforms`) list on the canonical
`native-mobile-engineer.md` frontmatter so the generator only emits
it to `codex` and `opencode`, never `claude`.

```yaml
---
name: native-mobile-engineer
platforms: [codex, opencode]
---
```

- [ ] **Step 3: Update `.agents/README.md`**

Document the per-agent model override map and the
`includePlatforms` exclusivity convention.

- [ ] **Step 4: Commit**

Do not commit unless the user explicitly asks for one.

## Task 2: Teach the generator per-agent models and exclusivity

**Files:**
- Modify: `generate-agents.sh`
- Test: `tests/sync-local-agents-single-source.test.sh`

- [ ] **Step 1: Surface per-agent model overrides from config**

Extend `read_platforms_config` to also emit each platform's `agents`
override map. In `render_platform_file`, choose the effective model
as `platforms.<p>.agents[slug]` if present, else the platform
`model` default.

- [ ] **Step 2: Respect platform-inclusion metadata**

Parse the optional `platforms:` list from the canonical frontmatter.
If present, only render the platforms listed; if absent, emit to all
platforms (today's behavior). This keeps `native-mobile-engineer`
out of `.claude/agents`.

- [ ] **Step 3: Preserve `mode`/`permission` and other frontmatter**

The current generator already copies unknown frontmatter lines
verbatim (only `model`/`temperature` are injected and `color`
conditionally dropped), so `native-mobile-engineer.md`'s
`mode`/`permission` survive unchanged. Add a test asserting this.

- [ ] **Step 4: Commit**

Do not commit unless the user explicitly asks for one.

## Task 3: Author the canonical `.agents/*.md` for all agents

**Files:**
- Add: `.agents/*.md` (all 19 agents: 18 shared + native-mobile-engineer)
- Test: `tests/sync-local-agents-single-source.test.sh`

- [ ] **Step 1: Copy the 18 shared Claude bodies to `.agents/`**

For each agent, copy `.claude/agents/<slug>.md` body + frontmatter
into `.agents/<slug>.md`, dropping the `model`/`temperature` lines.
Use the **Claude** `description` for all except `backend-engineer`
(keep Claude's short description as canonical).

- [ ] **Step 2: Add `native-mobile-engineer.md`**

Copy the Codex version body + frontmatter (identical to OpenCode),
drop `model`/`temperature`, and add the `platforms: [codex, opencode]`
frontmatter line.

- [ ] **Step 3: Keep `.agents/README.md` and `it-task-master.md`**

The pilot canonical file is already correct; no change needed beyond
the config/REDAME updates in Task 1.

- [ ] **Step 4: Regenerate and verify byte-parity**

Run `bash generate-agents.sh`. For every shared agent, confirm the
generated platform file is **byte-identical** to the current
committed platform file. The only expected diffs: `3d-modeling-artist`
gains `model:` lines it lacked (a behavior change, see audit), and
`backend-engineer` keeps the platform descriptions from the canonical
(which would flatten — see Step 5).

- [ ] **Step 5: Preserve `backend-engineer` description divergence**

Because `backend-engineer`'s long `\n\nExamples:` description exists
only on Codex/OpenCode, add it to `.config/agent-platforms.json`
(per-platform `description` override) OR extend the canonical file to
carry a per-platform `description` key. Verify the generated Codex /
OpenCode outputs keep the long description with the `\n\nExamples:`
block, and Claude keeps the short one.

- [ ] **Step 6: Commit**

Do not commit unless the user explicitly asks for one.

## Task 4: Git-ignore and clean the platform agent dirs

**Files:**
- Modify: `.gitignore`
- Test: `tests/sync-local-agents-single-source.test.sh`

- [ ] **Step 1: Git-ignore the three generated agent dirs**

Replace the pilot's per-file ignores
(`.claude/agents/it-task-master.md`, etc.) with directory ignores:
`.claude/agents/`, `.codex/agents/`, `.config/opencode/agents/`.
Because `native-mobile-engineer` is not generated into Claude, it must
NOT be ignored there (it never exists). Confirm `.codex/agents/` and
`.config/opencode/agents/` are fully ignored.

- [ ] **Step 2: Remove committed platform copies from tracking**

`git rm -r --cached .claude/agents .codex/agents .config/opencode/agents`
so the generated outputs take over. (The generated files will be
re-created by the generator and then ignored.) Do NOT delete
`native-mobile-engineer` from Claude — it does not exist there.

- [ ] **Step 3: Verify the sync flow still works from generated dirs**

Run `bash generate-agents.sh`, then
`./sync-local-agents.sh --dry-run` to confirm the repo→local flow
consumes the generated dirs without error, for all platforms.

- [ ] **Step 4: Commit**

Do not commit unless the user explicitly asks for one.

## Task 5: Update regression tests

**Files:**
- Modify: `tests/sync-local-agents-single-source.test.sh`
- Test: `tests/sync-local-agents-single-source.test.sh`

- [ ] **Step 1: Extend parity assertions to all agents**

For each shared agent, assert the canonical body marker and shared
frontmatter appear in all 3 generated platform files (generalizing
the existing `it-task-master` assertions).

- [ ] **Step 2: Assert per-agent model overrides**

Assert e.g. `backend-architect` generates `model: opus` (Claude),
`openai/gpt-5.6-sol` (OpenCode), `openai/gpt-5.3-codex` (Codex);
and a default model agent still gets the platform default.

- [ ] **Step 3: Assert platform-exclusivity**

`native-mobile-engineer` appears in `.codex/` and `.config/opencode/`
but NOT in `.claude/agents/`.

- [ ] **Step 4: Assert `backend-engineer` description divergence**

Codex/OpenCode keep the long `\n\nExamples:` description; Claude
keeps the short one.

- [ ] **Step 5: Keep `mode`/`permission` assertion for native-mobile-engineer**

Confirm `mode: subagent` and `permission:` survive into the generated
Codex/OpenCode outputs.

- [ ] **Step 6: Commit**

Do not commit unless the user explicitly asks for one.

## Task 6: Update repository documentation

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`

- [ ] **Step 1: Document the canonical agents flow in `README.md`**

Replace the pilot-scoped section with: all agents now source from
`.agents/`, run `generate-agents.sh`, `--target-dir` option, per-agent
model override map, and platform-exclusivity.

- [ ] **Step 2: Align `AGENTS.md` agent-definition guidance**

Update the directory overview to note `.claude/agents/`,
`.codex/agents/`, `.config/opencode/agents/` are generated from
`.agents/` (not hand-edited sources).

- [ ] **Step 3: Commit**

Do not commit unless the user explicitly asks for one.

## Task 7: Final verification

**Files:**
- Verify: `.agents/*.md`, `generate-agents.sh`,
  `.config/agent-platforms.json`, `.gitignore`, tests, docs.

- [ ] **Step 1: Run the single-source test**

Run: `bash tests/sync-local-agents-single-source.test.sh`
Expected: pass.

- [ ] **Step 2: Run the existing sync regression suite**

Run:
```
bash tests/sync-local-agents.test.sh
bash tests/sync-local-agents-config.test.sh
bash tests/sync-local-agents-codex-bootstrap.test.sh
```
Expected: all pass.

- [ ] **Step 3: Byte-parity audit**

After `bash generate-agents.sh`, `git status` should show only
canonical `.agents/`, config, docs, and tests — no stray tracked
platform copies. Regenerate into a temp `--target-dir` and diff the
per-platform outputs against the current committed copies where
behavior is identical to today.

- [ ] **Step 4: Confirm the behavior deltas are intentional**

`3d-modeling-artist` now gains `model:` defaults on Claude/Codex
(previously absent). `backend-engineer` keeps its platform
description divergence. Document these as the only intentional
changes to any generated agent.

- [ ] **Step 5: Commit**

Do not commit unless the user explicitly asks for one.

---

## Follow-ups (tracked separately)

- Optionally single-source skills the same way (26/27/27 trees today).
- Decide whether `3d-modeling-artist`'s newly-added default models are
  desired (it previously had none on Claude/Codex).
- Optionally centralize `backend-engineer`'s long description so the
  `\n\nExamples:` block is canonical rather than per-platform.
