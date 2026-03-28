# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository stores Claude, OpenCode, and Codex agents for different engineering and content purposes. Each agent is a specialized expert designed to handle specific domains and tasks, and should check the available shared skills before proceeding with specialized work.

## Agent Structure

All agents are stored in `.claude/agents/` (for Claude), `.config/opencode/agents/` (for OpenCode), and `.codex/agents/` (for Codex) as markdown files with YAML frontmatter containing:
- `name`: Agent identifier
- `description`: When and how to use the agent with examples
- `model`: Claude model to use (typically sonnet)
- `color`: UI color for the agent

## Default Orchestration

`it-task-master.md` is the default orchestrator agent for this repository. Start with it when a task is broad, mixed, or unclear: it classifies the task type and routes work to the right specialist agent.

## Available Claude Agents

- **it-task-master.md**: Default orchestrator that selects the best specialist agent for each task.
- **backend-architect.md**: DDD, Microservices design, and architectural guidance.
- **backend-engineer.md**: Implementation of services, APIs, and domain logic.
- **content-writer.md**: Technical blog strategy and writing with strong hooks, attention retention, SEO awareness, and conversion-minded editorial execution.
- **devops-engineer.md**: Infrastructure as Code, CI/CD, and orchestration.
- **e2e-test-engineer.md**: Playwright E2E testing and QA.
- **frontend-architect.md**: High-level technical strategy for web apps.
- **frontend-engineer.md**: UI/UX implementation and frontend testing.
- **principal-engineer.md**: Strategic technical leadership and reviews.
- **secops-auditor.md**: Security architecture and threat analysis.
- **seo-inspector.md**: SEO audits covering technical SEO, content strategy, and AI search readiness.
- **staff-engineer.md**: Cross-team coordination and strategic planning.
- **team-manager.md**: People management and project delivery.
- **ux-ui-architect.md**: High-performance, accessible interface architecture.

## Available Claude Skills

Check the available shared skills before starting specialized work, and use the relevant ones when they improve quality, depth, or verification.

- **code-review**: Specialized skill for comprehensive code analysis.
- **tech-arch-research**: Research-driven technical architecture analysis.
- **java**: Reusable Java engineering guidance for application architecture, Spring-based services, testing, performance, and production reliability.
- **seo-inspection**: Full-spectrum SEO inspection workflow.
- **technical-seo-audit**: Deep technical SEO validation and remediation guidance.
- **seo-content-strategy**: Search-intent, internal linking, and topical authority planning.
- **ai-search-optimization**: AI Overview and answer-engine optimization workflow.
- **seo-measurement-observability**: SEO KPI and crawl observability framework.
- **technical-blog-writing**: Technical article structure, clarity, credibility, and developer-focused storytelling.
- **attention-retention-writing**: Hooks, pacing, transitions, and ethical read-through optimization.
- **blog-editorial-strategy**: Audience-fit content planning, positioning, and content-program design.

## Content Guidance

Use `content-writer.md` when the task involves blog posts, thought leadership, technical explainers, comparison articles, or product-adjacent educational content. Combine it with:
- `technical-blog-writing` for draft quality and article structure
- `attention-retention-writing` for stronger openings and better reader flow
- `blog-editorial-strategy` for audience targeting, topic framing, and editorial planning

## Agent Development Guidelines

When creating or modifying agents:
- Follow the established YAML frontmatter format.
- Include clear descriptions with practical usage examples.
- Define specific expertise areas and responsibilities.
- Maintain consistent communication style and quality standards.
- Include quality controls and self-verification steps for complex agents.

## Tool/Library Documentation Verification (Context7 MCP)

When working with a specific tool, library, or framework, first check whether documentation is available via Context7 MCP. If available, use Context7 docs to verify APIs and usage patterns, and rely on them during implementation decisions.

Practical flow: resolve library ID → query docs → implement.

## UI Design & Prototyping (Stitch MCP)

Stitch MCP is available for UI design and prototyping workflows.

Use Stitch MCP to:

- create and list projects
- generate screens from text prompts
- edit existing screens
- generate design variants
- retrieve project and screen details
