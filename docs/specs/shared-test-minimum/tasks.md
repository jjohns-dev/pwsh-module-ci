# Shared test minimum — tasks

- **Requirements:** [requirements.md](requirements.md), approved 2026-11-13
- **Design:** [design.md](design.md), approved 2026-11-13
- **Status:** Approved — 2026-11-13

Each task names its verification and the acceptance criteria (AC) it serves. Phases A–B are one PR in this repo; C is the release; D is one PR per consumer, through the agent-prompt pattern, each report verified here from run artifacts before its box is ticked.

## A. Measure before building

- [x] **A1. Confirm the two assumed Pester behaviours** on Pester 6.2.0, in a scratch run: path containers and `-Data` containers mixed in one `Invoke-Pester` call, and containers executing in the order given. *(design: Risks)*
  - Verify: a probe that records execution order and fails if either behaviour does not hold, plus a control showing the probe can fail. Result recorded in this file. If either fails, revise the design before B.
  - **Result, 2026-11-13: both hold.** Two path containers and one `-Data` container in one call: 5/5 passed. Order follows input, not file name: `zeta, beta, alpha` given in that order ran in that order, and reversed ran reversed. `-Data` reached `BeforeDiscovery`, which built three cases from it. Control: the same `-Data` file without `-Data` failed the run with a container error and 0 tests.
  - **Found by the control:** a `Mandatory` parameter in a shared file makes a run without `-Data` prompt interactively, hanging a local run. Shared files declare their parameters non-mandatory and throw in `BeforeDiscovery` when a value is missing.

## B. Harness change, one PR

Every assertion gets a fixture that must fail it and one that must pass it, under strict mode on and off. *(AC 14)*

- [x] **B1. `Build/SharedTests/manifest.tests.ps1`**, the 11 assertions. *(AC 3, AC 4)*
  - Verify: for each assertion, a fixture module in `TestDrive:` that violates only it fails only it. `PowerShellVersion` cases: `5.1` and `7.0` pass; `3.0`, `5.0`, `6.2` and one above `$PSVersionTable.PSVersion` fail. Resolved exports: a `Public/` file whose function is misnamed fails, even with the module already loaded.
  - **Done 2026-11-13.** `tests/SharedTests.Tests.ps1` runs 19 fixture cases through `tests/SharedSuite.Driver.ps1` in a child pwsh, lenient and strict, each asserting the exact set of tests that fail; every test fails in at least one case; a run without `-Data` fails. 42/42. Three mutations of the suite (lower bound removed, wildcard check narrowed, resolved exports reading the declared list) each turned it red. Two cases fail more than one test by nature: an empty `FunctionsToExport` also fails the Public/ match and resolved exports, and a version above the running pwsh also fails `Test-ModuleManifest` and the import.
- [x] **B2. ~~`Build/SharedTests/module.tests.ps1`~~ — dropped 2026-11-13.** Its loader and import checks are enforced by harness steps before `Test` (AC 5); its resolved-exports check moved to B1.
- [x] **B3. `Build/SharedTests/meta.tests.ps1`**, 3 looped tests. *(AC 6)*
  - Verify: a BOM, a tab and a `0x00` byte each fail their own test and name the file; files under `.git`, `Staging` and `Artifacts` are ignored; adding source files does not change the test count.
  - **Done 2026-11-13.** Seven fixture cases, lenient and strict, including a tab in a `.github/` script (scanned: the suite lists with `-Force`, because without it only Windows sees dot-folders) and twenty extra files (still 3 tests). Mutations caught: dropping `-Force`, un-excluding `Staging`, removing the `0x00` scan.
