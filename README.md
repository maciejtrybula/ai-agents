# ai-agents

Centralized hub for AI agent definitions and reusable skills across Claude, OpenCode, and Codex.

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
| **content-writer** | Technical blog strategy and writing with strong hooks, retention techniques, SEO awareness, and conversion-minded execution. |

### Leadership Agents

| Agent | Primary Purpose |
|-------|-----------------|
| **principal-engineer** | Strategic technical leadership, mentoring, and cross-stack reviews. |
| **staff-engineer** | Cross-team coordination and solving complex technical bottlenecks. |
| **team-manager** | People management, project delivery, and organizational health. |

## 🛠️ Specialized Skills

Skills are shared across **Claude**, **OpenCode**, and **Codex**.

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
./sync-local-agents.sh --platform opencode
```

- `--dry-run` previews changes without writing files.
- `--delete` removes local files that no longer exist in this repository.
- `--platform` limits the sync to `claude`, `opencode`, or `codex`.
