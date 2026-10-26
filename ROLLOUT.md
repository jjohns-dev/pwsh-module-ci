# Rollout tracker

**Temporary working file. Delete it when the last box is checked.** It exists to coordinate one batch of cross-repo work; it is not a permanent part of this repo and nothing reads it.

Authoritative detail lives in the linked issues — this is an index and an ordering, not a substitute. Where the two disagree, the issue wins.

## Phase 1 — Suites that are currently lying

Zero matching-help cases collected. Green because the tests do not exist.

- [ ] **PS.Log** — [PS.Log#54](https://github.com/jjohns-dev/PS.Log/issues/54)
  Discovery+AST fix, defects 1/2/3, floor. One PR, floor measured last.
- [ ] **PS.SSL** — [PS.SSL#71](https://github.com/jjohns-dev/PS.SSL/issues/71)
  Same as PS.Log. Floor semantics affected by #23 — uses `Describe -Skip:` on openssl and network reachability.
- [ ] **SecurityTools** — [SecurityTools#153](https://github.com/jjohns-dev/SecurityTools/issues/153)
  Same, **plus add the verify step** — the only repo without one, so container and discovery errors still pass green. Per-leg floor. Also affected by #23.

## Phase 2 — The silent ones

Counts already look correct, so nothing will surface these on their own.

- [ ] **AWSAutomation** — [AWSAutomation#97](https://github.com/jjohns-dev/AWSAutomation/issues/97)
  Reference implementation others port from. **Only repo with an existing floor (560) — must be re-derived in the same PR.**
- [ ] **ArcGISEnterprise** — [ArcGISEnterprise#143](https://github.com/PS-MCS/ArcGISEnterprise/issues/143)
  Defects 1/2/3 plus the floor is unset. Zero `Mandatory` coverage elsewhere in its tests.
- [ ] **MCS** — [MCS#212](https://github.com/PS-MCS/MCS/issues/212)
  Defect 3 only; 1 and 2 already fixed. Deletion drops CrossPlatform 495 → 444, below the current floor of 445 — re-derive in the same PR.

## Phase 3 — Make regressions visible

- [ ] **pwsh-module-ci** — [#23](https://github.com/jjohns-dev/pwsh-module-ci/issues/23)
  The floor counts skipped tests, so a mass-skip regression passes. **Also apply to `PS-MCS/mcssec-ops`.** Staged rollout via an immutable `vX.Y.Z` pin. Ideally lands before the two Phase 1 floors.
- [ ] **PS.GHOps** — [PS.GHOps#19](https://github.com/jjohns-dev/PS.GHOps/issues/19)
  Floor only. No `Help.Tests.ps1`, nothing to fix.
- [ ] **PS.GitHub** — [PS.GitHub#37](https://github.com/jjohns-dev/PS.GitHub/issues/37)
  Floor only. No `Help.Tests.ps1`.
- [ ] **PS.DCU** — [PS.DCU#16](https://github.com/jjohns-dev/PS.DCU/issues/16)
  Floor **plus stale-help detection**. Best-shaped file in the fleet — keep the single-`It` style, do not convert it to `-ForEach`.

## Phase 4 — Close the tracker issue

Gated on Phases 1–3.

- [ ] **Close** [#17](https://github.com/jjohns-dev/pwsh-module-ci/issues/17)
  PS.ETL, PS.DCU and the Open question are already re-homed, so nothing else holds it open.

## Phase 5 — Stop the duplication

Gated on Phases 1–2.

- [ ] **pwsh-module-ci** — [#20](https://github.com/jjohns-dev/pwsh-module-ci/issues/20)
  Stop duplicating `Build/` **and** `Tests/Common/`. Diff the test template only after Phase 1–2 lands, or you classify drift against a moving baseline.

## Phase 6 — Migration

- [ ] **pwsh-module-ci** — [#19](https://github.com/jjohns-dev/pwsh-module-ci/issues/19) — gated on Phases 1–5
  psake → Sampler. Design for SecurityTools' per-leg test scope from the start, migrate that repo last.
- [ ] **pwsh-module-ci** — [#21](https://github.com/jjohns-dev/pwsh-module-ci/issues/21) — gated on #19
  Centralize SecurityTools CI. Current lean is a second reusable workflow rather than extending `ci.yml`.

## Phase 7 — Deferred

Gated on Phases 1–2.

- [ ] **pwsh-module-ci** — [#22](https://github.com/jjohns-dev/pwsh-module-ci/issues/22)
  Stop generating link-test cases for commands with no `.LINK`. Edits the same `It` block as Phases 1–2.

## Runs on its own clock

- [ ] **PS.ETL** — [PS.ETL#22](https://github.com/PS-MCS/PS.ETL/issues/22)
  Pester 5.5.0 → 6.2.0 first, including the `CommandInfo` hang fix. Decoupled from #17, blocks nothing.

## Two sequencing traps

**#22 edits the same `It` block as Phases 1–2.** Do it with them, or well after — never between, or the same block gets rebased twice.

**#23 changes floor semantics for the only two repos that use `-Skip`** (PS.SSL, SecurityTools). Everywhere else `tests` and executed counts are identical, so it makes no difference. Either land #23 first, or accept re-deriving those two floors.

## Recurring rules for every PR in Phases 1–3

- **Fix first, measure second, set the floor third.** A floor derived before the fix records the defective count as the baseline, and can never trip on a regression back to it.
- **Acceptance is the mutation, not the count.** Make the thing you are guarding fail, confirm red, revert. A check that never fires is indistinguishable from one that passes.
- **Verify floors in both directions.** An impossible floor must fail the run *and* leave the result XML uploaded; a correct floor must stay quiet.

## Along the way: AGENTS.md for three repos

- [ ] **PS.Log**
- [ ] **PS.SSL**
- [ ] **PS.DCU**

None of these has an `AGENTS.md`, and all three are receiving non-trivial PRs. Writing one first is cheap and pays off on every later session in that repo.

Give the prompt below to an agent working **in that repo** rather than drafting the file from elsewhere — most of an `AGENTS.md` is claims about what commands work and what has bitten people, and those have to be verified by running them. Substitute the repo's own issue number for `#<N>`: PS.Log → 54, PS.SSL → 71, PS.DCU → 16.

```text
Create an AGENTS.md at the root of this repository. It does not currently have one.

STRUCTURAL MODEL
Use jjohns-dev/pwsh-module-ci's AGENTS.md as the model for structure and tone: a short
"What this repo is", a Layout table, Conventions, "Validating a change", and a
"Gotchas that have bitten here" section. Read a sibling module repo's AGENTS.md
(jjohns-dev/AWSAutomation or jjohns-dev/PS.GHOps) for content shape. Do not copy either
verbatim.

VERIFICATION IS MANDATORY
This file is auto-loaded into every future agent session here, so a wrong statement is
worse than a missing one.
- Every command you document must be one you actually ran in this repo. Run it.
- Every version number must come from a file you read (Build/depend.psd1, the manifest),
  not from memory.
- Every gotcha must be one you reproduced, or one you found evidenced in this repo's git
  history, closed PRs, or issues. Cite where it came from.
- Do NOT copy a sibling repo's gotchas unless you reproduce them here.
- If something is important but you could not verify it, either omit it or label it
  explicitly as unverified. Do not guess.

COVER AT LEAST
- What this module is and what it exports.
- Layout: where Public/, Private/, Tests/, Build/ live and what each holds.
- How to build, analyze and test locally — the exact ./Build/build.ps1 -TaskList
  invocations, confirmed by running them. Note any that fail today.
- The pinned Pester / PSScriptAnalyzer / psake versions, read from Build/depend.psd1.
- How CI is wired and what it does NOT do.
- Commit and branch conventions, inferred from actual git history, not assumed.

CONTEXT YOU DO NOT NEED TO REDISCOVER (verify anything you restate)
- CI calls the reusable workflow jjohns-dev/pwsh-module-ci/.github/workflows/ci.yml@v1.
  release.yml and pssa-sarif.yml call that repo too.
- That workflow accepts a `min-tests` input (fail when a Pester result file collects
  fewer tests than this; 0 disables). This repo currently passes nothing, so there is no
  floor. Issue #<N> tracks setting one.
- Pester container and discovery errors do not increment FailedCount; they land in the
  JUnit root `errors` attribute instead. A psake gate reading FailedCount misses them.
  This repo's Test task almost certainly gates on $TestResults.Result, which DOES catch
  them - 9 of the 10 module repos do, PS-MCS/PS.ETL being the only exception. Check
  which form this repo uses before writing anything about it; do not assume.
- The shared workflow still runs an independent "Verify Pester results" step, for the
  min-tests floor, for detecting a missing result file, and so the check does not depend
  on each consumer's harness staying correct.
- Tests/Common/Help.Tests.ps1 is a copy-pasted template shared across eight repos and
  has known defects, tracked at jjohns-dev/pwsh-module-ci#17 and locally at #<N>. Do not
  "fix" it as a side effect of writing this file.

LENGTH — treat this as a hard budget
Target 3,500 bytes. Do not exceed 4,500. For calibration, jjohns-dev/AWSAutomation and
jjohns-dev/PS.GHOps are 4,548 and 4,543 bytes; jjohns-dev/PS.GitHub is 9,627 and is too
long — do not match it.

This file is loaded into every agent session in this repo, so it is paid for on every
task, forever.

Apply this test to every section before you keep it: name the specific mistake an agent
would make without it. If you cannot name one, delete the section. "Useful background"
is not a mistake prevented.

Do NOT include:
- Anything discoverable by listing a directory or reading a filename.
- General PowerShell, Pester or GitHub Actions knowledge. Assume competence.
- Content that duplicates README.md. Link to it instead.
- Aspirations, roadmap, or how things ought to work. Only how they do work.
- Gotchas you did not reproduce here.

Prefer tables over prose. Prefer one precise sentence over three hedged ones.

Do not create any other files. Do not modify code. When done, show me the file and tell
me which statements you verified by execution versus by reading, and the final byte
count.
```
