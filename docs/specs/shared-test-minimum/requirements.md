# Shared test minimum — requirements

- **Tracking:** [#53](https://github.com/jjohns-dev/pwsh-module-ci/issues/53)
- **Decision record:** the [2026-11-06 decision](https://github.com/jjohns-dev/pwsh-module-ci/issues/53#issuecomment-6690021906), as refreshed by the [2026-11-12 survey](https://github.com/jjohns-dev/pwsh-module-ci/issues/53#issuecomment-6839693409)
- **Status:** Draft — revised 2026-11-13 after review

## Problem

- The consumers test the same module-level properties in two incompatible shapes. Five repos vendor `Tests/Common/` (manifest, meta, and in PS.SSL path literals); PS.GHOps, PS.GitHub and PS.YNAB each carry a `Tests/Unit/Module.tests.ps1` instead. Fixes do not flow between the copies.
- The variants differ in what they can detect. SecurityTools' meta suite looks for `0x00` bytes, so it cannot see a UTF-8 BOM, and four of its files carry one. Only PS.SSL checks for Windows-only path literals, and AWSAutomation has three in exported code. Both re-measured unchanged on 2026-11-12.
- Four repos carry `Tests/Common/MetaFixers.psm1`, 79 lines each, three of whose five functions are never called (measured 2026-11-06; the file's presence re-confirmed 2026-11-12).
- The harness now runs every consumer's build (#20), so it can carry the shared half the same way it carries `Build/`.

## User stories

- As the maintainer, I want module-level checks defined once, so that a fix or a new check reaches every consumer without a PR per repo.
- As the maintainer, I want the checks to catch the defects the fleet actually has today, so that centralizing them is a gain in coverage rather than a reshuffle.
- As the maintainer, I want the whole fleet to take the shared checks in one release, proven on two consumers first, so that defects surface everywhere at once and a broken release can be rolled back with one tag move.
- As the maintainer, I want every test a consumer deletes to be accounted for, so that centralizing cannot silently drop coverage.
- As a module developer, I want the same checks to run locally through the shim as in CI.

## Acceptance criteria

1. THE harness SHALL carry four shared suites, run against the consumer's project: manifest, module, meta and path literals. They SHALL depend on Pester only.
2. THE shared suites SHALL take every consumer-specific value as a `New-PesterContainer -Data` parameter. They SHALL NOT locate the consumer from `$PSScriptRoot`, which resolves into the harness, nor read `$env:BH*` or its replacements.
3. THE manifest suite SHALL assert: the manifest exists; it passes `Test-ModuleManifest`; its name matches the module; `RootModule` names the `.psm1`; `ModuleVersion` and `Guid` parse; `Description`, `Author` and `Copyright` are non-empty; `FunctionsToExport` is non-empty and matches `Public/*.ps1`; no export field contains `'*'`; `ProjectUri` is present in `PSData`.
4. THE manifest suite SHALL assert that `PowerShellVersion` is present, parses as a version, and is either exactly `5.1` or at least `7.0` and no greater than the PowerShell running the tests. `3.0`, `5.0`, any `6.x` and any unreleased version SHALL fail. There is no per-repo minimum.
5. THE module suite SHALL assert that the `.psm1` loader exists, that the module imports without throwing, and that its resolved `ExportedFunctions` match `Public/*.ps1`.
6. THE meta suite SHALL check every `.ps1`, `.psm1` and `.psd1` file outside `.git`, `Staging` and `Artifacts` for a UTF-8 BOM, tab characters and `0x00` bytes, reading bytes rather than decoded text. It SHALL run one test per check, not one per file, and each failure SHALL name every offending file. Its test count is therefore fixed and counts toward the `min-tests` floor like any other.
7. THE reason AC 6 loops rather than runs per file SHALL be recorded in `docs/test-integrity.md`: a per-file suite ties the floor to the number of source files, so deleting four files in an ordinary refactor would drop twelve tests, beyond the floor's maximum margin of 10, and fail CI with nothing wrong.
8. THE path-literals suite SHALL check each `Public/*.ps1` for a backslash following `$HOME`, `$PSScriptRoot`, `$PWD` or `$TestDrive` in code. Comments, including comment-based help, SHALL NOT count: four `.EXAMPLE` paths in today's fleet are not defects.
9. THE shared suites SHALL be selected by `PesterScope` as cross-platform tests, exactly as a consumer's `*.tests.ps1` files are: they run on `All` and `CrossPlatform` legs and not on `WindowsOnly`. SecurityTools' windows leg is unchanged.
10. BEFORE `v2` moves to the release carrying the shared suites, THE release SHALL be proven on two throwaway consumer PRs pinned to its immutable tag: one expected green (PS.YNAB, whose manifest has not been measured against AC 3) and one expected red (SecurityTools, to confirm the failure messages name the defects).
11. WHEN `v2` moves, every consumer SHALL run the shared suites from its next build. Consumers whose own defects then fail CI stay red until their cleanup PR (AC 12) lands; that is accepted. IF the shared suites themselves are wrong, THE rollback SHALL be moving `v2` back to the previous release.
12. FOR each consumer, ONE cleanup PR after `v2` moves SHALL: delete its manifest, meta, module and path-literal tests and any `MetaFixers.psm1`; fix its red-list defects (four UTF-8 BOM files in SecurityTools, three `"$HOME\Desktop"` literals in AWSAutomation's exported code); recalculate every leg's `min-tests` floor from its own run, recording executed count and margin as the floors do today; and refresh its shim to the current template. `Help.Tests.ps1` and function unit tests stay.
13. EVERY assertion a cleanup PR deletes SHALL be accounted for as covered by a shared suite or kept locally with a recorded reason. The classification of the three `Module.tests.ps1` files (PS.GHOps, PS.GitHub, PS.YNAB) is done: every assertion maps to AC 3 or AC 5 except `PowerShellVersion` ≥ `7.4`, which is dropped in favour of AC 4.
14. THE shared suites SHALL be covered by Pester suites in `tests/`, run by the required `verify Pester result step` check. Each assertion SHALL be shown to fail on a fixture that violates it as well as pass on one that does not.
15. WHEN a developer runs the build locally through the shim, THE shared suites SHALL run exactly as in CI.

## Scope

The eight consumers: PS.Log, PS.GHOps, PS.GitHub, PS.SSL, PS.DCU, AWSAutomation, SecurityTools, PS.YNAB. Ships as `v2.1.0`, then one cleanup PR per consumer.

## Out of scope

- `Help.Tests.ps1` — stays per repo here. Agreed 2026-11-13 that it should be centralized, as its own release after this one; [#55](https://github.com/jjohns-dev/pwsh-module-ci/issues/55).
- Function-level unit tests.
- [PS-MCS/ArcGISEnterprise#153](https://github.com/PS-MCS/ArcGISEnterprise/issues/153) — deferred to ROLLOUT item 10; it adopts the shared suites in its own migration.
- The `PS-MCS` repos — they pick this up on promotion.
- Renaming `$env:BH*` in consumers' unit tests.

## Decisions, 2026-11-13

The four open questions in the first draft, resolved in review:

- **Q1 — Meta and the floor:** one looped test per check (AC 6), reason recorded (AC 7). The draft's "does not count" was unworkable: tag-excluding a test stops it running.
- **Q2 — Opt-in:** none. The whole fleet takes the shared suites when `v2` moves, after a two-consumer proof (AC 10, AC 11). Known defects are fixed in each repo's cleanup PR rather than before the move.
- **Q3 — SecurityTools' legs:** selected by `PesterScope` as cross-platform tests (AC 9).
- **Q4 — The three `Module.tests.ps1` files:** classified (AC 13); `PowerShellVersion` ≥ `7.4` is dropped in favour of AC 4.
