# WARP.md

This file provides guidance to Warp when working with code and agent definitions in this repository.

## Repository Purpose

This repository stores Claude, OpenCode, and Codex agents plus shared skills for engineering, SEO, and technical content work. Agents should check the shared skills before proceeding with specialized work and use them when relevant.

## Key Agent Directories

- `.claude/agents/` - Claude agent definitions
- `.config/opencode/agents/` - OpenCode agent definitions
- `.codex/agents/` - Codex agent definitions

## Key Skill Directories

- `.claude/skills/` - Claude skill definitions
- `.config/opencode/skills/` - OpenCode skill definitions
- `.codex/skills/` - Codex skill definitions

## Notable Agent Coverage

- `it-task-master` is the default orchestrator agent. It evaluates task type and routes work to the right specialist.
- Engineering agents cover backend, frontend, DevOps, E2E, UX/UI, security, and architecture roles.
- `seo-inspector` handles SEO, discoverability, content architecture, and AI-search readiness.
- `tax-advisor` handles Polish tax law questions across PIT, CIT, VAT, compliance, deadlines, and practical business-tax tradeoffs.
- `content-writer` handles technical blog strategy and writing with strong hooks, attention retention techniques, SEO awareness, and conversion-minded editorial execution.

## Notable Skill Coverage

Skills are shared across platforms and should be checked before specialized work so agents can reuse the best available guidance instead of recreating it.

- Engineering skills include reusable guidance such as `java` for application architecture, Spring-based services, testing, performance, and production reliability.
- Tax skills include `polish-tax-law` for structured Polish tax analysis, compliance-aware reasoning, and escalation boundaries.
- SEO skills include `seo-inspection`, `technical-seo-audit`, `seo-content-strategy`, `ai-search-optimization`, and `seo-measurement-observability`.
- Writing skills include `technical-blog-writing`, `attention-retention-writing`, and `blog-editorial-strategy`.

## Usage Guidance

Start with `it-task-master` as the default orchestrator for general requests; it decides which specialist agent should handle the task based on task type.

When working with a specific tool, library, or framework, first check whether documentation is available via Context7 MCP. If available, use Context7 docs to verify APIs and usage patterns, and rely on them during implementation decisions.

Practical flow: resolve library ID → query docs → implement.

Stitch MCP is also available for UI design and prototyping workflows. Use it
to create/list projects, generate screens from text, edit screens, generate
design variants, and retrieve project/screen details.

When working on blog or thought-leadership content, use `content-writer` as the primary specialist and combine it with:
- `technical-blog-writing` for structure, clarity, examples, and credibility
- `attention-retention-writing` for hooks, pacing, and transitions
- `blog-editorial-strategy` for audience targeting, positioning, and content planning

When creating or modifying agents and skills, follow the conventions documented in `AGENTS.md`.
