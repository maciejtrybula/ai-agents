# ai-agents

Centralized hub for AI agent definitions and reusable skills across
Claude, OpenCode, Codex, and OMP (Oh My Pi). Agents should check the shared
skills before doing specialized work and use the relevant ones when they add
depth, quality, or verification.

## 🤖 Available Agents

All current agents are shared across **Claude**, **OpenCode**, **Codex**, and
**OMP**.

### Shared Agents

- **it-task-master**: Default orchestrator and end-to-end SDLC owner;
  coordinates intake, approved plans, specialist implementation,
  verification, independent review, and a green pull/merge request.
- **backend-architect**: DDD, microservices design, and high-level
  backend strategy.
- **backend-engineer**: Implementation of services, APIs, and domain
  logic in Node.js/TS.
- **frontend-architect**: Web architecture, data flow, and frontend
  project structure.
- **frontend-engineer**: UI implementation, component development, and
  frontend testing.
- **ux-ui-architect**: Design systems, accessibility, and
  high-performance mobile-first interfaces.
- **devops-engineer**: Infrastructure as Code, CI/CD, and cloud
  orchestration.
- **developer-tooling-engineer**: Shell tooling, local developer
  automation, config sync scripts, CLI UX, provider and model catalogs,
  and Claude/OpenCode/Codex/OMP local tooling integration.
- **e2e-test-engineer**: Playwright-based end-to-end testing and
  quality assurance.
- **secops-auditor**: Security architecture, threat analysis, and
  OWASP compliance.
- **seo-inspector**: Technical SEO, content architecture, AI search
  readiness, and discoverability audits.
- **tax-advisor**: Polish tax law guidance covering PIT, CIT, VAT,
  compliance, and practical business-tax tradeoffs.
- **content-writer**: Technical blog strategy and writing with strong
  hooks, retention techniques, SEO awareness, and conversion-minded
  execution.

### Leadership Agents

- **principal-engineer**: Strategic technical leadership, mentoring,
  and cross-stack reviews.
- **staff-engineer**: Cross-team coordination and solving complex
  technical bottlenecks.
- **team-manager**: People management, project delivery, and
  organizational health.

### Running a workflow

Start the existing `it-task-master` agent and provide the requested outcome
or an explicitly ready tracker item. It uses the tracker, design, code-host,
CI, and agent-runtime tools available in the active host; Linear/Jira,
GitHub/GitLab (including self-managed GitLab), and Claude Design/Figma/Stitch
are provider choices, not required dependencies.

Every implementation plan needs human approval before code changes. The
initial delivery boundary is a green pull/merge request; a human reviews and
merges it. Missing integrations block only the operation that needs them.
This is an agent workflow, not a background webhook service.

The shared workflow defines provider-neutral contracts; it does not bundle
every provider connector. This repo's GitHub MCP is read-only, and Jira,
GitLab, Figma, and Claude Design connectors are not configured here. Supply
the selected host integration and required permissions; unsupported writes
block at that stage.

Any later reduction in approval requires a human-approved policy change;
risk-based approval is the only future relaxation considered.

Repository checks are declared in `sdlc.json` and run with:

```bash
python3 scripts/sdlc.py doctor
python3 scripts/sdlc.py verify
python3 scripts/sdlc.py commit-range origin/main
```

`verify` runs configured argument-vector commands without shell expansion.
The commit-range check enforces Conventional Commit subjects on PR commits.

These commands validate this repository's local gates. A target project must
provide its own configured executor or use its documented commands; the hub's
CLI is not installed into other repositories. Configure the selected code host
to require successful CI and human review; the workflow file alone cannot
enforce branch protection.

Markdown lint currently covers `README.md` and the shared SDLC skill. Canonical
agent sources have a repository-wide Markdown lint baseline, including
`AGENTS.md`; expand the required scope after that baseline is cleaned.

## 🛠️ Specialized Skills

