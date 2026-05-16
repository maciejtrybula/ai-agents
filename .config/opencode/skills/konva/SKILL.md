---
name: konva-diagram-editor
description: Use when implementing or refactoring a Konva-powered diagram or spatial editor in the web app while keeping renderer concerns out of shared editor logic.
---

# Skill: Konva Diagram Editor

## When to use

Use this skill when a task involves any of the following:

- Konva `Stage`, `Layer`, `Group`, `Shape`, `Transformer`
- diagram rendering or spatial editing
- selection, drag, pan, zoom, resize, rotate, connect, marquee
- snapping, guides, hit testing, overlays, drag previews
- editor performance works in the browser
- refactors where canvas code is leaking into shared editor logic

Do **not** use this skill for:

- pure domain modeling unrelated to rendering
- backend persistence or API design by itself
- standard forms, tables, or admin UI with no canvas interaction

---

## Core rule

Treat **Konva as a web renderer**, not as the source of product truth.

If a rule still exists after replacing Konva with another renderer, it belongs outside Konva code.

---

## Outcome

Produce changes where:

- editor and domain logic remain renderer-agnostic
- Konva is only the browser rendering and interaction adapter
- persisted state comes from editor state, not `stage.toJSON()`
- mobile and tablet clients can reuse the same core logic later

---

## Required boundaries

## 1. Shared editor core

Owns:

- document model
- entity IDs and relationships
- geometry and transforms
- selection semantics
- commands and reducers/use cases
- undo/redo history
- snapping and constraints
- serialization and deserialization
- validation entry points
- tool state machines
- permissions and entitlement-aware behavior

Must **not** know about:

- Konva types
- React components
- browser globals
- DOM APIs
- layer ordering for rendering

## 2. Konva renderer adapter

Owns:

- `Stage` / `Layer` composition
- mapping editor state to Konva nodes
- coordinate conversion
- pointer/wheel event adaptation
- drag preview behavior
- viewport drawing
- temporary visual state
- DOM overlay anchoring for text editing
- renderer-specific performance tuning

Must **not** own:

- business rules
- authoritative document state
- persistence format
- history model
- validation logic

## 3. Shell / UI

Owns:

- toolbars
- inspectors
- dialogs
- route/page composition
- keyboard shortcut registration
- save/load wiring
- feature flags
- app-level notifications and status

---

## Package placement guidance

Prefer this shape:

```text
packages/
  editor-schema/
  workspace-core/
  editor-canvas/
  editor-grid/
  editor-logic/
  editor-renderer-konva/
  editor-shared-ui/
  editor-testkit/
```

### Rule

- `editor-renderer-konva/` may import Konva
- shared editor logic packages must not import Konva

---

## State ownership

Use three tiers.

## A. Persistent document state

Contains:

- nodes
- edges
- groups
- labels
- metadata
- revision identifiers

Properties:

- canonical
- normalized
- renderer-agnostic
- safe for backend persistence

## B. Session/editor state

Contains:

- active tool
- selection
- viewport
- history
- clipboard
- draft interactions

## C. Renderer-ephemeral state

Contains:

- Konva refs
- drag-layer state
- hover caches
- pointer-frame caches
- temporary overlay anchors

### Hard rule

Konva nodes must never become canonical editor state.

---

## Interaction pipeline

Use this pipeline:

```text
Browser input
  -> Konva adapter
  -> normalized editor intent
  -> tool state machine
  -> command or draft update
  -> store update
  -> scene projection
  -> Konva render
```

### Normalized intents

Use intents like:

- `pointerDown`
- `pointerMove`
- `pointerUp`
- `pointerCancel`
- `wheelZoom`
- `viewportPan`
- `shortcutTriggered`
- `textCommit`
- `transformCommit`

Do not pass raw Konva event objects into core logic.

### Commit rule

- preview interaction in transient state
- commit document changes through explicit commands at stable boundaries
- avoid history spam during drag/transform loops

---

## Layer strategy

Start with a small number of layers:

1. background layer
2. main content layer
3. interaction/selection layer
4. temporary drag layer

### Rules

- keep layer count low
- use `listening(false)` on non-interactive layers
- move dragged nodes to a temporary drag layer when it helps performance
- keep z-order deterministic in editor state or scene descriptors, not ad hoc in components

