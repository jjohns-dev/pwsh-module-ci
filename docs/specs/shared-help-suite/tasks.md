# Shared help suite — tasks

- **Requirements:** [requirements.md](requirements.md), approved 2026-11-16; AC 2 amended 2026-11-16
- **Design:** [design.md](design.md), approved 2026-11-16
- **Status:** Approved — 2026-11-16

Each task names its verification and the acceptance criteria (AC) it serves. Phase B is one PR in this repo; C is the release; D is one PR per consumer, through the agent-prompt pattern, each verified here from run artifacts before its box is ticked.

## B. Harness change, one PR

Every assertion gets a fixture that must fail it and one that must pass it, under strict mode on and off. *(AC 8)*

- [x] **B1. `Build/SharedTests/help.tests.ps1`**: four tests per exported function, one looped link test. *(AC 1–7)*
  - Verify: re-run the 2026-11-16 measurement through the real suite: stage each of the eight consumers' `main` and run the suite against it, lenient and strict. Expect zero failures and `4n + 1` tests each, `Get-KEVList` included.
  - **Done 2026-11-16.** All eight green in both modes at exactly `4n + 1`: PS.Log 25, PS.GHOps 41, PS.GitHub 25, PS.SSL 61, PS.DCU 33, AWSAutomation 145, SecurityTools 265, PS.YNAB 41. PS.YNAB's `main` moved to `674e1dd` since the requirements were measured and now exports 10 functions, so 41 rather than the 37 recorded there.
- [x] **B2. Fixture cases** in `tests/SharedTests.Tests.ps1`, the design's list, each naming exactly the tests it must fail, lenient and strict. *(AC 8)*
  - Verify: every test fails in at least one case; a run without `-Data` fails. Mutations, each of which must turn the suite red: reading parameters through `Get-Help`; dropping the `DynamicParam` exemption's AST check, so it exempts every function; dropping `.PSBase`; dropping either half of the link check; checking only the first function.
  - **Done 2026-11-16.** Seventeen cases, lenient and strict; 126/126 for the whole file. The link case was split in two, a non-`http` scheme and a malformed `https` URI, so each half of the link check has a case only it catches. All six mutations turned it red, each caught by the case built for it; the suite was restored byte-for-byte after each. The `Keys` case first failed because the fixture builder itself iterated `.Keys` on a dictionary holding a `Keys` entry, the trap the suite guards against; fixed with `.PSBase.Keys`.
- [x] **B3. `tests/Harness.Tests.ps1`**: the expected container list starts with `help.tests.ps1`. *(AC 1)*
  - Verify: the case fails before the suite file exists and passes after.
- [x] **B4. `tests/HarnessTasks.Tests.ps1`**: the fixture consumer's function gains complete help; `$sharedCount` 15 → 20; the expected suite order starts with `help.tests.ps1`. *(AC 1, AC 13)*
  - Verify: the task cases pass; a fixture function with no help fails the build.
  - **B3 and B4 done 2026-11-16.** With `help.tests.ps1` moved aside, six cases across both files failed, including the new no-help case (4 failures); restored, all pass. Full verification suite 275/275. PSScriptAnalyzer with the shared settings: no findings on the four changed files, after renaming a fixture helper that only builds a string from `New-` to `Get-HelpFixtureSource`.
- [x] **B5. Documentation.** `docs/consumer-guide.md` *Shared tests*: four suites, `15 + 5n`, delete `help.tests.ps1`. `docs/test-integrity.md`: help is per function with one looped link test, and why; the `.PSBase.Keys` trap; the `DynamicParam` exemption, pointing at the design's *Future: checking dynamic parameters*; the intro's `Help.Tests.ps1` mention. `AGENTS.md`: the `Build/` row says four suites.
  - Verify: markdown lint clean; `git diff -U0` reviewed hunk by hunk.
  - **Done 2026-11-16.** Also rewrote `test-integrity.md`'s settled decision *link URIs come from `Get-Help`*: the shared suite reads links from the AST and classifies them by scheme, which SecurityTools' related-topic `.LINK` confirms (skipped, green). Lint clean.