- [x] **B4. `Build/SharedTests/pathliterals.tests.ps1`**, one test per `Public/*.ps1`. *(AC 8)*
  - Verify: each of the four variables followed by `\` in a string fails; the same text in a comment and in comment-based help `.EXAMPLE` passes.
  - **Done 2026-11-13.** Eight cases, lenient and strict. Running both modes caught a real bug: `.ForEach()` on `FindAll`'s `IEnumerable` passed silently when lenient and threw when strict; fixed with `foreach`. Mutations caught: ignoring expandable strings, checking only `$HOME`, scanning comments.
- [x] **B5. `Test` task integration** in `Build/build.psake.ps1`. *(AC 1, AC 2, AC 9, design: Order)*
  - Verify, in `tests/HarnessTasks.Tests.ps1` against a fixture consumer: shared tests appear in the single JUnit file on `All` and `CrossPlatform`, not on `WindowsOnly`; they run after the consumer's tests; a failing shared test fails the task. The fixture builder there produces a manifest that passes the shared suites, so existing cases keep testing what they test.
  - **Done 2026-11-13.** Consumer files and shared suites become containers in one `Invoke-Pester` call; `Get-HarnessSharedContainer` (in `Harness.Functions.ps1`) gives each suite only the `-Data` keys its `param` block declares, and stops on one it cannot supply. Four task cases: suite order in the JUnit file is consumer then `manifest`, `meta`, `pathliterals`; counts on `All` and `CrossPlatform` include the 15 shared tests; `WindowsOnly` runs none; an empty `Description` fails the build. Mutations caught: shared suites on every scope, shared suites first, every key passed to every suite. Full verification suite 228/228.
- [x] **B6. Fleet dry run.** Run the branch's harness locally against shallow clones of all eight consumers. *(AC 10, design: Rollout)*
  - Verify: expected red is exactly SecurityTools' four BOM files and AWSAutomation's three literals. Anything else is recorded here and resolved (fixed in the suite, or added to that repo's cleanup list) before release.
  - **Done 2026-11-13**, `Test` task at `CrossPlatform` scope, each consumer at its `main` (PS.Log `2f36114`, PS.GHOps `7f6156a`, PS.GitHub `8f1c2c1`, PS.SSL `7ed0afe`, PS.DCU `8d2b51a`, AWSAutomation `2f454a1`, SecurityTools `29863db`, PS.YNAB `848a3a6`). Shared failures are exactly as predicted: AWSAutomation 3 (`Export-CFNStackDrift` L72, `Export-EC2UsageReport` L112, `Export-IAMRolePolicy` L69), SecurityTools 1 naming its four BOM files. Shared test counts equal 14 + public functions in all eight (20 to 80). Consumer counts unchanged against the floors' baselines.
  - **Not caused by this change:** PS.YNAB's own suite has 15 failures locally, decimal precision such as `12.34` against `12.3399999…`. The `main` harness (`114d292`) gives the same 191 tests and 15 failures on the same clone. This machine runs pwsh 7.7.0; PS.YNAB's CI on `main` is green. Inferred, not verified: a pwsh 7.7 behaviour change its runners have not reached. Raised for PS.YNAB, outside #53.
- [x] **B7. Documentation.** `docs/test-integrity.md` *Settled decisions*: why meta loops (AC 7). `docs/consumer-guide.md`: what the harness tests and what consumers no longer carry. `AGENTS.md` and `README.md`: the `Build/SharedTests/` layout row.
  - Verify: markdown lint clean; `git diff -U0` reviewed hunk by hunk.
  - **Done 2026-11-13.** `test-integrity.md` also records why the six harness-guaranteed assertions are not shared tests. The consumer guide gains a *Shared tests* section (suites, counts as `14 + n`, which files to delete). Lint clean; the `AGENTS.md` and `README.md` word diffs are additions only.

## C. Release

- [x] **C1. Merge B, cut `v2.1.0`** with a GitHub release whose notes say every consumer will run the shared suites when `v2` moves, and which repos are expected red. *(ADR-0002: minor)*
  - Verify: tag annotated, on the merge commit, release immutable.
  - **Done 2026-11-13.** #85 squashed to `552999b`; `v2.1.0` annotated (tag object `95a31b2`), release immutable.
- [x] **C2. Prove `v2.1.0` on two consumers, in the PRs that become D1 and D8.** Each opens with one commit: its callers pinned `@v2.1.0`, nothing else. That first run is the proof; its evidence is posted as a PR comment before any other commit is pushed. *(AC 10)*
  - PS.YNAB (D8): all three workflows green, executed count up by exactly the shared suites' count.
  - SecurityTools (D1): red on the meta BOM test only, the message naming exactly its four files; the windows leg unchanged at 21.
  - Verify: `referenced_workflows` shows the `v2.1.0` tag object; counts from JUnit artifacts. Both PRs stay open for D.
  - **Done 2026-11-13.** [PS.YNAB#19](https://github.com/jjohns-dev/PS.YNAB/pull/19) (`5c56f3d`): ci, release dry run and pssa-sarif green; 214 executed = 191 own + 23 shared. [SecurityTools#171](https://github.com/jjohns-dev/SecurityTools/pull/171) (`431003f`): ubuntu 1077 tests, 1 disabled, the one failure the BOM test naming exactly its four files; windows 21, no shared suites; release dry run red on the same test; pssa-sarif green. All six runs reference `95a31b2`. Evidence commented on both PRs.
- [x] **C3. Move `v2` to `v2.1.0`.** *(AC 11)*
  - Verify: `git ls-remote origin 'refs/tags/v2^{}'` shows the `v2.1.0` commit; a rerun of one consumer's `main` ci records the new tag object.
  - **Done 2026-11-13.** `v2^{}` = `552999b` (tag object `e128d30`). PS.Log `main` ci rerun (43271792912, attempt 3) referenced `e128d30` and passed, executing 111 = 91 own + 20 shared.
- [x] **C4. `v2.1.1`: widen the meta suite's file types** *(added 2026-11-13; AC 6 amended, AC 13)*
  - Why: the D1 agent stopped because SecurityTools' `Get-TextFilesList` also checked `.json`, `.xml`, `.cmd`, `.mof`, `.gitignore` and `.gitattributes`; deleting it would have dropped coverage of runtime-loaded `Private/*.json` data.
  - **Done 2026-11-13.** [#86](https://github.com/jjohns-dev/pwsh-module-ci/pull/86) squashed to `8f74daf`; `v2.1.1` released (tag object `bce2b1b`, immutable); `v2` moved (tag object `2e53e23`). PS.Log `main` ci rerun (attempt 4) referenced `2e53e23` and failed exactly as predicted: 111 tests, one failure, the shared tab test naming only `.devcontainer/devcontainer.json`.

## D. Cleanup PRs, one per consumer *(AC 12, AC 13)*

Each PR: delete the vendored files below; fix that repo's red-list defects; recalculate every leg's floor from the PR's own run; copy the shim template; callers on `@v2`. The PR comment maps every deleted assertion to a shared one, or records why it is dropped.

D1 and D8 are the C2 PRs, continued after C3: the cleanup commits are added on top of the proof commit, and the callers are repointed from `@v2.1.0` back to `@v2` before merge, so no consumer is left on an immutable pin.

Red repos first, so `main` is green again soonest.

- [x] **D1. SecurityTools** (continues C2) — `Tests/Common/{manifest,meta}.tests.ps1`, `MetaFixers.psm1`; remove BOMs from four files. Both legs.
  - **Done 2026-11-13.** [#171](https://github.com/jjohns-dev/SecurityTools/pull/171) squashed to `d18c091`, all commits signed. The agent first stopped on the meta file-type gap, which became C4 (`v2.1.1`). Verified here: BOMs gone from the four files, three vendored files deleted, `help.tests.ps1` unchanged, shim `C09FEE99…0CFF`, callers on `@v2`. ubuntu 1066 executed (996 − 10 + 80 shared) → `minTests` 1056; windows 21 → 20. Post-merge `main`: ci green at 1066 and 21, pssa-sarif green.
- [x] **D2. AWSAutomation** — `Tests/Common/{manifest,meta}.tests.ps1`, `MetaFixers.psm1`; fix three `"$HOME\Desktop"` literals and the tab in `.devcontainer/devcontainer.json` (v2.1.1).
  - **Done 2026-11-13.** [#109](https://github.com/jjohns-dev/AWSAutomation/pull/109) squashed to `8c1399f` by the repo agent, both commits signed. Verified here: the three code literals now use nested `Join-Path` (5.1-safe), the help `.EXAMPLE` on line 26 left as is; `devcontainer.json` has no tabs and parses; three vendored files deleted, `help.tests.ps1` unchanged; shim `C09FEE99…0CFF`; callers on `@v2`. 484 executed (444 − 10 + 50 shared) → `min-tests` 474. Post-merge `main`: ci green at 484, pssa-sarif green.
- [x] **D3. PS.SSL** — `Tests/Common/{manifest,meta,PathLiterals}.tests.ps1`, `MetaFixers.psm1`. Both legs.
  - **Done 2026-11-13.** [#80](https://github.com/jjohns-dev/PS.SSL/pull/80) squashed to `6b148a9` by the repo agent. Verified here: four vendored files deleted, `help.tests.ps1` unchanged; `AGENTS.md` points the manifest, encoding and path-literal checks at the shared suites; shim `C09FEE99…0CFF`; callers on `@v2`. ubuntu 350 executed (346 − 25 vendored + 29 shared), windows 351 (347 − 25 + 29) → `min-tests` 340 from the ubuntu leg. Post-merge `main`: ci green at 350 and 351 against `v2` tag object `2e53e23`, pssa-sarif green.
- [x] **D4. PS.Log** — `Tests/Common/{manifest,meta}.tests.ps1`, `MetaFixers.psm1`; fix the tab in `.devcontainer/devcontainer.json` (v2.1.1).
  - **Done 2026-11-13.** [#63](https://github.com/jjohns-dev/PS.Log/pull/63) squashed to `74e614e` by the repo agent. Verified here: `devcontainer.json` has no tabs; three vendored files deleted, `help.tests.ps1` unchanged; shim `C09FEE99…0CFF`; callers on `@v2`. 101 executed (111 at C3, which included 20 shared, minus 10 vendored) → `min-tests` 96. Post-merge `main`: ci green at 101 against `v2` tag object `2e53e23`, pssa-sarif green.
- [x] **D5. PS.DCU** — `Tests/Common/{manifest,meta}.tests.ps1`. Its count falls: 38 per-file meta tests become 3.
  - **Done 2026-11-13.** [#28](https://github.com/jjohns-dev/PS.DCU/pull/28) squashed to `1b677ed` by the repo agent. Verified here: two vendored files deleted, `help.tests.ps1` unchanged at 32 tests; shim `C09FEE99…0CFF`; callers on `@v2`. 54 executed (81 − 11 manifest − 38 meta + 22 shared) → `min-tests` 52. Post-merge `main`: ci green at 54 against `v2` tag object `2e53e23` under `PesterStrictMode`, pssa-sarif green.
  - PS.DCU's *declares empty CmdletsToExport, VariablesToExport, AliasesToExport* was dropped, not replaced. The fleet rule is no `*` in any export field (design, test 8); PS.SSL, AWSAutomation and SecurityTools export aliases or variables, and an explicit export is already a reviewed manifest edit.
- [x] **D6. PS.GHOps** — `Tests/Unit/Module.tests.ps1`.
  - **Done 2026-11-13.** [#24](https://github.com/jjohns-dev/PS.GHOps/pull/24) squashed to `8df428a` by the repo agent. Verified here: `Module.tests.ps1` deleted, no other test file changed; shim `C09FEE99…0CFF`; callers on `@v2`. 111 executed on each of ubuntu, windows and macos (95 − 8 + 24 shared) → `min-tests` 106. Post-merge `main`: ci green at 111 on all three against `v2` tag object `2e53e23`, pssa-sarif green. Its *minimum PowerShell version of 7.4 or higher* was dropped, superseded by the shared `PowerShellVersion` test (AC 4).
- [ ] **D7. PS.GitHub** — `Tests/Unit/Module.tests.ps1`.
- [ ] **D8. PS.YNAB** (continues C2) — `Tests/Unit/Module.tests.ps1`.

Verify each: post-merge `main` run green; executed count per leg read from JUnit; floor equals executed minus `min(floor(executed * 0.05), 10)`; callers pin `@v2`; `Build/build.ps1` byte-identical to the template; `help.tests.ps1` and unit tests untouched.

## E. Close-out

- [ ] **E1.** Close #53 with the evidence; tick `ROLLOUT.md` item 8 with the merge commits and final floors.
- [ ] **E2.** Update #55 and `ROLLOUT.md` item 9: help is to be centralized as its own release (agreed 2026-11-13), no longer optional.
  - Verify: issue and file agree.
