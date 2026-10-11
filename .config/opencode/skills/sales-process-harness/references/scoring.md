# Provisional Opportunity Scorecard

This rubric is a working aid, not Divante/Cloudflight policy. Weights are
provisional and have no automatic decision thresholds. The user makes every
pursuit, bid, pricing, and staffing decision.

## Dimensions and weights

- **Outcome/problem clarity (20%):** Evidence that the business problem,
  baseline, desired outcome, and success measures are understood.
- **Evidenced capability fit (20%):** Evidence linking the requested work to
  demonstrated capabilities; flag gaps and unverified claims.
- **Solution/delivery feasibility (15%):** Scope, architecture, dependencies,
  delivery constraints, and credible path to validate feasibility.
- **Buying process/stakeholders/timing (15%):** Decision roles, procurement
  steps, access to stakeholders, decision date, and trigger/timing evidence.
- **Differentiation/competition (10%):** Customer-relevant distinction and
  verified alternatives/competitors; unknown competition stays unknown.
- **Commercial viability (10%):** Approved economics only; otherwise mark
  `Not assessed—approved economics not supplied`.
- **Pursuit effort relative to value/reuse (10%):** Evidence-backed pursuit
  effort compared with potential value and reusable learning/assets.

The listed weights sum to 100%. Do not invent an economic model or company
pricing/margin rule. An estimate structure may list work packages, assumptions,
dependencies, and unknown inputs without filling unsupported rates or totals.

## Rating scale

Rate an assessable dimension from 1 to 5 and explain the evidence and rationale.
Use the same anchors consistently:

- **1:** Material mismatch or adverse evidence.
- **2:** Weak fit; important gaps or risks remain.
- **3:** Mixed/conditional fit; viable path depends on validation.
- **4:** Strong fit supported by relevant evidence.
- **5:** Very strong fit with specific, compelling evidence.

Use `Unknown` rather than assigning a low rating when evidence is insufficient.
Do not use 0. A low rating is evidence of a poor fit; unknown is an evidence gap.
Record a short rationale and the evidence reference for each rated dimension.

## Calculation and confidence

Let `A` be the dimensions with enough evidence to assign a 1–5 rating. Exclude
unknown dimensions from both numerator and denominator:

```text
weighted score = sum(weight_i × rating_i for i in A)
                 / sum(weight_i for i in A)
```

The result stays on a 1–5 scale. Show one decimal place and list the denominator
weight used. Show weighted evidence coverage separately:

```text
weighted evidence coverage = sum(weight_i for i in A) / 100 × 100%
```

Coverage uses the full 100% rubric as its denominator. If approved economics
were not supplied, commercial viability is unassessed and coverage can reach at
most 90%. If no dimension is assessable, show score `N/A`, coverage `0%`, and
explain that evidence is insufficient. Never count an unknown as zero.

Give overall confidence as `Low`, `Medium`, or `High`, with a reason based on
source quality, recency, directness, and coverage. Sparse, indirect, or
contradictory evidence should lower confidence even when the arithmetic score
looks strong. Confidence is a judgment about the evidence, not deal quality.
Do not set pass/fail thresholds, convert scores to probabilities, or claim the
rubric is calibrated against historical company outcomes.

## Suggested scorecard display

For every dimension show: weight, rating or `Unknown`, evidence/source, concise
rationale, and confidence where useful. End with:

- weighted score and assessed-weight denominator (or N/A);
- weighted evidence coverage;
- overall confidence and why;
- material unknowns and actions that could resolve them;
- an advisory recommendation with no automatic decision implied.
