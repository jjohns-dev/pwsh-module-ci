# Shared test minimum — design

- **Requirements:** [requirements.md](requirements.md), approved 2026-11-13
- **Status:** Approved — 2026-11-13; amended 2026-11-13 to three suites (see *What the harness already enforces*)

## Approach

- Three Pester files ship in the harness and run inside the existing `Test` task, in the **same** `Invoke-Pester` call as the consumer's own tests. One run means one JUnit file, so `ci.yml`'s verify step and the `min-tests` floor see shared and consumer tests together with no workflow change.
- Each shared file is handed to Pester as a container built with `New-PesterContainer -Path <file> -Data @{ ProjectPath; ModuleName }` (AC 2). The consumer's files become plain path containers in the same list.
- Nothing changes in `ci.yml`, `release.yml`, `pssa-sarif.yml` or the shim. The change is `Build/build.psake.ps1`'s `Test` task plus three new files.

## Architecture

```text
Build/
  build.psake.ps1          Test task: consumer containers + shared containers -> one Invoke-Pester
  SharedTests/
    manifest.tests.ps1     11 tests, fixed
    meta.tests.ps1          3 tests, fixed (looped)
    pathliterals.tests.ps1  1 per Public/*.ps1
```

- **Location: `Build/SharedTests/`, not `Tests/`.** This repo already has `tests/` for its own suites, and macOS's case-insensitive filesystem would merge `Tests/` into it. Under `Build/` the files travel with the harness checkout to `$RUNNER_TEMP/harness`, and `tests/Invoke-VerificationTest.ps1` (`Run.Path = tests/`) never collects them by accident.
- **Names are lowercase `*.tests.ps1`**, the consumer convention, so they read the same in a consumer's JUnit output.

### Selection (AC 9)

The `Test` task already sorts the consumer's files into `$crossPlatform` and `$windowsOnly` by `PesterScope`. The shared containers join the selection whenever `$crossPlatform` would: `All` and `CrossPlatform` include them, `WindowsOnly` does not. SecurityTools' windows leg therefore stays at 21 executed.

### Order

Shared containers run **after** the consumer's. The manifest suite's resolved-exports check re-imports the staged module (below), so running it last keeps every consumer test on the module exactly as `ImportStagingModule` left it.

### Strict mode

The `Test` task turns strict mode off around `Invoke-Pester` unless the consumer sets `PesterStrictMode` (PS.DCU does). The shared files must therefore pass under both, and their own tests run them both ways.

## Interfaces

| `-Data` key | Value | Used by |
| ----------- | ----- | ------- |
| `ProjectPath` | `$ProjectRoot`, the consumer checkout | all three |
| `ModuleName` | `$ModuleName` | manifest |

