# Product baseline

Status: proposed direction approved for preservation as a future baseline, not a completed implementation.

## Audience and problem

Parents need to coordinate different children, curricula, schedules, and records without repeatedly entering the same information. The product should handle both planned lessons and learning recorded after it happens.

The central promise is: **Plan the week, adapt when life changes, and keep a reliable record of learning.**

## Principles

1. Make daily work clear and quick to record.
2. Allow ordered lessons without mandatory dates.
3. Keep reusable curriculum separate from each child's experience.
4. Distinguish proposed, actual, and finalized information.
5. Make changes reviewable and recoverable.
6. Keep records exportable and owned by the family.
7. Keep the initial product narrow enough to operate sustainably.

## Proposed first release

- Household and student setup; school-year configuration.
- Courses and ordered lesson sequences; simple bulk lesson creation.
- Student assignments, daily checklist, and completion history.
- Retrospective learning entry and activities shared by multiple students.
- Explicit attendance and instructional-time recording.
- Simple grades and final course results.
- Basic record and transcript exports, with configurable grading policies.
- Reliable local persistence, migrations, and a documented recovery/export path.

The baseline prototype also shows reading logs, budgets, receipt concepts, and family pricing. These are candidate later features. They are not all required to validate the first release.

## Deferred scope

- Publisher curriculum marketplace and licensed lesson-plan collections.
- Full curriculum delivery, AI tutoring, or unlimited AI generation.
- State-specific compliance guarantees.
- Social networking, co-op administration, and complex tutor sharing.
- Unlimited attachment storage.
- Simultaneous multi-user editing before conflict handling is designed.

## Main workflows

### Plan ahead

Create a course → define a lesson sequence → assign students → select eligible days → review assignments → save.

### Record a day

View today's work → complete or partially complete assignments → enter actual time if desired → review attendance → confirm → inspect progress.

### Record unplanned learning

Log an activity → select one or more students → record actual date and optional time → optionally attach evidence → review attendance implications. This workflow is required by the review but is not yet designed in the prototype.

### Recover from a missed day

Choose scope → calculate proposed moves → review affected dates and finish date → confirm atomically → allow guarded undo.

### Produce records

Review data → finalize course grades/credits where needed → preview report → generate an immutable report snapshot → export. Later corrections create a new finalized version.

## Commercial hypothesis

Test $29/year per household against alternatives such as $39/year. Price alone is insufficient: the research snapshot includes competitors at $15–$20/year and free products. Validate onboarding speed, regular use, willingness to pay, support effort, and retention before committing to pricing.

At $29/year, 1,000 paying households yield $29,000 gross annual revenue before fees, operations, acquisition, taxes, and development. This arithmetic is not a forecast or a profitability claim.

## Validation

Recruit 5–10 homeschool families to enter a real week of work. Observe setup friction, missed-day recovery, retrospective logging, and report usefulness. Include different ages, multiple children, and flexible teaching styles. Define success thresholds before the pilot rather than inferring product-market fit from positive visual feedback.
