# Rollout tracker

**Temporary working file. Delete it when the last box is checked.** It exists to coordinate one batch of cross-repo work; it is not a permanent part of this repo and nothing reads it.

Authoritative detail lives in the linked issues — this is an index and an ordering, not a substitute. Where the two disagree, the issue wins.

## Where we are

Phase numbers are **names, not a sequence**. They were assigned before #22 moved and before the Phase 2B debt surfaced, and they are cited from issue bodies and merged PRs, so they are not being renumbered. The table below is the running order, agreed 2026-11-04.

| | Phase | State |
| - | ----- | ----- |
| ✓ | **1**, **2**, **2B**, **7** | complete 2026-10-27 to 10-29. Narratives drained 2026-11-04; the issues and PRs are authoritative |
| ✓ | **3** — make regressions visible | complete 2026-11-03. The floor measures **executed**, shipped as `v1.5.0` and live fleet-wide |
| ✓ | **4** — close the tracker issue | complete 2026-11-03 — #17 closed after auditing every box against the repos |
| ✓ | **8** — drain this file | **complete 2026-11-04** — [#43](https://github.com/jjohns-dev/pwsh-module-ci/issues/43), closed. 391 lines to 117 |
| ✓ | [#27](https://github.com/jjohns-dev/pwsh-module-ci/issues/27) | **complete 2026-11-04** — `pssa-sarif.yml` moved to `Install-PSResource`, released as `v1.5.1`, `v1` moved and verified on a live consumer run |
| → | **5** — stop the duplication | **in progress.** Items 1–8 complete 2026-11-05 to 11-13: every consumer runs the shared harness and the shared test minimum at `@v2` (`v2.1.1`), and `v1` is retired. Remaining, in order: [#55](https://github.com/jjohns-dev/pwsh-module-ci/issues/55), centralizing help as its own release (no longer optional, agreed 2026-11-13), then [ArcGISEnterprise#153](https://github.com/PS-MCS/ArcGISEnterprise/issues/153) joins as the ninth consumer (deferred by choice). Phase 6 follows |
| | **6** — migration | [#19](https://github.com/jjohns-dev/pwsh-module-ci/issues/19) only. #21 moved into Phase 5 on 2026-11-05, once [ADR-0006](docs/adr/0006-host-the-build-harness-in-this-repo.md) removed its dependency on the Sampler decision |
| | **Final phase** — delete this file | once it has nothing left to carry |

Completed phases are closed. New work goes in a later phase or a new one, never back into a phase already marked done — Phase 2B exists because that rule was applied rather than reopening Phase 1.

**The table above is the running order. The section order below is not** — sections sit where their phase number put them, and phase numbers are names. Read the table to find what is live; read a section for its detail.

## Phase 5 — Stop the duplication

**`jjohns-dev` repos only.** `PS-MCS` is downstream: changes are incubated and vetted here, then promoted, so its repos are not in scope for this phase and will pick the work up with that promotion.

- [x] **pwsh-module-ci** — [#24](https://github.com/jjohns-dev/pwsh-module-ci/issues/24) — **complete 2026-11-05**
  `BuildHelpers` is absent from all ten module repos across both orgs; renaming the `$env:BH*` assignments was decided against. Measurements on #24 and [#20](https://github.com/jjohns-dev/pwsh-module-ci/issues/20).

### The remaining sequence, agreed 2026-11-05

Ten items, in order. The ordering is not arbitrary and it is not a simple chain — each item records what it gates.

- [x] **1 — [#53](https://github.com/jjohns-dev/pwsh-module-ci/issues/53), decide the test-scaffold minimum** — **complete 2026-11-06**. Decision and measurements on the issue.
- [x] **2 — [#9](https://github.com/jjohns-dev/pwsh-module-ci/issues/9), `os-matrix-include`** — **complete 2026-11-06**. Shipped by [#57](https://github.com/jjohns-dev/pwsh-module-ci/pull/57) as a polymorphic `os-matrix` in `v1.6.0`; ADR-0006 amended. Proof and release record on the issue.
- [x] **3 — [SecurityTools#166](https://github.com/jjohns-dev/SecurityTools/issues/166), cross-platform tests only run on Linux** — **complete 2026-11-06**. Linux-only by design; closed by [SecurityTools#168](https://github.com/jjohns-dev/SecurityTools/pull/168).
- [x] **4 — [#59](https://github.com/jjohns-dev/pwsh-module-ci/issues/59), rewrite the verification harness as Pester and make it a required check** — **complete 2026-11-06**. Landed as [#64](https://github.com/jjohns-dev/pwsh-module-ci/pull/64); `verify Pester result step` is a required check. Evidence on the issue.
- [x] **5 — ~~[#61](https://github.com/jjohns-dev/pwsh-module-ci/issues/61), let an `os-matrix` leg name itself with an optional `label`~~** — **withdrawn 2026-11-06**, closed as not planned. Kept so the numbering stays stable; its findings are on the issue.
- [x] **6 — [#21](https://github.com/jjohns-dev/pwsh-module-ci/issues/21), centralize SecurityTools CI** — **complete 2026-11-09**. [SecurityTools#169](https://github.com/jjohns-dev/SecurityTools/pull/169): SecurityTools calls `ci.yml` with the object form of `os-matrix`, its ruleset updated for the renamed checks.
- [x] **7 — [#20](https://github.com/jjohns-dev/pwsh-module-ci/issues/20), move the harness** — **complete 2026-11-12**. Shipped as `v2.0.0` and `v2.0.1` ([#77](https://github.com/jjohns-dev/pwsh-module-ci/issues/77)); per-repo evidence in [`docs/specs/centralized-harness/tasks.md`](docs/specs/centralized-harness/tasks.md); `v1` retired.
- [x] **7a — [#73](https://github.com/jjohns-dev/pwsh-module-ci/issues/73), shim runs a stale harness on a branch pin** — **complete 2026-11-12**. Fixed with #79 by [#82](https://github.com/jjohns-dev/pwsh-module-ci/pull/82) in `v2.0.2`; closing record on the issue.
- [x] **7b — [#79](https://github.com/jjohns-dev/pwsh-module-ci/issues/79), name every workflow step** — **complete 2026-11-12**. Shipped in `v2.0.2` with #73; closing record on the issue.
- [x] **8 — [#53](https://github.com/jjohns-dev/pwsh-module-ci/issues/53), implement the minimum** — **complete 2026-11-13**. Spec [#84](https://github.com/jjohns-dev/pwsh-module-ci/pull/84); `v2.1.0` ([#85](https://github.com/jjohns-dev/pwsh-module-ci/pull/85)) and `v2.1.1` ([#86](https://github.com/jjohns-dev/pwsh-module-ci/pull/86)); eight consumer PRs. Per-repo evidence in [tasks.md](docs/specs/shared-test-minimum/tasks.md) D1–D8; final floors in the issue's closing comment.
- [ ] **9 — [#55](https://github.com/jjohns-dev/pwsh-module-ci/issues/55), merge the `Help.Tests.ps1` variants**
  **No longer optional (agreed 2026-11-13):** help is centralized next, as its own release. The *Why here* below records the original framing.
  **Closes when** either a merged help suite ships in the harness and every affected floor is recalculated from a real run, or a comment records why help stays per-repo permanently, naming the constraint that makes it so.
  **Why here:** After #53, and **gates nothing** — Phase 5's harness work completes without it. Split out of #53 for two structural reasons: help is the only category that requires the module to be *imported* rather than read from disk, so it inherits every per-repo import constraint; and the suites are different checks rather than variants, so merging them is its own decision. It is nonetheless the worst drift in the set — five repos, five distinct variants, no two identical, with three of them asserting the same six things in 19 lines' worth of differing code.
- [ ] **10 — [PS-MCS/ArcGISEnterprise#153](https://github.com/PS-MCS/ArcGISEnterprise/issues/153), transfer ArcGISEnterprise to `jjohns-dev` and onto the harness**
  **Closes when** the repo is in `jjohns-dev`, calls `ci.yml`, `release.yml` and `pssa-sarif.yml` at `@v2` with the template shim, is green with its executed count unchanged, and is registered here as the ninth consumer. Steps and their order are on the issue.
  **Why here:** Deferred by choice 2026-11-12; it was item 7c, between `v2.0.2` and #53. Consequence: #53's refreshed spec covers eight consumers, so this repo adopts the shared minimum and the current shim as part of its own migration rather than through #53's consumer PRs. Phase 5 stays `jjohns-dev` only: the repo enters scope by transferring, not by Phase 5 reaching into `PS-MCS`.

## Phase 6 — Migration

- [ ] **pwsh-module-ci** — [#19](https://github.com/jjohns-dev/pwsh-module-ci/issues/19) — gated on Phases 1–5
  psake → Sampler. Design for SecurityTools' per-leg test scope from the start, migrate that repo last.
  **Re-scoped 2026-11-05.** The question is no longer *"migrate psake to Sampler"* but *"should the centralised harness be Sampler-based or hand-rolled?"* — a decision taken once here, with no per-repo migration, and one that #20's outcome informs. All three of this issue's `$env:BH*` checkboxes were answered on 2026-11-05.

## Phase 8 — Drain this file

The header says to delete this file when the last box is checked, which is right about the file and wrong about its contents: several sections were the only written record of something measured once and expensive to re-derive. The "Found during the rollout" section already conceded the point — it exists *"so they are not lost when this file is deleted."*

So this phase is a drain, not a `git rm`. **Nothing is deleted until its destination is named**, and a destination means a merged commit rather than an intention. Deleting the file is a separate, later phase; see the end of this document.

**Considered and rejected: moving this file to `docs/specs/`.** It is not a spec — no requirements, no design, and the task list is a byproduct rather than the artifact. It was written during and after execution rather than before, so filing it as one would imply approval gates that never happened. The decisive objection is the third: `docs/specs/` is read as *current intent*, and this file disclaims authority in its own header — *"Where the two disagree, the issue wins."* A permanent, unmaintained, non-authoritative document in a directory agents treat as intent is how stale guidance gets manufactured. `docs/adr/` is already this repo's mechanism for the durable half.

- [x] **Disposition pass**, one row at a time. **Complete 2026-11-04**, worked as [#43](https://github.com/jjohns-dev/pwsh-module-ci/issues/43) items 0–5.

  | Section | Destination |
  | ------- | ----------- |
  | Phase table, every checkbox, all sequencing and gating | **kept until the end** — it is this file's remaining job, and the final phase takes it |
  | Per-repo phase narratives | ✓ **done 2026-11-04** — deleted; the issues and PRs are authoritative. Recoverable with `git show <this PR's merge commit>^:ROLLOUT.md` |
  | `Install-PSResource` exact-pin and NuGet-range traps | ✓ **done** — already stated in `docs/dependency-stack.md`; the copies here and in `shared-ci-standards.md` were duplicates, so deleted rather than moved |
  | Floor, vacuity and measurement traps | ✓ **done 2026-11-04** — [`docs/test-integrity.md`](docs/test-integrity.md) |
  | The opportunistic-floor blind spot | ✓ **done 2026-11-04** — [ADR-0005](docs/adr/0005-floor-sweeps-scoped-by-repo-list.md) |
  | Repo-local gotchas | ✓ **done 2026-11-04 — nothing to move.** Measured: no repo-local gotcha remained here, and no `AGENTS.md` in the seven `jjohns-dev` repos asserts anything the rollout invalidated — zero stale `PSDepend` or `Install-Module` claims. This row always said *verified in the repo rather than copied across*, so the repo was the source, not this file. The three `PS-MCS` repos with no `AGENTS.md` at all are [mcssec-ops#154](https://github.com/PS-MCS/mcssec-ops/issues/154) |
  | GitHub ruleset mechanics — `PUT` not `PATCH`, and no classic branch protection anywhere in the fleet | ✓ **done 2026-11-04** — `AGENTS.md`, under *Gotchas that have bitten here* |
  | Anything still open | ✓ **done 2026-11-04** — each open item is carried by its own issue: [#24](https://github.com/jjohns-dev/pwsh-module-ci/issues/24), [#34](https://github.com/jjohns-dev/pwsh-module-ci/issues/34), [PS.DCU#20](https://github.com/jjohns-dev/PS.DCU/issues/20), [mcssec-ops#154](https://github.com/PS-MCS/mcssec-ops/issues/154) |
  | `mcssec-ops` cannot be staged; the copies of the verify step | ✓ **done 2026-11-04** — [#20](https://github.com/jjohns-dev/pwsh-module-ci/issues/20), with the copy count re-measured at **5**, not four |
  | `AWSAutomation`'s ADR-0002 caveat | ✓ **drained 2026-11-04** — but the confirmation this row asked for **failed**: the caveat was *not* in that repo's ADR. Removing it from here was safe only because [`docs/dependency-stack.md`](docs/dependency-stack.md) states it independently. **Resolved 2026-11-04** — [#106](https://github.com/jjohns-dev/AWSAutomation/pull/106) added it to that ADR's Consequences |
  | Second drain: completed Phase 5 narratives, closed findings, the retrospective note, the standing caveat and *Reference — moved out* | ✓ **done 2026-11-13** — the linked issues and PRs; #9, #73 and #79 got closing records first. The caveat lives in `AWSAutomation`'s ADR-0002, and [ADR-0008](docs/adr/0008-runtime-modules-float-build-tools-pinned.md) has since made floating runtime dependencies the fleet rule. Recoverable with `git show <this PR's merge commit>^:ROLLOUT.md` |

Deleting `ROLLOUT.md` itself is **not** a row in this phase. It moved to the **Final phase** at the end of this document, because it is gated on far more than the drain.

## Found during the rollout, deliberately not folded into it

Each of these was surfaced by rollout work, is independent of it, and would have expanded a phase's scope if bundled. Recorded here so they are not lost when this file is deleted.

- [x] **`SecurityTools` has no `.gitattributes`** — [SecurityTools#161](https://github.com/jjohns-dev/SecurityTools/issues/161), opened 2026-11-02, **closed 2026-11-03**. Landed as [#163](https://github.com/jjohns-dev/SecurityTools/pull/163) and [#164](https://github.com/jjohns-dev/SecurityTools/pull/164); measurements on the issue.
- [ ] **`PS.DCU` has no behavioural tests** — [PS.DCU#20](https://github.com/jjohns-dev/PS.DCU/issues/20), opened 2026-11-02. Its tests check help and metadata, not module logic.
- [ ] **Evaluate `PSMutant`** — [#34](https://github.com/jjohns-dev/pwsh-module-ci/issues/34), opened 2026-11-02. Independent of [#19](https://github.com/jjohns-dev/pwsh-module-ci/issues/19).
- [x] **Remove the unused `PlatyPS` pin** — folded into [#24](https://github.com/jjohns-dev/pwsh-module-ci/issues/24), **complete 2026-11-04** by [AWSAutomation#106](https://github.com/jjohns-dev/AWSAutomation/pull/106), which amended that repo's ADR-0002.
- [ ] **Three `PS-MCS` repos have no `AGENTS.md`** — [mcssec-ops#154](https://github.com/PS-MCS/mcssec-ops/issues/154), opened 2026-11-04. Filed in `mcssec-ops`, where the work lands.

## Final phase — Delete this file

**Not "Phase 9", and not "Phase X"** — X reads as Roman numeral 10 among numbered phases. This is the only unnumbered phase, because it is the only one whose position cannot change.

Gated on what remains: Phase 5 items 9 and 10, then Phase 6; the drain ([#43](https://github.com/jjohns-dev/pwsh-module-ci/issues/43)) and [#27](https://github.com/jjohns-dev/pwsh-module-ci/issues/27) are done. The file stays until then, because it still carries the Phase 5 and Phase 6 sections and the running order at the top.

- [ ] **Delete `ROLLOUT.md` from `main`**, in its own PR, once nothing here is unrecorded elsewhere.

Two things worth stating in that PR rather than assuming:

- **Deleting it does not lose the content.** `git show <merge-sha>^:ROLLOUT.md` retrieves the last complete version, and every drained section names its destination in the disposition table above.
- **The running order is the one thing with no other home.** Either it is finished by then, or it moves to an issue before the file goes — otherwise deleting this file loses the sequence rather than the history.
