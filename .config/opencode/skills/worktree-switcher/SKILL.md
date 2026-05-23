---
name: worktree-switcher
description: Use when adopting, reviewing, or hardening a shell helper like `wt` for local `git worktree` create, switch, and delete flows, especially when parsing `git worktree list`, defaulting base branches, or expecting `cd` to persist.
metadata:
  short-description: Safe local git worktree helper guidance
---

# Worktree Switcher

Use this skill when the task is about a sourceable shell helper like `wt` that creates, switches, or deletes local git worktrees.

## Core rules

- Source the helper from your shell config. Do not execute it as a standalone script if you expect `cd` to affect the current shell.
- Parse `git worktree list --porcelain`, not the human-formatted output.
- Never print a success message after a failed `git worktree add`, `git worktree remove`, or `cd`.
- Do not hard-code a base branch like `devel`. Default to the current branch or require an explicit `-c <base>`.
- If you use a repo-local `.worktrees/` directory, require it to be gitignored before creating a worktree there.
- Treat `fzf` as optional. Interactive selection should fail with a clear message when `fzf` is unavailable.

## Reference implementation

Source `.config/opencode/skills/worktree-switcher/wt.zsh` from `.zshrc` or another zsh startup file.

Quick reference:

- `wt feature-name`: create or switch to `.worktrees/feature-name`
- `wt feature-name -c main`: create from an explicit base ref
- `wt`: choose an existing worktree with `fzf`
- `wt -d feature-name`: remove the linked worktree for that branch
- `wt -d`: choose a linked worktree to remove with `fzf`

## Verified failure modes from the original helper

- It reported success after `git worktree add` failed because the default `devel` base branch did not exist.
- It reported success outside a git repository and built a bogus `/.worktrees/...` path.
- It matched existing worktrees by substring, so `feature` could be mistaken for `feature-long`.
- Its interactive mode crashed when `fzf` was not installed.

## Common mistakes

- Parsing `git worktree list` with `awk '{print $1}'` or `awk '{print $3}'`
- Using `grep -qF "$worktree_path"` for exact path matching
- Assuming every repo uses `devel`, `develop`, or `main` as the same default base branch
- Shipping the helper as an executable file instead of a sourceable shell function

## Rationalizations

| Excuse | Reality |
|--------|---------|
| "This is just a personal helper" | Personal helpers still damage repos when they misreport success or remove the wrong path. |
| "The git error is visible anyway" | A trailing success message overrides the signal the user actually sees. |
| "`git worktree list` is stable enough to parse with `awk`" | The human format is for people, not scripts. Use porcelain output. |
| "Hard-coding `devel` is fine in my repos" | Reusable helpers should derive the current branch or require an explicit base. |

## Red flags

- A helper prints `Gotowe`, `Done`, or similar after an `&&` chain without checking the exit status.
- Interactive selection depends on `fzf` but never checks whether `fzf` exists.
- Existing-worktree detection uses substring matching instead of exact path comparison.
- The helper is stored in a file but documented as if executing the file could change the caller's directory.
