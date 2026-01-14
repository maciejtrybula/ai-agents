---
name: code-review
description: Perform rigorous code reviews: identify correctness, security, reliability, and testing gaps; report findings by severity with file references and actionable fixes.
metadata:
  short-description: High-signal code review workflow
---

# Code Review

Use this skill when the user requests a code review or review of a diff/PR.

## Workflow

1. Read the change scope and identify risk hotspots (auth, payments, data writes, public APIs).
2. Review logic paths and error handling before style or refactors.
3. Validate API contracts and backward compatibility.
4. Inspect data integrity, migrations, and transaction boundaries.
5. Check tests: coverage for edge cases, negative paths, and integrations.
6. Summarize findings ordered by severity, then list open questions.

## Severity Definitions

- **Blocker**: incorrect behavior, security issue, data loss, broken build.
- **High**: likely regression, major correctness gap, missing critical tests.
- **Medium**: edge case, performance risk, unclear behavior, maintainability risk.
- **Low**: minor cleanup, style issues, optional improvements.

## Output Format

- Findings first, ordered by severity with file references.
- Follow with open questions and assumptions.
- Provide a brief change-summary only after findings.
- If no findings, explicitly say so and list residual risks or testing gaps.

## Review Checklist

- **Correctness**: invariants, null/undefined handling, edge cases.
- **Security**: authn/authz, input validation, secrets and PII exposure.
- **Reliability**: timeouts, retries, idempotency, concurrency safety.
- **Performance**: N+1 queries, hot paths, memory and IO usage.
- **Observability**: logs/metrics/traces for new behavior.
- **Testing**: missing unit/integration tests for risky paths.

## Microservices Checklist

- **Service boundaries**: no cross-domain leakage; owns its data and rules.
- **Contracts**: API/event schemas versioned and backward compatible.
- **Resilience**: retries with jitter, circuit breakers, timeouts, bulkheads.
- **Data ownership**: no direct DB access across services.
- **Operational**: health checks, graceful shutdown, config via env.

## DDD Checklist

- **Ubiquitous language**: names match domain terms.
- **Aggregates**: invariants enforced inside aggregate boundaries.
- **Domain events**: emitted from domain layer, not adapters.
- **Application layer**: orchestrates use cases; no domain leakage to controllers.
- **Anti-corruption**: external models mapped, not reused directly.

## Event-Driven Checklist

- **Idempotency**: handlers safe to retry; dedupe strategy exists.
- **Ordering**: explicit handling for out-of-order events.
- **Delivery**: at-least-once assumed; no reliance on exactly-once.
- **Schema**: event versioning and evolution plan.
- **Failure paths**: dead-letter strategy and observability for poison events.
