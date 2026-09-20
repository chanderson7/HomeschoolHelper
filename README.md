# HomeSchoolHelper

Baseline v0.1 · September 20, 2026

An iOS homeschool planning and recordkeeping concept centered on a dependable cycle:

**Plan → teach → adjust → record → export.**

This repository currently contains design prototypes and planning documentation. It does **not** contain a production iOS app, backend, authentication, payments, durable user storage, or real transcript export.

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

- SwiftUI is the proposed native UI framework; no iOS deployment target is chosen yet.
- Begin with a modular monolith and local persistence behind storage interfaces.
- Separate reusable lesson definitions from student assignments and completion records.
- Keep attendance, grades, and credits explicit; completion alone does not create them.
- Preview schedule changes before applying them; preserve completed work.
- Preserve finalized report snapshots and grading-policy versions.
- Introduce backup and recovery before multi-user cloud editing.
- Treat $29/year per household as a pricing hypothesis, not an approved commercial offer.

## Future changes

Use this baseline as a starting point rather than treating every proposal as settled. Resolve the open decisions in the roadmap, update the relevant specifications, and record material changes in [CHANGELOG.md](CHANGELOG.md). Preserve the distinction between implemented behavior, prototype simulations, and planned work.
