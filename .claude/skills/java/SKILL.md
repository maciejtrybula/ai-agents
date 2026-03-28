---
name: java
description: Reusable Java backend engineering guidance for modern JVM services (Java 17/21) across Spring Boot, Micronaut, Quarkus, Jakarta EE, and plain Java applications.
metadata:
  short-description: Framework-agnostic Java backend standards for runtime, reliability, contracts, testing, and operations
---

# Java

Use this skill when implementing or reviewing Java backend services on modern JVM stacks.

## Runtime and Tooling Baseline

- Prefer Java 17 or 21 LTS and pin the JDK version with toolchains for reproducible local and CI builds.
- Keep builds deterministic with locked dependency versions, consistent plugin configuration, and minimal transitive dependencies.
- Externalize operational configuration, validate required values at startup, and fail fast on invalid runtime setup.
- Include static analysis, formatting, and dependency vulnerability checks in CI.

## Language and Design Standards

- Prefer immutable models (`record` where appropriate, final fields, unmodifiable collections) and avoid shared mutable state.
- Model domain constraints with value objects and precise types instead of overusing primitives and strings.
- Avoid returning `null`; use consistent nullability annotations and reserve `Optional` for boundary return types rather than fields.
- Keep DTOs, persistence models, and domain models separate to avoid framework or transport leakage.
- Use exceptions intentionally: domain errors should be meaningful, while technical failures should be translated at system boundaries.

## Concurrency and Reliability Patterns

- Use explicit executors with bounded queues and separate CPU-bound work from blocking I/O workloads.
- Apply timeouts, retries with jitter, and circuit breaking for outbound calls; never retry blindly without budgets or idempotency.
- Keep transactional boundaries short and explicit; avoid long-running database transactions and hidden cross-service consistency assumptions.
- Design externally triggered write operations to be idempotent and use outbox or inbox patterns for reliable event delivery.

## Boundary Validation and Contracts

- Validate untrusted input at all entry points including HTTP handlers, message consumers, and scheduled jobs.
- Treat APIs and events as versioned contracts with additive evolution by default and explicit compatibility rules.
- Be explicit about serialization for dates, times, precision, unknown fields, and enum evolution.
- Return stable, machine-readable error contracts and never expose internal stack traces or sensitive fields.

## Testing in Java Ecosystems

- Keep unit tests fast and isolated for domain logic, invariants, and application services.
- Add focused integration tests for persistence, messaging, serialization, and HTTP adapters against realistic dependencies.
- Add contract tests for APIs and events to protect cross-service compatibility.
- Verify negative and resilience paths including timeout handling, retries, idempotency, transaction rollback, and duplicate delivery.

## Observability and Operability

- Emit structured logs with correlation or trace IDs and avoid logging secrets, tokens, or PII.
- Prefer contextual logs over payload dumps and reduce noisy stack traces on expected failure paths.
- Capture key metrics such as latency, throughput, error rate, saturation, queue depth, and retry counts.
- Support graceful shutdown by stopping intake, draining in-flight work, and closing resources predictably.
- Expose health and readiness checks that reflect true dependency state.
