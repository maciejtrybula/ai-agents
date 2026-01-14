# Repository Guidelines

## Project Structure & Module Organization

This project is intentionally lean: `README.md` introduces the repo, `CLAUDE.md` documents global expectations, and every actual agent brief lives under `.claude/agents/*.md`. Each agent file starts with YAML front matter (`name`, `description`, `model`, `color`) followed by consistent sections such as Core Principles, Technical Standards, Workflow, Review Checklist, and Communication Style. Add one persona per hyphenated file (for example `e2e-test-engineer.md`) and reuse the established headings so downstream tools can parse them reliably.

## Build, Test, and Development Commands

- `markdownlint "**/*.md"` – run after edits to catch heading depth, list spacing, and code-block formatting issues; install `markdownlint-cli` globally or via `npx`.
- `rg --files .claude/agents | sort` – confirm your new persona file sits in the canonical directory.
- `git diff --word-diff=color` – review prompt tweaks inline to ensure intentional tone changes.

## Coding Style & Naming Conventions

Write in professional, second-person prose that mirrors the voice in existing agents (`You are an elite…`). Keep paragraphs short, use `##` subheads, and favor bullet lists for standards or checklists. YAML keys are lowercase with hyphenated colors; Markdown uses fenced code blocks for snippets and avoids raw HTML. Sample interactions should follow the "User"/"Assistant" pattern already present.

## Testing Guidelines

Because this is a documentation repository, "tests" mean verification passes. Ensure the YAML front matter parses (no tabs, quote multi-line descriptions), run `markdownlint` before pushing, and manually proofread that every checklist item is actionable. Validate that examples match the described responsibilities and that no section contradicts `CLAUDE.md`.

## Commit & Pull Request Guidelines

Commits follow short, imperative summaries (`Improve principal-engineer`, `Add team-manager and staff-engineer`). Use similar phrasing and keep each commit scoped to one persona. PRs should describe why the change helps the agent pool, enumerate affected files ("Updated `.claude/agents/devops-engineer.md`"), and link any tracking issues. When altering behavior, add before/after snippets or screenshots from your IDE so reviewers can gauge tone changes quickly.

## Security & Configuration Tips

Never embed tokens, company names, or customer data inside an agent brief—prompts are long-lived. Prefer generic placeholders ("Acme Corp") and double-check that commands you recommend do not expose secrets. When referencing environment configuration, defer to higher-level docs and remind users to keep credentials outside the repo.
