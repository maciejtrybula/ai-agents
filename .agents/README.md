# Canonical Agent Sources

This directory holds the canonical (single source of truth) definition
for each agent. It is the authoritative copy that all three platform
copies (`.claude/agents/`, `.codex/agents/`, `.config/opencode/agents/`)
are generated from.

## Convention

Each `<slug>.md` in this directory contains only **shared content**:

- Shared YAML frontmatter: `name`, `description`, `color`.
- The full markdown body (the agent prompt), identical across platforms.

**No `model` or `temperature` here.** Those are platform-specific values
injected by `generate-agents.sh` at generation time (see
`.config/agent-platforms.json` for the per-platform defaults).

### Per-agent overrides

Most agents use their platform's default `model` (e.g. Claude `sonnet`,
Codex `openai/gpt-5.4`, OpenCode `openai/gpt-5.6-luna`), but every
agent's effective per-platform `model`/`temperature` is explicit. This
is handled two ways:

1. **Per-agent listing** (`.config/agent-platforms.json` ->
   `platforms.<name>.agents.<slug>`): every canonical agent is listed
   explicitly per platform with its effective `model` and, where the
   platform has a temperature concept, its `temperature`. A
   `description` appears in that listing only where it diverges from the
   canonical `.agents/*.md` description — e.g. `backend-architect`
   (Claude `opus`). No agent currently carries a `description` override,
   so every platform uses the canonical description. Claude is listed
   without `temperature`, as it has no temperature concept.
2. **Platform-inclusion list** (canonical `platforms:` frontmatter): for
   agents that exist on only some platforms (e.g. a `platforms:
   [codex, opencode]` list would emit the agent to Codex and OpenCode but
   not Claude). The generator only emits these to the listed platforms;
   an absent `platforms:` line means "all platforms". Most agents are
   shared across all three platforms and declare no `platforms:` line.

## Generated Outputs Are Git-Ignored

The three platform directories (`.claude/agents/`, `.codex/agents/`,
`.config/opencode/agents/`) are **generated outputs** and are listed in
`.gitignore`. Do not edit those files by hand — edit the canonical file
here and regenerate. The existing `sync-local-agents.sh` flow consumes
the generated platform dirs and rsyncs them to your local tool
directories (`$HOME/.claude`, `$HOME/.codex`, `$HOME/.config/opencode`),
applying model overrides as before.

## Authoring Flow

1. **Edit** the canonical file in `.agents/`.
2. **Regenerate** the three platform outputs:
   ```bash
   ./generate-agents.sh
   ```
3. **Sync** to your local tool directories (with model overrides applied):
   ```bash
   ./sync-local-agents.sh
   ```
   Or **drop the generated files directly into a project**:
   ```bash
   ./generate-agents.sh --target-dir /path/to/project
   ```
   which writes them under
   `/path/to/project/.claude/agents`,
   `/path/to/project/.codex/agents`,
   `/path/to/project/.config/opencode/agents`.
