# Centralized build harness — tasks

- **Requirements:** [requirements.md](requirements.md), approved 2026-11-09
- **Design:** [design.md](design.md), approved 2026-11-09
- **Status:** Approved — 2026-11-09

Each task names its verification and the acceptance criteria (AC) it serves. Tasks are ordered so `main` stays green between them. Consumers are untouched until phase F, because they pin `@v1` and `v1` never moves (Q5). Expect roughly one PR per lettered phase in this repo, adjusted as the work shows; phase F is one PR per consumer.

## A. Before anything changes on `main`

- [x] **A1. Create a `v1` maintenance branch** from the last tagged release, `v1.6.1` (`b40b9c8`, cut 2026-11-09), so an urgent `v1.6.x` fix stays possible once `main` carries `v2` work. `main` has gained only #69, documentation, since that tag. *(Q5)*
  - Verify: `git rev-parse 'v1.6.1^{commit}'` equals the branch tip on `origin`.

## B. Harness code in this repo, each with its tests

All suites live in `tests/` and run under the required `verify Pester result step` check. Every behaviour gets a case that must fail when the behaviour is broken, not only one that passes. *(AC9)*

The eight stranded corrections from #20 *(AC8)*, and where each lands:

| Correction, from #20 | Task |
| -------------------- | ---- |
| `$ProjectRoot` fallback resolves to `Build/` | B2: the project path is explicit, so there is no fallback |
| Manifest lookup array trap | B2 |
| Dead `$PSVersion` | B6 |
| `Run.Path` coerced to `String[]` | B8 |
| Build inputs validated before staging | B6 |
| Dead `Analyze` gate (`$analysisResult`) | B7 |
| Resolved-dependency log | B3 |
| `Set-StrictMode` | B5, B6 |

- [x] **B1. Shared analyzer settings and pinned build tools.** `Build/PSScriptAnalyzerSettings.psd1` with no `ExcludeRules`; `Build/depend.psd1` with Pester `6.2.0`, psake `5.0.4` and PSScriptAnalyzer `1.25.0` only. *(Q2, Q6)*
  - Verify: both parse with `Import-PowerShellDataFile`; a test asserts `depend.psd1` holds exactly those three entries.
- [x] **B2. Harness entry point, `Build/build.ps1`.** *(AC2, AC4)*
  - Takes `-ProjectPath`, plus today's `-TaskList`, `-Parameters`, `-Properties` and `-ResolveDependency`.
  - Finds the manifest at the project root and fails unless there is exactly one, replacing the array trap #20 found.
  - Sets both `$env:BH*` and `$env:HARNESS_*`.
  - Prints its own commit SHA at the start of every run.
  - Verify: tests for a missing or invalid `-ProjectPath`, zero and two root manifests (both must fail), all six environment variables set and equal pairwise, and the SHA line present.
- [x] **B3. Dependency resolution.** Build tools from `depend.psd1`; runtime modules from the manifest's `RequiredModules`, following the Q2 table; one `Resolved dependency: <name> <version>` line per module. *(Q2)*
  - Verify: a case for each manifest form, including `MaximumVersion`, which must fail and name the module; no `RequiredModules`; the key commented out; an unversioned entry installed with no `-Version`; one resolved-version line per module. Installation is mocked, so the suite needs no network.
- [x] **B4. `harness.psd1` loader.** Reads `<ProjectPath>/Build/harness.psd1` when present; accepts only `PSScriptAnalyzerExcludeRules`, `PesterExcludeTag` and `PesterStrictMode`. *(design: Interfaces)*
  - Verify: an absent file gives defaults; each key is applied; an unknown key fails and names the key; a wrong type fails.
- [x] **B5. Measure where strict mode must go for psake**, at the top of `build.psake.ps1` or in each task, before writing the tasks. *(Q7)*
  - Verify: a scratch measurement in which the chosen placement makes the `$analysisResult` expression throw in a task body, and the other placement, or none, lets it pass. Record the result in the design's Q7 section.
- [x] **B6. `build.psake.ps1`: `Init`, `Setup`, `CombineFunctionsAndStage`, `ImportStagingModule`, `Cleanup`, `Default`.** The nine task names are unchanged. Staging copies `Public`, `Private`, `README.md` and the module's `.psd1` and `.psm1`, and fails on a missing or empty required path (PS.SSL's fix). The dead `$PSVersion` assignment is not carried. Strict mode is placed per B5. *(AC8)*
  - Verify: staging a fixture module produces exactly that file set; a missing `Public/` and an empty `Public/` each fail; `Documentation/` in the fixture is not staged.
