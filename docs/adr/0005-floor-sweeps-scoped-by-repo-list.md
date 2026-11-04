# ADR 5: A floor sweep is scoped by the repo list, not the consumer graph

## Status

Accepted — 2026-11-04

Amends the rollout half of [ADR-0004](0004-min-tests-floor-margin.md) rather than superseding it. The margin rule and the opportunistic default both stand; this adds the half that was missing.

## Context

- [ADR-0004](0004-min-tests-floor-margin.md) says existing floors move **opportunistically** — re-derived whenever a pull request next touches a repo's floor for any reason — and that there is no dedicated back-port sweep.
- That rule assumes a pull request will come. For a stable repo it may not, and the repos least likely to receive one are exactly the repos whose floors go unexamined longest.
- ADR-0004 records that [#23](https://github.com/jjohns-dev/pwsh-module-ci/issues/23) *"picked up the stragglers"* when it changed the floor's input from `tests` to `tests - disabled`. **It did not pick up all of them.**
- An audit on 2026-11-03 found two floors still on the superseded 90% convention: `PS-MCS/ArcGISEnterprise` at **1692** against 1,881 collected — a blind spot of **189 tests** — and `PS-MCS/MCS` at **369 / 122**. Both were set in Phase 2, hours before ADR-0004 landed, and nothing had touched them since.
- **The reason #23 missed them is structural, not an oversight.** Its rollout was staged through the `v1` tag, so it reached exactly the repos that pin `ci.yml@v1`. Measured 2026-11-04: `ArcGISEnterprise` and `PS.ETL` consume `PS-MCS/mcssec-ops/.github/workflows/ps-module-validate.yml@main`, while `MCS` and `SecurityTools` carry an inline copy of the verify step and consume no shared workflow at all. Four of eleven repos were outside the sweep by construction.
- A sweep scoped by *"who consumes the thing I am changing"* is therefore scoped by the duplication the fleet is trying to remove ([#20](https://github.com/jjohns-dev/pwsh-module-ci/issues/20)). The blind spot and the duplication are the same root cause.
- Correcting both took one pass: [ArcGISEnterprise#150](https://github.com/PS-MCS/ArcGISEnterprise/pull/150) moved 1692 → **1871**, and [MCS#216](https://github.com/PS-MCS/MCS/pull/216) moved 369 / 122 → **400 / 130**. The cost of the audit is small; the cost of not running it was a 189-test hole that persisted for six days.

## Decision

- **Any change to the floor's formula or its input carries a fleet-wide floor audit as part of that change's rollout.** Not opportunistic, not deferred — the change is not finished until the audit is.
- **The audit is scoped by the repo list, not by the consumer graph.** Enumerate every repo with a `min-tests` floor and check each one. Do not scope by who pins the workflow being changed: private copies and repos consuming a different shared workflow are invisible to that scoping, and are precisely where stale floors survive.
- For each repo, compare the configured floor against the executed count from its most recent green run, and re-derive under ADR-0004 where they disagree.
- Opportunistic re-derivation remains the default **between** such changes. This ADR does not add a calendar cadence.

## Consequences

- The author of a formula or input change owns more work than before: a sweep over every repo with a floor, not just the ones that pin the workflow. That is the point — it was previously nobody's job, so it did not happen.
- **The audit is manual, and nothing enforces it.** A future change could skip it exactly as #23 did, and the failure mode is silent: a stale floor is a green floor.
- **Suite growth is not addressed and remains an open gap.** A repo that adds tests without touching its floor widens its own blind spot, and no trigger in this ADR fires for that. Nothing currently detects it.
- **Proposed second half, not decided here:** the shipped verify step already computes `executed` on every run, so it could warn when `executed - floor` exceeds ADR-0004's margin. That would make drift self-reporting and remove the need for both the audit and a cadence. It is deliberately left undecided because it changes behaviour for every consumer and so needs its own staged rollout.
- Once [#20](https://github.com/jjohns-dev/pwsh-module-ci/issues/20) lands and the shared files are inherited rather than copied, the consumer graph and the repo list converge, and the distinction this ADR draws stops mattering. Until then it matters a great deal.
