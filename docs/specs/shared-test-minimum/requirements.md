# Shared test minimum — requirements

- **Tracking:** [#53](https://github.com/jjohns-dev/pwsh-module-ci/issues/53)
- **Decision record:** the [2026-11-06 decision](https://github.com/jjohns-dev/pwsh-module-ci/issues/53#issuecomment-6690021906), as refreshed by the [2026-11-12 survey](https://github.com/jjohns-dev/pwsh-module-ci/issues/53#issuecomment-6839693409)
- **Status:** Draft — 2026-11-12

## Problem

- The consumers test the same module-level properties in two incompatible shapes. Five repos vendor `Tests/Common/` (manifest, meta, and in PS.SSL path literals); PS.GHOps, PS.GitHub and PS.YNAB each carry a `Tests/Unit/Module.tests.ps1` instead. Fixes do not flow between the copies.
- The variants differ in what they can detect. SecurityTools' meta suite looks for `0x00` bytes, so it cannot see a UTF-8 BOM, and four of its files carry one. Only PS.SSL checks for Windows-only path literals, and AWSAutomation has three in exported code. Both re-measured unchanged on 2026-11-12.
- Four repos carry `Tests/Common/MetaFixers.psm1`, 79 lines each, three of whose five functions are never called (measured 2026-11-06; the file's presence re-confirmed 2026-11-12).
- The harness now runs every consumer's build (#20), so it can carry the shared half the same way it carries `Build/`.

## User stories

- As the maintainer, I want module-level checks defined once, so that a fix or a new check reaches every consumer without a PR per repo.
- As the maintainer, I want the checks to catch the defects the fleet actually has today, so that centralizing them is a gain in coverage rather than a reshuffle.
- As the maintainer, I want each consumer to adopt the shared checks on its own schedule, so that a red check reaches one repo rather than the fleet.
- As the maintainer, I want every test a consumer deletes to be accounted for, so that centralizing cannot silently drop coverage.
- As a module developer, I want the same checks to run locally through the shim as in CI.

## Acceptance criteria

1. THE harness SHALL carry four shared suites, run against the consumer's project: manifest, module, meta and path literals. They SHALL depend on Pester only.
2. THE shared suites SHALL take every consumer-specific value as a `New-PesterContainer -Data` parameter. They SHALL NOT locate the consumer from `$PSScriptRoot`, which resolves into the harness, nor read `$env:BH*` or its replacements.
3. THE manifest suite SHALL assert: the manifest exists; it passes `Test-ModuleManifest`; its name matches the module; `RootModule` names the `.psm1`; `ModuleVersion` and `Guid` parse; `Description`, `Author` and `Copyright` are non-empty; `FunctionsToExport` is non-empty and matches `Public/*.ps1`; no export field contains `'*'`; `ProjectUri` is present in `PSData`.
4. THE manifest suite SHALL assert that `PowerShellVersion` is present, parses as a version, and is either exactly `5.1` or at least `7.0` and no greater than the PowerShell running the tests. `3.0`, `5.0`, any `6.x` and any unreleased version SHALL fail. There is no per-repo minimum.
5. THE module suite SHALL assert that the `.psm1` loader exists, that the module imports without throwing, and that its resolved `ExportedFunctions` match `Public/*.ps1`.
6. THE meta suite SHALL check every `.ps1`, `.psm1` and `.psd1` file outside `.git`, `Staging` and `Artifacts` for a UTF-8 BOM, tab characters and `0x00` bytes, reading bytes rather than decoded text. It SHALL fail the build on any hit, and its tests SHALL NOT count toward the `min-tests` floor, so that adding or deleting source files cannot move the floor. *(Mechanism: Q1.)*
7. THE path-literals suite SHALL check each `Public/*.ps1` for a backslash following `$HOME`, `$PSScriptRoot`, `$PWD` or `$TestDrive` in code. Comments, including comment-based help, SHALL NOT count: four `.EXAMPLE` paths in today's fleet are not defects.
8. WHEN this repo releases the shared suites, THE SYSTEM SHALL NOT change any consumer's CI outcome until that consumer opts in. *(Mechanism: Q2.)*
9. WHEN a consumer adopts the shared suites, THE consumer SHALL delete its manifest, meta, module and path-literal tests and any `MetaFixers.psm1`, and SHALL account for every deleted assertion as either covered by a shared suite or kept locally with a recorded reason. `Help.Tests.ps1` and function unit tests stay.
10. WHEN SecurityTools and AWSAutomation adopt, THE same change SHALL fix their red-list defects: four UTF-8 BOM files in SecurityTools, three `"$HOME\Desktop"` literals in AWSAutomation's exported code.
11. WHEN a consumer adopts, THE same change SHALL recalculate every leg's `min-tests` floor from that change's own run, recording executed count and margin as the floors do today, and SHALL refresh the consumer's shim to the current template.
12. THE shared suites SHALL be covered by Pester suites in `tests/`, run by the required `verify Pester result step` check. Each assertion SHALL be shown to fail on a fixture that violates it as well as pass on one that does not.
13. WHEN a developer runs the build locally through the shim, THE shared suites SHALL run exactly as in CI.

## Scope

The eight consumers: PS.Log, PS.GHOps, PS.GitHub, PS.SSL, PS.DCU, AWSAutomation, SecurityTools, PS.YNAB. Ships as `v2.1.0`, with one adoption PR per consumer.

## Out of scope

- `Help.Tests.ps1` — stays per repo; [#55](https://github.com/jjohns-dev/pwsh-module-ci/issues/55).
- Function-level unit tests.
- [PS-MCS/ArcGISEnterprise#153](https://github.com/PS-MCS/ArcGISEnterprise/issues/153) — deferred to ROLLOUT item 10; it adopts the shared suites in its own migration.
- The `PS-MCS` repos — they pick this up on promotion.
- Renaming `$env:BH*` in consumers' unit tests.

## Open questions

- **Q1 — Keeping meta out of the floor.** Tag-excluding a test stops it running, so "runs and fails the build, but does not count" needs a mechanism. Candidates: one looped test per check rather than one per file (the four-repo shape today, 2 tests); a separate Pester run with its own result file that the floor does not read; or subtracting meta's count before the floor compares.
- **Q2 — Opt-in.** Once `v2` moves, every consumer runs the harness at once, and SecurityTools and AWSAutomation would go red on their red lists. Candidates: a `harness.psd1` key that turns the shared suites on; or consumers pin `@v2.1.0` in their adoption PRs and `v2` moves only when all eight have adopted.
- **Q3 — Which legs run the shared suites.** SecurityTools selects tests per leg with `pesterScope` (`CrossPlatform`, `WindowsOnly`). Run the shared suites on every leg, or only where scope allows? The answer moves the windows floor of 20.
- **Q4 — What the three `Module.tests.ps1` files assert beyond AC 5.** PS.GHOps runs 8 tests in its file, PS.GitHub 7, PS.YNAB 7. Each assertion must be classified before AC 9 can be met.
