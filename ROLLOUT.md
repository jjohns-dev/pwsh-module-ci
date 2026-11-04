# Rollout tracker

**Temporary working file. Delete it when the last box is checked.** It exists to coordinate one batch of cross-repo work; it is not a permanent part of this repo and nothing reads it.

Authoritative detail lives in the linked issues — this is an index and an ordering, not a substitute. Where the two disagree, the issue wins.

## Where we are

Phase numbers are **names, not a sequence**. They were assigned before #22 moved and before the Phase 2B debt surfaced, and they are cited from issue bodies and merged PRs, so they are not being renumbered. This list is the sequence.

| | Phase | State |
| - | ----- | ----- |
| ✓ | **1** — suites that were lying | done 2026-10-27 — PS.Log, PS.SSL, SecurityTools |
| ✓ | **2** — the silent ones | done 2026-10-28 — AWSAutomation, ArcGISEnterprise, MCS |
| ✓ | **2B** — catch-up PSDepend migrations | done 2026-10-29 — PS.Log, PS.SSL. All six repos are now off PSDepend |
| ✓ | **7** — #22 link-case back-fill | done 2026-10-29 — all six repos. Each moved that repo's floor, re-derived under ADR-0004 in the same PR |
| ✓ | **3** — make regressions visible | **done 2026-11-03.** Track A: first floors for PS.GHOps `91`, PS.GitHub `107`, PS.DCU `81`. Track B: the floor now measures **executed**, shipped as `v1.5.0` and live fleet-wide |
| ✓ | **4** — close the tracker issue | **done 2026-11-03** — #17 closed after auditing every box against the repos. Only `PS.ETL` outstanding, decoupled to PS.ETL#22 |
| → | **5** — stop the duplication | **next.** #24 (BuildHelpers + the unused PlatyPS pin), then #20 |
| | **6** — migration | #19, then #21 |
| | **8** — drain this file, then delete it | last. Nothing is deleted until its destination is named |

Completed phases are closed. New work goes in a later phase or a new one, never back into a phase already marked done — Phase 2B exists because that rule was applied rather than reopening Phase 1.

## Phase 1 — Suites that are currently lying

Zero matching-help cases collected. Green because the tests do not exist.

