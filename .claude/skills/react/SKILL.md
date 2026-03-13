---
name: react
description: Reusable React engineering guidance covering component patterns, rendering behavior, state boundaries, testing, accessibility, and performance in React 18+ applications.
metadata:
  short-description: React 18+ implementation standards
---

# React

Use this skill when implementing or reviewing React web applications.

## React 18 Baseline

- Prefer function components and hooks-based composition.
- Understand rendering behavior under concurrent features and avoid side effects during render.
- Model component state transitions explicitly for loading, success, and error paths.

## Component and State Patterns

- Keep components focused and extract reusable logic into custom hooks.
- Place state near usage and promote shared state only when multiple branches require it.
- Use context deliberately for cross-cutting concerns, not as a default global state tool.
- Define clear boundaries between presentational components and data-orchestration components.

## Rendering and Performance

- Profile before optimization, then apply memoization (`useMemo`, `useCallback`, `React.memo`) where it materially reduces work.
- Use list virtualization for large datasets and stabilize keys for dynamic collections.
- Apply code splitting and lazy loading for non-critical routes and heavy components.
- Manage Suspense and fallback UX intentionally to avoid layout instability.

## Error Handling and UX Resilience

- Use error boundaries around unstable or high-risk subtrees.
- Keep asynchronous effects cancellable where possible and prevent stale updates on unmounted components.
- Provide explicit empty, loading, partial-data, and error states for user-facing flows.

## Testing and Accessibility

- Favor behavior-driven tests with React Testing Library over implementation-detail assertions.
- Validate keyboard navigation, semantic structure, and accessible names for interactive controls.
- Include integration tests for form workflows, async state transitions, and edge cases.
