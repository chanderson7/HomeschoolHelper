# Implementation roadmap and decisions

This is a sequencing proposal, not a schedule or commitment. No production phase is marked complete.

## Phase 0 — Resolve semantics and validate workflows

- Interview/pilot with 5–10 families using real weekly planning scenarios.
- Define dates, completion states, attendance/time, grading and credit policies.
- Add retrospective and multi-child learning designs.
- Choose target iOS version, persistence approach, and initial device support.
- Establish accessibility and record-correctness acceptance criteria.

Exit: a documented first-release scope and reviewed data model with representative edge cases.

## Phase 1 — One complete local workflow

Student → course → lesson sequence → assignment → completion → confirmed attendance → record summary.

- Native SwiftUI navigation and accessible forms.
- Storage interfaces, local persistence, migrations, complete data export.
- Ordered undated work and basic eligible-day scheduling.
- Retrospective activities and individual records for shared learning.

Exit: the workflow survives app restart and produces correct records without a network.

## Phase 2 — Reliable scheduling and academic records

- Real reschedule proposal/apply/undo with conflict guards.
- Score entry, explicit policies, final course results and credits.
- Report previews, finalized snapshots, actual PDF/CSV exports.
- Backup and restore verification.

Exit: agreed scheduling, calculation, migration, restoration, and report tests pass.

## Phase 3 — Broader utility

- Reading/activity logs and lightweight budgeting.
- Receipt/work-sample attachments with limits and lifecycle rules.
- Additional report formats based on observed family needs.

Exit: measured user value justifies added maintenance and operating cost.

## Phase 4 — Optional cloud and commercial operation

- Identity, household permissions, multi-device sync, explicit status.
- Conflict resolution, retry/idempotency, deletion and attachment handling.
- Student access; tutor scope only when validated.
- Billing and entitlements after pricing validation.

Exit: permissions, restore, sync/conflict, and lifecycle behavior are verified before shared editing launches.

## Open decisions

| Decision | Current position | Required evidence |
|---|---|---|
| Minimum iOS/device support | Unselected | Audience/device needs and API tradeoffs |
| Local database | Unselected; behind interfaces | Relationships, migrations, sync compatibility |
| Cloud provider | Deferred | Identity, access, conflict, attachment and cost requirements |
| Missed-day policy | Preview and confirm | Extend vs compress; workload limits; fixed dates |
| Partial completion | Required, semantics unresolved | Family workflows and data invariants |
| Attendance aggregation | Explicit confirmation | Multi-activity/day deduplication and time rules |
| Grading policies | Configurable and versioned | Scales, rounding, weighting, missing/excused work |
| Credit finalization | Separate from completion | Parent approval and correction workflow |
| Student access | Restricted | Parent controls and shared-device behavior |
| Storage and retention | No unlimited promise | Costs, backup/export/deletion needs |
| Pricing | Test $29 and $39 annual household plans | Willingness to pay, support and retention |

## Future baseline changes

Record major architecture decisions with context, alternatives, decision, and consequences. Update prototype behavior and documentation together. Never mark a feature implemented based solely on a mockup, a navigation button, or a generated plan.