---

## Performance rules

### Non-negotiables

- do not mirror the full scene through React state on every pointer move
- do not trigger broad React rerenders for drag/hover/transform loops
- do not store large transient geometry in global shell state

### Required tactics

- normalized document state + memoized selectors
- narrow subscriptions
- incremental scene projection
- `batchDraw()` for burst updates
- selective Konva caching only where measured is useful
- `perfectDrawEnabled={false}` where visually acceptable
- static layers with `listening(false)`
- keep inspector/panels separate from the hot canvas render loop

### Text editing

Use DOM overlays for text entry and menus.

Do not force rich or inline text editing fully inside canvas if it harms IME support or accessibility.

---

## Accessibility and input rules

Canvas is not accessible by default. Accessibility must be designed outside the canvas.

### Required rules

- all core actions must have keyboard-accessible paths on the web
- an important state must be available in DOM UI, not only visually on canvas
- do not rely only on color to communicate state
- touch targets must be large enough for tablet/mobile web
- selection, mode, and save status should be represented outside the canvas too

### Keyboard minimums

Support at least:

- arrow nudging
- delete/backspace remove
- escape cancel
- undo/redo
- zoom shortcuts
- copy/cut/paste where applicable

---

## Mobile and tablet caveat

Konva is the **web** renderer choice.

It is **not** the mobile renderer strategy.

Design now so that future phone and tablet clients can reuse:

- commands
- geometry
- validation
- serialization
- revision logic
- interaction semantics

without depending on Konva internals.

---

## Task classification guide

Before coding, classify the task.

## Belongs in the shared core when it affects:

- document structure
- geometry rules
- snapping
- constraints
- selection semantics
- transforms
- commands/history
- serialization
- copy/paste rules
- any behavior future mobile/tablet clients must share

## Belongs in `editor-renderer-konva` when it affects:

- drawing primitives
- selection visuals
- hit areas
- pointer adaptation
- drag preview
- layer usage
- Konva performance tuning
- DOM overlay anchoring

## Belongs in shell/UI when it affects:

- toolbars
- inspectors
- dialogs
- route/layout
- save status UX
- keyboard shortcut registration
- onboarding/help/status display

### Decision rule

Ask:

> Would this still be needed if Konva were replaced tomorrow?

- **Yes** -> shared core
- **No** -> renderer or shell

---

## Good patterns

### Pattern: event translation at the boundary

- renderer handles Konva event
- renderer converts it into typed editor intent or command
- core receives domain-safe data only

### Pattern: transform normalization

- read Konva transform state
- convert to canonical geometry
- reset the temporary scale where needed
- commit normalized update

### Pattern: persisted state from the editor model

- serialize editor state
- never use `stage.toJSON()` as canonical persistence

---

## Anti-patterns to avoid

Never do these without explicit architectural exception:

1. store Konva refs inside a persistent document state
2. use Konva serialization as the source of truth
3. import Konva into shared editor logic packages
4. put validation rules inside React/Konva components
5. update the global React state on every pointer frame
6. couple undo/redo to renderer mutations instead of commands
7. assume Konva solves the future mobile renderer problem
8. place browser-only APIs in shared editor packages
9. branch domain logic on Konva node classes
10. pass raw event objects into core reducers/use cases

---

## Validation checklist

Before finishing, verify:

- [ ] shared editor logic imports no Konva modules
- [ ] renderer converts events into typed intents or commands
- [ ] geometry is normalized before persistence/state update
- [ ] the persisted state is renderer-agnostic
- [ ] transient visuals stay out of domain state
- [ ] coordinate conversion is explicit
- [ ] performance tweaks are isolated to the renderer adapter
- [ ] core tests run without Konva
- [ ] replacing Konva would not force domain redesign

---

## Delivery expectations for agents

For every Konva-related change:

1. classify the task as core, renderer, or shell
2. state why
3. list affected invariants
4. note mouse and touch impact
5. call out performance implications
6. call out accessibility or text-editing implications
7. add tests at the correct layer

If a task spans multiple layers, implement from the inside out:

`core -> renderer -> shell`

Never start with toolbar wiring if command semantics are still undefined.

