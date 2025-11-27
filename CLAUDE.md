# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository stores Claude agents for different engineering purposes. Each agent is a specialized expert designed to handle specific software engineering domains and tasks.

## Agent Structure

All agents are stored in `.claude/agents/` directory as markdown files with YAML frontmatter containing:
- `name`: Agent identifier
- `description`: When and how to use the agent with examples
- `model`: Claude model to use (typically sonnet)
- `color`: UI color for the agent

## Available Agents

- **backend-architect.md**: Domain-Driven Design expert for backend architecture decisions, microservices design, and event-driven systems
- **backend-engineer.md**: General backend development guidance
- **devops-engineer.md**: DevOps and infrastructure automation
- **e2e-test-engineer.md**: End-to-end testing strategies and implementation
- **principal-engineer.md**: Senior-level code review and architectural guidance focusing on SOLID principles, DDD, and enterprise patterns
- **secops-auditor.md**: Security operations and compliance auditing

## Agent Development Guidelines

When creating or modifying agents:
- Follow the established YAML frontmatter format
- Include clear description with usage examples
- Define specific expertise areas and responsibilities
- Maintain consistent communication style and quality standards
- Include quality controls and self-verification steps for complex agents