- [x] **PS.Log** — [PS.Log#54](https://github.com/jjohns-dev/PS.Log/issues/54)
  Done 2026-10-26, merged as [PS.Log#55](https://github.com/jjohns-dev/PS.Log/pull/55). AST discovery binding, defects 1/2/3, `min-tests: 87`. The implementing agent also caught two errors in its brief — see the corrections on #17.
  **Still owes the PSDepend migration** — see Catch-up below.
- [x] **PS.SSL** — [PS.SSL#71](https://github.com/jjohns-dev/PS.SSL/issues/71)
  Done 2026-10-27, merged as [PS.SSL#72](https://github.com/jjohns-dev/PS.SSL/pull/72). AST discovery binding, defects 1/2/3, `min-tests: 337`, and the vestigial `BuildHelpers` entry removed (#24). Floor confirmed against both legs: ubuntu `tests=375`, windows `tests=377`. **Still owes the PSDepend migration** — catch-up, tracked on #27.
- [x] **SecurityTools** — [SecurityTools#153](https://github.com/jjohns-dev/SecurityTools/issues/153) and [#155](https://github.com/jjohns-dev/SecurityTools/issues/155), both closed
  Discovery binding and the verify step landed 2026-10-27 as [SecurityTools#154](https://github.com/jjohns-dev/SecurityTools/pull/154) — matching-help 0 → 165 cases, per-leg floors 1104 / 20, and all three no-result-file guards. Both failure paths verified in CI as separate claims. Its agent also taught the test to resolve `Get-KEVList`'s conditional `DynamicParam` block.
  The PSDepend migration landed as [SecurityTools#156](https://github.com/jjohns-dev/SecurityTools/pull/156) (`6eec42d`), **which answered the fleet-wide `SkipPublisherCheck` question** — see #27.
  The four remaining defects landed as [SecurityTools#157](https://github.com/jjohns-dev/SecurityTools/pull/157) (`4f1f023`) — null guard, `-BeLike` replacing the `-Contain` tautology, offline URI shape check, and the mandatory-value test deleted with its marker comment. Floors re-derived in the same PR: ubuntu 1227 → 1063 collected, floor **1104 → 956**; windows unchanged at 21 / 20. Both mutations and both floor directions verified on separate runs, and the failing-floor run still uploaded its result XML.

## Phase 2 — The silent ones

Counts already look correct, so nothing will surface these on their own.

All three issue bodies were corrected on 2026-10-28 before any work started: each was missing the `$_ -and` null guard, and all three banners pointed at a comment for the PSDepend detail. Defect counts went from three to four.

- [x] **AWSAutomation** — [AWSAutomation#97](https://github.com/jjohns-dev/AWSAutomation/issues/97) and [#100](https://github.com/jjohns-dev/AWSAutomation/issues/100), both closed
  Reference implementation others port from. Three PRs, all merged 2026-10-28: [#98](https://github.com/jjohns-dev/AWSAutomation/pull/98) PSDepend migration (`dbcd482`), [#99](https://github.com/jjohns-dev/AWSAutomation/pull/99) the four defects with the floor re-derived 560 → **430** against 478 collected (`2f49d83`), and [#101](https://github.com/jjohns-dev/AWSAutomation/pull/101) floating the unversioned runtime dependencies (`110e246`).
  The link test here was **live, not dormant** — `Edit-AWSProfile` and `Get-WindowsDisk` were making real calls to `docs.aws.amazon.com` on every run. That is now an offline shape check.
  `ubuntu-latest` only, and zero `-Skip` usage, so #23 will not disturb its floor.
- [x] **ArcGISEnterprise** — [ArcGISEnterprise#143](https://github.com/PS-MCS/ArcGISEnterprise/issues/143), closed
  Two PRs, both merged 2026-10-28: [#145](https://github.com/PS-MCS/ArcGISEnterprise/pull/145) PSDepend migration (`9c0bc88`), and [#146](https://github.com/PS-MCS/ArcGISEnterprise/pull/146) the four defects plus the first floor at **1692** against 1,881 collected (`105b60a`).
  **It also pulled [#22](https://github.com/jjohns-dev/pwsh-module-ci/issues/22) forward** — link cases are now generated at discovery from `Get-Help`, so a command with no `.LINK` produces none. That dropped 2,013 → 1,881, i.e. 132 cases that could never fail. This repo is now ahead of the five that already merged the template without it.
  Also normalised the whole repo to LF (89 files, content-identity proven by an empty `git diff --ignore-cr-at-eol`). The `.git-blame-ignore-revs` follow-up landed as [#148](https://github.com/PS-MCS/ArcGISEnterprise/pull/148) (`45a2d48`), closing [#147](https://github.com/PS-MCS/ArcGISEnterprise/issues/147) — blame attribution verified to move off the renormalisation commit and back to the original authors.
- [x] **MCS** — [MCS#212](https://github.com/PS-MCS/MCS/issues/212), closed
  Two PRs, both merged 2026-10-28: [#213](https://github.com/PS-MCS/MCS/pull/213) PSDepend migration (`60fc7de`), and [#214](https://github.com/PS-MCS/MCS/pull/214) the remaining defects plus the floor (`3e8fd71`). Defects 1 and 2 were already fixed here, so the scope was defect 3, the null guard, and the link change.
  **Also pulled [#22](https://github.com/jjohns-dev/pwsh-module-ci/issues/22) forward**, as ArcGIS did. CrossPlatform went 495 → 444 (51 mandatory cases) → **410** (34 link cases), floor **369**. WindowsOnly unaffected at 136 / 122.
  `#214` was rebased onto `main` after `#213` merged, so the 410 and the floor are measured under the merged `Install-PSResource` loop rather than inferred. Post-merge CI on `main` is green.

## Phase 2B — Catch-up: PSDepend migrations owed from Phase 1

Phase 1's boxes are ticked for the Help.Tests work, which is all it was scoped to. Two of those repos still owe the PSDepend migration: their Help.Tests work landed *before* that migration was decided, so they were never sequenced through it. Tracked at [#27](https://github.com/jjohns-dev/pwsh-module-ci/issues/27), verified still outstanding 2026-10-29.

- [x] **PS.Log** — [PS.Log#57](https://github.com/jjohns-dev/PS.Log/issues/57)
  Done 2026-10-29, merged as [PS.Log#58](https://github.com/jjohns-dev/PS.Log/pull/58) (`4152e0c`). Count unchanged at 97 and the test names matched between runs, not just the totals. Floor untouched at 87.
- [x] **PS.SSL** — [PS.SSL#73](https://github.com/jjohns-dev/PS.SSL/issues/73)
  Done 2026-10-29, merged as [PS.SSL#74](https://github.com/jjohns-dev/PS.SSL/pull/74) (`3ec8b96`). Counts unchanged at 375 / 377, floor untouched at 337.
  **Also delivered the measurement that was blocking #23:** `disabled` is 14 on ubuntu and 15 on windows, so executed is 361 / 362 — both already above the 337 floor.

Both are `jjohns-dev` repos, so zero approvals and self-merge. Neither touches `depend.psd1`, tests, or the floor.

## Phase 3 — Make regressions visible

Two independent tracks. **Track A is unblocked and can start now**; Track B is the staged #23 rollout.

### Track A — first-time floors — COMPLETE 2026-11-02

All three now carry a floor derived under ADR-0004, and all three measured `disabled = 0`, so none is affected by #23. Each repo was two PRs — PSDepend migration first, then the floor — except `PS.DCU`, which needed five.

| Repo | Collected | Floor | Margin term that bound |
| ---- | --------- | ----- | ---------------------- |
| PS.GHOps | 95 (3 legs) | **91** | percentage, `floor(95 * 0.05) = 4` |
| PS.GitHub | 112 (3 legs) | **107** | percentage, `floor(112 * 0.05) = 5` |
| PS.DCU | 85 (1 leg) | **81** | percentage, `floor(85 * 0.05) = 4` |

None of the three hit ADR-0004's cap of 10 — every suite is small enough that the 5% term binds. The cap only matters for `ArcGISEnterprise`, `SecurityTools` and `AWSAutomation`.

- [x] **PS.GHOps** — [PS.GHOps#19](https://github.com/jjohns-dev/PS.GHOps/issues/19) — **done 2026-10-30**
  Floor only. No `Help.Tests.ps1`, nothing to fix. 95 collected, identical on all three legs → floor **91**. Two PRs: [#20](https://github.com/jjohns-dev/PS.GHOps/pull/20) PSDepend → `Install-PSResource` (`f17c19c`), [#21](https://github.com/jjohns-dev/PS.GHOps/pull/21) the floor (`93ce0a1`).
  **It is now the reference for the other two**, closer than the `SecurityTools` loop the standards doc names: identical starting shape — same three exact pins, same bootstrap at `build.ps1` lines 31-51, same `ci.yml` with no `with:` block. First repo where ADR-0004's *percentage* term binds rather than the cap, `floor(95 * 0.05) = 4`.
  Verified independently: the sabotage run failed **and** uploaded all three artifacts, re-parsed to `tests=95`. The failure annotation quoted the repo's own `9999` back, which is what proves the input reaches the reusable workflow — a green run cannot distinguish a working floor from an unset one, since `MIN_TESTS` defaults to `0` and disables the check.
  **Small debt, tidy later:** `build.ps1` still carries four cosmetic `PSDepend` references — `$psdependencyConfigPath` twice, the `Import-PowerShellDataFile` line, and the `PSDependOptions` filter. The filter is load-bearing because `depend.psd1` keeps PSDepend's schema; the variable name is not. Grepping `PSDepend` to check whether the migration happened returns four hits in a file that no longer uses it.
- [x] **PS.GitHub** — [PS.GitHub#37](https://github.com/jjohns-dev/PS.GitHub/issues/37) — **done 2026-10-30**
  Floor only. No `Help.Tests.ps1`. 112 collected, identical on all three legs → floor **107**. Two PRs: [#38](https://github.com/jjohns-dev/PS.GitHub/pull/38) PSDepend → `Install-PSResource` (`161ffa7`), [#39](https://github.com/jjohns-dev/PS.GitHub/pull/39) the floor (`5c1ebde`).
  **Took the neutral-variable improvement, so this is the cleanest of the three.** `build.ps1` now greps to exactly **one** `PSDepend` hit — the load-bearing `PSDependOptions` filter — against four in `PS.GHOps`. `PS.DCU` should match this, leaving `PS.GHOps` as the only rename outstanding.
  **Correction carried back from that work: these repos are not under classic branch protection.** Required checks come from a repository ruleset, not a branch-protection setting — drained to `AGENTS.md`, *Gotchas that have bitten here*, with the ruleset name, id and rule list.
- [x] **PS.DCU** — [PS.DCU#16](https://github.com/jjohns-dev/PS.DCU/issues/16) — **done 2026-11-02, issue closed**
  Five PRs, not two: [#17](https://github.com/jjohns-dev/PS.DCU/pull/17) PSDepend (`2bc4569`), [#18](https://github.com/jjohns-dev/PS.DCU/pull/18) psake 4.9.1 → 5.0.4 (`d600bc3`), [#19](https://github.com/jjohns-dev/PS.DCU/pull/19) `os-matrix` → Windows + new `AGENTS.md` (`54611fd`), [#21](https://github.com/jjohns-dev/PS.DCU/pull/21) stale-help detection (`7865c25`), [#22](https://github.com/jjohns-dev/PS.DCU/pull/22) the floor (`d38c98c`). Plus one ruleset edit by the repo owner.
  **85 collected, `disabled` 0, floor 81.** The pre-switch ubuntu number happened to be identical — confirmed coincidental, since the Windows run was measured independently. Comparing the two artifacts showed 76 raw differences, **all** of them `Meta.Tests` names embedding paths with `\` versus `/`; normalised, the suites are identical. The OS switch changed nothing about what is collected.
  **The ruleset had to change before the OS switch could merge.** Ruleset `22407813` required `validate / validate (ubuntu-latest)`; switching the matrix makes CI produce `(windows-latest)`, so the required check would never report and the PR could never merge. Changed to `(windows-latest)` with all six rules preserved, verified through both the ruleset object and `/rules/branches/main`. The `PUT`-not-`PATCH` trap and the silent-`gh`-failure trap are drained to `AGENTS.md`.
  **The OS rationale we started with was wrong, and the measurement is why.** We said "testing it anywhere but Windows is meaningless". Measured: the 85 tests are `Meta` 42, `Help` 32, `Manifest` 11 — the only three test files in the repo, none using `Mock` or `Should -Invoke`, none executing module logic, against 12 source files carrying 25 `dcu-cli` and 24 `System.Management` references. The suite is **metadata-only on every OS**. Windows-only is still correct, but because CI should match the target platform, not because the Windows leg tests something the ubuntu leg did not. The real gap is tracked at [PS.DCU#20](https://github.com/jjohns-dev/PS.DCU/issues/20).
  **It also exposed a floor blind spot**, now generalized into [`docs/test-integrity.md`](docs/test-integrity.md): the stale-help assertion loops inside an existing `It`, so it produces no `testcase` node, the count stayed at 85, and deleting it would leave the floor silent. `AGENTS.md` records it as the cost of the deliberate run-time loop rather than a defect — *"a green floor means the suite still collects, not that this check is still present."*

### Track B — the #23 rollout

- [ ] **pwsh-module-ci** — [#23](https://github.com/jjohns-dev/pwsh-module-ci/issues/23)
  The floor counts skipped tests, so a mass-skip regression passes. **Also apply to `PS-MCS/mcssec-ops`.** Staged rollout via an immutable `vX.Y.Z` pin.
  **Scope shrank 2026-10-28.** The margin question that used to live here is settled in [ADR-0004](docs/adr/0004-min-tests-floor-margin.md), so what remains is only the change of input from `tests` to `tests - disabled`.
  **No longer blocked — measured 2026-10-29** (run `40934797901`, on `main` after [PS.SSL#76](https://github.com/jjohns-dev/PS.SSL/pull/76)):

  | Leg | collected | disabled | executed | floor today |
  | --- | --------- | -------- | -------- | ----------- |
  | ubuntu | 360 | 14 | **346** | 350 |
  | windows | 362 | 15 | **347** | 350 |

  **This change turns `PS.SSL` red on both legs the moment `v1` moves** — executed sits below its floor of 350, which was derived from the *collected* count four hours earlier. Not a regression; the floor and its input would simply stop measuring the same thing.
  **Correction to what this bullet used to say.** The skips are **not** "whole `Describe` blocks gated on openssl and network reachability". The 14 on both legs are the `Network`-tagged integration tests removed by `Filter.ExcludeTag = 'Network'` in `build.psake.ps1` (added in PS.SSL#50 for `badssl.com` flakiness) — tag exclusion emits no `testcase` node at all. The `-Skip:(-not $NetworkReachable)` wrapper does exist, documented in [PS.SSL#69](https://github.com/jjohns-dev/PS.SSL/issues/69), but never fires in CI because `ExcludeTag` removes those tests first. The 15th on windows is unrelated: `Loader.Tests.ps1` → *"does not warn about missing openssl when openssl is on PATH"*, marked `-Skip:($IsWindows)` because it exercises the Linux/macOS `/usr/bin` probe branch.
  **`PS.SSL#69` is the authoritative record of *why* those 14 are excluded. Do not restate it here or open a competing issue.** Its proposal adds more `Network`-tagged tests, which raise `collected` and `disabled` but not `executed` — so under today's floor they would silently inflate the number, and under #23's floor they have no effect. #23 should land first for that reason.

  **Ordered rollout. The `PS.SSL` floor changes in step 3, in the same PR as the pin — not before, not after.** Lowering it early would open ~24 tests of slack while the floor still measures `tests`, which is the exact blind spot #23 exists to close.

  **Hold lifted 2026-10-30.** The floor change was paused pending an explanation of the disabled tests. That explanation is now complete and **confirms the plan rather than changing it**: the 14 are excluded from the gate permanently and by design, so `executed` stays at ~346 no matter what happens to [PS.SSL#69](https://github.com/jjohns-dev/PS.SSL/issues/69). The separate network workflow #69 proposes does **not** affect this floor — the gating run excludes those tests either way. Two problems sharing a cause, not one problem. Track B is clear to start.

  1. [x] Merge #23 to `main`. No consumer is affected; `v1` has not moved. **Done 2026-11-02** — [#36](https://github.com/jjohns-dev/pwsh-module-ci/pull/36) `9aa935a`. Two new fixtures, `Test-MassSkip` and `Test-SomeSkipped`, verified to **fail under the old step body** before the change landed: stashing only the workflow edit gave `2 of 14 case(s) disagreed`. Also corrected AGENTS.md in [#37](https://github.com/jjohns-dev/pwsh-module-ci/pull/37).
  2. [x] Cut an annotated `vX.Y.Z`. Still no consumer effect. **Done** — `v1.5.0`, annotated tag `2cfc303` → commit `9aa935a`, content verified before tagging because `protect-version-tags` makes it permanent.
  3. [x] **`PS.SSL` PR, one commit, two changes.** **Done** — [PS.SSL#77](https://github.com/jjohns-dev/PS.SSL/pull/77) `6c88f3d`, pinned `@v1.5.0` with `min-tests: 350 → 336`. **This was the verification, and it passed:** old floor 350 vs executed 346 would have failed; new floor 336 clears by 10. Both legs green, and the step's log printed `tests=360 disabled=14 executed=346`, matching the derivation input. The comment now says *executed*, not *collected*.
  4. [x] **Apply the change to `SecurityTools`'s own `validate.yml`**, independently of the tag. **Done 2026-11-02** — [SecurityTools#160](https://github.com/jjohns-dev/SecurityTools/pull/160) `96e5263`. The `run:` block is **character-identical** to `ci.yml@v1.5.0` once parsed (3156 chars, `-ceq` true), so #21's migration is now a deletion rather than a reconciliation. Verified in both directions: impossible floor `424242` failed and still uploaded parseable artifacts; a floor of 997 failed under the new logic (`996 executed (997 collected, 1 disabled)`) where it would have passed under the old — the narrow divergence case this repo could produce with only one disabled test.
     **This step was planned wrong and rewritten.** It originally read *"spot-check `SecurityTools` the same way"*, assuming it consumed the shared `ci.yml` like the other repos. It does not — `validate.yml` carries a private copy of the verify step, which is why [#21](https://github.com/jjohns-dev/pwsh-module-ci/issues/21) exists. There was never a pin to stage, so moving `v1` would not have reached its floor. It is unaffected by step 5 for **that** reason, not because its numbers clear. Its `release.yml` and `pssa-sarif.yml` do use `@v1`, harmlessly: the shared `release.yml` has no `min-tests` input by design, so `MIN_TESTS` is unset and the floor is disabled there.
     Required splitting into two commits because `validate.yml` was the fleet's only CRLF workflow file; the EOL conversion is isolated and proven whitespace-only. That led to [SecurityTools#161](https://github.com/jjohns-dev/SecurityTools/issues/161).
     **Floor correction landed:** [SecurityTools#162](https://github.com/jjohns-dev/SecurityTools/pull/162) `3baafba` moved ubuntu 987 → **986**, matching ADR-0004 applied to executed (`996 - 10`). My brief had wrongly said the number would not move — `997 - 10 = 987` but `996 - 10 = 986`. Windows stays **20**, where the formula and the exact-match trip-wire coincide. The step body is still character-identical to `v1.5.0` after the edit, and the file is still LF. **`SecurityTools` is fully converged.**
  5. [x] Move `v1` to `v1.5.0`. **Done 2026-11-03.** `v1` ref object `107b6c1` → `ffbef62`, both dereferencing to commit **`9aa935a`**; `v1.4.0` untouched at `eeadf88`. The push reported `Bypassed rule violations for refs/tags/v1` — that is the admin bypass on `protect-release-tags` working, not an error. **Rollback target if ever needed: `eeadf88`.**
     The script confirmed the target commit actually carried the change before pointing `v1` at it — a moving tag aimed at a commit without the fix would have been the worst available outcome. Verified afterwards three independent ways: `ls-remote` deref, `commits/v1`, `commits/v1.5.0`.
     **All six consumers confirmed safe against their real executed counts, not just the survey:** PS.Log 91/87, PS.GHOps 95/91 (×3 legs), PS.GitHub 112/107 (×3), PS.DCU 85/81, AWSAutomation 444/434, PS.SSL 346/336. The four with `disabled = 0` were never going to move — collected and executed are the same number there.
     `docs/shared-ci-standards.md` corrected at this point, not earlier ([#38](https://github.com/jjohns-dev/pwsh-module-ci/pull/38)): its "a mass-skip regression sails past a floor" line was true for every consumer until this moment. That line now lives in [`docs/test-integrity.md`](docs/test-integrity.md).
  6. [x] Repoint `PS.SSL` to `@v1` to clear the pin debt. **Done 2026-11-03** — [PS.SSL#78](https://github.com/jjohns-dev/PS.SSL/pull/78) `e5a6cb2`, one line. Deliberately done while it was a behavioural no-op: `v1` (tag object `ffbef62`) and `v1.5.0` (`2cfc303`) both dereference to commit `9aa935a`, so only the ref name changed. The same repoint after a `v1.6.0` lands would have carried real change.
     **No staging pins remain anywhere in the fleet** — every `pwsh-module-ci` reference across all seven repos' workflows resolves to `@v1`, verified 2026-11-03. The floor, `os-matrix`, `Build/` and the LF encoding were untouched; `min-tests: 336` still reads *executed*.
  7. [x] **`PS-MCS/mcssec-ops`'s `ps-module-validate.yml`** — a private copy of the same step, not reachable by the tag. **Done 2026-11-03** — [mcssec-ops#152](https://github.com/PS-MCS/mcssec-ops/pull/152) `1613cad`, signed. The `run:` block is **character-identical** to `ci.yml@v1.5.0` (3156 chars, `-ceq` true), matching `SecurityTools`; `MIN_TESTS: ${{ inputs.min-tests }}` and the `inputs:` block untouched.
     **Could not be staged**, since `ArcGISEnterprise` and `PS.ETL` both pin `@main` — so all verification was pre-merge, and there is no `required_status_checks` rule on that repo to catch a mistake afterwards. Both consumers were re-measured safe first: ArcGIS `disabled = 0`, PS.ETL passes no floor at all.
     **Confirmed live at a consumer**, which a green run alone could never show. `ArcGISEnterprise`'s next run — its first since the merge, five days after its previous one — produced the **new** message format: `1881 tests executed (1881 collected, 0 disabled), below the min-tests floor of 999999`. The failing run also still uploaded a well-formed artifact.
     Merged under the org-admin bypass on ruleset `2420725`, as all four earlier PS-MCS rollout PRs were. Review came from Copilot code review, which that ruleset requires; the repo-owner decision and its rationale — CI-only scope, discussed with the team — are recorded on the PR.
     **A fourth copy surfaced afterwards.** This step's list was assembled from the duplication already known, and `PS-MCS/MCS` was not in it — its `validate.yml` carries its own inline copy of the step. Found 2026-11-03 while scoping MCS#215 and folded into that issue; not reopened here.

**Track B is complete. Phase 3 is complete.**

### Picked up while finishing Track B

- [x] **`ArcGISEnterprise` floor re-derived** — [#149](https://github.com/PS-MCS/ArcGISEnterprise/issues/149) closed by [#150](https://github.com/PS-MCS/ArcGISEnterprise/pull/150) `b3444f8`. **1692 → 1871**, cutting headroom from **189 tests to 10**. It was the widest gap in the fleet. Its floor had been set hours before ADR-0004 landed and nothing had touched it since.
  This PR doubled as the step 7 confirmation above — real work rather than a throwaway run, and its impossible-floor test is what proved `mcssec-ops#152` had taken effect.
- [x] **`MCS` floors re-derived, and its private copy of the verify step brought current** — [MCS#215](https://github.com/PS-MCS/MCS/issues/215) closed by [#216](https://github.com/PS-MCS/MCS/pull/216), merged as `45172b7` on 2026-11-03. ubuntu `369 → 400`, windows `122 → 130`. The windows leg lands at a margin of **6, not 10**: ADR-0004's percentage term binds below the cap at that size, `floor(136 * 0.05) = 6`.
  **`MCS` held a fourth private copy of the verify step**, missed by Track B step 7 because that list was assembled from the duplication already known. Its `validate.yml` consumes no shared workflow, and its block was character-identical to the **pre-#23** shared one (2525 chars trimmed). After the port it matches `ci.yml@v1.5.0`, `-ceq` true. Eleven repos were audited at the time and `MCS` was the last holdout, so the mass-skip blind spot is now closed everywhere.
  **Verified from the artifacts rather than from the agent's arithmetic.** Both legs re-measured at `disabled = 0`, executed **410 / 136**, and both floors re-derived from those counts rather than checked against the report. The sabotage run failed on both legs **and** still uploaded parseable XML, and its log carried the new message format — `410 tests executed (410 collected, 0 disabled), below the min-tests floor of 999999` — which the old block cannot produce. That is what proves the port took effect; a green run could not. Post-merge CI on `main` is green at `45172b7`.
  **The agent raised a real discrepancy rather than matching the brief.** The issue's 3156 / 2526 counts include the block scalar's trailing newline; its own 3155 / 2525 exclude it. Both reproduce. The issue body's claim that the executed logic was already live here was false and had been corrected in the body before work started.
- **Audit result, 2026-11-03 — drained to [ADR-0005](docs/adr/0005-floor-sweeps-scoped-by-repo-list.md).** Both stale floors are corrected. The ADR also **corrects the diagnosis that used to sit here**: this file called the missing half a *periodic audit*, when the actual defect is a sweep scoped by the consumer graph rather than by the repo list. The other claim that went with it — `PS.ETL` being the only repo without a floor at all — was falsified the same week by [PS.ETL#31](https://github.com/PS-MCS/PS.ETL/pull/31) setting it to 70.

  **Survey complete, 2026-10-29. `PS.SSL` is the only repo that breaks.**

  | Repo | Floor | `disabled` | Under #23 |
  | ---- | ----- | ---------- | --------- |
  | `PS.SSL` | 350 | 14 / 15 | **RED on both legs** — executed 346 / 347 |
  | `SecurityTools` | 987 / 20 | 1 / 0 | safe, executed 996 |
  | `AWSAutomation` | 430 | 0 | safe |
  | `PS.Log` | 87 | 0 | safe |
  | `PS.GHOps` · `PS.GitHub` · `PS.DCU` | none yet | 0 | safe, Track A sets them |
  | `MCS` | 369 / 122 | 0 | safe |
  | `ArcGISEnterprise` | 1692 | 0 | safe |
  | `PS.ETL` | **none passed** | n/a | safe — an unset `MIN_TESTS` reads as 0, which disables the check |

  **`mcssec-ops` cannot be staged the way `pwsh-module-ci` can** — drained to [#20](https://github.com/jjohns-dev/pwsh-module-ci/issues/20), together with the measured inventory of every file carrying a copy of the verify step.

  `PS.ETL`'s `validate.yml` runs on `pull_request` only, which is why its `main` history shows no test artifacts. That is not an absence of CI.

## Phase 4 — Close the tracker issue — COMPLETE

- [x] **Close** [#17](https://github.com/jjohns-dev/pwsh-module-ci/issues/17) — **done 2026-11-03**, `closed/completed`.
  **Every checkbox was audited against the repositories, not against memory**, and the audit was worth running: eleven boxes were unticked but already complete, and two carried stale numbers. `AWSAutomation` was recorded at `560` and is now `434`; `ArcGISEnterprise` had moved `1692 → 1871`. Both corrected in place rather than silently re-ticked.
  **Seven of eight repos with a `Help.Tests.ps1` now source parameter names from the AST.** `PS.GHOps` and `PS.GitHub` never needed the fix — they have no such file — and got floors only. `ECSNext` is archived.
  **`PS.ETL` is the sole outstanding item, in both sections**, and the decoupling was real rather than convenient: verified 2026-11-03 that its `Help.Tests.ps1` still does not use the AST and it passes no floor. It needs a Pester 5.5.0 → 6.2.0 upgrade first, which no other repo did, and is tracked at [PS.ETL#22](https://github.com/PS-MCS/PS.ETL/issues/22).
  The closing summary records what the issue turned into: #22, #23, #27, ADR-0004 and both docs all grew out of one tautology. Their shared signature — *a check that could not fail, indistinguishable from one that passes* — is now three documented vacuity traps in `docs/shared-ci-standards.md`.

## Phase 5 — Stop the duplication

Gated on Phases 1–2.

- [ ] **pwsh-module-ci** — [#24](https://github.com/jjohns-dev/pwsh-module-ci/issues/24)
  Converge the fleet off `BuildHelpers`. Prep for #20 — it removes one known `Build/` difference before the classification work starts.
  **Only `PS.ETL` remains.** `PS.Log` converged 2026-10-26 ([PS.Log#56](https://github.com/jjohns-dev/PS.Log/pull/56)) and `PS.SSL`'s vestigial entry went with [PS.SSL#72](https://github.com/jjohns-dev/PS.SSL/pull/72) — verified 2026-10-28, zero `BuildHelpers` entries in either `depend.psd1`. The `PS.ETL` half waits on PS-MCS/PS.ETL#22.
- [ ] **pwsh-module-ci** — [#20](https://github.com/jjohns-dev/pwsh-module-ci/issues/20)
  Stop duplicating `Build/` **and** `Tests/Common/`. Diff the test template only after Phase 1–2 lands, or you classify drift against a moving baseline.

## Phase 6 — Migration

- [ ] **pwsh-module-ci** — [#19](https://github.com/jjohns-dev/pwsh-module-ci/issues/19) — gated on Phases 1–5
  psake → Sampler. Design for SecurityTools' per-leg test scope from the start, migrate that repo last.
- [ ] **pwsh-module-ci** — [#21](https://github.com/jjohns-dev/pwsh-module-ci/issues/21) — gated on #19
  Centralize SecurityTools CI. Current lean is a second reusable workflow rather than extending `ci.yml`.

## Phase 7 — Link-case back-fill — COMPLETE

No longer deferred. Pulled forward into Phase 2 for both `PS-MCS` repos, because each was already editing the same `It` block and already re-deriving its floor, so the marginal cost was near zero. **All six repos landed 2026-10-28/29.**

- [x] **pwsh-module-ci** — [#22](https://github.com/jjohns-dev/pwsh-module-ci/issues/22)
  Stop generating link cases for commands with no `.LINK`. **Done everywhere: `ArcGISEnterprise` (132 cases removed), `SecurityTools` (66), `MCS` (34), `AWSAutomation` (34 of 36), `PS.SSL` (15 per leg), `PS.Log` (6).**
  Reference implementation is `MCS` after [#214](https://github.com/PS-MCS/MCS/pull/214) — URIs collected in `BeforeDiscovery` from `Get-Help`, bound with `-ForEach ... -AllowNullOrEmptyForEach`. **Source from `Get-Help`, not the AST**: the AST returns related-topic names alongside URIs, which would fail the scheme check. Filter on a non-empty `uri`, since a command with no `.LINK` still yields an entry with an empty one.
  **Each back-fill moved that repo's floor**, re-derived in the same PR under ADR-0004 with the derivation recorded in the `min-tests` trailing comment, as [PS.Log#60](https://github.com/jjohns-dev/PS.Log/pull/60) did. That matters most when the floor value happens not to change, since the diff then carries no evidence the floor was considered at all.

  | Repo | Cases | Collected after | Floor | PR |
  | ---- | ----- | --------------- | ----- | -- |
  | `ArcGISEnterprise` | 132 → 0 | 1881 | 1692 | [#146](https://github.com/PS-MCS/ArcGISEnterprise/pull/146) |
  | `SecurityTools` | 66 → 0 | 997 / 21 | 987 / 20 | [#159](https://github.com/jjohns-dev/SecurityTools/pull/159) `48c1ffe` |
  | `MCS` | 34 → 0 | 410 / 136 | 369 / 122 | [#214](https://github.com/PS-MCS/MCS/pull/214) |
  | `AWSAutomation` | 36 → **2** | 444 | 430 → **434** | [#103](https://github.com/jjohns-dev/AWSAutomation/pull/103) `b11313b` |
  | `PS.SSL` | 15 → 0 per leg | 360 / 362 | 337 → 350 | [#76](https://github.com/jjohns-dev/PS.SSL/pull/76) `90d9a6d` |
  | `PS.Log` | 6 → 0 | 91 | 87 unchanged | [#60](https://github.com/jjohns-dev/PS.Log/pull/60) `9f0b086` |

  **`SecurityTools` was the live test of the AST-vs-`Get-Help` choice, and it passed.** Its one `.LINK` is `ConvertTo-GZipString`, a related-topic name rather than a URI, so `Get-Help` files it under `linkText` with an empty `uri` and it is correctly dropped — while the AST would return it and fail the scheme check. It is the only repo in the fleet where the wrong source breaks something.
  **`AWSAutomation` was the genuine exception, and it closed the one remaining hole.** Its two `.LINK`s are real `docs.aws.amazon.com` URLs, so two cases survive and "zero cases generated" would have been the wrong assertion. More importantly it is the only repo that could prove the *generator* still works: its mutation runs collected 445 tests with **3** link cases and exactly one failure each, the two real links passing alongside the broken one. In the other five, a filter returning nothing unconditionally would have produced zero cases and passed green through every check. That failure mode is now ruled out by measurement rather than by argument — generalized into `docs/shared-ci-standards.md`.

## Phase 8 — Drain this file, then delete it

Gated on everything else. The header says to delete this file when the last box is checked, which is right about the file and wrong about its contents: several sections are the only written record of something measured once and expensive to re-derive. The "Found during the rollout" section already concedes the point — it exists *"so they are not lost when this file is deleted."*

So the last phase is a drain, not a `git rm`. **Nothing is deleted until its destination is named**, and a destination means a merged commit rather than an intention.

**Considered and rejected: moving this file to `docs/specs/`.** It is not a spec — no requirements, no design, and the task list is a byproduct rather than the artifact. It was written during and after execution rather than before, so filing it as one would imply approval gates that never happened. The decisive objection is the third: `docs/specs/` is read as *current intent*, and this file disclaims authority in its own header — *"Where the two disagree, the issue wins."* A permanent, unmaintained, non-authoritative document in a directory agents treat as intent is how stale guidance gets manufactured. `docs/adr/` is already this repo's mechanism for the durable half.

- [ ] **Disposition pass**, one row at a time.

  | Section | Destination |
  | ------- | ----------- |
  | Phase table, every checkbox, all sequencing and gating | **delete** — coordination state, worthless once the batch lands |
  | Per-repo phase narratives | **delete** — the issues and PRs are authoritative and already linked from here |
  | `Install-PSResource` exact-pin and NuGet-range traps | ✓ **done** — already stated in `docs/dependency-stack.md`; the copies here and in `shared-ci-standards.md` were duplicates, so deleted rather than moved |
  | Floor, vacuity and measurement traps | ✓ **done 2026-11-04** — [`docs/test-integrity.md`](docs/test-integrity.md) |
  | The opportunistic-floor blind spot | ✓ **done 2026-11-04** — [ADR-0005](docs/adr/0005-floor-sweeps-scoped-by-repo-list.md) |
  | Repo-local gotchas | that repo's `AGENTS.md`, verified in the repo rather than copied across |
  | GitHub ruleset mechanics — `PUT` not `PATCH`, and no classic branch protection anywhere in the fleet | this repo's `AGENTS.md`, under *Gotchas that have bitten here*, which already carries the tag-ruleset lore |
  | Anything still open | its issue, in the body |
  | `mcssec-ops` cannot be staged; the copies of the verify step | ✓ **done 2026-11-04** — [#20](https://github.com/jjohns-dev/pwsh-module-ci/issues/20), with the copy count re-measured at **5**, not four |
  | `AWSAutomation`'s ADR-0002 caveat | ✓ **done 2026-11-04** — confirmation **failed**: the caveat is *not* in that repo's ADR. Safe only because [`docs/dependency-stack.md`](docs/dependency-stack.md) states it independently; adding it to the ADR folded into [#24](https://github.com/jjohns-dev/pwsh-module-ci/issues/24) |

- [ ] **Delete `ROLLOUT.md` from `main`** in its own PR, once every row above is worked.

**Two things that looked like they needed a retrospective, and do not.** Checked 2026-11-03, and the check corrected a row above.

**The traps were already written — in a file scheduled for deletion. Resolved 2026-11-04.** `docs/shared-ci-standards.md` declares itself *"Interim scaffolding. Delete it when #20 lands"* while carrying lessons that are in no way interim, so they were carved into [`docs/test-integrity.md`](docs/test-integrity.md) exactly as `dependency-stack.md` was carved out before it.
**It was more than the four traps this row originally named.** Reading the file properly showed that only the reference-implementations table dies with #20; the test-design decisions, the floor procedure and the mutation rule all survive it. `shared-ci-standards.md` is now that table plus a pointer. The move also fixed a self-contradiction it had been carrying — one bullet derived the floor margin from the **collected** count while another, four lines later, said a floor must be derived from the **executed** count.

**The evidence catalogue belongs on [#34](https://github.com/jjohns-dev/pwsh-module-ci/issues/34), not in a doc.** #34 makes the argument but names its evidence in a single sentence — four defects, no links, no commits. Its decisive checkbox asks whether `PSMutant` would have caught the defects already fixed, and answering it needs the actual list: repo, pre-fix commit, what the defect was, and the mutation that proved it red. Evidence serving a pending decision has a home; a free-floating retrospective would be the same content with nowhere to act on it.

**So: no retrospective.** What looked like a page-sized gap is a misfiled set of traps plus a thin evidence section on an open issue.

## Runs on its own clock

- [x] **PS.ETL** — [PS.ETL#22](https://github.com/PS-MCS/PS.ETL/issues/22), **closed 2026-11-04**
  Pester 5.5.0 → 6.2.0 first, passing command **names** rather than `CommandInfo` objects to `-ForEach`. Decoupled from #17, blocks nothing.
  **This was recorded fleet-wide as a "hang" and it is not one.** Measured 2026-11-03 during PS.ETL step 1: 6.2.0 renames every affected test to `Management.Automation.FunctionInfo{Name='...'} help`, which would have moved 68 of that repo's 78 test names. 6.0.0 did not hang either — it finished in 52s and wrote a **1.2 GB** result file, which is almost certainly what the original report described. The change is still required; the reason was wrong.
  **Restructured into eight steps 2026-11-03**, each its own PR: `0` PSDepend · `1` Pester 6.2.0 **and** the psake gate · `2` matching-help binding · `3` the three other defects · `3A` remove the dead docs pipeline · `4` psake · `5` the floor · `6` CI on `main`. `3A` is lettered because the later numbers are cited in merged commits; it must land before `4`, since both touch `depend.psd1` and one removes a pin while the other bumps one.

  | Step | State |
  | ---- | ----- |
  | 0 — PSDepend → `Install-PSResource` | done, `b9c5699` ([#23](https://github.com/PS-MCS/PS.ETL/pull/23)) |
  | 1 — Pester 6.2.0 + the `Result` gate | done, `69ced39` ([#24](https://github.com/PS-MCS/PS.ETL/pull/24)) |
  | 2 — matching-help discovery binding | done, `907dd41` ([#25](https://github.com/PS-MCS/PS.ETL/pull/25)) |
  | 3 — the three remaining defects | done, `19c3e6f` ([#28](https://github.com/PS-MCS/PS.ETL/pull/28)) |
  | 3A — remove the dead docs pipeline | done, `dfdf2c2` ([#29](https://github.com/PS-MCS/PS.ETL/pull/29)) |
  | 4 — psake 4.9.0 → 5.0.4 | done, `bdaaae7` ([#30](https://github.com/PS-MCS/PS.ETL/pull/30)) |
  | 5 — the `min-tests` floor | done, `bf395da` ([#31](https://github.com/PS-MCS/PS.ETL/pull/31)) — **70** |
  | 6 — CI on `main` | done, `5ec1314` ([#32](https://github.com/PS-MCS/PS.ETL/pull/32)) |

  **Step 2 is the one that paid off visibly: 78 → 102 collected, with the matching-help cases going 0 → 24.** They had never run in this repo. Both mutations were required and proved different things — a bogus `.PARAMETER` took the count to 25 with exactly one failure named `BOGUS` (the assertion works), while stripping a function's help took its cases to 0 with no case named `$null` (the generator and the `$_ -and` guard work). Either alone would have been insufficient.
  **Step 3 then took it to 73**, deleting 24 mandatory-value cases and 5 link cases. **Its mutation is the cleanest demonstration in the rollout of why a fix needs proving in both directions:** the same sabotage — all comment-based help stripped from one function — left `Should not be auto-generated` **passing** under the old `-Contain` assertion and **failing** under the new `-BeLike` one. The "after" run alone would have proved nothing.
  **No function in this repo has a `.LINK`**, so the link test's `if` was never true: five cases that asserted nothing on every run, invisible to the floor because they still emitted `testcase` nodes. Applying [#22](https://github.com/jjohns-dev/pwsh-module-ci/issues/22)'s generator here therefore yields **zero** cases, and this repo cannot prove that generator works — `AWSAutomation`, the only repo with real `.LINK` URLs, is where that proof lives.
  **Step 3A deleted the PlatyPS pipeline**, which was wired into `CombineFunctionsAndStage` via `$pathsToCopy` — so the published release asset had been shipping six stale markdown files, and deleting the folder without that line would have failed staging and every task depending on it. The patch block in `build.ps1` turned out not to be merely dead: it ran on every invocation and had been printing `Get-Content: Cannot find path` on every **local** build, silently, because nothing imports PlatyPS. Three further edit sites — a `ValidateSet`, a `CONTRIBUTING.md` step and a stale comment — were found by grepping during implementation rather than during scoping.
  **Step 4's stated rationale was wrong, and the agent measured it rather than accepting it.** The issue claimed Pester failures surfaced "only in the raw log" on psake 4.9.0. Measured: 4.9.0 **already** annotates failing tests — that is Pester 6's own GitHub Actions output, independent of psake. What 5.0.4 adds is psake's own gate message, annotated at `psake/5.0.4/private/Invoke-BuildPlan.ps1:185` — i.e. pointing into psake's source, not this repo's. The honest case for the bump is fleet consistency, not annotations. Still unverified: whether 5.0.4 annotates PSScriptAnalyzer failures, since `Analyze` passed in every run.
  **Step 5 set the floor at 70**, from executed 73 under ADR-0004 — `73 - min(floor(3.65), 10) = 73 - 3`. The percentage term binds here, not the cap. Verified in both directions, and the impossible-floor run is the clean case: `Verify Pester results` **failed** and `upload-artifact` **succeeded after it**, so the diagnostic XML survived the failure it was meant to explain.
  **Step 5 also surfaced a defect in [ADR-0004](docs/adr/0004-min-tests-floor-margin.md) itself** — its Decision still read `collected` after [#23](https://github.com/jjohns-dev/pwsh-module-ci/issues/23) changed the input to `executed`. Harmless in `PS.ETL`, where `disabled` is 0, but deriving from collected in a repo with disabled tests yields a floor **above** the executed count, which is the defect #23 removes. Amended, not superseded: the decision stands, only its input changed, and Context is deliberately left as the record of 2026-10-28 — including the bullet *"skipped tests are still counted"* that #23 went on to falsify.
  **Step 6 turned on one fact: `validate` was not a required status check.** That repo has no classic branch protection, and its only ruleset — org-level — requires a pull request and a code-owner review but sets **no required checks at all**. So the PR run was advisory and nothing had ever run against the commit that actually landed. Adding `push: branches: [main]` therefore buys a *detective* guard, not a preventive one, and the PR says so rather than overselling it.
  **Its concurrency handling went past the brief, correctly.** Pushes get a per-SHA group so back-to-back merges cannot cancel one another, while pull requests keep cancel-on-supersede. Eight of the nine siblings group by ref with `cancel-in-progress: true` and so carry the gap this avoids; `queue: max` is the only other fix and is unavailable, since GitHub rejects it combined with `cancel-in-progress: true`, which the PR leg needs. **The merge proved itself** — a workflow file is evaluated at the pushed commit, so the squash commit that added the trigger fired the first run: `event=push`, green, 73 executed. `main` has CI and a result artifact for the first time.
  **`PS.ETL` was also the last repo on PSDepend** — every other `Build/build.ps1` in both orgs had migrated.

### Found during the rollout, deliberately not folded into it

Each of these was surfaced by rollout work, is independent of it, and would have expanded a phase's scope if bundled. Recorded here so they are not lost when this file is deleted.

- [x] **`SecurityTools` has no `.gitattributes`** — [SecurityTools#161](https://github.com/jjohns-dev/SecurityTools/issues/161), opened 2026-11-02, **closed 2026-11-03**
  **72 tracked files were CRLF; zero are now.** Surfaced when [#160](https://github.com/jjohns-dev/SecurityTools/pull/160) had to split into two commits — one pure EOL conversion, one real change — just to keep the substantive diff legible. Measured across the fleet: 22 of 23 workflow files in the 8 `jjohns-dev` repos are LF, and `validate.yml` was the single exception *and* the odd file inside its own repo. Done **before** [#21](https://github.com/jjohns-dev/pwsh-module-ci/issues/21), as planned.
  Landed as [#163](https://github.com/jjohns-dev/SecurityTools/pull/163), squashed to `6bf77d4`, then [#164](https://github.com/jjohns-dev/SecurityTools/pull/164) → `8d3d72d` for `.git-blame-ignore-revs` and an `AGENTS.md` note. Both post-merge runs green.
  **The safety argument was made properly**: `git diff --ignore-cr-at-eol` empty across the renormalisation, *plus* a control proving that command can return non-empty against a real content change. An empty diff from a command that cannot report a difference would have proved nothing. Test counts identical before and after on both legs (997/1 and 21/0), so the floors never moved.
  **Blame attribution moves, but only partly.** Measured against the real squash commit: 5,514 → 596 across the 72 files, and every remaining line is blank — git's ignore-revs matching does not reassign blank lines. The issue body implied attribution returns wholesale to the original authors; it does not. Independently re-measured here at 5,528 → 610 over all 73 files the commit touched, the 14-line difference being `.gitattributes` itself.
  **Two sequencing traps, both caught before they bit.** The `.git-blame-ignore-revs` entry had to name the **post-merge squash SHA**, which does not exist until the merge — this repo allows squash only, so the pre-merge commit SHAs would have matched nothing. And #163 deliberately said *"Part of #161"* rather than *"Closes"*, so the issue stayed open to carry the blame follow-up rather than taking it to the grave.
- [ ] **`PS.DCU` has no behavioural tests** — [PS.DCU#20](https://github.com/jjohns-dev/PS.DCU/issues/20), opened 2026-11-02
  Its 85 tests are `Meta` 42, `Help` 32, `Manifest` 11 — the only three test files in the repo, none using `Mock`, none executing module logic — against 12 source files carrying 25 `dcu-cli` and 24 `System.Management` references. Found while questioning whether the Windows-only switch was justified. **Its `min-tests` floor guards metadata coverage, not behaviour**, and nothing in the rollout changes that.
- [ ] **Evaluate `PSMutant`** — [#34](https://github.com/jjohns-dev/pwsh-module-ci/issues/34), opened 2026-11-02
  Every test-authoring defect this rollout fixed shared one shape: an assertion that could not fail. Each was caught by a human reading the test and proving it by hand — which is mutation testing, executed one mutant at a time. `PSMutant` 0.9.1 was published 2026-10-26. **Independent of [#19](https://github.com/jjohns-dev/pwsh-module-ci/issues/19)**: a build framework operates at a different layer, and #19 already records that Sampler *"would have prevented none of"* these defects.
- [ ] **Remove the unused `PlatyPS` pin** — folded into [#24](https://github.com/jjohns-dev/pwsh-module-ci/issues/24)
  Pinned at `0.14.2` in `AWSAutomation` and **never invoked** — no `New-MarkdownHelp`, no `en-US/`, no docs task, `HelpInfoURI` commented out. Same category as the `BuildHelpers` work already in that issue. Its ADR-0002 justifies the pin on a premise that cannot hold for an uncalled tool, so that ADR needs an **amendment, not a superseding ADR** — the decision stands, one item in its enumeration was wrong.

**Not work, a standing caveat — kept in [`docs/dependency-stack.md`](docs/dependency-stack.md), not here.** `AWSAutomation` floats its runtime dependencies to `'latest'`; **do not copy that without re-deriving it**, since it turns on those modules being unversioned `RequiredModules`, which no other repo has. **Phase 8 assumed this caveat was already in that repo's ADR-0002. It is not** — checked 2026-11-04, that ADR records the decision but carries no do-not-copy warning, so deleting on that premise would have lost it. It survives here only because `dependency-stack.md` states it independently. Giving that ADR the caveat belongs with [#24](https://github.com/jjohns-dev/pwsh-module-ci/issues/24), which is already correcting its PlatyPS premise.

## Reference — moved out

The floor procedure, the mutation rule, the vacuity traps and the `-ceq` distinction moved to [`docs/test-integrity.md`](docs/test-integrity.md) on 2026-11-04, along with the whole non-interim half of `docs/shared-ci-standards.md`. Read that file; these rules are no longer duplicated here.

**Deleted rather than moved**, and worth recording why. The two #22 / #23 sequencing traps went: both issues are closed, and their only durable content — which repos have `disabled` tests — is now in `test-integrity.md`. That section also carried a **superseded measurement**, `PS.SSL` at executed 361 / 362 against a floor of 337 from 2026-10-29; the later Phase 3 table in this file records 346 / 347 against 350, so copying the old pair forward would have propagated the wrong one. The PSDepend migration rule went too — all ten repos are migrated, so it is a completed instruction rather than a standing one, and its two carry-forward facts are in [`docs/dependency-stack.md`](docs/dependency-stack.md).

## Along the way: AGENTS.md for three repos

- [x] **PS.Log** — written in [PS.Log#55](https://github.com/jjohns-dev/PS.Log/pull/55), kept current in [#56](https://github.com/jjohns-dev/PS.Log/pull/56)
- [x] **PS.SSL** — present on `main`, verified 2026-10-28
- [ ] **PS.DCU** — still the only one of the three without an `AGENTS.md`

Only `PS.DCU` is outstanding, and it is receiving a non-trivial PR in Phase 3.

**Decided 2026-10-30 — fold it into the PS.DCU prompt rather than tracking it separately, and sequence it after the OS switch, not before.** The general advice above is "write it first", and for a repo in a steady state that is right. PS.DCU is not in a steady state: the Track A work removes the PSDepend bootstrap and moves CI from `ubuntu-latest` to `windows-latest`. Those are exactly the two things an `AGENTS.md` would lead with, so a file written first would be documenting a repo that no longer exists by the end of the same session, and would need correcting in the PR that invalidated it.

Write it in or after the PR that lands the OS switch, so the Windows-only rationale — *the module wraps a Dell utility, so testing it anywhere else asserts nothing* — is recorded as a current fact rather than a pending change. `PS.GHOps` and `PS.GitHub` already have an `AGENTS.md`; they need theirs **checked for staleness** against the PSDepend removal instead, in the PR that causes it.

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