- [x] **B7. `Analyze` task.** Shared settings plus `PSScriptAnalyzerExcludeRules`; gate on Errors; the `default` branch uses `$Results`, not the undefined `$analysisResult`. *(AC8)*
  - Verify: a fixture with an Error finding fails; a Warning finding passes; an excluded rule is not reported; with the threshold set to `Any`, a Warning **fails**, which is the dead gate fixed.
- [x] **B8. `Test` task.** *(Q4, Q7, AC8)*
  - The selection rule: `All` (the default), `CrossPlatform` or `WindowsOnly`, resolved inside the task, matching `.tests.windows.ps1` case-insensitively at `Tests/*/`.
  - `Run.Path` coerced to `String[]`.
  - `PesterExcludeTag` applied.
  - Strict mode turned off around `Invoke-Pester` unless `PesterStrictMode` is set.
  - JUnit output and the result gate, as today.
  - Verify: each scope on the current OS with mixed-case fixture names; an unknown scope fails; a fixture with exactly one test file runs, which is the `Run.Path` trap; a tagged test is excluded; a fixture test reading an undefined variable passes by default and fails with `PesterStrictMode = $true`.
- [x] **B9. `CreateBuildArtifact` task**, declared `-depends 'Init'` as in six repos. *(AC8)*
  - Then settle PS.DCU's alternative by measurement: run `Test` then `CreateBuildArtifact` with each declaration and check whether `Artifacts/Test-*.xml` survives.
  - Verify: the artifact zip contains the staged module; the measurement and its outcome are recorded in the design. Adopt PS.DCU's form only if the measurement supports it.
- [x] **B10. Shim and template, `templates/Build/build.ps1`**, from the Q1 sketch. *(Q1)*
  - Checks the fetch result and **stops** on failure, never continuing with the cached copy. The error states that the fetch failed, includes git's own message, names the cache path, and says nothing was run.
  - Carries the fetch-failure code comment recorded in the design.
  - Handles line endings so a CRLF checkout does not read as drift.
  - Verify: `tests/Shim.Tests.ps1` covers all 14 spike cases against a local origin, plus a fetch failure (must exit non-zero, run nothing, and print the cache path) and a CRLF copy of the shim (must not report drift).
- [x] **B11. Optional settings sample, `templates/Build/harness.psd1`.** Header states the file is optional; every key commented out, with its type, default and the repo that uses it.
  - Verify: it parses; loaded by B4 as-is, it yields the same settings as no file at all.
