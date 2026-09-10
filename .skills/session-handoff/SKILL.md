---
name: session-handoff
description: Check context usage and, when it's getting full or the user asks to prepare a handoff for a new session, write a structured continuation summary so work can continue in a fresh session. Use when the user asks to check context, prepare a summary/handoff for a new session, or when context usage is critically high.
---

# Session Handoff

Use this skill when the user asks to check context usage or prepare a handoff for a new session, or when context is getting full.

This skill works across Claude Code, OpenCode, and Codex. It determines its own
paths at runtime (never hard-coded), so it behaves identically wherever it is
installed — project or user-global, any platform, any machine.

## 1. Check context

Run the context monitor from this skill's directory:

```bash
bash bin/context-monitor.sh
```

It prints an integer percent (0-100) of the context window, or nothing when usage
cannot be determined.

Read the effective thresholds from the merged config:

```bash
bash -c 'source lib/paths.sh; echo "warn=$(config_get warnPercent)% critical=$(config_get criticalPercent)% block=$(config_get blockPercent)%"'
```

Defaults (override via user/project config — see README): **warn** 70%+, **critical** 85%+.

If the number is below warn, report it and stop — do NOT write a handoff file. If it
is at/above warn, proceed.

## 2. Gather the summary

Collect a structured summary from the conversation, including every section below when
the information is available:

- **Task / goal and acceptance criteria** — restate from the conversation.
- **Done (progress)** and **In-flight (current work)**.
- **Key decisions and tradeoffs** made.
- **Files touched / created** — full paths.
- **Open questions / blockers / risks**.
- **Next steps** — with the exact commands to run.
- **Git state** — current branch and uncommitted changes.

For the git state, run and capture the branch plus a summary of changes:

```
git branch --show-current
git status --porcelain
```

## 3. Write the handoff file

Resolve the target location by sourcing the shared path library (from this skill's
directory):

```bash
bash -c 'source lib/paths.sh; echo "HANDOFF_ROOT=$HANDOFF_ROOT"; echo "SESSION_ID=$SESSION_ID"'
```

When inside a writable git work tree, handoffs land under the project store:

```
<project>/.claude/handoff/<project-slug>/session-handoffs/<sessionId>.md
```

When not (e.g. a user-global run outside a git repo), they fall back to the
user-global store:

```
$HOME/.local/state/session-handoff/handoffs/<platform>/<project-slug>/session-handoffs/<sessionId>.md
```

Create the directory if needed. Use the printed `SESSION_ID`. Write your curated
summary there. The transcript is NOT copied; it lives in the platform's own storage
tree (Claude: `~/.claude/projects/<slug>/<sessionId>.jsonl`).

For the mechanical snapshot (files touched, git state, last prompt) you may run:

```bash
bash bin/context-autohandoff.sh
```

which writes the same kind of file automatically.

## 4. Report

Tell the user where the file was written and what the severity was (warn or critical).
