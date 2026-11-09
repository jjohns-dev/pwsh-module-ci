# Centralized build harness — requirements

- **Tracking:** [#20](https://github.com/jjohns-dev/pwsh-module-ci/issues/20)
- **Decision record:** [ADR-0006](../../adr/0006-host-the-build-harness-in-this-repo.md), currently Proposed
- **Status:** Approved — 2026-11-09

## Problem

- Each of the seven consumer repos vendors its own copy of four `Build/` files: `build.ps1`, `build.psake.ps1`, `depend.psd1` and `PSScriptAnalyzerSettings.psd1`. Measured 2026-10-26: 4–6 distinct variants per file.
- Fixes do not flow between copies. The classification on #20 (2026-11-05) found eight corrections that each exist in one or two repos and nowhere else, including a dead analysis gate in six.
- Fixing a harness defect therefore costs one PR per repo, and the copies keep drifting.
- Most of the variation is not intentional. The same classification reduced it to a handful of genuine per-repo settings; everything else is drift, dead code or style.

## User stories

- As the maintainer, I want to fix a harness defect once, so that every consumer gets the fix without a PR per repo.
- As the maintainer, I want each repo's genuine differences declared as named inputs with a recorded reason, so that intent is distinguishable from drift.
- As the maintainer, I want each consumer to move onto the central harness on its own schedule, so that a mistake reaches one repo rather than the fleet.
- As the maintainer, I want proof that moving a repo changes no test outcome, so that the migration cannot hide a regression.
- As a module developer, I want to build and test a module on my own machine, so that I am not dependent on CI to find out whether a change works. *(Met by the shim, Q1.)*

## Acceptance criteria

1. WHEN a consumer calls a reusable workflow at a version that contains the harness, THE SYSTEM SHALL run that consumer's build, analyze, test and artifact tasks from this repo's harness, checked out at `job.workflow_sha`, against the caller's checkout.
2. THE harness SHALL take the consumer's project path as an explicit input. It SHALL NOT derive it from its own location, which resolves to the harness checkout rather than the caller's.
3. THE SYSTEM SHALL express per-repo variation only as declared inputs, each with a recorded reason. Known set:

   | Input | Needed by | Status |
   | ----- | --------- | ------ |
   | `pesterScope`, per leg | SecurityTools | exists, via `os-matrix` |
   | `minTests`, per leg | SecurityTools | exists, via `os-matrix` |
   | Pester tag exclusion | PS.SSL | `Build/harness.psd1` — see Q4 |
   | PSScriptAnalyzer `ExcludeRules` | AWSAutomation | `Build/harness.psd1` — see Q3 |
   | runtime dependencies | SecurityTools, AWSAutomation | read from each manifest's `RequiredModules` — see Q2 |

4. THE harness SHALL set both the legacy `$env:BHProjectPath`, `$env:BHProjectName` and `$env:BHPSModuleManifest` and their replacements `$env:HARNESS_PROJECT_PATH`, `$env:HARNESS_MODULE_NAME` and `$env:HARNESS_MANIFEST_PATH`, and SHALL be written against the new names. Decided on #20, 2026-11-06.
5. WHEN a consumer moves onto the harness, THE executed count for each of its legs SHALL equal the baseline recorded on #20 on 2026-11-09, with errors and failures at 0. Any difference SHALL be explained before that consumer's change merges.
6. WHEN this repo releases the harness, THE SYSTEM SHALL NOT change any consumer's CI outcome until that consumer opts in. *(Mechanism: Q5.)*
7. WHEN every consumer has moved, NO consumer SHALL keep a copy of a file the harness provides. *(Per Q1 and Q2, the only per-repo files that remain are the identical shim and an optional `Build/harness.psd1`.)*
8. THE harness SHALL include the eight stranded corrections from #20, except `PS.DCU`'s `CreateBuildArtifact` dependency, which SHALL be decided by measurement on a real release run rather than adopted because one repo has it.
9. THE harness's logic SHALL be covered by Pester suites in `tests/`, run by the required `verify Pester result step` check. Each new behaviour SHALL be shown to fail when broken as well as pass when correct.
10. WHEN the design is approved, ADR-0006 SHALL move to Accepted and cite the self-checkout spike, run [42090065876](https://github.com/jjohns-dev/PS.Log/actions/runs/42090065876).
11. THE chosen mechanism SHALL be recorded so that `PS-MCS/mcssec-ops` can adopt it without re-deriving the decision, including for consumers that pin a branch (`@main`) rather than a tag.

## Out of scope

- `Tests/Common/` and `Help.Tests.ps1` — #53 and #55.
- Migrating psake to Sampler — #19.
- The `PS-MCS` repos. They pick this up on promotion; criterion 11 only requires that they can.
- Renaming `$env:BH*` in consumers' `Tests/Unit/` — opportunistic, never a sweep.
- GitHub Enterprise Server. `job.workflow_*` is unavailable there.

## Open questions

- **Q1 — Local builds.** *Decided 2026-11-09: a per-repo shim. See [design.md](design.md#q1--local-builds-a-per-repo-shim-decided-2026-11-09).* Once `Build/` leaves a consumer, how does a developer run `build.ps1 -TaskList Test` locally? Neither #20 nor ADR-0006 addresses it. Candidates:
  - a thin per-repo `Build/build.ps1` that fetches the harness at a pinned version;
  - the harness published as a PowerShell module, so local and CI run the same code (#20's second option);
  - clone this repo beside the module and pass the project path;
  - no local support; CI only.
- **Q2 — Runtime dependencies.** *Decided 2026-11-09: names from each manifest's `RequiredModules`, versions float unless the manifest declares one. See [design.md](design.md#q2--runtime-dependencies-read-from-the-manifest-float-unless-declared-decided-2026-11-09).* `depend.psd1` mixes build tooling, which is uniform, with per-repo runtime modules: SecurityTools pins `ImportExcel` `7.8.10`; AWSAutomation floats `ImportExcel` and `AWS.Tools.*` to `latest` by its own ADR-0002. Keep a per-repo file for runtime modules only, take them as an input, or read them from each manifest's `RequiredModules`?
- **Q3 — Workflow scope.** *Decided 2026-11-09: all three move together, per consumer in one PR, with a release dry run. See [design.md](design.md#q3--workflow-scope-all-three-move-together-decided-2026-11-09).* `release.yml` runs `./Build/build.ps1` five times, and `pssa-sarif.yml` defaults to `./Build/PSScriptAnalyzerSettings.psd1`. Move all three workflows in one release, or `ci.yml` first?
- **Q4 — Test selection.** *Decided 2026-11-09: SecurityTools' scopes with default `All`, tag exclusion in `harness.psd1`, lowercase test file names. See [design.md](design.md#q4--test-selection-one-rule-default-all-decided-2026-11-09).* PS.SSL splits Windows-only tests by filename and `$IsWindows`; SecurityTools uses an explicit `PesterScope`. The harness needs one mechanism, and whichever repo changes must keep its executed counts (criterion 5).
- **Q5 — Opt-in.** *Decided 2026-11-09: the harness ships as `v2`; consumers opt in by repointing to `@v2`, and ADR-0002 is amended. See [design.md](design.md#q5--opt-in-the-central-harness-ships-as-v2-decided-2026-11-09).* A per-consumer input that selects the central harness, an immutable `vX.Y.Z` pin per consumer, or a `v2`? Which one ADR-0002 calls breaking decides part of this.
- **Q6 — Tool versions.** *Decided 2026-11-09: the harness pins PSScriptAnalyzer `1.25.0`; the five repos on `1.24.0` move in their migration PR. See [design.md](design.md#q6--build-tool-versions-psscriptanalyzer-1250-adopted-in-each-migration-pr-decided-2026-11-09).* A central `depend.psd1` pins one PSScriptAnalyzer. Five repos are on `1.24.0` and two on `1.25.0`, so most consumers change analyzer version as a side effect. Accept that inside this work or converge first?
- **Q7 — Strict mode.** *Decided 2026-11-09: strict harness code, lenient consumer tests by default, opt-in per repo through `harness.psd1`. See [design.md](design.md#q7--strict-mode-strict-harness-code-lenient-tests-by-default-opt-in-per-repo-decided-2026-11-09).* `PS.DCU` alone runs `Set-StrictMode -Version Latest`, and it is also the repo that fixed the dead analysis gate, which passes silently without strict mode and throws under it. Adopt it in the harness, accepting that it may fail other repos' builds on first run?
