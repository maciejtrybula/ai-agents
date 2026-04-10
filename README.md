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
./sync-local-agents.sh --sync skills --platform claude
./sync-local-agents.sh --interactive
./sync-local-agents.sh --platform claude --claude-model sonnet
./sync-local-agents.sh --platform opencode
./sync-local-agents.sh --opencode-model openai/gpt-5.4
./sync-local-agents.sh --platform codex --codex-model openai/gpt-5.4
```

- Default behavior syncs both `agents/` and `skills/` for all platforms.
- `--dry-run` previews changes without writing files.
- `--delete` removes local files that no longer exist in this repository.
  - If you sync selected entries only (for example via interactive narrowing), deletion is scoped to those selected directories and does not remove unsynced sibling entries.
- `--platform` limits the sync to `claude`, `opencode`, or `codex`.
- `--sync` provides non-interactive scope selection: `both` (default), `agents`, or `skills`.
- `--interactive` starts an interactive picker:
  - prompts for scope (defaults to `both`, or to your `--sync` preset when provided),
  - lists actual available agents/skills for each selected platform,
  - defaults to syncing all entries, with optional narrowing to selected items.
  - requires a TTY; otherwise it exits with a clear error.
- `--claude-model` rewrites synced Claude agent `model:` frontmatter so one model can be used across all Claude agents locally.
- `--opencode-model` rewrites synced OpenCode agent `model:` frontmatter so one model can be used across all OpenCode agents locally.
- `--codex-model` rewrites synced Codex agent `model:` frontmatter so one model can be used across all Codex agents locally.

To keep one model per platform without passing flags every time, create the local env files in this repository root, next to `sync-local-agents.sh`.

Do not put them in the synced target directories such as `~/.claude/`, `~/.config/opencode/`, or `~/.codex/`.

```bash
# .claude.local.env
CLAUDE_MODEL=sonnet

# .opencode.local.env
OPENCODE_MODEL=openai/gpt-5.4

# .codex.local.env
CODEX_MODEL=openai/gpt-5.4
```

Example files are included:

- `.claude.local.env.example`
- `.opencode.local.env.example`
- `.codex.local.env.example`

Precedence for each platform's model selection during sync is:

1. Platform-specific CLI flag, for example `--claude-model`
2. Platform-specific environment variable, for example `CLAUDE_MODEL`
3. Platform-specific local env file, for example `.claude.local.env`
4. The repo's per-agent defaults in that platform's `agents/` directory
