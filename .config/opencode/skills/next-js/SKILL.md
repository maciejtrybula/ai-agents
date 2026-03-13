---
name: next-js
description: Reusable Next.js guidance for App Router architecture, rendering strategy, data mutations, caching, routing, and deployment-safe runtime behavior.
metadata:
  short-description: Next.js App Router implementation standards
---

# Next.js

Use this skill when implementing or reviewing Next.js applications.

## App Router Architecture

- Default to Server Components and introduce Client Components only for interactive client-only concerns.
- Keep route segment boundaries intentional (`layout`, `page`, `loading`, `error`, `not-found`).
- Co-locate data dependencies with route segments to reduce waterfall requests.

## Rendering and Caching Strategy

- Choose rendering mode per route based on freshness and latency needs (static generation, dynamic rendering, revalidation).
- Use caching and revalidation deliberately and document invalidation triggers.
- Avoid over-fetching in client components when server-side fetching can reduce bundle size.

## Mutations and Server Actions

- Use Server Actions for trusted, co-located mutations when they simplify client-server boundaries.
- Validate action inputs and handle expected failure states explicitly.
- Keep optimistic UI behavior consistent with server truth and revalidation logic.

## Routing and Middleware

- Use middleware sparingly for cross-cutting concerns (auth, localization, redirects) and keep it fast.
- Ensure route transitions preserve accessibility and predictable loading/error experiences.
- Keep route handlers thin and delegate business logic to dedicated service layers.

## Performance and Operations

- Monitor Core Web Vitals, hydration costs, and route-level bundle sizes.
- Prefer streaming and partial rendering where it materially improves perceived performance.
- Verify environment configuration for edge vs node runtimes and avoid unsupported APIs.