`-Data` binds at discovery as well as run time on Pester 6.2.0 (measured 2026-11-06, recorded on #53), which `pathliterals.tests.ps1` needs to build one case per public file in `BeforeDiscovery`.

## What the harness already enforces (AC 5)

These were in the consumer copies and are **deliberately not** shared tests. Each is guaranteed by a step that runs before `Test`, so as a shared test it could never fail. Do not re-add them.

| Behaviour | Enforced by |
| --------- | ----------- |
| exactly one manifest at the project root | `Resolve-HarnessProject` stops the build otherwise |
| manifest name matches the module | the module name **is** the manifest's file name, as is `Test-ModuleManifest`'s `Name`; the comparison is a tautology |
| the `.psm1` loader exists | `CombineFunctionsAndStage` stops the build if a required input is missing |
| the staged module imports | `ImportStagingModule` imports with `-ErrorAction Stop`, and `Test` depends on it |
| `ModuleVersion` and `GUID` parse | an unparseable value fails that import (measured 2026-11-13, pwsh 7.6.9) |

Measured 2026-11-13 on pwsh 7.6.9 against fixture manifests, to find which remaining checks the import already covers:

| Defect | `Import-Module` | `Test-ModuleManifest` |
| ------ | --------------- | --------------------- |
| `ModuleVersion` or `GUID` unparseable | fails | fails |
| `PowerShellVersion` `9.0` or `abc` | fails | fails |
| `PowerShellVersion` `3.0` | imports | passes |
| `FileList` names a missing file | imports | fails |
| `RootModule` without extension, or absent | imports | passes |
| `Description` absent; `FunctionsToExport = '*'` | imports | passes |
| a `Public/` function misnamed | imports, exports nothing | passes |

So AC 4's upper bound and parsing are also enforced by the import, but its lower bound is not, and that is why the version test stays.

They made sense in the consumers, which ran outside a harness that checks them.

## The three suites

### `manifest.tests.ps1` — 11 tests (AC 3, AC 4)

Reads the manifest with `Import-PowerShellDataFile`, for what is literally declared, plus one `Test-ModuleManifest` call and one import of the staged module.

| # | Assertion | Source |
| - | --------- | ------ |
| 1 | passes `Test-ModuleManifest` | resolved |
| 2 | `RootModule` is `<ModuleName>.psm1` | declared |
| 3–5 | `Description`, `Author`, `Copyright` non-empty | declared |
| 6 | `FunctionsToExport` non-empty | declared |
| 7 | `FunctionsToExport` equals `Public/*.ps1` base names | declared |
| 8 | no `*` in `FunctionsToExport`, `CmdletsToExport`, `VariablesToExport`, `AliasesToExport` | declared |
| 9 | `PrivateData.PSData.ProjectUri` non-empty | declared |
| 10 | `PowerShellVersion` present, parses, and is `5.1` or in `7.0`..`$PSVersionTable.PSVersion` | declared |
| 11 | the staged module's `ExportedFunctions` equal `Public/*.ps1` base names | imported |

Test 11 imports `Staging/<ModuleName>` with `-Force -PassThru` and reads the returned module, not `Get-Module`, because a consumer test may have removed or replaced the loaded copy. It catches what test 7 cannot: a `Public/` file whose function is named differently, or which defines nothing, is declared and present yet never exported, and `Import-Module` does not error on a missing export. Measured 2026-11-13 on pwsh 7.6.9: such a module imports cleanly with `ExportedFunctions` empty, while `Test-ModuleManifest` still reports the declared name. Staged, because that is what the artifact ships.

Set comparisons join sorted arrays before comparing, as PS.YNAB's suite does, so an empty side cannot pass vacuously.

### `meta.tests.ps1` — 3 tests, looped (AC 6, AC 7)

One file list: every `.ps1`, `.psm1` and `.psd1` under `ProjectPath`, excluding any path containing a `.git`, `Staging` or `Artifacts` segment. Each test reads bytes and fails with every offender in the message:

1. no UTF-8 BOM (`EF BB BF` at offset 0) — PS.DCU's check, which a `0x00` scan cannot replace;
2. no tab byte (`0x09`);
3. no `0x00` byte — the four-repo check, which PS.DCU lacks.

### `pathliterals.tests.ps1` — 1 per `Public/*.ps1` (AC 8)

PS.SSL's implementation, adapted to `-Data`: parse each file and inspect only `StringConstantExpressionAst` and `ExpandableStringExpressionAst` nodes for `\$(HOME|PSScriptRoot|PWD|TestDrive)\\`. Comments are not string nodes, so the four `.EXAMPLE` paths in today's fleet do not match. Observed in PS.SSL's code 2026-11-13; its suite passes 15/15 with two such examples present.

## Affected files

### This repo

| File | Change |
| ---- | ------ |
| `Build/SharedTests/*.tests.ps1` | new, the three suites |
| `Build/build.psake.ps1` | `Test` task builds containers; shared ones selected by scope, run last |
| `tests/SharedTests.Tests.ps1` | new: runs each shared file against fixture modules in `TestDrive:`, one passing fixture and one failing fixture per assertion (AC 14), under strict mode on and off |
| `tests/HarnessTasks.Tests.ps1` | the `Test` task includes shared containers on `All`/`CrossPlatform` and excludes them on `WindowsOnly` |
| `docs/test-integrity.md` | *Settled decisions*: why meta loops (AC 7) |
| `docs/consumer-guide.md` | what the harness now tests; what a consumer no longer carries |
| `AGENTS.md`, `README.md` | layout row for `Build/SharedTests/` |

### Each consumer, in its cleanup PR (AC 12)

Delete `Tests/Common/manifest.tests.ps1`, `meta.tests.ps1`, `PathLiterals.tests.ps1`, `MetaFixers.psm1`, or `Tests/Unit/Module.tests.ps1`, as present; fix that repo's red-list defects; recalculate floors from the PR's own run; copy the current shim template. Done through the agent-prompt pattern, one repo at a time, each report verified here from artifacts.

## Rollout

1. Harness PR here; suites green on both OS legs. Release `v2.1.0` — a minor under ADR-0002: no call changes, and a wrongly-green build turning red is not breaking.
2. Throwaway PRs pinned `@v2.1.0` (AC 10): PS.YNAB expected green; SecurityTools expected red on exactly its four BOM files.
3. Move `v2` (AC 11). Rollback: move `v2` back to `v2.0.2`.
4. Eight cleanup PRs. Until each lands, that repo runs its vendored copies **and** the shared suites; counts only rise, so no floor trips, but the four red-list files and three literals keep SecurityTools and AWSAutomation red.

## Alternatives considered

- **A separate `Invoke-Pester` for the shared suites.** Two result files, and the floor and verify step read every `Test-*.xml`, so it would work, but it splits one leg's count across files and changes what a floor means. Rejected: one run is simpler and matches AC 6's "counts like any other".
- **Shared files under a root `Tests/`.** Collides with `tests/` on macOS. Rejected.
- **Importing from the project root rather than `Staging/`.** Tests the sources, not what ships. Rejected.

## Risks and tradeoffs

- **Two Pester behaviours are assumed, not measured.** That path and `-Data` containers can be mixed in one run, and that containers run in the order given, which the manifest suite's "run last" depends on. Converting every consumer file to `New-PesterContainer -Path` avoids mixing `Run.Path` with `Run.Container`; the first task measures both on Pester 6.2.0 before anything else is built.
- **A shared-suite bug reaches eight repos at once.** Mitigated by AC 10's two proofs and the one-command rollback.
- **The manifest suite re-imports the module.** Safe only because it runs last; a consumer test that ran after it would see a fresh import. Covered by the order rule and a harness test.
- **`pathliterals` scales with public-function count.** Deleting more than ten public functions in one change trips the floor. Accepted in #53's decision: it tracks the module's surface, as help tests already do.

## ADR check

No new ADR. The decision with lasting consequences, looping meta rather than per-file, is a test-design rule and goes to `docs/test-integrity.md` (AC 7). Shipping as a minor follows ADR-0002; hosting test code in the harness extends ADR-0006 without changing it.
