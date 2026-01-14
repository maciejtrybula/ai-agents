---
name: tech-arch-research
description: Deep technical research for architecture and implementation solutions, including dependency risk analysis, remediation plans, migration options, and design decisions. Use when asked to investigate technical risks, compare options, propose architectures, or produce plans (ADR/RFC/markdown).
---

# Tech Architecture Research

## Core workflow

1. Confirm goals and constraints

- Identify the target outcome, security/compliance drivers, and time horizon.
- Capture environment constraints: runtime, infra, CI/CD, network access, and repo boundaries.

2. Gather local evidence

- Prefer repo data first: `package.json`, lockfiles, Docker/CI configs, service entrypoints.
- Extract concrete versions and dependency edges from lockfiles or installed metadata.
- Record evidence with file paths for traceability.

3. Research upstream inputs

- Identify authoritative sources: release notes, migration guides, CVEs, vendor advisories.
- If network access is blocked, state the limitation and proceed with local evidence; flag any gaps.

4. Analyze options and impact

- Provide 2-3 viable remediation options with tradeoffs.
- Assess compatibility risks (API changes, peer deps, runtime versions, plugin ecosystems).
- Highlight cross-service impact in monorepos.

5. Produce a decision-ready plan

- Include steps, validation, rollback, and monitoring guidance.
- Add a testing checklist aligned with repo scripts.
- Provide a clear recommendation with rationale.

## Output guidelines

- Default format: Markdown with short headings and checklists.
- Separate facts (evidence) from hypotheses (assumptions).
- For each recommendation, include: scope, changes, risks, tests, and rollout.
- Avoid speculation; if unsure, add a follow-up action to verify.

## Suggested deliverables

- Problem statement and current-state evidence
- Options matrix (benefits, risks, effort)
- Recommended remediation plan (phased)
- Validation/testing plan
- Rollback/contingency plan
- Open questions and required decisions

## Templated structure (use when helpful)

```
# Title

## Summary

## Current state (evidence)
- File/path references

## Options
- Option A
- Option B
- Option C

## Recommendation

## Remediation plan
- Step-by-step

## Validation

## Rollback

## Open questions
```

## Notes

- Keep the narrative concise; focus on actionable steps.
- If a repository has specific commands or policies, align validation steps to them.
