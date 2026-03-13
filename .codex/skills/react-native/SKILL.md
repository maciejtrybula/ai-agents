---
name: react-native
description: Reusable React Native and Expo guidance for architecture, navigation, device constraints, performance, and mobile-specific testing and release quality.
metadata:
  short-description: React Native and Expo implementation standards
---

# React Native

Use this skill when implementing or reviewing React Native or Expo applications.

## Platform Baseline

- Align implementation with current React Native architecture expectations (Fabric/TurboModules) for new work.
- Use Expo workflow capabilities intentionally (managed/native, OTA updates, build pipeline) based on release constraints.
- Treat iOS and Android behavior differences as first-class requirements.

## Mobile UI and Interaction

- Respect safe areas, device notches, orientation changes, and varied screen densities.
- Use platform-appropriate navigation patterns and keep deep-link/state restoration flows deterministic.
- Handle gestures, animations, and touch targets with accessibility and responsiveness in mind.

## State, Storage, and Networking

- Separate transient view state from persisted/offline-capable state.
- Define clear synchronization strategy for local storage, cache invalidation, and reconnect scenarios.
- Guard mobile network calls with timeout, retry, and background/foreground lifecycle awareness.

## Mobile Performance

- Keep list rendering efficient with virtualization and stable item keys.
- Avoid unnecessary bridge traffic and heavy work on critical interaction paths.
- Optimize images/assets by format, size, and resolution per device tier.

## Reliability, Testing, and Delivery

- Test critical paths on multiple devices, OS versions, and screen sizes.
- Validate startup/splash behavior, permissions, background handling, and push/deep-link entry paths.
- Include end-to-end coverage for high-risk mobile flows and release gating checks.
