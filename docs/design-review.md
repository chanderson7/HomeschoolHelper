# Multi-perspective design review

Overall: a strong starting point, with scope and data semantics requiring refinement before production implementation. This is a conceptual review; it does not claim code, accessibility, security, or performance verification.

## Parent and student

**Strength:** a clear daily checklist and flexible planning.

**Gap:** planned, separate lessons do not cover retrospective logging, shared family activities, substitutions, or partial completion.

**Action:** add Log learning and multi-child activity workflows. Keep individual completion/time/assessment records. Design a smaller student experience with only assigned work and permitted feedback.

## Product and business

**Strength:** a coherent need for planning and durable records.

**Gap:** the design encompasses several products and could overextend a small team. Pricing and demand are unvalidated.

**Action:** validate the plan–teach–adjust–record–export cycle first. Defer marketplace, social, complex sharing, and large storage promises. Track support effort as well as conversion.

## UX and accessibility

**Strength:** calm visual language and consistent tab navigation.

**Gap:** decorative headings consume space; small muted text needs verification; happy-path screens omit important states. Missing and zero values may be confused.

**Action:** concise functional headings, Dynamic Type, VoiceOver, adequate contrast/touch targets, explicit labels, and empty/loading/error/offline/recovery designs. Show schedule downstream impact and resulting finish date.

## Architecture

**Strength:** separation of lesson content from student-specific work.

**Gap:** modules could become tightly coupled through shared tables or implicit events. Premature packages can create overhead.

**Action:** explicit workflows and read interfaces; Reporting does not own academic source data. Keep Attendance and Assessment separate. Start with a modular monolith.

## Data and educational records

**Strength:** a foundation for reuse and historical reporting.

**Gap:** planned/actual dates, raw/final grades, and completed/credited courses are not interchangeable.

**Action:** explicit finalization, versioned grading policies, immutable finalized report snapshots, and correction history.

## Scheduling

**Strength:** missed-day recovery is a valuable workflow.

**Gap:** fixed dates, partial work, school calendars, multiple children, and workload constraints make it more complex than a date offset.

**Action:** calculate proposals without mutation, show all relevant effects, revision-check before atomic application, guard undo against later edits.

## Privacy and security

**Strength:** household scope is recognized early.

**Gap:** household membership alone does not define student/tutor permissions; shared devices and attachments need equivalent protection.

**Action:** least-privilege role matrix, scoped access enforcement, minimal data collection, export/deletion/retention policy, and attachment authorization. No production security assurance is implied by the prototype.

## Reliability and operations

**Strength:** local-first use reduces dependence on network availability.

**Gap:** local storage is not backup; synchronization is not automatically safe collaboration.

**Action:** verified restore, schema migrations, explicit save/sync states, retries, deletion propagation, and conflict handling before shared editing.

## Testing

Focus tests on risk-bearing rules:

- Holiday/fixed-date scheduling and preservation of completed work.
- Reschedule preview, atomic apply, stale proposals, and guarded undo.
- Missing grades, weights, rounding, credits, and GPA policies.
- Attendance deduplication and duration aggregation.
- Exact monetary calculations.
- Data migration and backup restoration.
- Household and role access restrictions.
- Stable finalized report output and accessible UI.

Use a small end-to-end suite for the full core workflow. Do not substitute broad UI test counts for verified academic-record correctness.

## Reuse and maintainability

**Strength:** scheduling, reporting, logs, attachments, and UI components have plausible reuse.

**Gap:** a generic framework built before another product exists could slow delivery and blur business rules.

**Action:** narrow interfaces now; extract libraries after demonstrated reuse.

## Prioritized actions

| Priority | Action | Reason |
|---|---|---|
| P0 | Define assignment, completion, attendance, and credit semantics | Prevent foundational data errors |
| P0 | Design retrospective and multi-child workflows | Cover important family behavior |
| P0 | Reduce initial release scope | Improve delivery and quality |
| P0 | Define finalization and snapshots | Protect historical record accuracy |
| P1 | Define permissions before sharing | Avoid expensive access-model retrofits |
| P1 | Specify migration, export, backup, restore | Protect long-lived data |
| P1 | Design accessibility and failure states | Cover real usage |
| P2 | Extract proven reusable modules | Avoid speculative abstraction |
