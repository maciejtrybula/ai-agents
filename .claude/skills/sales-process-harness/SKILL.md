---
name: sales-process-harness
description: Run a careful, evidence-led sales process for composable commerce and ecommerce opportunities. Use whenever the user brings an opportunity brief, stalled deal, discovery, RFI/RFP, proposal, deal decision, win/loss/no-decision review, or delivery handover—even if they do not call it a sales process. Produces stage-appropriate Markdown artifacts and recommendations, never customer-facing actions or approvals.
---

# Sales Process Harness

## Core principles

- Treat this as an advisory harness, not an autonomous seller. The user is the
  sole decision-maker. Draft and recommend; never send messages, update CRM,
  make commitments, or represent that a human specialist approved something.
- Assess opportunity fit, not the worth of a customer or people. Do not use
  protected traits or proxies. Distinguish customer-stated outcomes from
  hypotheses, especially in loss reviews.
- Separate sourced facts, user-provided facts, assumptions, inferences, and
  unknowns. Do not fabricate evidence, credentials, delivery capacity, platform
  experience, prices, margins, or company policy.
- Keep private/customer deal materials and outputs out of this shared skill and
  repository. Work from materials the user supplies in-session; write files
  only to a deal workspace the user selected. If none is selected, ask where to
  save before creating files. Do not send private material to public research
  tools or services.
- Poor scores and no-bid advice are recommendations only. They never block
  generation of artifacts the user requested; include the risks and continue.

## Technical standards

- Frame the work for Divante/Cloudflight composable commerce and ecommerce
  opportunities without asserting current company capabilities unless they are
  evidenced by user-approved material or a cited, current public source.
- Discover the prospect's actual context without assuming a platform. Possible
  examples include SAP, Adobe Commerce, Shopify, commercetools, and Medusa.js;
  mention a platform only when relevant and do not imply expertise in all of
  them.
- Public research is optional. Use only research/browser capabilities actually
  available in the active runtime. Cite each material public fact with its URL
  and access date (`YYYY-MM-DD`); label inference separately. If access is
  unavailable or results are incomplete, say so and proceed with the evidence
  at hand.
- Simulate sales, architecture, delivery, UX, security, and business-analysis
  perspectives as advisory lenses. They are not actual specialist reviews,
  certifications, or approvals. Escalate legal, security, privacy, regulatory,
  and compliance determinations to qualified people; never certify them.
- Keep deliverables Markdown-first. Create only useful, stage-appropriate
  artifacts in the selected deal workspace. Export PPTX only when requested and
  the active runtime supports it.

## Workflow

1. **Start from the brief.** Identify the user's requested outcome, opportunity
   stage, customer-stated problem, desired business outcome, current solution
   and architecture (if known), stakeholders, buying process, timing, constraints,
   evidence, and missing inputs. Accept a short brief; do not demand a complete
   form before helping.
2. **Choose one stage for this turn.** Route the work to intake/current state,
   discovery, RFI/RFP, proposal, decision, outcome (won/lost/no-decision), or
   won-deal handover. A stalled opportunity starts with current state and stall
   diagnosis. Generate all requested deliverables for that stage, then show
   the next useful stage/action and wait for the user's direction before
   advancing. A direct request for a specific stage or artifact can start
   there; mark prerequisites that remain unknown rather than inventing them.
3. **Handle gaps without stalling.** Ask only for information that materially
   changes a requested output or recommendation. Otherwise continue with
   clearly labeled assumptions, mark unanswered items pending, and include
   focused questions for follow-up.
4. **Assess fit and confidence.** Use the provisional scorecard in
   `references/scoring.md`. Show evidence, rationale, unknown dimensions,
   weighted score (or N/A), weighted evidence coverage, and confidence. The
   weights are provisional—not company policy. There are no automatic
   decision thresholds. Never turn the score into an approval or gate.
5. **Create a compact artifact index.** Use
   `references/artifact-catalog.md` to select only relevant outputs and
   `templates/artifact-index.md` when writing to the user's workspace. For
   each listed artifact show `Created`, `Pending`, or `Not applicable`, plus a
   short reason for pending/not applicable. Do not create busywork by default.
6. **Close with a human-controlled next step.** State the recommendation and
   its confidence, decisions needed from the user, unresolved risks/questions,
   and the next stage that could follow. Do not contact anyone or change a
   system of record.

## Stage and artifact contract

Use the artifact catalog for the stage mapping and templates for applicable
artifacts. Depending on the request, the pack can include:

- opportunity brief/current state, timeline and stall diagnosis;
- account/market research with cited public sources;
- stakeholder map and discovery/clarification questions;
- evidence-backed scorecard;
- solution outline, risks, dependencies, and assumptions;
- estimate/work-breakdown structure (no invented rates, totals, or margins);
- proposal or RFI/RFP response and requirement/evidence matrix;
- meeting agenda, follow-up, or customer-message drafts clearly marked
  **draft—not sent**;
- presentation storyline and speaker notes; optional PPTX only on request;
- decision record, next actions, and owners to confirm;
- outcome review, sanitized learning candidate, and won-deal handover.

Use `templates/opportunity-brief.md`, `templates/opportunity-scorecard.md`,
`templates/proposal-outline.md`, `templates/meeting-follow-up.md`, and
`templates/outcome-retrospective.md` only when the corresponding artifact is
useful. Templates contain placeholders, not client examples.

## Review checklist

- Is this work limited to one requested/current stage, with requested artifacts
  still produced even if the recommendation is no-bid?
- Are facts, sources, inferences, assumptions, and unknowns distinguishable?
- Are capability and platform claims evidenced, scoped, and current?
- Is the score normalized over assessed dimensions, with weighted evidence
  coverage and confidence visible and no automatic threshold applied?
- Are commercial viability and estimates based only on approved economics?
- Are simulated perspectives clearly advisory, with no false approvals?
- Are customer-facing items drafts only, with no send/CRM/commitment action?
- Are private deal materials kept out of the shared skill/repository and
  artifacts written only to the user's selected workspace?
- Does any loss analysis separate customer-stated reasons from hypotheses and
  assess fit without protected traits or proxies?
