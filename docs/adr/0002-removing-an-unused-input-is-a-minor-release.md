# ADR 2: Removing an Unused Input Is a Minor Release

Amends: ADR-0001

## Status

Proposed — 2026-10-02

## Context

- ADR-0001 commits consumers to the moving `@v1` tag and states that "a breaking change to inputs or job structure bumps to `v2`". It does not distinguish adding an input, changing one's default, or removing one.
- ADR-0001's Context lists `enable-test-report` among the inputs consumers require. That was accurate when it was written on 2026-09-14.
- `enable-test-report` existed only as an escape hatch for a consumer configuring Pester with `NUnitXml`. As of 2026-10-02 all six consumers emit `JUnitXml` and none passes the input.
- A `with:` key that the called workflow does not declare is a workflow-resolution error, not a warning. Removing an input that a consumer *does* pass breaks that consumer on its next run, with no deprecation period available.
- The cost of a `v2` is paid per consumer: six repos each need their own PR to repoint `uses:`, and ADR-0001 lets them migrate on their own schedule — so the fleet runs split versions until the last one lands, and this repo must maintain both majors meanwhile.
- A literal reading of ADR-0001 charges that cost for every input removal, including one that no consumer can observe.
- Because consumers pin to a moving tag, this repo has no mechanism to detect a consumer that starts passing a removed input; the only signal is that consumer's CI failing.

## Decision

- We will scope "breaking" in ADR-0001 to mean *observable by a consumer at its current pin*, rather than any change to the input surface.
- We will treat removal of an input as a **minor** release when no consumer passes it, and as a **major** release when any consumer does.
- We will verify "no consumer passes it" by inspecting all consumer repos at the time of removal, and record that verification in the pull request that removes the input.
- We will stage every release that can change a consumer's CI outcome behind the moving `v1.<minor>` tag, moving `v1` only once each consumer has been confirmed green or deliberately fixed.
- We will ship the removal of `enable-test-report` as `v1.3.0` under this rule.

## Consequences

- **Positive** — a six-repo coordinated migration is not spent on a change no consumer can observe, which keeps the `v2` signal meaningful for changes that genuinely require action.
- **Positive** — the verification is cheap (one search across six known repos) and lands in the PR record, so the claim behind the minor version is auditable later.
- **Negative** — correctness now rests on a point-in-time scan that this repo cannot enforce. A consumer that adds the removed input between the scan and the `v1` move breaks with a resolution error, and nothing here would catch it.
- **Negative** — the semver contract is weaker than it reads. A consumer can no longer infer from "still `v1`" that its existing `with:` block remains valid, which is precisely what a major-version pin normally buys.
- **Negative** — ADR-0001 now contains two statements that are false on their face. Its Status section flags both and links here, but a reader who quotes ADR-0001 without reading its Status will get the old rule.
- **Neutral** — the moving `v1.<minor>` tag becomes load-bearing rather than a convenience, since it is now the only staging mechanism between merge and fleet-wide rollout.
- **Neutral** — this rule applies to any future input removal, not just `enable-test-report`; the verification step is a standing obligation on whoever removes one.
