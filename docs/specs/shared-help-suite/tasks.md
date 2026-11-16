# Shared help suite — tasks

- **Requirements:** [requirements.md](requirements.md), approved 2026-11-16; AC 2 amended 2026-11-16
- **Design:** [design.md](design.md), approved 2026-11-16
- **Status:** Approved — 2026-11-16

Each task names its verification and the acceptance criteria (AC) it serves. Phase B is one PR in this repo; C is the release; D is one PR per consumer, through the agent-prompt pattern, each verified here from run artifacts before its box is ticked.

## B. Harness change, one PR

Every assertion gets a fixture that must fail it and one that must pass it, under strict mode on and off. *(AC 8)*

- [ ] **B1. `Build/SharedTests/help.tests.ps1`**: four tests per exported function, one looped link test. *(AC 1–7)*
  - Verify: re-run the 2026-11-16 measurement through the real suite: stage each of the eight consumers' `main` and run the suite against it, lenient and strict. Expect zero failures and `4n + 1` tests each, `Get-KEVList` included.
- [ ] **B2. Fixture cases** in `tests/SharedTests.Tests.ps1`, the design's list, each naming exactly the tests it must fail, lenient and strict. *(AC 8)*
  - Verify: every test fails in at least one case; a run without `-Data` fails. Mutations, each of which must turn the suite red: reading parameters through `Get-Help`; dropping the `DynamicParam` exemption's AST check, so it exempts every function; dropping `.PSBase`; dropping either half of the link check; checking only the first function.
- [ ] **B3. `tests/Harness.Tests.ps1`**: the expected container list starts with `help.tests.ps1`. *(AC 1)*
  - Verify: the case fails before the suite file exists and passes after.
- [ ] **B4. `tests/HarnessTasks.Tests.ps1`**: the fixture consumer's function gains complete help; `$sharedCount` 15 → 20; the expected suite order starts with `help.tests.ps1`. *(AC 1, AC 13)*
  - Verify: the task cases pass; a fixture function with no help fails the build.
- [ ] **B5. Documentation.** `docs/consumer-guide.md` *Shared tests*: four suites, `15 + 5n`, delete `help.tests.ps1`. `docs/test-integrity.md`: help is per function with one looped link test, and why; the `.PSBase.Keys` trap; the `DynamicParam` exemption, pointing at the design's *Future: checking dynamic parameters*; the intro's `Help.Tests.ps1` mention. `AGENTS.md`: the `Build/` row says four suites.
  - Verify: markdown lint clean; `git diff -U0` reviewed hunk by hunk.
- [ ] **B6. Merge.** Full verification suite green locally, then the required `verify Pester result step` on the PR.

## C. Release

- [ ] **C1. Cut `v2.2.0`** on the merge commit, annotated, with a GitHub release whose notes say every consumer runs the help suite when `v2` moves and none is expected red. *(ADR-0002: minor)*
  - Verify: tag annotated, on the merge commit, release immutable.
- [ ] **C2. Prove on two throwaway consumer PRs pinned `@v2.2.0`**: PS.GHOps and SecurityTools, callers repinned and nothing else. *(AC 9)*
  - PS.GHOps: every leg (ubuntu, windows, macOS) green at its `main` count plus 41.
  - SecurityTools: ubuntu green at its `main` count plus 265, `Get-KEVList` passing; windows unchanged at 21.
  - Verify: `referenced_workflows` shows the `v2.2.0` tag object; counts from JUnit artifacts. Evidence commented on each PR; both closed unmerged and their branches deleted.
- [ ] **C3. Move `v2` to `v2.2.0`.** *(AC 10)*
  - Verify: `git ls-remote origin 'refs/tags/v2^{}'` shows the `v2.2.0` commit; a rerun of one consumer's `main` ci records the new tag object and passes.

## D. Cleanup PRs, one per consumer *(AC 11, AC 12)*

Each PR: delete the consumer's `help.tests.ps1` where it has one, and `Tests/Common/` if it is then empty; update any `AGENTS.md` text describing it; recalculate every leg's floor from the PR's own run; callers on `@v2`. The PR comment maps every deleted assertion to the help suite, or records why it is dropped: Group A's *not auto-generated* (AC 12), PS.SSL's *Exports at least one command* (AC 12), and Group A's per-parameter and per-link tests, now per function (requirements Q1, Q2).

Verify each: post-merge `main` run green; executed count per leg read from JUnit artifacts, equal to the PR's final run; remote branch deleted.

- [ ] **D1. PS.Log** — `Tests/Common/help.tests.ps1`.
- [ ] **D2. PS.SSL** — `Tests/Common/help.tests.ps1`; `AGENTS.md` line 48. Both legs.
- [ ] **D3. PS.DCU** — `Tests/Common/help.tests.ps1`; `AGENTS.md` line 40. Under `PesterStrictMode`.
- [ ] **D4. AWSAutomation** — `Tests/Common/help.tests.ps1`.
- [ ] **D5. SecurityTools** — `Tests/Common/help.tests.ps1`, whose `ValidateSet` trigger for dynamic parameters is replaced by the AC 2 exemption. Both legs; windows unchanged.
- [ ] **D6. PS.GHOps** — floor only.
- [ ] **D7. PS.GitHub** — floor only.
- [ ] **D8. PS.YNAB** — floor only.

## E. Close-out

- [ ] **E1.** Close #55 with the evidence; tick `ROLLOUT.md` item 9 with the merge commits and final floors.
