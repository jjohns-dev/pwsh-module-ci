# Shared test minimum — tasks

- **Requirements:** [requirements.md](requirements.md), approved 2026-11-13
- **Design:** [design.md](design.md), approved 2026-11-13
- **Status:** Draft — 2026-11-13

Each task names its verification and the acceptance criteria (AC) it serves. Phases A–B are one PR in this repo; C is the release; D is one PR per consumer, through the agent-prompt pattern, each report verified here from run artifacts before its box is ticked.

## A. Measure before building

- [ ] **A1. Confirm the two assumed Pester behaviours** on Pester 6.2.0, in a scratch run: path containers and `-Data` containers mixed in one `Invoke-Pester` call, and containers executing in the order given. *(design: Risks)*
  - Verify: a probe that records execution order and fails if either behaviour does not hold, plus a control showing the probe can fail. Result recorded in this file. If either fails, revise the design before B.

## B. Harness change, one PR

Every assertion gets a fixture that must fail it and one that must pass it, under strict mode on and off. *(AC 14)*

- [ ] **B1. `Build/SharedTests/manifest.tests.ps1`**, the 14 assertions. *(AC 3, AC 4)*
  - Verify: for each assertion, a fixture module in `TestDrive:` that violates only it fails only it. `PowerShellVersion` cases: `5.1` and `7.0` pass; `3.0`, `5.0`, `6.2` and one above `$PSVersionTable.PSVersion` fail.
- [ ] **B2. `Build/SharedTests/module.tests.ps1`**, the 3 assertions, importing the staged copy after `Remove-Module`. *(AC 5)*
  - Verify: a missing `.psm1`, a loader that throws, and a public function that fails to load each fail exactly one test; a fixture where the module is already loaded still performs a real import.
- [ ] **B3. `Build/SharedTests/meta.tests.ps1`**, 3 looped tests. *(AC 6)*
  - Verify: a BOM, a tab and a `0x00` byte each fail their own test and name the file; files under `.git`, `Staging` and `Artifacts` are ignored; adding source files does not change the test count.
- [ ] **B4. `Build/SharedTests/pathliterals.tests.ps1`**, one test per `Public/*.ps1`. *(AC 8)*
  - Verify: each of the four variables followed by `\` in a string fails; the same text in a comment and in comment-based help `.EXAMPLE` passes.
- [ ] **B5. `Test` task integration** in `Build/build.psake.ps1`. *(AC 1, AC 2, AC 9, design: Order)*
  - Verify, in `tests/HarnessTasks.Tests.ps1` against a fixture consumer: shared tests appear in the single JUnit file on `All` and `CrossPlatform`, not on `WindowsOnly`; they run after the consumer's tests; a failing shared test fails the task.
- [ ] **B6. Fleet dry run.** Run the branch's harness locally against shallow clones of all eight consumers. *(AC 10, design: Rollout)*
  - Verify: expected red is exactly SecurityTools' four BOM files and AWSAutomation's three literals. Anything else is recorded here and resolved (fixed in the suite, or added to that repo's cleanup list) before release.
- [ ] **B7. Documentation.** `docs/test-integrity.md` *Settled decisions*: why meta loops (AC 7). `docs/consumer-guide.md`: what the harness tests and what consumers no longer carry. `AGENTS.md` and `README.md`: the `Build/SharedTests/` layout row.
  - Verify: markdown lint clean; `git diff -U0` reviewed hunk by hunk.

## C. Release

- [ ] **C1. Merge B, cut `v2.1.0`** with a GitHub release whose notes say every consumer will run the shared suites when `v2` moves, and which repos are expected red. *(ADR-0002: minor)*
  - Verify: tag annotated, on the merge commit, release immutable.
- [ ] **C2. Two throwaway proofs pinned `@v2.1.0`.** *(AC 10)*
  - PS.YNAB: all three workflows green, executed count up by exactly the shared suites' count.
  - SecurityTools: red on the meta BOM test only, the message naming exactly its four files; the windows leg unchanged at 21.
  - Verify: `referenced_workflows` shows the `v2.1.0` tag object; counts from JUnit artifacts. Close both unmerged, branches deleted, evidence commented.
- [ ] **C3. Move `v2` to `v2.1.0`.** *(AC 11)*
  - Verify: `git ls-remote origin 'refs/tags/v2^{}'` shows the `v2.1.0` commit; a rerun of one consumer's `main` ci records the new tag object.

## D. Cleanup PRs, one per consumer *(AC 12, AC 13)*

Each PR: delete the vendored files below; fix that repo's red-list defects; recalculate every leg's floor from the PR's own run; copy the shim template. The PR comment maps every deleted assertion to a shared one, or records why it is dropped.

Red repos first, so `main` is green again soonest.

- [ ] **D1. SecurityTools** — `Tests/Common/{manifest,meta}.tests.ps1`, `MetaFixers.psm1`; remove BOMs from four files. Both legs.
- [ ] **D2. AWSAutomation** — `Tests/Common/{manifest,meta}.tests.ps1`, `MetaFixers.psm1`; fix three `"$HOME\Desktop"` literals.
- [ ] **D3. PS.SSL** — `Tests/Common/{manifest,meta,PathLiterals}.tests.ps1`, `MetaFixers.psm1`. Both legs.
- [ ] **D4. PS.Log** — `Tests/Common/{manifest,meta}.tests.ps1`, `MetaFixers.psm1`.
- [ ] **D5. PS.DCU** — `Tests/Common/{manifest,meta}.tests.ps1`. Its count falls: 38 per-file meta tests become 3.
- [ ] **D6. PS.GHOps** — `Tests/Unit/Module.tests.ps1`.
- [ ] **D7. PS.GitHub** — `Tests/Unit/Module.tests.ps1`.
- [ ] **D8. PS.YNAB** — `Tests/Unit/Module.tests.ps1`.

Verify each: post-merge `main` run green; executed count per leg read from JUnit; floor equals executed minus `min(floor(executed * 0.05), 10)`; `Build/build.ps1` byte-identical to the template; `help.tests.ps1` and unit tests untouched.

## E. Close-out

- [ ] **E1.** Close #53 with the evidence; tick `ROLLOUT.md` item 8 with the merge commits and final floors.
- [ ] **E2.** Update #55 and `ROLLOUT.md` item 9: help is to be centralized as its own release (agreed 2026-11-13), no longer optional.
  - Verify: issue and file agree.
