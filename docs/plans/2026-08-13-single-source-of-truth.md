# Plan: Single Source of Truth for Agents & Skills (North-Star Optimization)

- **Date:** 2026-08-13
- **Status:** Draft — pending approval
- **Owner:** Task Master (delegating implementation to `developer-tooling-engineer`)
- **Scope:** `.claude/`, `.config/opencode/`, `.codex/` agent + skill definitions and the `sync-local-agents.sh` pipeline

---

## 1. Problem statement

The repo triplicates ~20 agents and ~28 skills across three trees
(`.claude/`, `.config/opencode/`, `.codex/`). The **bodies** are byte-identical
across trees (verified for `backend-engineer.md` and `it-task-master.md`); only
the **frontmatter** differs per platform:

| field | claude | opencode | codex |
|---|---|---|---|
| `model` | `sonnet` | `openai/gpt-5.6-luna` | `openai/gpt-5.4` |
| `color` | `orange` | *(absent)* | `orange` |
| `temperature` | *(absent)* | `0.4` | `0.4` |
| `description` | short | long + `\n\nExamples:` | long + `\n\nExamples:` |

The sync script only rewrites `model` at sync time (a perl one-liner, line 882).
`description`, `temperature`, and `color` are maintained **by hand in all three
copies** — the true triplication pain and the main drift-by-hand failure mode.
There is currently no drift test (being added separately as O2).

## 2. Goal / acceptance criteria

- One **canonical body** per agent and per skill.
- One machine-readable **manifest** holding per-platform frontmatter
  (`description`, `temperature`, `color`, `defaultModel`).
- The two non-canonical trees become **generated artifacts**, not hand-edited
  sources.
- Two new subcommands:
  - `--generate <platform>` — render variants from canonical body + manifest + catalog.
  - `--verify <platform>` — regenerate to a temp dir and diff (zero-dependency drift check).
- **AC:** editing a body/description in one canonical place and running
  `--generate` reproduces all three trees; `--verify` returns non-zero on drift.
- **AC:** existing `sync` (repo → `$HOME`) and model-override behavior remain unchanged.

## 3. Current infrastructure we reuse (verified)

- Canonical body source: `.claude/agents/*.md`, `.claude/skills/*/SKILL.md`
  (bodies identical across trees — make Claude the canonical tree).
- `iterate_agent_markdown_files` (line 820) — iterates agent md files.
- Frontmatter model rewrite (line 882) — the existing perl substitution.
- Model catalog helpers (lines 191–448) — resolve `model`/provider/recommended
  values from `.config/model-catalog.json`.
- Per-platform settings merge for `$HOME` — existing `sync`/`substitute_api_keys`
  paths, which remain.

## 4. Design

### 4.1 Canonical structure
- Canonical body stays at `.claude/agents/<name>.md` (frontmatter reduced to
  a minimal canonical set: `name`, `color` only — or even less, since `name`
  equals the filename). Everything else is data-driven.
- New `agents/manifest.json` next to `model-catalog.json`:
  ```jsonc
  {
    "backend-engineer": {
      "claude":   { "description": "...", "temperature": null, "color": "green" },
      "opencode": { "description": "...", "temperature": 0.4, "color": null },
      "codex":    { "description": "...", "temperature": 0.4, "color": "green" }
    }
    // ... one entry per agent
  }
  ```
  Default `model`/target values come from `model-catalog.json` (unchanged).

### 4.2 Renderer
- A small **Node** renderer (~150 lines), since `node` is already a hard
  dependency for catalog ops (`require_node`, line 180).
- Inputs: canonical body + `manifest.json` + resolved model from catalog.
- Output: per-platform `.md` with correct frontmatter (description / model /
  temperature / color) + the identical body.
- Written as data-driven templating (not bash string assembly), so the current
  inline `\n\nExamples:` blocks in opencode/codex descriptions become manifest
  data rather than hand-copied text.

### 4.3 Wiring into the CLI
- `--generate <platform>` and `--verify <platform>` subcommands, reusing the
  existing arg-parsing and entry-selection helpers.
- `--verify`: render to a temp dir and `diff -r` against the in-place tree;
  exit non-zero on any difference (never mutates the tree).

### 4.4 Migration path (avoid a big-bang)
1. Add `manifest.json` by extracting the per-platform frontmatter that already
   exists across the three trees today (data already present — just centralized).
2. Add Node renderer + `--generate`/`--verify` behind a default-off flag.
3. Land O2 parity test (already in progress) as the safety net.
4. Run `--verify` on the current tree → expect clean (no drift) → proves the
   renderer reproduces today's artifacts.
5. Flip canonical tree to `.claude/`, mark opencode/codex trees generated,
   gate edits via `--verify` in CI/pre-commit.
6. Optionally port `apply_model_override` (personal/runtime overrides) to sit
   on top of generated defaults, preserving `resolve_agent_model_override`
   precedence (line 595) exactly.

## 5. Risks & mitigations

- **Precedence semantics** (O3-adjacent model resolution) must be preserved —
  generator only sets defaults; the existing override resolution order stays.
  *Mitigation:* `--verify` diff guards behavior; unit-test the precedence path.
- **Description templating differences** (long vs short, `\n\nExamples:`) are
  non-trivial to express as data. *Mitigation:* capture exact current strings
  into manifest first, then verify byte-equal output before any cleanup.
- **Skills** have a nested `SKILL.md` (+ `rules/*.md`) structure — handle in
  the same generator using a per-skill manifest stanza.
- **Generated-artifact concern:** files under opencode/codex become build
  output; devs must not hand-edit them. *Mitigation:* a comment header plus
  `--verify` in pre-commit/CI (recommend a CI runner as a subsequent task).

## 6. Effort & rollout

- **Effort:** M–L overall. Near-term slice (manifest + renderer for agents only)
  is M.
- **Rollout:** default-off flag → verify-clean on current tree → flip canonical
  → pre-commit/CI gate (CI itself is a separate follow-up, pending devops input).

## 7. Out of scope (this plan)

- O1 (injectable rsync) and O2 (parity test) — **already being implemented** as
  quick wins; this plan depends on O2 landing as the safety net.
- O3 (batch node spawns), O4 (transactional sync), O6 (module decomposition),
  O7 (JSON5 instead of `vm` eval), O8 (tighten frontmatter regex), B1 — tracked
  separately.
