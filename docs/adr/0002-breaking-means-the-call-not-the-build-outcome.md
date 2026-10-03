# ADR 2: Breaking Means the Call Stops Working, Not the Build Stops Passing

Amends: ADR-0001

## Status

Accepted — 2026-10-02

## Context

- ADR-0001 commits consumers to the moving `@v1` tag and states that "a breaking change to inputs or job structure bumps to `v2`", without defining either term.
- Consumers depend on more of this repo than its input surface. They depend on job names (branch-protection required status checks are configured by job name), on the `permissions:` their caller block grants, on input defaults, and on the workflow's observable side effects such as uploaded artifact names.
- A renamed job does not fail anything in the consumer. Its required status check simply stops matching, and the branch becomes ungated silently. This repo cannot read a consumer's branch-protection configuration, so nothing here can detect it.
- A `with:` key the called workflow does not declare is a workflow-resolution error, not a warning. Removing an input a consumer passes breaks that consumer on its next run, with no deprecation period available.
- Separately, a change can turn a consumer's build red **without** breaking anything it configured. The result-verification step added in #8 does exactly that: the caller's `uses:` block is untouched and still valid, but builds that were previously — and wrongly — green now fail, because the check detects a defect that was always there.
- Those two situations have opposite correct responses. The first is a contract the consumer must be given time to migrate. The second is a correctness fix whose entire purpose is to stop being ignored.
- The cost of a `v2` is paid per consumer: six repos each need their own PR to repoint `uses:`, and ADR-0001 lets them migrate on their own schedule — so the fleet runs split versions until the last one lands, and this repo maintains both majors meanwhile.
- `enable-test-report` existed only as an escape hatch for a consumer configuring Pester with `NUnitXml`. As of 2026-10-02 all six consumers emit `JUnitXml` and none passes the input. A literal reading of ADR-0001 charges the full `v2` cost to remove it.
- Because consumers pin to a moving tag, this repo has no mechanism to detect a consumer that starts depending on something after it has been checked. The only signal is that consumer's CI failing.

## Decision

- We will define a **breaking** change as one that stops a consumer's call from working as configured, and bump the major version for it. Non-exhaustively, that includes:
  - removing or renaming an input that any consumer passes, or adding a required input;
  - renaming or removing a job, because it silently un-gates every consumer whose branch protection names it;
  - requiring a `permissions:` scope that consumers do not already grant;
  - changing an input's default such that a consumer relying on the default gets materially different behavior;
  - renaming or removing a workflow output, or an artifact name a consumer consumes downstream.
- We will **not** treat a change as breaking merely because it turns a passing build red, where the call itself remains valid and the new failure reflects a real defect in the consumer. A major bump there would let consumers opt out of a correctness fix indefinitely, which inverts the reason this repo is centralized.
- We will stage every change that can alter a consumer's CI outcome behind the moving `v1.<minor>` tag, and move `v1` only once each consumer is confirmed green or deliberately fixed. This, not the version number, is the mechanism that controls blast radius.
- We will treat removal of an input as a **minor** when no consumer passes it, verified by inspecting every consumer repo at the time of removal, with that verification recorded in the pull request.
- We will ship the removal of `enable-test-report`, and the result-verification step, as `v1.3.0`.

## Consequences

- **Positive** — a six-repo coordinated migration is not spent on changes no consumer can observe, which keeps the `v2` signal meaningful for the changes that genuinely require someone to act.
- **Positive** — naming job renames as breaking captures the one failure mode here that is both high-impact and completely silent, which the previous wording left to inference.
- **Positive** — the verification behind a minor version lands in the PR record, so the claim is auditable after the fact rather than asserted.
- **Negative** — "still `v1`" now guarantees only that a consumer's call keeps resolving, not that a passing build keeps passing. That is a real reduction in what the pin promises, and it is the deliberate price of being able to ship correctness fixes to the whole fleet.
- **Negative** — the job-rename rule is honor-system. This repo cannot read consumer branch-protection settings, so nothing detects a violation; it depends on whoever edits a job name remembering this record exists.
- **Negative** — "materially different behavior" from a changed default is a judgement call with no test attached, and will eventually be argued about.
- **Negative** — correctness of the unused-input rule rests on a point-in-time scan. A consumer that starts passing a removed input between the scan and the `v1` move breaks with a resolution error, and nothing here would catch it.
- **Negative** — ADR-0001 now contains statements that are false on their face. Its Status section flags them and links here, but a reader who quotes ADR-0001 without reading its Status will get the old rule.
- **Neutral** — the moving `v1.<minor>` tag becomes load-bearing rather than a convenience, since it is now the only staging mechanism between merge and fleet-wide rollout.
- **Neutral** — these rules bind every future change here, not just `enable-test-report`; the verification and the staging are standing obligations.
