# GEMINI.md

This file provides guidance to Gemini when working with code in this repository.

## Directory Overview

This repository stores Claude agents, OpenCode agents, Codex agents, and shared skills for different engineering and content purposes. Each agent is a specialized expert designed to handle specific domains and tasks, and should check the available shared skills before proceeding with specialized work.

`it-task-master` is the default orchestrator agent in this repository. It determines task type first, then routes execution to the most appropriate specialist agent.

## Key Directories and Files

### 🤖 Agent Definitions
- **`.claude/agents/`**: Core definitions for Claude.
  - `backend-architect.md`, `backend-engineer.md`, `content-writer.md`, `devops-engineer.md`, `e2e-test-engineer.md`, `frontend-architect.md`, `frontend-engineer.md`, `it-task-master.md`, `principal-engineer.md`, `secops-auditor.md`, `seo-inspector.md`, `staff-engineer.md`, `team-manager.md`, `ux-ui-architect.md`.
- **`.config/opencode/agents/`**: Definitions for OpenCode.
  - `backend-architect.md`, `backend-engineer.md`, `content-writer.md`, `devops-engineer.md`, `e2e-test-engineer.md`, `frontend-architect.md`, `frontend-engineer.md`, `it-task-master.md`, `principal-engineer.md`, `secops-auditor.md`, `seo-inspector.md`, `staff-engineer.md`, `team-manager.md`, `ux-ui-architect.md`.
- **`.codex/agents/`**: Definitions for Codex.
  - `backend-architect.md`, `backend-engineer.md`, `content-writer.md`, `devops-engineer.md`, `e2e-test-engineer.md`, `frontend-architect.md`, `frontend-engineer.md`, `it-task-master.md`, `principal-engineer.md`, `secops-auditor.md`, `seo-inspector.md`, `staff-engineer.md`, `team-manager.md`, `ux-ui-architect.md`.

### 🛠️ Skill Definitions
- **`.claude/skills/`**: Specialized skills for Claude including `code-review`, `tech-arch-research`, `java`, the SEO skill set, and the new writing skills `technical-blog-writing`, `attention-retention-writing`, and `blog-editorial-strategy`.
- **`.config/opencode/skills/`**: Specialized skills for OpenCode including `java`, the same SEO skill set, and the writing skill set.
- **`.codex/skills/`**: Codex-compatible skill definitions including `code-review`, `tech-arch-research`, `java`, the SEO skill set, and the new writing skills `technical-blog-writing`, `attention-retention-writing`, and `blog-editorial-strategy`.

### 📘 Core Documentation
- **`AGENTS.md`**: Central directory and guidelines for all agents and skills.
- **`CLAUDE.md`**: Claude-specific instructions and agent listings.
- **`README.md`**: Main repository introduction.

## Usage

The contents of this directory are used to configure and provision AI agents. When creating or modifying agents, follow the established format (YAML frontmatter + structured sections) and guidelines outlined in `AGENTS.md`. Check the shared skills before starting specialized work, and use the relevant ones when they materially improve the result.

When working with a specific tool, library, or framework, first check whether documentation is available via Context7 MCP. If available, use Context7 docs to verify APIs and usage patterns, and rely on them during implementation decisions.

Practical flow: resolve library ID → query docs → implement.

Stitch MCP is also available for UI design and prototyping workflows. Use it
to create/list projects, generate screens from text, edit screens, generate
design variants, and retrieve project/screen details.

For general or mixed requests, use `it-task-master` first. It acts as the default orchestrator and delegates work to the correct specialist based on task type.

The new `content-writer` agent is the default specialist for technical blog writing, editorial planning, and attention-aware content refinement. Pair it with `technical-blog-writing`, `attention-retention-writing`, and `blog-editorial-strategy` when working on blog or thought-leadership content.
