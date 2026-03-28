# Agents & Skills Directory

This repository serves as a centralized hub for AI agent definitions and specialized skills. It is organized to support multiple AI platforms (Claude, OpenCode, Codex) with consistent standards. Shared skills are part of the core workflow: agents should check the available skills before proceeding with specialized work and use them when relevant.

## 🤖 Available Agents

`it-task-master` is the default orchestrator for day-to-day usage. It evaluates task type and then delegates execution to the most relevant specialist agent.

### Engineering Roles
| Agent | Primary Purpose | Location |
|-------|-----------------|----------|
| **IT Task Master** | Default orchestrator that routes tasks to the most relevant specialist agent. | `.claude/`, `.config/opencode/`, `.codex/` |
| **Backend Architect** | DDD, Microservices design, and high-level backend strategy. | `.claude/`, `.config/opencode/`, `.codex/` |
| **Backend Engineer** | Implementation of services, APIs, and domain logic in Node.js/TS. | `.claude/`, `.config/opencode/`, `.codex/` |
| **Frontend Architect** | Technical leads for web architecture, data flow, and project structure. | `.claude/`, `.config/opencode/`, `.codex/` |
| **Frontend Engineer** | UI implementation, component development, and frontend testing. | `.claude/`, `.config/opencode/`, `.codex/` |
| **UX/UI Architect** | Design tokens, accessibility, and high-performance mobile-first interfaces. | `.claude/`, `.config/opencode/`, `.codex/` |
| **DevOps Engineer** | Infrastructure as Code, CI/CD, and cloud orchestration. | `.claude/`, `.config/opencode/`, `.codex/` |
| **E2E Test Engineer** | Playwright-based end-to-end testing and quality assurance. | `.claude/`, `.config/opencode/`, `.codex/` |
| **SecOps Auditor** | Security architecture, threat analysis, and OWASP compliance. | `.claude/`, `.config/opencode/`, `.codex/` |
| **SEO Inspector** | Technical SEO, content architecture, AI search readiness, and discoverability audits. | `.claude/`, `.config/opencode/`, `.codex/` |
| **Tax Advisor** | Polish tax law guidance for PIT, CIT, VAT, compliance, deadlines, and practical business-tax tradeoffs. | `.claude/`, `.config/opencode/`, `.codex/` |

### Content & Growth Roles
| Agent | Primary Purpose | Location |
|-------|-----------------|----------|
| **Content Writer** | Technical blog strategy and writing with strong hooks, retention techniques, SEO awareness, and conversion-minded editorial execution. | `.claude/`, `.config/opencode/`, `.codex/` |

### Leadership Roles
| Agent | Primary Purpose | Location |
|-------|-----------------|----------|
| **Principal Engineer** | Strategic technical leadership, mentoring, and cross-stack reviews. | `.claude/`, `.config/opencode/`, `.codex/` |
| **Staff Engineer** | Cross-team coordination and solving complex technical bottlenecks. | `.claude/`, `.config/opencode/`, `.codex/` |
| **Team Manager** | People management, project delivery, and organizational health. | `.claude/`, `.config/opencode/`, `.codex/` |

## 🛠️ Specialized Skills

Skills are reusable logic modules located in `.claude/skills/`, `.config/opencode/skills/`, and `.codex/skills/`. They are shared building blocks, so agents should check them before specialized work and use the relevant ones when they improve the outcome:
- **Code Review**: Standards-based analysis of pull requests and code changes.
- **Tech Arch Research**: Deep-dive analysis into technical architectures and patterns.
- **Java**: Reusable Java engineering guidance for application architecture, Spring-based services, testing, performance, and production reliability.
- **SEO Inspection**: Full-spectrum audits spanning technical SEO, content quality, and AI search readiness.
- **Technical SEO Audit**: Crawlability, rendering, indexation, and structured-data validation.
- **SEO Content Strategy**: Search-intent mapping, internal linking, and topical authority planning.
- **AI Search Optimization**: LLM retrieval, AI Overview readiness, and citation-friendly content design.
- **SEO Measurement and Observability**: KPI frameworks, crawl monitoring, and discoverability reporting.
- **Polish Tax Law**: Reusable guidance for Polish tax analysis, compliance boundaries, risk framing, and current-law verification.
- **Technical Blog Writing**: Clear, credible, developer-focused article writing with strong structure and examples.
- **Attention Retention Writing**: Hooks, pacing, transitions, and ethical engagement techniques for stronger read-through.
- **Blog Editorial Strategy**: Topic framing, audience alignment, internal linking, and content-program planning for technical blogs.

---

## 📘 Repository Guidelines

### Project Structure
- `.claude/agents/`: Definitions for Claude Code.
- `.claude/skills/`: Specialized skills for Claude.
- `.config/opencode/agents/`: Definitions for OpenCode.
- `.codex/agents/`: Definitions for Codex.
- `.codex/skills/`: Codex-compatible skill definitions.

### Development Workflow
1. **Persona Consistency**: Every agent starts with YAML frontmatter (`name`, `description`, `model`, `color`).
2. **Standard Headings**: Use `Core Principles`, `Technical Standards`, `Workflow`, and `Review Checklist`.
3. **Task Routing**: Use `it-task-master` as the default orchestrator, then hand off to specialist agents by task type.
4. **Skills Awareness**: Before doing specialized work, check the available shared skills and use the relevant ones instead of recreating guidance that already exists.
5. **Tool/Library Documentation Verification (Context7 MCP)**:
   - When implementing with a specific tool, library, or framework, first check whether its documentation is available via Context7 MCP.
   - If available, use Context7 docs to verify APIs and usage patterns, and rely on them during implementation decisions.
   - Practical flow: resolve library ID → query docs → implement.
6. **UI Design & Prototyping (Stitch MCP)**:
   - Stitch MCP is available for UI design and prototyping workflows.
   - Use it to create/list projects, generate screens from text, edit screens,
     generate design variants, and retrieve project/screen details.
7. **Verification**:
   - Run `markdownlint "**/*.md"` to ensure formatting consistency.
   - Use `rg --files .claude/agents | sort` to verify the agent pool.
8. **Commits**: Use imperative summaries: `Add [agent-name]` or `Improve [agent-name]`.

### Security
- Never embed secrets or sensitive company data in agent prompts.
- Use generic placeholders for examples.