- [x] **B6. Merge.** Full verification suite green locally, then the required `verify Pester result step` on the PR.
  - **Done 2026-11-16.** [#90](https://github.com/jjohns-dev/pwsh-module-ci/pull/90) squashed to `2952aa6`, signed; 275/275 locally, required check green on ubuntu and windows.

## C. Release

- [x] **C1. Cut `v2.2.0`** on the merge commit, annotated, with a GitHub release whose notes say every consumer runs the help suite when `v2` moves and none is expected red. *(ADR-0002: minor)*
  - Verify: tag annotated, on the merge commit, release immutable.
  - **Done 2026-11-16.** `v2.2.0` annotated (tag object `a4ad17d`) on `2952aa6`; [release](https://github.com/jjohns-dev/pwsh-module-ci/releases/tag/v2.2.0) published, immutable.
- [x] **C2. Prove on two throwaway consumer PRs pinned `@v2.2.0`**: PS.GHOps and SecurityTools, callers repinned and nothing else. *(AC 9)*
  - PS.GHOps: every leg (ubuntu, windows, macOS) green at its `main` count plus 41.
  - SecurityTools: ubuntu green at its `main` count plus 265, `Get-KEVList` passing; windows unchanged at 21.
  - Verify: `referenced_workflows` shows the `v2.2.0` tag object; counts from JUnit artifacts. Evidence commented on each PR; both closed unmerged and their branches deleted.
  - **Done 2026-11-16.** Both runs reference tag object `a4ad17d`; both PRs closed unmerged with evidence comments, branches deleted, `main` untouched. [SecurityTools#172](https://github.com/jjohns-dev/SecurityTools/pull/172): ci, release and pssa-sarif green; ubuntu 1331 executed with the shared help suite at 265 and all four `Get-KEVList` tests passing; windows 21. Its own `help.tests.ps1` ran 527, matching the per-parameter estimate. [PS.GHOps#25](https://github.com/jjohns-dev/PS.GHOps/pull/25): ubuntu and windows 152 executed each, help 41, pssa-sarif and release green. **macOS not proven:** GitHub cancelled that leg after 15 minutes with no runner ever assigned (no incident on githubstatus.com); accepted as unproven, since the suite reads help from the AST and is OS-independent. That outcome led to dropping the macOS leg in D6 and D7.
- [x] **C3. Move `v2` to `v2.2.0`.** *(AC 10)*
  - Verify: `git ls-remote origin 'refs/tags/v2^{}'` shows the `v2.2.0` commit; a rerun of one consumer's `main` ci records the new tag object and passes.
  - **Done 2026-11-16.** `v2^{}` = `2952aa6` (tag object `969808e`), pushed with the logged admin bypass. PS.Log `main` ci rerun (43503707486, attempt 2) referenced `969808e` and passed: 126 executed, the shared help suite 25 and PS.Log's own `help.tests.ps1` 54, both suites running until D1.

## D. Cleanup PRs, one per consumer *(AC 11, AC 12)*

Each PR: delete the consumer's `help.tests.ps1` where it has one, and `Tests/Common/` if it is then empty; update any `AGENTS.md` text describing it; recalculate every leg's floor from the PR's own run; callers on `@v2`. The PR comment maps every deleted assertion to the help suite, or records why it is dropped: Group A's *not auto-generated* (AC 12), PS.SSL's *Exports at least one command* (AC 12), and Group A's per-parameter and per-link tests, now per function (requirements Q1, Q2).

Verify each: post-merge `main` run green; executed count per leg read from JUnit artifacts, equal to the PR's final run; remote branch deleted.

- [x] **D1. PS.Log** — `Tests/Common/help.tests.ps1`.
  - **Done 2026-11-16.** [#64](https://github.com/jjohns-dev/PS.Log/pull/64) squashed to `ec75083` by the repo agent. `help.tests.ps1` and `Tests/Common/` deleted; `AGENTS.md`'s row and template note removed. 72 executed (126 − 54 own help), shared help 25 → `min-tests` 69. Post-merge `main`: ci green at 72 against `v2` tag object `969808e`, pssa-sarif green.
- [x] **D2. PS.SSL** — `Tests/Common/help.tests.ps1`; `AGENTS.md` line 48. Both legs.
  - **Done 2026-11-16.** [#81](https://github.com/jjohns-dev/PS.SSL/pull/81) squashed to `648ed3a` by the repo agent. `help.tests.ps1` and `Tests/Common/` deleted; `AGENTS.md` updated. The windows leg hung in two of three attempts: a pre-existing pipe deadlock in `Invoke-OpenSsl`, sequential stdout-then-stderr reads, hit when `rsa:4096` key generation fills the windows stderr pipe, which deadlocked at 4,131 bytes but not at 2,091. Same hang on windows 2026-09-06, 2026-10-27 and 2026-11-12, before this suite. Fixed first in [#83](https://github.com/jjohns-dev/PS.SSL/pull/83) (`0571e05`, closes [#82](https://github.com/jjohns-dev/PS.SSL/issues/82); +1 regression test, proven to fail on the old code), three green windows runs; #81 rebased onto it. Executed ubuntu 252, windows 253, shared help 61 per leg → `min-tests` 242. Post-merge `main`: ci green at the same counts against `v2` tag object `969808e`, pssa-sarif green. Side finding, deferred past E1: [#91](https://github.com/jjohns-dev/pwsh-module-ci/issues/91), the meta suite scans git-ignored files.
- [ ] **D3. PS.DCU** — `Tests/Common/help.tests.ps1`; `AGENTS.md` line 40. Under `PesterStrictMode`.
  - **Then archive PS.DCU** (decided 2026-11-16): once D3's post-merge `main` is verified green, archive `jjohns-dev/PS.DCU`. Confirm first that it has no open PRs; settle its open issues, [PS.DCU#20](https://github.com/jjohns-dev/PS.DCU/issues/20) among them, and its row in `ROLLOUT.md`'s *Found during the rollout*; and drop it from the consumer list in `AGENTS.md`.
- [ ] **D4. AWSAutomation** — `Tests/Common/help.tests.ps1`.
- [ ] **D5. SecurityTools** — `Tests/Common/help.tests.ps1`, whose `ValidateSet` trigger for dynamic parameters is replaced by the AC 2 exemption. Both legs; windows unchanged.
- [ ] **D6. PS.GHOps** — floor; drop the macOS leg.
- [ ] **D7. PS.GitHub** — floor; drop the macOS leg.
  - **macOS leg dropped in D6 and D7** (decided 2026-11-16). Both repos run macOS only because they inherit `ci.yml`'s default `os-matrix`, and `validate / validate (macos-latest)` is a required check in each. Each PR sets `os-matrix: '["ubuntu-latest", "windows-latest"]'` and removes that check from the repo's ruleset in the same change; otherwise it never reports and blocks every merge. Why: for these modules Linux is the stricter Unix leg (case-sensitive), and local builds already run on macOS; the leg's cost is runner availability, shown when C2's macOS leg was cancelled unrun. The harness default is unchanged: changing it would silently remove a required check from every consumer relying on the default.
- [ ] **D8. PS.YNAB** — floor only.

## E. Close-out

- [ ] **E1.** Close #55 with the evidence; tick `ROLLOUT.md` item 9 with the merge commits and final floors.