- [x] **B12. Windows in self-test.** Add a `windows-latest` leg to `self-test.yml`. *(Q1)*
  - A matrix may append the OS to the job's check name, which would rename the required check `verify Pester result step`. Not verified either way.
  - Verify: both legs green on the PR; read the check names the PR actually reports. If they differ from `verify Pester result step`, update the `protect-main` ruleset (id `22409716`) with `PUT` in the same PR, and read it back.
  - **Outcome (PR #71):** the matrix did rename the check, to `verify Pester result step (<os>)`. The ruleset was **not** edited, because it also protects `release/v1`, whose self-test has no matrix. Instead the legs report as `verify Pester (<os>)` and a summary job keeps the required name, passing only when every leg succeeded. Seen in both directions on the PR: it failed when the Windows leg failed, and passed once both legs did.

## C. Workflows

- [x] **C1. `ci.yml`** checks out the caller as now, checks out this repo at `job.workflow_sha` into `.harness/`, and runs `.harness/Build/build.ps1 -ProjectPath $GITHUB_WORKSPACE` for each task. Job names unchanged. *(AC1)*
- [x] **C2. `release.yml`**: the same harness steps, plus a `dry-run` input (boolean, default `false`). Only the publishing step (`action-gh-release`) is gated on it; build, test, the `Verify Pester results` step and the artifact upload all still run. *(Q3)*
- [x] **C3. `pssa-sarif.yml`**: checks out the harness at `job.workflow_sha`, as C1 does, and analyses with the harness's settings plus the repo's `PSScriptAnalyzerExcludeRules`; the `psscriptanalyzer-settings-path` input is removed. *(Q3)*
- [x] **C4. Tests for the changed `run:` blocks**, extracted from the YAML like today's suites. The `Verify Pester results` drift check between `ci.yml` and `release.yml` still passes.
  - Verify for C1–C4: `actionlint` and self-test green.
  - **Outcome:** `PSScriptAnalyzer -Recurse` descends into dot-folders, so analysing the checkout root would have reported the harness's own code in each consumer's Security tab. `Invoke-HarnessAnalysis` analyses each top-level item except `.harness` and `.git` instead, and the `Analyze` task and `pssa-sarif.yml` share `Get-HarnessAnalyzerSetting`. `pssa-sarif.yml` reads the PSScriptAnalyzer version from `depend.psd1` rather than repeating it. New `tests/Workflows.Tests.ps1` checks the three workflows' structure; ten mutants, one per guarded property, were each caught.
- [x] **C5. End-to-end proof before any tag.** From a branch of this repo, point caller branches at the branch's workflows, pinned by full commit SHA, as the 2026-11-05 spike did, in three repos: PS.GHOps (the first migration), and PS.SSL and SecurityTools (the hardest cases: tag exclusion, Windows-only selection, per-leg scopes). Each branch carries what its migration PR would: the shim, any `harness.psd1`, and renames.
  - Verify: all three workflows green in each repo; executed counts equal the baseline (PS.GHOps 95 on each of three legs; PS.SSL 346 and 347; SecurityTools 996 and 21); the harness commit SHA printed by B2 equals the workflow's commit; a dry-run release in PS.GHOps produces an artifact matching its last real release, file for file.
  - The draft PRs are **kept**, not torn down: each becomes that repo's F-task PR, since it already holds the shim, the deletions and the release caller's dry-run changes.
  - **PS.GHOps outcome ([PS.GHOps#23](https://github.com/jjohns-dev/PS.GHOps/pull/23), harness `a3e5f5c`):** all three workflows green; 95 executed on each leg, 0 errors and failures; harness commit printed in CI and through the local shim; required check names unchanged; publishing skipped, no release or tag created. The dry-run zip matches `v0.5.0` except the URL repointing committed since (`9e8d725`); entry order inside the zip differs. The macOS leg needed a re-run for lack of a hosted runner, not because of the harness.
  - **PS.SSL outcome ([PS.SSL#79](https://github.com/jjohns-dev/PS.SSL/pull/79), harness `a3e5f5c`):** all three workflows green; executed 346 ubuntu and 347 windows, 0 errors and failures; the 14 `Network` tests excluded by tag on both legs (`NotRun`, no suite in the JUnit); harness commit printed everywhere; required check names unchanged; publishing skipped, no release or tag created; the dry-run zip holds `PS.SSL/` with the manifest, root module, README, `Public` and `Private`. Before the change, the whole-repo analyzer scan found that one dropped exclusion still suppressed two test-fixture findings; they are now suppressed inline (see design). Runs were delayed by a GitHub incident on 2026-11-10 and fired on their own after it.
  - **SecurityTools outcome ([SecurityTools#170](https://github.com/jjohns-dev/SecurityTools/pull/170), harness `a3e5f5c`):** all three workflows green; executed 996 ubuntu and 21 windows against floors 986 and 20, 0 errors and failures; ubuntu selected only the 65 `*.tests.ps1`, windows only the 9 `*.tests.windows.ps1`; harness commit printed everywhere; `ImportExcel` resolved from the manifest to 7.8.10, which is also its latest Gallery version, so floating changed nothing yet; required check names unchanged; pssa-sarif 0 results and dropping `PSAvoidGlobalVars` surfaced nothing; publishing skipped, no release or tag created; the dry-run zip holds `SecurityTools/` with the manifest, root module, README, `Public` and `Private`.

## D. Records and docs

- [ ] **D1. ADR-0006 to Accepted**, citing run [42090065876](https://github.com/jjohns-dev/PS.Log/actions/runs/42090065876) and the 2026-11-09 shim spike; amend its Decision for the shim, `harness.psd1` and the manifest. *(AC10)*
- [ ] **D2. Amend ADR-0002** with the major-version exception. *(Q5)*
- [ ] **D3. New ADR-0007**: runtime modules float from the manifest, build tools pinned centrally.
- [ ] **D4. `docs/test-integrity.md`**: add the three durable rules #20 asks to extract (`Run.Path` and a scalar `FileInfo`; an `Assert` on an undefined variable passes silently; a non-terminating `Write-Error` does fail a psake task).
- [ ] **D5. `docs/dependency-stack.md`**: build tools pinned centrally; runtime modules from the manifest.
- [ ] **D6. Delete `docs/shared-ci-standards.md`**, as its own header instructs.
- [ ] **D7a. Consumer guide, `docs/consumer-guide.md`.** Move the consumer-facing material out of `README.md` (Usage, Runner matrix, Pester result verification, Minimum test count) into its own document, and leave `README.md` as an overview with a link to it. Update the moved content for `v2`, and add what a consumer needs to adopt the harness:
  - the three caller workflows on `@v2`, including the release caller's `pull_request` trigger with `dry-run`, and that `psscriptanalyzer-settings-path` is gone;
  - the shim: what it does, where it caches the harness, running from a clone instead, and the drift warning;
  - `Build/harness.psd1`: its three keys, and that an unknown key fails the build;
  - the module layout the harness expects: `Public/` required, `Private/` optional, where tests live, the lowercase test-file convention, and how `PesterScope` selects files;
  - dependency resolution: `RequiredModules` float, `RequiredVersion` pins, `MaximumVersion` fails, each logged as `Resolved dependency:`;
  - the task names and properties a consumer can pass;
  - running tests the repo excludes by tag: the harness always applies `PesterExcludeTag` and has no override, so run them with Pester directly, e.g. PS.SSL's `Invoke-Pester -Path ./Tests -TagFilter 'Network' -Output Detailed` from the repo root (its test files import `$env:BHPSModuleManifest` when set, else the source manifest at the repo root).
  - Verify: no content lost in the move (`git diff -w` of the moved sections against `README.md` at the base); every in-page anchor that moved still resolves; `AGENTS.md`'s layout row for `README.md` points at the guide.
- [ ] **D7b. `AGENTS.md`** (maintainers): layout, two major tags, and how to cut and move `v2`. Also add these to AGENTS.md's *Gotchas*, each found during phase B (PR #71) or phase C (PR #72):
  - **A job matrix renames its required check.** Adding `strategy.matrix` turns `verify Pester result step` into `verify Pester result step (<os>)`, so a ruleset requiring the plain name never sees it report. `self-test.yml` keeps the name with a summary job over the legs, rather than editing `protect-main`, which also covers `release/*`.
  - **On Windows, git fixture repos in `TestDrive:` break Pester's cleanup.** git writes object files read-only, so the container fails after every test passed. Remove them with `Remove-Item -Force` in `AfterAll`.
  - **A parameter typed `[System.Management.Automation.PSCustomObject]` rejects `[PSCustomObject] @{}`.** The value's runtime type is `PSObject`, so type such parameters `[System.Management.Automation.PSObject]`.
  - **Never send a second command to a terminal running a long job.** It interrupted a mutation run part-way; check every mutated file is restored before trusting the tree.
  - **`Invoke-ScriptAnalyzer -Recurse` descends into dot-folders**, so analysing a checkout root also reports `.harness/`. `Invoke-HarnessAnalysis` analyses each top-level item except `.harness` and `.git` instead.
  - **actionlint 1.7.12 rejects `job.workflow_repository` and `job.workflow_sha`**, though GitHub documents both. `.github/actionlint.yaml` ignores exactly those two names; remove it once a release includes [rhysd/actionlint#707](https://github.com/rhysd/actionlint/pull/707).
- [ ] **D8. Record the mechanism for `PS-MCS`** in ADR-0006's Consequences: what `mcssec-ops` would adopt unchanged, and that its `@main`-pinned consumers need an input switch or verification before merge, since there is no tag to repoint. *(AC11)*
  - Verify for D1–D8: markdownlint clean; every link resolves; ADRs follow the bullet style and dated Status line.

## E. Release

- [ ] **E1. Cut `v2.0.0`** as an annotated tag on #72's squash-merge commit on `main`, and create the moving `v2` tag on it. C5 proved `a3e5f5c`, which a squash merge does not put on `main`, so first confirm `git diff a3e5f5c <merge> -- .github Build templates tests` is empty: the tagged code is then exactly the code C5 ran.
  - Verify: `git ls-remote origin 'refs/tags/v2^{}'` shows that commit; confirm via the API that `protect-release-tags` now covers `v2` (AGENTS.md says its pattern does; unverified until now).
  - Carried nit from the #72 review, deliberately not fixed before the tag: `pssa-sarif.yml` reads `depend.psd1` with `Import-PowerShellDataFile -Path` where the rest of the code uses `-LiteralPath`. Harmless for that fixed path; fix in the next change.

## F. Migrations, in order, one PR per repo

Each PR follows the same checklist:

- Shim in place of `Build/build.ps1`; delete `build.psake.ps1`, `depend.psd1` and `PSScriptAnalyzerSettings.psd1`.
- `Build/harness.psd1` only where listed below.
- Where C5 left a draft PR, start from it: rebase on the repo's `main`, then repoint its SHA pins to `@v2` as the last commit.
- All three callers on `@v2`; the release caller gains its `pull_request` dry-run trigger, `dry-run: ${{ github.event_name == 'pull_request' }}`, and an `artifact-name` that is valid on a PR (`github.ref_name` is `<n>/merge` there, and artifact names cannot contain `/`).
- Test files renamed to lowercase with `git mv`, confirmed as renames in `git status`.
- AGENTS.md, CONTRIBUTING.md, ADRs and test-file comments checked for references to the deleted files **and** for prose describing the old psake build; point them at the consumer guide (D7a).
- Close any Dependabot `@v1` → `@v2` PR.

Verification for every repo, read from the run artifacts, not log text:

- all three workflows green;
- executed counts equal the 2026-11-09 baseline per leg, with errors and failures at 0 *(AC5)*;
- the dry-run artifact matches the last real release, except for differences the PR names;
- `./Build/build.ps1 -TaskList Test` run locally through the shim succeeds.

| Task | Repo | Repo-specific | Baseline executed |
| ---- | ---- | ------------- | ----------------- |
| F1 | PS.GHOps | start from #23; psake prose in `AGENTS.md:45`, `CONTRIBUTING.md:93-94`, ADR-0001 line 18, `Module.tests.ps1:7` | 95 × 3 legs |
| F2 | PS.GitHub | — | 112 × 3 legs |
| F3 | PS.Log | artifact drops `Documentation/` | 91 |
| F4 | PS.DCU | `PesterStrictMode = $true`; 3 renames; confirm the dev container image has `git` | 85 |
| F5 | AWSAutomation | `PSScriptAnalyzerExcludeRules` (2 rules); 15 runtime modules now from the manifest | 444 |
| F6 | PS.SSL | start from #79; `PesterExcludeTag = 'Network'`; 22 renames; inline `SuppressMessageAttribute` for `PSAvoidUsingConvertToSecureStringWithPlainText` in the `ConvertTo-PEM` and `Export-PFX` tests (fixture passwords); `AGENTS.md` lines 14, 15, 20, 28, 51 and 59 describe the old build, and its *run `Network`-tagged tests* note should give the `Invoke-Pester -TagFilter 'Network'` command; compare the PR's analyzer warnings (6 in pssa-sarif, 1 in Analyze at C5) against `main`'s Security tab and name any that are new | 346 ubuntu, 347 windows |
| F7 | SecurityTools | start from #170; `ImportExcel` floats from the manifest instead of the `7.8.10` pin (7.8.10 is still the latest, so no change yet); per-leg scopes unchanged; `Tests/Common/{Help,Manifest,Meta}.Tests.ps1` keep their case and follow #53; `AGENTS.md:13`, `:46` and its PSScriptAnalyzer policy section describe the old build and settings | 996 ubuntu, 21 windows |

- [ ] F1. PS.GHOps
- [ ] F2. PS.GitHub
- [ ] F3. PS.Log
- [ ] F4. PS.DCU
- [ ] F5. AWSAutomation
- [ ] F6. PS.SSL
- [ ] F7. SecurityTools

If any repo's `main` has moved since the baseline, re-measure that repo before its PR rather than comparing against the old row.

## G. Close-out

- [ ] **G1. Retire `v1`**: record in AGENTS.md that no further `v1` releases will be made; leave the tag and maintenance branch in place.
- [ ] **G2. Every consumer shim byte-identical** to `templates/Build/build.ps1`, using the line-ending handling B10 chose. *(AC7)*
  - Verify: a scripted comparison across all seven repos' `main`.
- [ ] **G3. Close #20** with the evidence: the counts per repo, the dry-run comparisons, and the release tags.
- [ ] **G4. Tick item 7 in `ROLLOUT.md`** and update the phase table.
