# ADR 4: The min-tests floor margin is capped, not a flat percentage

## Status

Accepted — 2026-10-28

Applies to every floor derived from this date forward. Existing floors move to it opportunistically rather than in a dedicated sweep; see Consequences.

## Context

- The `min-tests` floor exists to catch part of a suite silently dropping out of collection — a discovery failure, a file no longer being picked up, a mass-skip regression.
- Every floor derived during the 2026-10 rollout used 90% of collected, giving a margin that scales with suite size: 10 tests in `PS.Log`, 107 in `SecurityTools`, 189 in `ArcGISEnterprise`.
- **A floor only trips on a decrease.** Adding tests never trips it, so the margin is not absorbing normal churn. The only thing it absorbs is deliberate test removal, which already requires a floor update in the same pull request.
- No legitimate source of small decreases was identified. Per-leg counts are deterministic, skipped tests are still counted, and platform differences are handled by separate per-leg floors.
- Measured test density across the fleet is **12 to 25 tests per command** (`MCS` ~12, `AWSAutomation` ~13, `ArcGISEnterprise` ~14, `PS.Log` and `SecurityTools` ~16, `PS.SSL` ~25).
- At 90%, `ArcGISEnterprise` can therefore lose roughly **thirteen commands' worth** of tests and stay green. Under a flat 5% it would still lose six. The regression the floor exists to catch is smaller than its own tolerance.
- A percentage implies that larger suites deserve larger blind spots. That is backwards: a larger suite has more files and more commands, so more opportunities for one to vanish, and each is a smaller fraction of the total. The thing being detected does not scale with suite size.
- A flat 3% was considered and rejected: `floor(21 * 0.03)` is zero, so any leg under ~33 tests becomes an exact-match assertion that reddens on a single test disappearing for any reason.

## Decision

- The floor is `collected - margin`, where **`margin = min(floor(collected * 0.05), 10)`**.
- Read aloud: *five percent of collected, but never more than ten tests*.
- The percentage term exists only so that very small legs do not get a zero margin. The cap is the operative part.
- The cap of 10 is calibrated, not arbitrary: it sits just below the smallest per-command test density in the fleet, so losing a single command's worth of tests trips the floor in every repo.
- This supersedes the previous convention of `floor(collected * 0.9)` and removes the need for its small-leg exception — `SecurityTools`' windows leg was hand-reasoned to 20 against 21 collected, and this formula yields exactly 20.
- The floor is derived **after** the fixes in a pull request land, read from that run's JUnit artifact. Never predicted, never carried forward from a previous value.

## Consequences

- Every floor becomes materially tighter. `ArcGISEnterprise` goes from a 189-test blind spot to 10, `SecurityTools` from 107 to 10.
- **Existing floors move opportunistically, not in a dedicated sweep.** A repo's floor is re-derived under this formula the next time a pull request touches that repo's floor for any reason. There is no separate back-porting exercise, because re-deriving a floor costs a measure-and-verify cycle and bundling it with work already in flight is free. jjohns-dev/pwsh-module-ci#23 picks up any stragglers when it changes the floor's input from `tests` to `tests - disabled`.
- **So the documented rule and the deployed values will disagree for a while, by design.** A repo still sitting at the old 90% convention is not a bug and does not need an issue filed against it. Check the repo's last floor-touching pull request before concluding otherwise.
- It still does not catch a single small test file dropping out. A six-test unit file vanishing stays under a margin of 10. The floor is a blunt instrument for catastrophic collection failure; granular detection needs a different mechanism, such as a committed expected-count, and squeezing the floor further is the wrong tool.
- A two-term rule is marginally more likely to be misremembered than a one-term rule. The mitigation is that it is written here and pointed at from `docs/shared-ci-standards.md`, rather than re-derived from memory each time.
- Deliberate test removal now reddens CI sooner, since there is less slack to absorb it. That is intended: the floor update belongs in the same pull request as the removal.