Skills are shared across **Claude**, **OpenCode**, and **Codex**, and
agents are expected to check them before starting specialized work.

- **sdlc-workflow**: Provider-neutral task intake, design handoff,
  implementation-plan approval, quality gates, independent review, and
  green change-request delivery.

### Engineering & Architecture

- **code-review**: Standards-based analysis of pull requests and code
  changes.
- **tech-arch-research**: Deep-dive analysis into technical
  architectures, risks, and implementation options.
- **documentation**: Technical writing support for clearer guides,
  references, and structured docs.
- **grill-me**: Structured challenge mode to pressure-test plans,
  designs, and tradeoffs.
- **fastify**: Best-practice guidance for Fastify application design and
  implementation.
- **next-js**: Reusable guidance for Next.js App Router architecture,
  rendering, and deployment-safe behavior.
- **java**: Reusable Java engineering guidance for application
  architecture, Spring-based services, testing, performance, and
  production reliability.
- **konva**: Guidance for Konva-powered diagram and spatial editors with
  strict separation between renderer and shared editor logic.
- **node-js**: Reusable Node.js and TypeScript engineering guidance for
  reliability and maintainability.
- **react**: Reusable React guidance for component patterns, state
  boundaries, testing, and performance.
- **react-native**: Reusable React Native and Expo guidance for mobile
  architecture, performance, and release quality.

### SEO, Discoverability & Measurement

- **seo-inspection**: Full-spectrum audits spanning technical SEO,
  content quality, and AI search readiness.
- **technical-seo-audit**: Crawlability, rendering, indexation,
  canonicals, and structured-data validation.
- **seo-content-strategy**: Search-intent mapping, internal linking,
  and topical authority planning.
- **ai-search-optimization**: LLM retrieval, AI Overview readiness, and
  citation-friendly content design.
- **seo-measurement-observability**: KPI frameworks, crawl monitoring,
  and discoverability reporting.

### Content & Editorial

- **technical-blog-writing**: Clear, credible, developer-focused
  article writing with strong structure and examples.
- **attention-retention-writing**: Hooks, pacing, transitions, and
  ethical engagement techniques for stronger read-through.
- **blog-editorial-strategy**: Topic framing, audience alignment,
  internal linking, and content-program planning.

### Tax & Compliance

- **polish-tax-law**: Reusable guidance for Polish PIT, CIT, VAT,
  OSS/IOSS basics, JDG/B2B issues, compliance, deadlines, and
  escalation-aware risk framing.

### Knowledge Management & Second Brain

