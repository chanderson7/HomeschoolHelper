# HomeschoolEZ

First native milestone · September 20, 2026

An iOS homeschool planning and recordkeeping app in early development, centered on a dependable cycle:

**Plan → teach → adjust → record → export.**

The repository includes a SwiftUI iOS app, a tested domain layer, local JSON persistence, and the original design baseline. This is an early engineering milestone, not a production release. There is no backend, authentication, payments, cloud sync, or transcript export yet.

## Run the native app

Open `HomeSchoolHelper.xcodeproj` in Xcode 26+ and choose the `HomeSchoolHelper` scheme and an iPhone simulator. The app targets iOS 17+. Physical devices require your own signing team.

```sh
sh scripts/test-core.sh
sh scripts/build-ios.sh
```

Implemented: add students; create shared lesson sequences with independent assignments; dated or flexible planning; planned/in-progress/completed/skipped status; explicit attendance; retrospective multi-child activity logs; save and reload local records. Failed loads block editing, and failed saves retain the last saved state.

See [development instructions](docs/development.md), [milestone contract](docs/implementation-contract.md), and [implementation report](docs/implementation-report.md) for verification and limits.

## Start here

- [Product baseline and release scope](docs/product-baseline.md)
- [Screen specifications and prototype behavior](docs/screens.md)
- [Architecture, interactions, and reusable modules](docs/architecture.md)
- [Review from multiple perspectives](docs/design-review.md)
- [Research and pricing snapshot](docs/market-research.md)
- [Implementation roadmap and open decisions](docs/roadmap.md)

## Explore the design

Open `design/prototype/index.html` in a modern browser. It is a standalone export with no build or account setup required. Choose **See every screen** for the thirteen-screen overview, or **Try the prototype** for individual interactions. GitHub's file view displays source; download or clone the repository to open the HTML locally.

The demo uses fictional people and sample educational records. Edits exist only in memory and reset when the page is reloaded. The full screen set expresses a longer-term direction, not a commitment to ship every screen in the first release.

The editable fragment is [design/source/homeschool-screen-prototypes.html](design/source/homeschool-screen-prototypes.html). The standalone export is generated from it; see [design/README.md](design/README.md).

## Baseline decisions

- SwiftUI and iOS 17+ are selected for the first native milestone; see [ADR 0001](docs/decisions/0001-local-first-milestone.md).
- Begin with a modular monolith and local persistence behind storage interfaces.
- Separate reusable lesson definitions from student assignments and completion records.
- Keep attendance, grades, and credits explicit; completion alone does not create them.
- Preview schedule changes before applying them; preserve completed work.
- Preserve finalized report snapshots and grading-policy versions.
- Introduce backup and recovery before multi-user cloud editing.
- Treat $29/year per household as a pricing hypothesis, not an approved commercial offer.

The principles above include future requirements. Advanced rescheduling, finalized academic records, exports, backup/restore, and cloud sharing are not implemented in this milestone.

## Future changes

Use this baseline as a starting point rather than treating every proposal as settled. Resolve the open decisions in the roadmap, update the relevant specifications, and record material changes in [CHANGELOG.md](CHANGELOG.md). Preserve the distinction between implemented behavior, prototype simulations, and planned work.
