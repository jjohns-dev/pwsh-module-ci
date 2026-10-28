# Rollout tracker

**Temporary working file. Delete it when the last box is checked.** It exists to coordinate one batch of cross-repo work; it is not a permanent part of this repo and nothing reads it.

Authoritative detail lives in the linked issues — this is an index and an ordering, not a substitute. Where the two disagree, the issue wins.

## Phase 1 — Suites that are currently lying

Zero matching-help cases collected. Green because the tests do not exist.

- [x] **PS.Log** — [PS.Log#54](https://github.com/jjohns-dev/PS.Log/issues/54)
  Done 2026-10-26, merged as [PS.Log#55](https://github.com/jjohns-dev/PS.Log/pull/55). AST discovery binding, defects 1/2/3, `min-tests: 87`. The implementing agent also caught two errors in its brief — see the corrections on #17.
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

## Phase 3 — Make regressions visible

- [ ] **pwsh-module-ci** — [#23](https://github.com/jjohns-dev/pwsh-module-ci/issues/23)
  The floor counts skipped tests, so a mass-skip regression passes. **Also apply to `PS-MCS/mcssec-ops`.** Staged rollout via an immutable `vX.Y.Z` pin.
  **Scope shrank 2026-10-28.** The margin question that used to live here is settled in [ADR-0004](docs/adr/0004-min-tests-floor-margin.md), so what remains is only the change of input from `tests` to `tests - disabled`.
  **Blocked on one measurement:** `PS.SSL`'s `disabled` count has never been taken. Its skips are whole `Describe` blocks gated on openssl and network reachability, so its executed count could be well below 375 — and this change makes the floor measure executed, not collected. Measure before deriving.
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

- [ ] **pwsh-module-ci** — [#24](https://github.com/jjohns-dev/pwsh-module-ci/issues/24)
  Converge `PS.Log` and `PS.ETL` off `BuildHelpers`, drop `PS.SSL`'s vestigial entry. Prep for #20 — it removes one known `Build/` difference before the classification work starts. **`PS.Log` done** 2026-10-26 ([PS.Log#56](https://github.com/jjohns-dev/PS.Log/pull/56), merged). `PS.SSL` is a one-line `depend.psd1` deletion; the `PS.ETL` half must wait for PS-MCS/PS.ETL#22.
- [ ] **pwsh-module-ci** — [#20](https://github.com/jjohns-dev/pwsh-module-ci/issues/20)
  Stop duplicating `Build/` **and** `Tests/Common/`. Diff the test template only after Phase 1–2 lands, or you classify drift against a moving baseline.

## Phase 6 — Migration

- [ ] **pwsh-module-ci** — [#19](https://github.com/jjohns-dev/pwsh-module-ci/issues/19) — gated on Phases 1–5
  psake → Sampler. Design for SecurityTools' per-leg test scope from the start, migrate that repo last.
- [ ] **pwsh-module-ci** — [#21](https://github.com/jjohns-dev/pwsh-module-ci/issues/21) — gated on #19
  Centralize SecurityTools CI. Current lean is a second reusable workflow rather than extending `ci.yml`.

## Phase 7 — Link-case back-fill, four repos

No longer deferred. Pulled forward into Phase 2 for both `PS-MCS` repos, because each was already editing the same `It` block and already re-deriving its floor, so the marginal cost was near zero.

- [ ] **pwsh-module-ci** — [#22](https://github.com/jjohns-dev/pwsh-module-ci/issues/22)
  Stop generating link cases for commands with no `.LINK`. **Done in `ArcGISEnterprise` (132 cases removed) and `MCS` (34).** Outstanding in `PS.Log` (~6), `PS.SSL` (~15), `SecurityTools` (~65, it has one real `.LINK`) and `AWSAutomation` (~34, two real `.LINK`s).
  Reference implementation is `MCS` after [#214](https://github.com/PS-MCS/MCS/pull/214) — URIs collected in `BeforeDiscovery` from `Get-Help`, bound with `-ForEach ... -AllowNullOrEmptyForEach`. **Source from `Get-Help`, not the AST**: the AST returns related-topic names alongside URIs, which would fail the scheme check.
  **Each back-fill moves that repo's floor**, so re-derive it in the same PR under ADR-0004's formula.

## Runs on its own clock

- [ ] **PS.ETL** — [PS.ETL#22](https://github.com/PS-MCS/PS.ETL/issues/22)
  Pester 5.5.0 → 6.2.0 first, including the `CommandInfo` hang fix. Decoupled from #17, blocks nothing.
- [ ] **AWSAutomation dependency policy** — recorded as ADR-0002 in that repo, 2026-10-28
  Its 14 `AWS.Tools.*` modules and `ImportExcel` now resolve to `'latest'`; build tooling stays pinned. **Do not copy this to another repo without re-deriving it** — it turns on those modules being unversioned `RequiredModules`, which no other repo in the fleet has. The NuGet-range trap behind it is recorded on #27.

## Two sequencing traps

**#22 edits the same `It` block as the Phase 1–2 work.** Resolved for `ArcGISEnterprise` and `MCS` by doing it with them. For the remaining four, that block is now settled on `main`, so the back-fill is a clean single edit rather than a rebase hazard.

**#23 changes floor semantics for the only two repos that use `-Skip`** (PS.SSL, SecurityTools). Everywhere else `tests` and executed counts are identical, so it makes no difference. **Decided by events** — #23 did not land first, so both repos carry floors derived against `tests`, which includes skips, and both need re-deriving when it lands. The measured counts are on #23. SecurityTools is the easy half (1 skipped on ubuntu, 0 on windows); **PS.SSL is the real exposure**, and its `disabled` count is still unmeasured.

## Recurring rules for every PR from here on

- **Migrate the repo off PSDepend first, in its own PR** (#27). `Import-PowerShellDataFile` on `Build/depend.psd1`, then `Install-PSResource` per entry. All ten `depend.psd1` files are identical in **shape** — every entry is a plain `Name = 'version'` string — so it is the same edit everywhere. They are *not* identical in content; the pinned versions have drifted, and the table is on #20. Separate PR, before any test work, so a module-install failure surfaces against a three-line diff instead of a large one.
  **Done in `SecurityTools`, `AWSAutomation`, `ArcGISEnterprise` and `MCS`. `PS.Log` and `PS.SSL` still owe it** — their Help.Tests work landed before this was decided, so they are catch-up, tracked on #27.
  Carry forward: a bare version string is an **exact** pin under `Install-PSResource`, not a minimum; and a NuGet *range* does not resolve to the newest member, so never use one.
- **Fix first, measure second, set the floor third.** A floor derived before the fix records the defective count as the baseline, and can never trip on a regression back to it. Read the number from the run's JUnit artifact; never predict it.
- **The floor is `collected - min(floor(collected * 0.05), 10)`** — [ADR-0004](docs/adr/0004-min-tests-floor-margin.md). Use it for every floor derived from 2026-10-28 on. Existing floors move opportunistically, whenever a PR next touches them; a repo still on the old 90% convention is expected, not a bug.
- **Acceptance is the mutation, not the count.** Make the thing you are guarding fail, confirm red, revert. A check that never fires is indistinguishable from one that passes. Where a repo cannot produce that evidence incidentally — no `.LINK` anywhere, for instance — the mutation has to be manufactured.
- **Verify floors in both directions.** An impossible floor must fail the run *and* leave the result XML uploaded; a correct floor must stay quiet.

## Along the way: AGENTS.md for three repos

- [x] **PS.Log** — written in [PS.Log#55](https://github.com/jjohns-dev/PS.Log/pull/55), kept current in [#56](https://github.com/jjohns-dev/PS.Log/pull/56)
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