A workflow set (from
[superhero-tech/super-brain](https://github.com/superhero-tech/super-brain))
for running a personal knowledge vault. These assume an Obsidian-style
wiki layout (`2-Inbox/`, `4-Knowledge/`, `5-Raw/`, `9-Outputs/`,
`8-System/`) and are best used inside a vault that follows it.

- **ingest**: Compiles a source from `2-Inbox/` into the wiki across
  every page it touches, then archives it.
- **query**: Answers from the compiled wiki with citations, saves the
  answer, and flags what the vault is missing.
- **lint**: Health check over the wiki (contradictions, orphans, stale
  data) written up as a ranked report.
- **feynman**: Explains a wiki page in plain language and names where
  the explanation went thin.
- **project-start**: Opens a project via an interview with pushback per
  section.
- **project-update**: Logs what happened and refreshes the project
  index.
- **second-brain-setup**: Writes the profile into `8-System/about.md`.
- **youtube**: Converts a video to a source note via `yt-dlp` or a
  pasted transcript, then hands off to `ingest`.

### Commerce Platform Expertise

- **adobe-commerce-expertise**: Guidance for Adobe Commerce
  architecture, customization, and platform-specific implementation
  decisions.
- **commercetools-expertise**: Guidance for commercetools composable
  commerce architecture and integration patterns.
- **medusa-expertise**: Guidance for Medusa-based commerce
  implementations, extensions, and backend workflows.
- **shopify-hydrogen-expertise**: Guidance for Shopify Hydrogen
  storefront architecture and Shopify platform integration.
- **shopware-expertise**: Guidance for Shopware architecture, plugin
  customization, and commerce workflows.

## Locations

- `.agents/` - **Canonical agent sources** (single source of truth):
  Markdown files with required canonical `name` and `description` frontmatter
  fields. Optional shared metadata such as `color` and platform-specific
  metadata such as `mode`, `permissions`, and `platforms` may also be present,
  followed by the full body. Per-platform `model` and supported
  platform-specific fields are injected at generation time. Codex generation
  requires the canonical `name` and `description` values.
- `.claude/agents/` - Claude agent definitions (generated Markdown,
  git-ignored)
- `.claude/skills/` - Claude skill definitions
- `.config/opencode/agents/` - OpenCode agent definitions (generated
  Markdown, git-ignored)
- `.config/opencode/skills/` - OpenCode skill definitions
- `.codex/agents/` - Codex agent definitions (generated native TOML with
  `name`, `description`, `model`, and `developer_instructions`, git-ignored)
- `.codex/skills/` - Codex skill definitions
- `.omp/agent/agents/` - OMP user-level agents (generated Markdown,
  git-ignored)
- OMP skills use the shared Agent Skills sources in `.claude/skills/` and
  sync to `$HOME/.omp/agent/skills/` or project `.omp/skills/`.

### Authoring Agents

The `.claude/agents/`, `.config/opencode/agents/`, `.codex/agents/`, and
`.omp/agent/agents/` directories are **generated outputs**, git-ignored and
created by `generate-agents.sh` from the canonical Markdown sources in
`.agents/`. Claude, OpenCode, and OMP outputs remain Markdown; Codex outputs
are native TOML custom-agent files using `name`, `description`, `model`, and
`developer_instructions`. Codex `temperature` is not emitted because it is
not a supported custom-agent field. Do not hand-edit generated files. To
author or update a shared agent:

1. **Edit** the canonical file in `.agents/`.
2. **Regenerate** the four platform outputs:

   ```bash
   ./generate-agents.sh
   ```

3. **Sync** to your local tool directories (model overrides applied):

   ```bash
   ./sync-local-agents.sh
   ```

Per-platform default `model` values and supported output fields are wired
through `.config/agent-platforms.json`; the existing model-override
machinery in `sync-local-agents.sh` applies on top of those defaults at sync
time. OpenCode emits per-agent temperature under the native V2
`request.body`; Claude, Codex, and OMP do not emit it.

**.config/agent-platforms.json** lists every canonical agent explicitly
per platform (`platforms.<name>.agents.<slug>`), each with its effective
`model`, with `temperature` only for platforms that support it (currently
OpenCode), and an optional `description` that appears only where it diverges
from the canonical `.agents/*.md` description. For example,
`backend-architect` → `opus` on Claude, `openai/gpt-6-sol` on
OpenCode, `openai/gpt-6-luna` on Codex, and `openai/gpt-6-luna` on OMP.
No agent currently carries a `description` override, so every platform
uses the canonical `.agents/*.md` description.

**Platform-exclusive agents** are handled with a `platforms:` list in
the canonical frontmatter. For example, declaring
`platforms: [codex, opencode]` makes the generator emit that agent only
to Codex and OpenCode and never to Claude or OMP. An agent with no `platforms:`
line is emitted to all four platforms. Most agents are shared across all
platforms; only those that genuinely need platform exclusivity declare a
`platforms:` list.

`generate-agents.sh` also supports `--target-dir <path>` to write the
generated platform files directly into an arbitrary destination, e.g. a
project checkout:

```bash
./generate-agents.sh --target-dir /path/to/project
```

This writes them under `/path/to/project/.claude/agents`,
`/path/to/project/.codex/agents`, `/path/to/project/.opencode/agents`, and
`/path/to/project/.omp/agents`. For OpenCode, the custom destination uses
`.opencode/`; OMP uses `.omp/agents` for project agents and
`$HOME/.omp/agent/agents` for user-level agents.

`sync-local-agents.sh` also supports `--target-dir <path>` to direct the
full sync (agents, skills, and config) into an arbitrary destination
root, applying model overrides exactly as it does for the default
`$HOME` folders:

```bash
./sync-local-agents.sh --target-dir /path/to/project
```

When set, files are written under `/path/to/project/.claude`,
`/path/to/project/.opencode`, `/path/to/project/.codex`, and
`/path/to/project/.omp` instead of `$HOME`. OpenCode uses `.opencode/`
for project config; OMP writes agents and skills to `.omp/agents` and
`.omp/skills`. OMP user-level agents and skills go under
`$HOME/.omp/agent/` (or the active `PI_CODING_AGENT_DIR` / named profile).
In `--interactive` mode you can also choose the destination after the
scope prompt: `user-local` (default) or `custom`.

## Local Sync

Use `sync-local-agents.sh` to copy the repository's current agents and
skills into your local tool directories.

```bash
./sync-local-agents.sh
./sync-local-agents.sh --target-dir /tmp/project-root
./sync-local-agents.sh --dry-run
./sync-local-agents.sh --delete
./sync-local-agents.sh --sync agents
./sync-local-agents.sh --sync config --platform claude
./sync-local-agents.sh --sync skills --platform claude
./sync-local-agents.sh --sync all --platform opencode
./sync-local-agents.sh --interactive
./sync-local-agents.sh --platform claude --claude-model anthropic/sonnet
./sync-local-agents.sh --agent-model claude:backend-architect:anthropic/opus
./sync-local-agents.sh --agent-model opencode:backend-engineer:openai/gpt-6-luna
./sync-local-agents.sh --platform opencode
./sync-local-agents.sh --opencode-model openai/gpt-6-luna
./sync-local-agents.sh --platform claude --use-recommended-models
./sync-local-agents.sh --platform opencode --use-recommended-models
./sync-local-agents.sh --platform codex --use-recommended-fallback-models
./sync-local-agents.sh --platform opencode \
  --use-recommended-models --recommended-provider openai
./sync-local-agents.sh --platform codex \
  --use-recommended-fallback-models --recommended-provider openai
./sync-local-agents.sh --platform codex --codex-model github-copilot/gpt-5.2-codex
./sync-local-agents.sh --platform codex --codex-model openai/gpt-6-luna
```

- Default behavior syncs both `agents/` and `skills/` for all four
  platforms.
- `--dry-run` previews changes without writing files.
- `--delete` removes local files that no longer exist in this
  repository.
  If you sync selected entries only, for example via interactive
  narrowing, deletion is scoped to those selected directories and does
  not remove unsynced sibling entries.
- `--platform` limits the sync to `claude`, `opencode`, `codex`, or `omp`.
- `--sync` provides non-interactive scope selection: `both` (default),
  `agents`, `skills`, `config`, or `all`.
- `--interactive` starts an interactive picker:
  - prompts for scope, defaulting to `both` or to your `--sync` preset
    when provided
  - lists actual available agents and skills for each selected platform
  - lets you keep current model precedence, choose one catalog model
    for all selected agents, or pick catalog-backed per-agent overrides
  - when a platform has multiple catalog providers, asks you to choose
    the provider first, shows favorite providers first, and then shows
    only that provider's models
  - when recommended-model mode is active on a platform with multiple
    recommended providers, asks which provider's recommendations to
    apply and defaults to the platform's configured recommended
    provider
  - lets you enter a plain-text model filter before choosing from the
    visible catalog models
  - when choosing per-agent models, visibly marks catalog entries
    recommended for that specific agent using the active recommended
    provider for that platform
  - when syncing config files, lets you choose per platform between
    full config sync, MCP-only sync, or skip
  - when syncing MCP only, lists actual MCP server names from the
    source config so you can sync all or selected servers
  - defaults to syncing all entries, with optional narrowing to
    selected items
  - requires a TTY; otherwise it exits with a clear error
- `--claude-model`, `--opencode-model`, and `--omp-model` set platform
  fallback models for agent frontmatter; `--codex-model` sets the Codex
  TOML `model =` field.
- `--agent-model platform:agent-slug:provider/model` is repeatable and
  applies a catalog-validated per-agent override for that platform.
- `--use-recommended-models` requires explicit `--platform`, supports
  `claude`, `opencode`, `codex`, and `omp`, and expands the first entry from
  `platforms.<platform>.recommendedAgents.<provider>` into per-agent
  overrides for the selected agents.
- `--use-recommended-fallback-models` requires explicit `--platform`,
  supports `claude`, `opencode`, `codex`, and `omp`, and expands the second
  entry from `platforms.<platform>.recommendedAgents.<provider>` into
  per-agent overrides for the selected agents. It fails if any selected
  agent does not have a second recommendation.
- `--recommended-provider <provider>` only applies with
  recommended-model modes and selects which provider-specific
  recommendation set to use. Current defaults stay unchanged: `claude`
  uses `anthropic`, `opencode` uses `github-copilot`, `codex` uses
  `github-copilot`, and `omp` uses `openai` when this flag is omitted.

Allowed overrides come from the repo-managed catalog at
`.config/model-catalog.json`.

- Claude accepts provider-scoped catalog entries such as
  `anthropic/sonnet` and writes the matching Claude frontmatter value
  such as `sonnet`.
- OpenCode and Codex use provider-prefixed values directly, for example
  `openai/gpt-6-luna` or `github-copilot/gpt-5.2-codex`.

Repo-managed config files currently supported by config sync are:

- `.claude/settings.json` -> `~/.claude/settings.json`
- `.config/opencode/opencode.json` ->
  `~/.config/opencode/opencode.json`
- `.codex/config.toml` -> `~/.codex/config.toml`

Repo-managed OpenCode support files currently synced with config are:

- `.config/opencode/plugins/caveman/*` ->
  `~/.config/opencode/plugins/caveman/*`

Repo-managed shared permission defaults live in
`.config/shared-permissions.json` and are projected into Claude,
OpenCode, and Codex during config sync.

Those repo-managed configs currently include MCP entries for:

- `github` across Claude, OpenCode, Codex, and OMP via the official
  `ghcr.io/github/github-mcp-server` Docker image
- `playwright` across Claude, OpenCode, Codex, and OMP via
  `npx --yes @playwright/mcp@0.0.80 --headless --isolated`
- `linear` and `blender` across Claude, OpenCode, and OMP
- `stitch` and `context7` across OpenCode and OMP
- `filesystem` across Claude, OpenCode, Codex, and OMP

OMP uses native project config in `.omp/mcp.json`; its MCP servers are not
installed by `sync-local-agents.sh`. `.omp/config.yml` disables OMP's native
browser tool so the external Playwright MCP server is discoverable, and
explicitly denies Playwright's unsafe code tool.

Config sync ownership differs by platform:

- Claude full config sync is merge-based for repo-managed top-level
  keys: `model`, `agent`, `permissions`, `mcpServers`, `statusLine`,
  `enabledPlugins`, `extraKnownMarketplaces`, `tui`, and
  `agentPushNotifEnabled`. Local-only keys such as `_disabledHooks`
  remain preserved in `~/.claude/settings.json`.
- OpenCode full config sync is merge-based for repo-managed top-level
  keys, syncs the vendored caveman plugin payload under
  `~/.config/opencode/plugins/caveman/`, and preserves existing local
  secret values anywhere the repo source still uses placeholders.
- Codex config sync is merge-based for repo-managed MCP entries and
  repo-managed permission profiles, so syncing `.codex/config.toml`
  preserves unrelated local Codex settings already present in
  `~/.codex/config.toml`. Full Codex config sync also makes a
  best-effort bootstrap attempt for `ponytail` via the native Codex
  plugin commands and for `caveman` via `npx skills add`.

- OMP reads its project-native `.omp/mcp.json` and `.omp/config.yml`
  directly; `sync-local-agents.sh` does not manage these files.

### GitHub MCP Setup

GitHub MCP is configured conservatively for read-only inspection with
Actions support enabled.

- Transport: local `docker run ... stdio`
- Image: `ghcr.io/github/github-mcp-server`
- Flags: `--read-only --toolsets repos,issues,pull_requests,actions`
- Authentication variable: `GITHUB_PERSONAL_ACCESS_TOKEN`
- Local requirement: Docker installed and available on your PATH

This setup is intended for:

- inspecting pull requests and review state
- reading issues
- reading repository metadata
- inspecting GitHub Actions workflows, runs, jobs, failures, and logs

The repository does **not** store any GitHub token value. The MCP
server forwards `GITHUB_PERSONAL_ACCESS_TOKEN` from your local shell
environment when the tool launches Docker.

Example setup:

```bash
export GITHUB_PERSONAL_ACCESS_TOKEN=github_pat_your_token_here
docker pull ghcr.io/github/github-mcp-server
./sync-local-agents.sh --sync config --platform claude
./sync-local-agents.sh --sync config --platform opencode
./sync-local-agents.sh --sync config --platform codex
```

Use a token with the minimum GitHub scopes needed for the repositories
and Actions data you want to inspect.

### Playwright MCP Setup

Playwright MCP is configured for headless, isolated local browser
automation.

- Transport: local `npx --yes @playwright/mcp@0.0.80 --headless --isolated`
- Local requirement: Node.js and `npx` available on your PATH
- No repo-managed API key is required for this baseline setup

The managed Claude, OpenCode, Codex, and OMP configs deny
`browser_run_code_unsafe`, which Playwright documents as arbitrary code
execution in the MCP server process. OMP also disables its built-in browser
tool (`browser.enabled: false`) because OMP otherwise filters external browser
MCP servers from discovery.
That means OMP uses the configured Playwright MCP instead of its built-in
browser tool.

If you only want to sync the repo-managed Playwright MCP entry for a
single platform, use interactive config sync and choose `MCP only`,
then select `playwright` from the MCP server list.

Example:

```bash
./sync-local-agents.sh --interactive --sync config --platform claude
./sync-local-agents.sh --interactive --sync config --platform opencode
./sync-local-agents.sh --interactive --sync config --platform codex
```

To keep one model per platform, or set readable per-agent overrides
without passing flags every time, create the local env files in this
repository root, next to `sync-local-agents.sh`.

Do not put them in synced target directories such as `~/.claude/`,
`~/.config/opencode/`, `~/.codex/`, or `~/.omp/agent/`.

```bash
# .claude.local.env
CLAUDE_MODEL=anthropic/sonnet
CLAUDE_AGENT_MODEL_BACKEND_ARCHITECT=anthropic/opus
CLAUDE_STATUSLINE_COMMAND_PATH=~/.claude/statusline-command.sh

# .opencode.local.env
OPENCODE_MODEL=openai/gpt-6-luna
OPENCODE_AGENT_MODEL_BACKEND_ENGINEER=openai/gpt-6-luna

# .codex.local.env
CODEX_MODEL=openai/gpt-6-luna
CODEX_AGENT_MODEL_DEVELOPER_TOOLING_ENGINEER=openai/gpt-6-luna

# .omp.local.env
OMP_MODEL=openai/gpt-6-luna
OMP_AGENT_MODEL_BACKEND_ARCHITECT=openai/gpt-6-sol
```

Example files are included:

- `.claude.local.env.example`
- `.opencode.local.env.example`
- `.codex.local.env.example`
- `.omp.local.env.example`

Per-agent environment keys use the pattern
`<PLATFORM>_AGENT_MODEL_<AGENT_NAME_IN_UPPER_SNAKE_CASE>`.

Use `CLAUDE_STATUSLINE_COMMAND_PATH` to point Claude's repo-managed
status line at a machine-specific script location while keeping the
setting itself repo-owned.

Precedence for model selection during sync is:

1. Per-agent CLI flag, for example
   `--agent-model claude:backend-architect:anthropic/opus`
2. Generated recommended per-agent override from
   `--use-recommended-models` or `--use-recommended-fallback-models`
3. Per-agent environment variable, for example
   `CLAUDE_AGENT_MODEL_BACKEND_ARCHITECT`
4. Per-agent local env file entry, for example in `.claude.local.env`
5. Platform-specific CLI flag, for example `--claude-model`
6. Platform-specific environment variable, for example `CLAUDE_MODEL`
7. Platform-specific local env file, for example `.claude.local.env`
8. The repo's per-agent defaults in that platform's `agents/`
   directory

### OpenCode API Key Configuration

The `.config/opencode/opencode.json` file contains API key placeholders
for security. These are substituted with actual values during sync.

**Placeholder Variables:**

- `{env:NVIDIA_NIM_API_KEY}` - NVIDIA NIM provider API key
  (format: `nvapi-...`)
- `{env:STITCH_API_KEY}` - Google Stitch MCP API key
  (format: `AQ.xxx...`)
- `{env:CONTEXT7_API_KEY}` - Context7 MCP API key
  (format: `ctx7sk-...`)

OMP uses native `.omp/mcp.json` environment placeholders for Stitch and
Context7 and forwards `GITHUB_PERSONAL_ACCESS_TOKEN` to the GitHub container.
Export those variables in the environment used to launch OMP. OMP does not use
the OpenCode key-sync prompt; missing variables leave their placeholders
unresolved. Keep secret values out of the checked-in config.

**During sync, you will be prompted to configure these keys.**

#### Automatic API Key Configuration

Use the `--configure-api-keys` flag to automatically enter API key
configuration mode:

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
2. Prompt for each API key securely, with input hidden
3. Ask you to confirm each entry
4. Substitute the values into `~/.config/opencode/opencode.json`

This also applies when you choose MCP-only config sync for OpenCode and
the selected MCP servers include placeholder-backed keys.

#### Interactive API Key Configuration

Without the flag, you'll be asked interactively when placeholders are
detected:

```bash
./sync-local-agents.sh --platform opencode
# Script detects placeholders and asks:
# "opencode.json contains API key placeholders."
# "Configure API keys now? [Y/n]:"
```

Type `Y` to enter configuration mode, or `n` to sync the latest config
while preserving existing local API key values anywhere the repo source
still contains placeholders. The same preservation behavior applies
during MCP-only sync.

#### Getting API Keys

**NVIDIA NIM API Key:**

1. Visit [https://build.nvidia.com/](https://build.nvidia.com/)
2. Sign in with your NVIDIA account
3. Generate an API key from your profile or dashboard
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
- Actual keys are injected into your local config at
  `~/.config/opencode/opencode.json`
- Input is hidden when typing, as a security best practice
- Keys are double-confirmed to prevent typos
- Your local `~/.config/opencode/` directory is outside version control
- GitHub MCP uses `GITHUB_PERSONAL_ACCESS_TOKEN` from your local
  environment and does not write the token into repo-managed config

## Restart Requirements

- **Claude**: restart Claude after syncing `.claude/settings.json` so
  the new MCP server is loaded.
- **OpenCode**: quit and restart OpenCode after syncing `opencode.json`;
  config is not hot-reloaded.
- **Codex**: restart Codex after syncing `~/.codex/config.toml`. If the
  ponytail or caveman bootstrap step warns, rerun the native install
  commands it prints after fixing your local Codex or `npx` setup.
- **OMP**: start a new session after editing `.omp/mcp.json` or
  `.omp/config.yml`; use `/mcp reload` to reconnect MCP servers in an
  existing session.
