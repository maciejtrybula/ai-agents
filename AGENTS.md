# Agents & Skills Directory

This repository serves as a centralized hub for AI agent definitions and specialized skills. It is organized to support multiple AI platforms (Claude, OpenCode, Codex) with consistent standards.

## 🤖 Available Agents

### Engineering Roles
| Agent | Primary Purpose | Location |
|-------|-----------------|----------|
| **Backend Architect** | DDD, Microservices design, and high-level backend strategy. | `.claude/`, `.config/opencode/` |
| **Backend Engineer** | Implementation of services, APIs, and domain logic in Node.js/TS. | `.claude/`, `.config/opencode/` |
| **Frontend Architect** | Technical leads for web architecture, data flow, and project structure. | `.claude/`, `.config/opencode/` |
| **Frontend Engineer** | UI implementation, component development, and frontend testing. | `.claude/`, `.config/opencode/` |
| **UX/UI Architect** | Design tokens, accessibility, and high-performance mobile-first interfaces. | `.claude/`, `.config/opencode/` |
| **DevOps Engineer** | Infrastructure as Code, CI/CD, and cloud orchestration. | `.claude/`, `.config/opencode/` |
| **E2E Test Engineer** | Playwright-based end-to-end testing and quality assurance. | `.claude/`, `.config/opencode/` |
| **SecOps Auditor** | Security architecture, threat analysis, and OWASP compliance. | `.claude/`, `.config/opencode/` |
| **SEO Inspector** | Technical SEO, content architecture, AI search readiness, and discoverability audits. | `.claude/`, `.config/opencode/`, `.codex/` |

### Leadership Roles (Claude Only)
| Agent | Primary Purpose | Location |
|-------|-----------------|----------|
| **Principal Engineer** | Strategic technical leadership, mentoring, and cross-stack reviews. | `.claude/` |
| **Staff Engineer** | Cross-team coordination and solving complex technical bottlenecks. | `.claude/` |
| **Team Manager** | People management, project delivery, and organizational health. | `.claude/` |

## 🛠️ Specialized Skills

Skills are reusable logic modules located in `.claude/skills/`, `.config/opencode/skills/`, and `.codex/skills/`:
- **Code Review**: Standards-based analysis of pull requests and code changes.
- **Tech Arch Research**: Deep-dive analysis into technical architectures and patterns.
- **SEO Inspection**: Full-spectrum audits spanning technical SEO, content quality, and AI search readiness.
- **Technical SEO Audit**: Crawlability, rendering, indexation, and structured-data validation.
- **SEO Content Strategy**: Search-intent mapping, internal linking, and topical authority planning.
- **AI Search Optimization**: LLM retrieval, AI Overview readiness, and citation-friendly content design.
- **SEO Measurement and Observability**: KPI frameworks, crawl monitoring, and discoverability reporting.

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
3. **Verification**:
   - Run `markdownlint "**/*.md"` to ensure formatting consistency.
   - Use `rg --files .claude/agents | sort` to verify the agent pool.
4. **Commits**: Use imperative summaries: `Add [agent-name]` or `Improve [agent-name]`.

### Security
- Never embed secrets or sensitive company data in agent prompts.
- Use generic placeholders for examples.
