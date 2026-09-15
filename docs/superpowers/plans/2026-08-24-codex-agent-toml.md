# Codex Agent TOML Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate valid native Codex custom-agent TOML files from the canonical Markdown agent sources.

**Architecture:** Keep `.agents/*.md` as the only authored source. Extend the existing platform renderer so Claude and OpenCode retain Markdown while Codex receives `name`, `description`, `model`, and `developer_instructions` TOML. Update source discovery and parity checks for the mixed output formats.

**Tech Stack:** Bash, awk, sed, Node.js JSON parsing, TOML syntax, existing shell regression tests.

---

### Task 1: Add failing Codex format assertions

**Files:**
- Modify: `tests/sync-local-agents-single-source.test.sh`

- [ ] **Step 1: Replace Codex Markdown assertions with TOML assertions**

Assert that generation creates `.codex/agents/it-task-master.toml`, that the old `.md` file is absent, and that the TOML contains:

```text
name = "it-task-master"
description = "Use this agent as the primary orchestrator for multi-step work. It decomposes the user's request, delegates to the best specialized agents, coordinates dependencies, integrates results, and verifies completion."
model = "openai/gpt-5.4"
developer_instructions = """
```

Also assert it contains the body marker and does not contain `temperature`, `color`, `mode`, or `permission` TOML keys. Apply the same extension and required-field assertions to custom `--target-dir` output.

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```bash
bash tests/sync-local-agents-single-source.test.sh
```

Expected: failure because the current generator writes `.codex/agents/*.md`.

### Task 2: Render native Codex TOML

**Files:**
- Modify: `generate-agents.sh`
- Modify: `.config/agent-platforms.json`

- [ ] **Step 1: Remove unsupported Codex temperature configuration**

Remove the Codex platform `temperature` default and every Codex per-agent `temperature` entry from `.config/agent-platforms.json`. Keep model overrides unchanged. Do not invent a `model_reasoning_effort` mapping from numeric temperatures.

- [ ] **Step 2: Add a TOML scalar quoting helper**

In `generate-agents.sh`, use a small Node.js helper or existing shell/Node boundary to encode arbitrary strings as valid TOML basic strings. The helper must escape backslashes, quotes, carriage returns, and newlines. Do not add a dependency.

- [ ] **Step 3: Add a Codex renderer**

Branch in `render_platform_file` for `platform == codex`:

```toml
name = "<canonical name>"
description = "<resolved description>"
model = "<resolved model>"
developer_instructions = """
<canonical body>
"""
```

Use the canonical `name` and resolved description, including any configured description override. Omit YAML-only and OpenCode-only fields: `color`, `mode`, `permission`, `platforms`, and `temperature`. Write the Codex output as `$out_dir/$slug.toml`.

- [ ] **Step 4: Keep Markdown rendering unchanged for Claude and OpenCode**

Ensure the existing frontmatter path still writes `$slug.md`, retains platform-specific color behavior, and injects only the configured model and temperature fields applicable to those platforms.

- [ ] **Step 5: Run the focused generation test**

Run:

```bash
bash tests/sync-local-agents-single-source.test.sh
```

Expected: the Codex-format assertions pass; remaining failures identify sync/parity assumptions to update in later tasks.

### Task 3: Make sync and parity format-aware

**Files:**
- Modify: `sync-local-agents.sh`
- Modify: `tests/sync-local-agents-parity.test.sh`
- Modify: `tests/sync-local-agents.test.sh`

- [ ] **Step 1: Update Codex source discovery**

Make agent-file iteration accept `.toml` for Codex and `.md` for Claude/OpenCode. Derive the agent slug with the matching extension instead of assuming `.md`. Update model override lookup and selected-agent validation so Codex checks `$slug.toml`.

- [ ] **Step 2: Preserve Codex TOML during sync**

Ensure sync copies the generated Codex TOML files to the target without applying Markdown frontmatter rewriting. Model overrides must update the TOML `model = "..."` field only, preserving `developer_instructions` and all other supported fields.

- [ ] **Step 3: Compare normalized instruction bodies in parity tests**

Keep Claude/OpenCode Markdown body extraction. Add a Codex extractor that reads the content between `developer_instructions = """` and the closing `"""`. Compare that extracted body against the Markdown body while using the corresponding `.toml` Codex path.

- [ ] **Step 4: Update model-output expectations**

Change only Codex path suffixes in `tests/sync-local-agents.test.sh` from `.md` to `.toml`. Keep the expected model values unchanged.

- [ ] **Step 5: Run focused tests**

Run:

```bash
bash tests/sync-local-agents-single-source.test.sh
bash tests/sync-local-agents-parity.test.sh
bash tests/sync-local-agents.test.sh
```

Expected: all three pass.

### Task 4: Update repository documentation and verify all checks

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`

- [ ] **Step 1: Document the native Codex format**

State that canonical sources remain Markdown, Claude/OpenCode generated agents remain Markdown, and Codex generated agents are TOML files using `name`, `description`, `model`, and `developer_instructions`. Explicitly state that Codex temperature is not emitted because it is not a supported custom-agent field.

- [ ] **Step 2: Run the complete verification set**

Run:

```bash
bash tests/sync-local-agents-single-source.test.sh
bash tests/sync-local-agents-parity.test.sh
bash tests/sync-local-agents.test.sh
bash tests/sync-local-agents-config.test.sh
markdownlint "**/*.md"
rg --files .claude/agents | sort
```

Expected: shell tests pass, Markdown lint reports no errors, and Claude generated agent paths remain present.

- [ ] **Step 3: Inspect the final diff**

Run:

```bash
git status --short
git diff --check
git diff -- generate-agents.sh sync-local-agents.sh .config/agent-platforms.json tests README.md AGENTS.md
```

Confirm no generated ignored files or unrelated user changes are staged.
