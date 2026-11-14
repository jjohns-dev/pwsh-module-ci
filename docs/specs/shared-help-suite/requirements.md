# Shared help suite — requirements

- **Tracking:** [#55](https://github.com/jjohns-dev/pwsh-module-ci/issues/55)
- **Follows:** [#53](https://github.com/jjohns-dev/pwsh-module-ci/issues/53), [shared test minimum](../shared-test-minimum/requirements.md), whose delivery mechanism this reuses
- **Status:** Draft — 2026-11-13

## Problem

- Five consumers vendor a `help.tests.ps1` and no two are identical. PS.Log, PS.SSL, AWSAutomation and SecurityTools assert the same six things per command (Group A in #55); PS.SSL adds a module-surface test; PS.DCU asserts four different things, per function rather than per parameter. Fixes do not flow between the copies.
- PS.GHOps, PS.GitHub and PS.YNAB have no help tests, though PS.GHOps' and PS.YNAB's `AGENTS.md` require full comment-based help on every function.
- The variants disagree on what they can detect: only PS.DCU checks for a synopsis, and only Group A checks `.LINK` URIs and that help is not auto-generated.
- Measured 2026-11-13 against every consumer's `main`, reading each `Public/*.ps1` with the parser and checking the union of every variant's assertions: **no help defects in any of the eight**, the three repos without help tests included. A control module with eight planted defects failed all eight checks. The one hit, `SecurityTools`' `Get-KEVList -OutputDirectory`, is a dynamic parameter the parser cannot see; that repo's suite, which reads the loaded command, passes.

## User stories

- As the maintainer, I want the help checks defined once, so that a fix reaches every consumer without a PR per repo.
- As the maintainer, I want the three repos without help tests covered, so that their documented help rule is enforced rather than assumed.
- As the maintainer, I want the merged suite to keep every check any variant has today, so that centralizing does not drop coverage.
- As a module developer, I want the same checks to run locally through the shim as in CI.

## Acceptance criteria

1. THE harness SHALL carry a fourth shared suite, help, delivered and selected exactly as the three from #53 are: taking consumer values as `New-PesterContainer -Data` parameters, depending on Pester only, and running on `All` and `CrossPlatform` legs but not `WindowsOnly`.
2. THE help suite SHALL check every function the staged module exports, read from the imported module so that dynamic parameters are included.
3. FOR each exported function, THE help suite SHALL fail WHEN: it has no comment-based help; its `.SYNOPSIS` is empty; its `.DESCRIPTION` is empty; it has no `.EXAMPLE`; a declared parameter, common parameters excepted, has no `.PARAMETER` entry or an empty one; a `.PARAMETER` entry names no declared parameter; or a `.LINK` that is a URI is not a well-formed absolute `http` or `https` URI. A `.LINK` naming a related command is not a URI and SHALL NOT fail.
4. THE parameter checks SHALL read documented parameters from the help content, not `Get-Help`, which synthesizes an entry for an undocumented parameter and drops a `.PARAMETER` naming no real one, so neither check could fail against it.
5. THE help suite SHALL NOT make network calls; a `.LINK` URI is checked for form only.
6. EACH failure message SHALL name the function and the offending parameter or link.
7. THE help suite SHALL be covered by Pester suites in `tests/`, run by the required `verify Pester result step` check, with every assertion shown to fail on a fixture that violates it and pass on one that does not, under both lenient and strict mode.
8. BEFORE `v2` moves to the release carrying the help suite, THE release SHALL be proven on two throwaway consumer PRs pinned to its immutable tag: one repo with no help tests today, and SecurityTools, which has the dynamic parameter.
9. WHEN `v2` moves, every consumer SHALL run the help suite from its next build. IF the help suite itself is wrong, THE rollback SHALL be moving `v2` back to the previous release.
10. FOR each consumer, ONE cleanup PR after `v2` moves SHALL delete its `help.tests.ps1` where it has one, recalculate every leg's `min-tests` floor from its own run, and update any `AGENTS.md` text that describes the deleted file.
11. EVERY assertion a cleanup PR deletes SHALL be accounted for as covered by the help suite or dropped with a recorded reason. PS.SSL's *Exports at least one command* is dropped as covered by the shared manifest suite's non-empty `FunctionsToExport` and resolved-exports tests.
12. WHEN a developer runs the build locally through the shim, THE help suite SHALL run exactly as in CI.

## Scope

The eight consumers: PS.Log, PS.GHOps, PS.GitHub, PS.SSL, PS.DCU, AWSAutomation, SecurityTools, PS.YNAB. Ships as a `v2` minor release, then one cleanup PR per consumer.

## Out of scope

- Function-level unit tests.
- Requesting `.LINK` URIs to check they resolve.
- Help for private functions.
- [PS-MCS/ArcGISEnterprise#153](https://github.com/PS-MCS/ArcGISEnterprise/issues/153), ROLLOUT item 10; it adopts the help suite in its own migration.
- The `PS-MCS` repos, which pick this up on promotion.

## Resolved by measurement, not open

- **Import coupling** (#55's third question). The harness's `Test` task depends on `ImportStagingModule`, so a module that cannot import fails the build before any test runs; and the `Test` gate fails on `Result -ne 'Passed'`, which catches a suite that errors in discovery. The help suite adds no import risk the build does not already carry. All eight modules import locally (macOS, pwsh 7.7.0).
- **Adoption by the three repos without help tests** (#55's fifth question). Yes, as with #53: no opt-in. The measurement found nothing for them to fix first.

## Open questions

- **Q1 — Granularity.** One test per check per function, or Group A's per-parameter and per-link expansion? Both detect the same defects (AC 3); they differ in count, and so in how the `min-tests` floor behaves. Measured counts, the per-parameter figure approximated from the parser:

  | Repo | Per function | Per parameter |
  | ---- | ------------ | ------------- |
  | PS.Log | 24 | ~54 |
  | PS.GHOps | 40 | ~136 |
  | PS.GitHub | 24 | ~58 |
  | PS.SSL | 60 | ~159 |
  | PS.DCU | 32 | ~74 |
  | AWSAutomation | 144 | ~400 |
  | SecurityTools | 264 | ~527 |
  | PS.YNAB | 36 | ~61 |

  Per-function is shown at four tests a function; AC 3's seven conditions could be one test each or grouped. Lean: per function. A per-parameter count ties the floor to the number of parameters, so removing a dozen in a refactor fails CI with nothing wrong — the reason the meta suite loops instead of running per file (`docs/test-integrity.md`).

- **Q2 — The link check under per-function.** Only AWSAutomation has `.LINK` URIs today (two, both valid). A separate per-function link test would pass with nothing to check in seven repos, which inflates the floor without guarding anything. Lean: fold it into another per-function test, or run one looped link test across the module, as the meta suite does.
- **Q3 — "Not auto-generated".** Group A detects missing help by the synopsis falling back to a syntax diagram. AC 3's "no comment-based help" condition replaces it directly. Lean: drop the Group A form, keep the condition.
