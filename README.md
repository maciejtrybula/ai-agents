# ai-agents

Centralized hub for AI agent definitions and reusable skills across Claude, OpenCode, and Codex. Agents should check the shared skills before doing specialized work and use the relevant ones when they add depth, quality, or verification.

## 🤖 Available Agents

All current agents are shared across **Claude**, **OpenCode**, and **Codex**.

### Shared Agents

| Agent | Primary Purpose |
|-------|-----------------|
| **it-task-master** | Default orchestrator that evaluates tasks and routes them to the most relevant specialist agent. |
| **backend-architect** | DDD, microservices design, and high-level backend strategy. |
| **backend-engineer** | Implementation of services, APIs, and domain logic in Node.js/TS. |
| **frontend-architect** | Web architecture, data flow, and frontend project structure. |
| **frontend-engineer** | UI implementation, component development, and frontend testing. |
| **ux-ui-architect** | Design systems, accessibility, and high-performance mobile-first interfaces. |
| **devops-engineer** | Infrastructure as Code, CI/CD, and cloud orchestration. |
| **developer-tooling-engineer** | Shell tooling, local developer automation, config sync scripts, CLI UX, provider and model catalogs, and Claude/OpenCode/Codex local tooling integration. |
| **e2e-test-engineer** | Playwright-based end-to-end testing and quality assurance. |
| **secops-auditor** | Security architecture, threat analysis, and OWASP compliance. |
| **seo-inspector** | Technical SEO, content architecture, AI search readiness, and discoverability audits. |
| **tax-advisor** | Polish tax law guidance covering PIT, CIT, VAT, compliance, and practical business-tax tradeoffs. |
| **content-writer** | Technical blog strategy and writing with strong hooks, retention techniques, SEO awareness, and conversion-minded execution. |

### Leadership Agents

| Agent | Primary Purpose |
|-------|-----------------|
| **principal-engineer** | Strategic technical leadership, mentoring, and cross-stack reviews. |
| **staff-engineer** | Cross-team coordination and solving complex technical bottlenecks. |
| **team-manager** | People management, project delivery, and organizational health. |

## 🛠️ Specialized Skills

Skills are shared across **Claude**, **OpenCode**, and **Codex**, and agents are expected to check them before starting specialized work.

### Engineering & Architecture

- **code-review**: Standards-based analysis of pull requests and code changes.
- **tech-arch-research**: Deep-dive analysis into technical architectures, risks, and implementation options.
- **documentation**: Technical writing support for clearer guides, references, and structured docs.
- **grill-me**: Structured challenge mode to pressure-test plans, designs, and tradeoffs.
- **fastify**: Best-practice guidance for Fastify application design and implementation.
- **next-js**: Reusable guidance for Next.js App Router architecture, rendering, and deployment-safe behavior.
- **java**: Reusable Java engineering guidance for application architecture, Spring-based services, testing, performance, and production reliability.
- **konva**: Guidance for Konva-powered diagram and spatial editors with strict separation between renderer and shared editor logic.
- **node-js**: Reusable Node.js and TypeScript engineering guidance for reliability and maintainability.
- **react**: Reusable React guidance for component patterns, state boundaries, testing, and performance.
- **react-native**: Reusable React Native and Expo guidance for mobile architecture, performance, and release quality.

### SEO, Discoverability & Measurement

- **seo-inspection**: Full-spectrum audits spanning technical SEO, content quality, and AI search readiness.
- **technical-seo-audit**: Crawlability, rendering, indexation, canonicals, and structured-data validation.
- **seo-content-strategy**: Search-intent mapping, internal linking, and topical authority planning.
- **ai-search-optimization**: LLM retrieval, AI Overview readiness, and citation-friendly content design.
- **seo-measurement-observability**: KPI frameworks, crawl monitoring, and discoverability reporting.

### Content & Editorial

- **technical-blog-writing**: Clear, credible, developer-focused article writing with strong structure and examples.
- **attention-retention-writing**: Hooks, pacing, transitions, and ethical engagement techniques for stronger read-through.
- **blog-editorial-strategy**: Topic framing, audience alignment, internal linking, and content-program planning.

### Tax & Compliance

- **polish-tax-law**: Reusable guidance for Polish PIT, CIT, VAT, OSS/IOSS basics, JDG/B2B issues, compliance, deadlines, and escalation-aware risk framing.

### Commerce Platform Expertise

- **adobe-commerce-expertise**: Guidance for Adobe Commerce architecture, customization, and platform-specific implementation decisions.
- **commercetools-expertise**: Guidance for commercetools composable commerce architecture and integration patterns.
- **medusa-expertise**: Guidance for Medusa-based commerce implementations, extensions, and backend workflows.
- **shopify-hydrogen-expertise**: Guidance for Shopify Hydrogen storefront architecture and Shopify platform integration.
- **shopware-expertise**: Guidance for Shopware architecture, plugin customization, and commerce workflows.

## Locations

