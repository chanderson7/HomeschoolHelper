# Agent team: first implementation milestone

The user authorized a strong lead model with lighter implementation workers running in parallel.

## Roles and task boundaries

| Role | Model requested | Owned work | Acceptance |
|---|---|---|---|
| Lead | Parent strong reasoning model | Shared contracts, Package.swift, Xcode project, integration, documentation | Compatible modules, build and integrated tests, honest status |
| Core worker | GPT-5.6 Terra, high reasoning | `Sources/HomeschoolCore/` | Validated records, deterministic civil-date scheduling, atomic persistence |
| UI worker | GPT-5.6 Terra, high reasoning | `iOS/HomeSchoolHelper/` | Native four-tab flow, real forms, save-before-publish, error states |
| Test worker | GPT-5.6 Luna, high reasoning | `Tests/HomeschoolCoreTests/` | Independent business-rule and save/reload tests |
| Store test worker | GPT-5.6 Luna, high reasoning | `Tests/HomeschoolStoreTests/` | Save failures, load failures and recovery |
| Independent reviewer | GPT-6 Astra, high reasoning | Read-only core review | Identify correctness risks before integration |

The source of truth is [implementation-contract.md](implementation-contract.md). Workers receive concise fresh task briefs rather than the full conversation. Parallel work is limited to non-overlapping paths. Shared API changes are coordinated through the lead before edits.

## Integration workflow

1. Lead defines scope, API spelling, invariants, and ownership.
2. Workers implement concurrently and report ambiguities.
3. Lead reviews changes and resolves integration issues.
4. Run core tests and native build checks.
5. Document limitations and follow-up work; commit the integrated milestone.

Task completion is based on verified code behavior, not an agent's assertion alone. No worker publishes, changes credentials, or performs repository-wide refactors. The lead handles Git integration.

## Reusing this approach

Assign strong models ambiguous architecture, schema changes, scheduling policy, and final review. Give smaller models bounded components with clear interfaces and tests. Use isolated file ownership or worktrees when changes overlap. Escalate repeated failures or uncertain rules instead of retrying indefinitely. Parallel agents may increase total token use; evaluate accepted changes and rework rather than assuming lower model cost means lower project cost.

This document records the workflow used in this task. It is not an automatically loaded agent configuration or permission to spawn agents in unrelated future tasks.
