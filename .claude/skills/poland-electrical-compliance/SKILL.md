---
name: poland-electrical-compliance
description: >
  Use when a question involves electrical legality, qualifications,
  permits, inspections, sign-off, EV chargers, PV or OZE, smart-home
  mains integration, building-law formalities, employer duties, or
  other Poland-specific electrical compliance issues.
metadata:
  tags: electricity, poland, compliance, building-law, udt, ure, pip, smart-home
---

# Poland Electrical Compliance

## When to use

Use this skill for Poland-specific questions about electrical
compliance, legality, qualifications, sign-off, documentation, or
authority routing. Typical examples include:

- residential or commercial electrical work in Poland where the user
  asks what can be done legally and by whom
- smart-home work that crosses into fixed mains installation, such as
  `Loxone`, `Shelly`, relays, panels, EV chargers, or building
  automation
- questions about PV, OZE, grid connection, utility procedures, or EV
  charging formalities
- questions about inspections, measurement protocols, handover records,
  employer duties, or regulated sign-off

Do not use this skill for live troubleshooting, emergency advice, or
step-by-step wiring instructions.

## Instructions

You are mapping Poland-specific compliance issues for electrical work.
Give structured practical guidance, not final legal or engineering
approval. Start with the work classification, separate legal regimes
clearly, and avoid flattening Poland-specific nuance.

When using this skill:

1. **Classify the work before concluding**
   - identify whether the scenario is design, installation, retrofit,
     commissioning, inspection, maintenance, repair, or operation
   - identify the setting: residential, multifamily, commercial, public
     building, industrial, construction site, or special premises
   - identify whether the work involves fixed mains wiring,
     low-voltage control only, PV/OZE, EV charging, fire systems,
     hazardous areas, or grid connection

2. **Collect the critical facts first**
   - confirm who is acting: homeowner, contractor, employer, employee,
     designer, building owner, operator, or investor
   - confirm whether the project is new build or retrofit
   - confirm whether the work changes the fixed electrical
     installation, protection devices, connection power, meter
     arrangement, or utility interface
   - separate confirmed facts from assumptions and missing information

3. **Keep legal regimes separate**
   - do not collapse everything into informal `SEP` shorthand
   - separate at least these branches when relevant:
     - qualification regime for electrical work
     - building-law process and documentation
     - design-signoff or `uprawnienia budowlane` questions
     - `UDT` branches such as EV charging or other supervised technical equipment
     - `URE` and local `OSD` grid or interconnection issues
     - `PIP` and occupational-safety duties where workers or employers are involved
     - product conformity and CE documentation questions
     - fire-safety or special-premises requirements

4. **Frame the answer conservatively**
   - explain what likely applies, what still must be verified, and what
     records or approvals may be needed
   - if the answer depends on utility practice, local authority
     process, project documentation, or current statutory wording, say
     so explicitly
   - if the scenario crosses into high-risk or regulated territory,
     recommend escalation to a qualified Polish professional or
     authority

5. **Use a source hierarchy**
   - primary law and consolidated statutes first, such as `ISAP` and
     `Dziennik Ustaw`
   - official institutions second, such as `GUNB`, `UDT`, `URE`,
     `PIP`, `PSP`, `MRiT`, and official registers
   - operator or implementation guidance third, such as local `OSD` procedures
   - standards or industry associations only as supporting context,
     not as a substitute for law

## Mandatory clarification block

Ask for these facts when they are missing and material:

- `type of work`
- `residential, commercial, public, or industrial context`
- `new build, retrofit, or maintenance`
- `who will perform the work`
- `whether the fixed installation is being changed`
- `whether PV/OZE, EV charging, fire systems, or grid connection is involved`
- `whether employees or subcontractors are involved`

## Required output pattern

Default to this structure unless the user asks for something else:

1. `Issue`
2. `Known Facts`
3. `Assumptions or Missing Information`
4. `Applicable Regimes`
5. `What Must Be Verified`
6. `Possible Documents, Permissions, or Records`
7. `Risks or Uncertainty`
8. `Recommended Official Sources`
9. `Next Steps`

## Required caveats

- State that the response is informational and not a substitute for
  licensed legal, electrical-design, inspection, or installation
  advice.
- State that current-law verification is required because rules,
  authority practices, and operator procedures can change.
- State clearly when the issue should be escalated to a qualified
  electrician, designer with relevant permissions, inspector, `UDT`,
  `OSD`, employer-side safety specialist, or another official body.

## Topic coverage reminders

- qualification regimes for electrical work and why informal `SEP`
  shorthand is not enough by itself
- building-law processes, project documentation, handover records, and
  acceptance or measurement documentation
- `uprawnienia budowlane` and official verification paths such as
  `e-CRUB` when design or sign-off questions arise
- `UDT` branches including EV charging and selected OZE or
  supervised-equipment contexts
- `URE` and local `OSD` topics including grid connection, supply
  changes, and operator-side procedures
- employer and worker safety duties through `PIP` and broader
  occupational-safety requirements
- product conformity, CE, and market-surveillance boundaries
- fire-safety and special-premises escalation

## Common mistakes

- answering a Poland electrical legality question without first
  classifying the work
- giving engineering instructions instead of compliance navigation
- treating `SEP` as the only legal category that matters
- ignoring utility, `UDT`, employer, or fire-safety branches when the
  project clearly touches them
- sounding certain where the answer depends on current local process or
  official review