- `.claude/agents/` - Claude agent definitions
- `.claude/skills/` - Claude skill definitions
- `.config/opencode/agents/` - OpenCode agent definitions
- `.config/opencode/skills/` - OpenCode skill definitions
- `.codex/agents/` - Codex agent definitions
- `.codex/skills/` - Codex skill definitions

## Local Sync

Use `sync-local-agents.sh` to copy the repository's current agents and skills into your local tool directories.

```bash
./sync-local-agents.sh
./sync-local-agents.sh --dry-run
./sync-local-agents.sh --delete
./sync-local-agents.sh --sync agents
./sync-local-agents.sh --sync config --platform claude
./sync-local-agents.sh --sync skills --platform claude
./sync-local-agents.sh --sync all --platform opencode
./sync-local-agents.sh --interactive
./sync-local-agents.sh --platform claude --claude-model anthropic/sonnet
./sync-local-agents.sh --agent-model claude:backend-engineer:anthropic/opus
./sync-local-agents.sh --agent-model opencode:backend-engineer:openai/gpt-5.3-codex
./sync-local-agents.sh --platform opencode
./sync-local-agents.sh --opencode-model openai/gpt-5.4
./sync-local-agents.sh --platform codex --codex-model github-copilot/gpt-5.2-codex
./sync-local-agents.sh --platform codex --codex-model openai/gpt-5.4
```

- Default behavior syncs both `agents/` and `skills/` for all platforms.
- `--dry-run` previews changes without writing files.
- `--delete` removes local files that no longer exist in this repository.
  - If you sync selected entries only (for example via interactive narrowing), deletion is scoped to those selected directories and does not remove unsynced sibling entries.
- `--platform` limits the sync to `claude`, `opencode`, or `codex`.
- `--sync` provides non-interactive scope selection: `both` (default), `agents`, `skills`, `config`, or `all`.
- `--interactive` starts an interactive picker:
  - prompts for scope (defaults to `both`, or to your `--sync` preset when provided),
  - lists actual available agents/skills for each selected platform,
  - lets you keep current model precedence, choose one catalog model for all selected agents, or pick catalog-backed per-agent overrides,
  - when a platform has multiple catalog providers, asks you to choose the provider first, shows favorite providers first, and then shows only that provider's models,
  - lets you enter a plain-text model filter before choosing from the visible catalog models,
  - when choosing per-agent models, visibly marks catalog entries recommended for that specific agent,
  - when syncing config files, lets you choose per platform between full config sync, MCP-only sync, or skip,
  - when syncing MCP only, lists actual MCP server names from the source config so you can sync all or selected servers,
  - defaults to syncing all entries, with optional narrowing to selected items.
  - requires a TTY; otherwise it exits with a clear error.
- `--claude-model`, `--opencode-model`, and `--codex-model` set per-platform fallback models for synced agent frontmatter.
- `--agent-model platform:agent-slug:provider/model` is repeatable and applies a catalog-validated per-agent override for that platform.

Allowed overrides come from the repo-managed catalog at `.config/model-catalog.json`.

- Claude accepts provider-scoped catalog entries such as `anthropic/sonnet` and writes the matching Claude frontmatter value such as `sonnet`.
- OpenCode and Codex use provider-prefixed values directly, for example `openai/gpt-5.4` or `github-copilot/gpt-5.2-codex`.

Repo-managed config files currently supported by config sync are:

- `.claude/settings.json` -> `~/.claude/settings.json`
- `.config/opencode/opencode.json` -> `~/.config/opencode/opencode.json`
- `.codex/config.toml` -> `~/.codex/config.toml`

Those repo-managed configs currently include MCP entries for:

- `github` across Claude, OpenCode, and Codex via the official `ghcr.io/github/github-mcp-server` Docker image
- `linear` and `blender` across Claude and OpenCode
- `stitch` and `context7` in OpenCode

Codex config sync is merge-based for repo-managed MCP entries, so syncing `.codex/config.toml` preserves unrelated local Codex settings already present in `~/.codex/config.toml`.

### GitHub MCP Setup

GitHub MCP is configured conservatively for read-only inspection with Actions support enabled.

- Transport: local `docker run ... stdio`
- Image: `ghcr.io/github/github-mcp-server`
- Flags: `--read-only --toolsets repos,issues,pull_requests,actions`
- Authentication variable: `GITHUB_PERSONAL_ACCESS_TOKEN`
- Local requirement: Docker installed and available on your PATH

This setup is intended for:

- inspecting pull requests and review state,
- reading issues,
- reading repository metadata,
- inspecting GitHub Actions workflows, runs, jobs, failures, and logs.

The repository does **not** store any GitHub token value. The MCP server forwards `GITHUB_PERSONAL_ACCESS_TOKEN` from your local shell environment when the tool launches Docker.

Example setup:

```bash
export GITHUB_PERSONAL_ACCESS_TOKEN=github_pat_your_token_here
docker pull ghcr.io/github/github-mcp-server
./sync-local-agents.sh --sync config --platform claude
./sync-local-agents.sh --sync config --platform opencode
./sync-local-agents.sh --sync config --platform codex
```

Use a token with the minimum GitHub scopes needed for the repositories and Actions data you want to inspect.

To keep one model per platform, or set readable per-agent overrides without passing flags every time, create the local env files in this repository root, next to `sync-local-agents.sh`.

Do not put them in the synced target directories such as `~/.claude/`, `~/.config/opencode/`, or `~/.codex/`.

```bash
# .claude.local.env
CLAUDE_MODEL=anthropic/sonnet
CLAUDE_AGENT_MODEL_BACKEND_ENGINEER=anthropic/opus

# .opencode.local.env
OPENCODE_MODEL=openai/gpt-5.4
OPENCODE_AGENT_MODEL_BACKEND_ENGINEER=openai/gpt-5.3-codex

# .codex.local.env
CODEX_MODEL=openai/gpt-5.4
CODEX_AGENT_MODEL_DEVELOPER_TOOLING_ENGINEER=openai/gpt-5.3-codex
```

Example files are included:

- `.claude.local.env.example`
- `.opencode.local.env.example`
- `.codex.local.env.example`

Per-agent environment keys use the pattern `<PLATFORM>_AGENT_MODEL_<AGENT_NAME_IN_UPPER_SNAKE_CASE>`.

Precedence for model selection during sync is:

1. Per-agent CLI flag, for example `--agent-model claude:backend-engineer:anthropic/opus`
2. Per-agent environment variable, for example `CLAUDE_AGENT_MODEL_BACKEND_ENGINEER`
3. Per-agent local env file entry, for example in `.claude.local.env`
4. Platform-specific CLI flag, for example `--claude-model`
5. Platform-specific environment variable, for example `CLAUDE_MODEL`
6. Platform-specific local env file, for example `.claude.local.env`
7. The repo's per-agent defaults in that platform's `agents/` directory

### OpenCode API Key Configuration

The `.config/opencode/opencode.json` file contains API key placeholders for security. These are substituted with actual values during sync.

**Placeholder Variables:**

- `${NVIDIA_NIM_API_KEY}` - NVIDIA NIM provider API key (format: `nvapi-...`)
- `${STITCH_API_KEY}` - Google Stitch MCP API key (format: `AQ.xxx...`)
- `${CONTEXT7_API_KEY}` - Context7 MCP API key (format: `ctx7sk-...`)

**During sync, you will be prompted to configure these keys.**

#### Automatic API Key Configuration

Use the `--configure-api-keys` flag to automatically enter API key configuration mode:

```bash
# Configure API keys while syncing opencode
./sync-local-agents.sh --platform opencode --configure-api-keys

# Configure API keys while syncing all platforms
./sync-local-agents.sh --configure-api-keys

# Combine with interactive mode
./sync-local-agents.sh --interactive --configure-api-keys
```

When this flag is set, the script will:
1. Detect placeholder variables in `opencode.json`
2. Prompt for each API key securely (input is hidden)
3. Ask you to confirm each entry
4. Substitute the values into `~/.config/opencode/opencode.json`

This also applies when you choose MCP-only config sync for OpenCode and the selected MCP servers include placeholder-backed keys.

#### Interactive API Key Configuration

Without the flag, you'll be asked interactively when placeholders are detected:

```bash
./sync-local-agents.sh --platform opencode
# Script detects placeholders and asks:
# "opencode.json contains API key placeholders."
# "Configure API keys now? [Y/n]:"
```

Type `Y` to enter configuration mode, or `n` to sync the latest config while preserving existing local API key values anywhere the repo source still contains placeholders. The same preservation behavior applies during MCP-only sync.

#### Getting API Keys

**NVIDIA NIM API Key:**
1. Visit [https://build.nvidia.com/](https://build.nvidia.com/)
2. Sign in with your NVIDIA account
3. Generate an API key from your profile/dashboard
4. Format: `nvapi-xxxxxxxxxxxxxxxx`

**Stitch MCP API Key:**
1. Go to [Google AI Studio](https://ai.google.dev/aistudio)
2. Create or access your project
3. Generate an API key
4. Format: `AQ.xxxxxxxxxxxxx`

**Context7 MCP API Key:**
1. Visit [https://context7.com](https://context7.com)
2. Sign up for an account
3. Generate an API key from your dashboard
4. Format: `ctx7sk-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

#### Security Notes

- API keys are **never stored in this git repository**
- The repository only contains placeholder syntax
- Actual keys are injected into your local config at `~/.config/opencode/opencode.json`
- Input is hidden when typing (security best practice)
- Keys are double-confirmed to prevent typos
- Your local `~/.config/opencode/` directory is outside version control
- GitHub MCP uses `GITHUB_PERSONAL_ACCESS_TOKEN` from your local environment and does not write the token into repo-managed config

## Restart Requirements

- **Claude**: restart Claude after syncing `.claude/settings.json` so the new MCP server is loaded.
- **OpenCode**: quit and restart OpenCode after syncing `opencode.json`; config is not hot-reloaded.
- **Codex**: restart Codex after syncing `~/.codex/config.toml`.
