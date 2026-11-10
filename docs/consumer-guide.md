# Consumer guide

How a PowerShell module repo calls the reusable workflows in this repo, and how its build runs. Covers `v2`, which runs every consumer's build from the shared harness in [`Build/`](../Build). A repo still on `@v1` runs its own vendored `Build/` and is migrated by the steps under [Migrating from `v1`](#migrating-from-v1).

## Calling the workflows

A consumer repo keeps its own trigger conditions and permissions, and calls the shared job:

```yaml
# .github/workflows/ci.yml
name: ci
on:
  pull_request:
    branches: ["*"]
  push:
    branches: [main]
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
jobs:
  validate:
    uses: jjohns-dev/pwsh-module-ci/.github/workflows/ci.yml@v2
    permissions:
      contents: read
      checks: write
```

```yaml
# .github/workflows/release.yml
name: release
on:
  push:
    tags: ["v[0-9].[0-9]+.[0-9]+"]
  pull_request:
    branches: ["*"]
jobs:
  release:
    uses: jjohns-dev/pwsh-module-ci/.github/workflows/release.yml@v2
    with:
      dry-run: ${{ github.event_name == 'pull_request' }}
    permissions:
      contents: write
```

```yaml
# .github/workflows/pssa-sarif.yml
name: pssa-sarif
on:
  pull_request:
    branches: ["*"]
  push:
    branches: [main]
jobs:
  analyze:
    uses: jjohns-dev/pwsh-module-ci/.github/workflows/pssa-sarif.yml@v2
    permissions:
      contents: read
      security-events: write
```

The release caller's `pull_request` trigger runs the whole release path on every PR (build, test, verify, upload the artifact) and skips only publishing, so a PR proves the release works before a tag is pushed. If the job carries an `if:` that admits only tags, widen it to `startsWith(github.ref, 'refs/tags/v') || github.event_name == 'pull_request'`, or the PR run is skipped.

Each workflow checks this repo out at its own commit into `.harness/` and runs the harness against your checkout, so the harness version always matches the workflow version you pinned. `.harness/` is never analysed, tested or packaged as part of your module.

### Inputs

| Input | Workflow | Default | Effect |
| ----- | -------- | ------- | ------ |
| `os-matrix` | `ci.yml` | `'["ubuntu-latest", "windows-latest", "macos-latest"]'` | Runners, and optionally per-leg settings; see [Runner matrix](#runner-matrix) |
| `min-tests` | `ci.yml` | `0` (off) | Floor on executed tests; see [Minimum test count](#minimum-test-count) |
| `artifact-name` | `release.yml` | `'Artifacts'` | Display name of the uploaded build artifact |
| `dry-run` | `release.yml` | `false` | Skip only the publishing step |

`artifact-name` must be valid on every event that runs it. `github.ref_name` is `<n>/merge` on a pull request, and artifact names cannot contain `/`, so a repo-specific name needs a PR fallback:

```yaml
    with:
      artifact-name: ${{ github.event_name == 'pull_request' && 'MyModule-dry-run' || format('MyModule-{0}', github.ref_name) }}
```

`pssa-sarif.yml` takes no inputs. `v1`'s `psscriptanalyzer-settings-path` is gone: the scan uses the harness's settings plus your [`harness.psd1`](#buildharnesspsd1) exclusions, the same settings as the build's `Analyze` task. The scopes differ: `Analyze` checks only the staged module, while the Security-tab scan covers the whole repo, tests included, except `.harness/` and `.git/`.

## Runner matrix

`os-matrix` accepts **two forms**, and `ci.yml` normalises them into one before building its matrix. Most repos never need the second.

**A JSON array of OS names.** The common case — every runner does the same thing.

```yaml
jobs:
  validate:
    uses: jjohns-dev/pwsh-module-ci/.github/workflows/ci.yml@v2
    with:
      os-matrix: '["ubuntu-latest", "windows-latest"]'
      min-tests: 91
    permissions:
      contents: read
      checks: write
```

The default is `'["ubuntu-latest", "windows-latest", "macos-latest"]'`.

**A JSON array of objects.** Use this when runners need *different* values — a different test scope, a different floor, or both. Each object must carry `os`; `pesterScope` and `minTests` are optional and apply only to that leg.

```yaml
jobs:
  validate:
    uses: jjohns-dev/pwsh-module-ci/.github/workflows/ci.yml@v2
    with:
      os-matrix: >-
        [{"os":"ubuntu-latest","pesterScope":"CrossPlatform","minTests":986},
         {"os":"windows-latest","pesterScope":"WindowsOnly","minTests":20}]
    permissions:
      contents: read
      checks: write
```

| Key | Required | Effect |
| --- | -------- | ------ |
| `os` | yes | The runner label, as `runs-on` |
| `pesterScope` | no | Passed to the `Test` task as `-Properties @{ PesterScope = ... }`. Omitted entirely when absent, so the harness default `All` stands |
| `minTests` | no | This leg's floor. Overrides the workflow-wide `min-tests` for this leg only |

The two forms are interchangeable per call, not per entry — do not mix strings and objects in the same array. Supplying an object without an `os` key fails the `normalize` job with a message naming the offending entry, rather than producing a leg that silently does nothing.

Why one polymorphic input rather than a second `os-matrix-include` input: when a matrix declares both `os:` and `include:`, an `os` leg that no `include` entry matches **still runs**, carrying empty values. A caller who supplied the include list but forgot to narrow `os-matrix` would get an extra leg whose empty `pesterScope` fell through to the default — green, and wrong. Measured; see [ADR-0006](adr/0006-host-the-build-harness-in-this-repo.md).

Expanding the input is done by a small `normalize` job that runs before `validate`. It adds one check name, `<your job> / normalize matrix`, and leaves the existing `<your job> / validate (<os>)` names unchanged — measured, so required-check rules do not need editing when you adopt this.

## Pester result verification

`ci.yml` verifies the JUnit XML that the `Test` task writes, after the Pester step and independently of the harness's own gate. The run fails if no result file was produced, if the root `<testsuites>` element reports `errors > 0`, or if it reports `tests == 0`. `release.yml` carries the identical step.

This exists because a discovery or container error attaches to the *container* rather than to a test, so a gate written as `if ($TestResults.FailedCount -gt 0)` leaves `FailedCount` at `0` and the build passes having collected a fraction of its suite. The counts must be read from the **root** `<testsuites>` element: the child `<testsuite>` reports `errors="0"` for the same run, so a check written against the child parses cleanly and silently never fires.

The harness configures Pester with `TestResult.OutputFormat = 'JUnitXml'` and writes `Artifacts/Test-Unit_<timestamp>.xml`, so a `v2` consumer configures nothing. `NUnitXml` is not supported — the verification step fails with an explicit message naming the root element it found, and `dorny/test-reporter`'s `java-junit` reporter cannot parse NUnit-format XML either.

The verification step is the gate; the `dorny/test-reporter` step is display only and keeps `fail-on-error: false` / `fail-on-empty: false`.

### Minimum test count

A suite can also shrink with `errors = 0`: a test-file glob that stops matching, a file moved outside the selected folders, or a `-ForEach` data source that shrinks rather than empties. It can also stop *running* without shrinking at all, when tests become skipped or tag-excluded. To catch both, pass the optional `min-tests` input to `ci.yml`. The run then fails when a result file's **executed** count — root `tests` minus `disabled` — is below it. The default, `0`, disables the check. `release.yml` does not take the input: a release is cut from a commit that already passed `ci.yml`, so the floor is set in one place.

```yaml
jobs:
  validate:
    uses: jjohns-dev/pwsh-module-ci/.github/workflows/ci.yml@v2
    with:
      min-tests: 430
    permissions:
      contents: read
      checks: write
```

`min-tests` is a floor, not an exact count, so adding tests never fails a run. Derive it from the **executed** count, using the lowest across your runner OSes when they differ — Pester's JUnitXml routes both skipped and tag-excluded tests to `disabled` while still counting them in `tests`, so a repo that skips anything has an executed count below its collected one. It catches a large drop rather than a single lost file, and it only stays useful if you raise it as the suite grows. The full procedure is in [`test-integrity.md`](test-integrity.md#deriving-a-min-tests-floor).

When the lowest-across-OSes compromise costs too much — one leg running a fraction of the suite, so a single floor is either far too low for the other leg or fails it outright — give each leg its own `minTests` through the object form of `os-matrix`, described under [Runner matrix](#runner-matrix). A leg that declares no `minTests` falls back to the workflow-wide `min-tests`.

The floor is compared against each result file separately, so it assumes one `Test-*.xml` per run, which is what the harness writes.

The root `tests` count includes tests excluded by `Filter.ExcludeTag`; Pester reports them in the root `disabled` attribute without a `<testcase>` element. A floor therefore does not catch a filter that starts excluding more of the suite.

## The build harness

### What your repo must look like

| Path | Required | Notes |
| ---- | -------- | ----- |
| `<Module>.psd1` at the repo root | yes | Exactly one root `.psd1`; its name is the module name. Two, or none, fails the build |
| `<Module>.psm1` at the repo root | yes | |
| `Public/` | yes | Must contain at least one file |
| `Private/` | no | Staged when present |
| `README.md` | yes | Staged into the module |
| `Tests/<folder>/*.tests.ps1` | yes | Cross-platform tests, one folder level below `Tests/` |
| `Tests/<folder>/*.tests.windows.ps1` | no | Windows-only tests |
| `Build/build.ps1` | yes | The [shim](#running-the-build-locally), byte-identical to the template |
| `Build/harness.psd1` | no | Only for the settings [below](#buildharnesspsd1) |

Staging copies exactly the manifest, the root module, `README.md`, `Public/` and `Private/` into `Staging/<Module>/`. Anything else at the root, such as `examples/` or `docs/`, is not shipped.

Test files are named in lowercase, `*.tests.ps1` and `*.tests.windows.ps1`. The harness matches names case-insensitively, so this is a consistency rule rather than a functional one.

### Test selection

`PesterScope` decides which files run:

| `PesterScope` | Runs |
| ------------- | ---- |
| `All` (default) | every `*.tests.ps1`, plus every `*.tests.windows.ps1` on Windows |
| `CrossPlatform` | every `*.tests.ps1` |
| `WindowsOnly` | every `*.tests.windows.ps1` |

A scope that selects no files fails the build. Set it per leg with `pesterScope` in `os-matrix`, or locally with `-Properties @{ PesterScope = 'CrossPlatform' }`.

Your tests run in the harness's session and can read `$env:HARNESS_PROJECT_PATH`, `$env:HARNESS_MODULE_NAME` and `$env:HARNESS_MANIFEST_PATH`. The legacy `$env:BHProjectPath`, `$env:BHProjectName` and `$env:BHPSModuleManifest` are set to the same values for tests that still read them.

### Tasks and properties

`Build/build.ps1 -TaskList <task[]>` accepts these tasks, which are the names `v1` repos already used:

| Task | Does |
| ---- | ---- |
| `Init` | Prints the build details. Combine with `-ResolveDependency` to install dependencies first |
| `Setup` | Recreates `Artifacts/` and `Staging/` |
| `CombineFunctionsAndStage` | Stages the module into `Staging/<Module>/`. The name is historical; nothing is combined |
| `ImportStagingModule` | Imports the staged module |
| `Analyze` | Runs PSScriptAnalyzer on the staged module |
| `Test` | Imports the staged module, runs Pester, and writes the JUnit result to `Artifacts/`. Each test file still loads whichever module it imports itself |
| `CreateBuildArtifact` | Zips `Staging/` to `Artifacts/<Module>-v<ModuleVersion>.zip` |
| `Cleanup` | Deletes `Artifacts/` and `Staging/` |
| `Default` | Runs `Test` |

Properties you can override with `-Properties`:

| Property | Default | Effect |
| -------- | ------- | ------ |
| `PesterScope` | `All` | See [Test selection](#test-selection) |
| `ScriptAnalysisFailBuildOnSeverityLevel` | `Error` | `Analyze` fails on findings at or above `Error`, `Warning` or `Any`; `None` never fails |

### `Build/harness.psd1`

Optional, and only for a genuine difference that must also apply to local runs. A repo that needs none of these has no file. Copy [`templates/Build/harness.psd1`](../templates/Build/harness.psd1) and uncomment what you need:

| Key | Type | Default | Used by |
| --- | ---- | ------- | ------- |
| `PSScriptAnalyzerExcludeRules` | string array | none | AWSAutomation, whose `AWS.Tools.*` calls never take a `PSCredential` |
| `PesterExcludeTag` | string array | none | PS.SSL, whose `Network` tests call a live endpoint |
| `PesterStrictMode` | boolean | `$false` | PS.DCU, to run its tests under `Set-StrictMode -Version Latest` |

An unknown key, or a value of the wrong type, fails the build, so a misspelt setting cannot be silently ignored. Exclusions apply to both the build's `Analyze` task and the Security-tab scan. Prefer an inline `SuppressMessageAttribute` when a finding is confined to a few files, such as a test fixture, so the rule stays on for the rest of the module.

**Running excluded tests.** The harness always applies `PesterExcludeTag` and has no override. Run tagged tests with Pester directly from the repo root, for example PS.SSL's network tests:

```powershell
Invoke-Pester -Path ./Tests -TagFilter 'Network' -Output Detailed
```

This works when the test files import the module themselves, from `$env:BHPSModuleManifest` when set and otherwise the manifest at the repo root, as PS.SSL's do.

### Dependencies

The harness installs two kinds of module when run with `-ResolveDependency` ([ADR-0008](adr/0008-runtime-modules-float-build-tools-pinned.md)):

- **Build tools**, pinned in this repo's [`Build/depend.psd1`](../Build/depend.psd1): Pester, psake and PSScriptAnalyzer. You do not declare them.
- **Runtime modules**, read from your manifest's `RequiredModules`:

| Manifest entry | Installs |
| -------------- | -------- |
| `'Name'` | the latest release |
| `@{ ModuleName = 'Name'; ModuleVersion = 'x' }` | the latest release, which satisfies the minimum |
| `@{ ModuleName = 'Name'; RequiredVersion = 'x' }` | exactly `x` |
| `@{ ModuleName = 'Name'; MaximumVersion = 'x' }` | nothing: the build fails, naming the module |

Every build logs `Build tools: ...` and one `Resolved dependency: <name> <version>` line per module; with runtime modules floating, that line is the record of what a build ran against. A pin belongs in the manifest, where users' installs see it too.

## Running the build locally

Run the same commands CI runs, through your repo's `Build/build.ps1`:

```powershell
./Build/build.ps1 -ResolveDependency -TaskList Init
./Build/build.ps1 -TaskList CombineFunctionsAndStage, Analyze, Test
./Build/build.ps1 -TaskList Test -Properties @{ PesterScope = 'CrossPlatform' }
./Build/build.ps1 -TaskList Cleanup
```

`Build/build.ps1` is a **shim**, identical in every consumer, copied from [`templates/Build/build.ps1`](../templates/Build/build.ps1). Do not edit it. It:

1. reads the harness version from the `jjohns-dev/pwsh-module-ci/.github/workflows/ci.yml@<ref>` line in your `.github/workflows/ci.yml`, so local runs use the same harness as CI;
2. keeps a clone of this repo under your local application data folder, `pwsh-module-ci` (on macOS, `~/Library/Application Support/pwsh-module-ci`), fetches with `--tags --force`, and checks out `<ref>`;
3. calls the harness's `Build/build.ps1 -ProjectPath <your repo>` with every argument you passed, and exits with its exit code.

Things to know:

- **It needs `git` and PowerShell 7 on `PATH`, and network access.** A failed fetch stops the run rather than running a cached harness that may not match CI.
- **Pin a tag or a full commit SHA.** A branch pin such as `@main` resolves to a stale commit in the cache ([#73](https://github.com/jjohns-dev/pwsh-module-ci/issues/73), to be fixed in `v2.0.1`). CI is unaffected, since it never runs the shim.
- **The harness warns when your shim differs from the template.** The build still runs; replace your copy with the template's.
- **The cache is shared** by every repo on the machine, and switches commit when repos pin different versions.

**Without the shim.** Clone this repo and call the harness directly; check out the tag your `ci.yml` pins to match CI:

```powershell
& <path-to-pwsh-module-ci>/Build/build.ps1 -ProjectPath <path-to-your-module> -TaskList Test
```

## Migrating from `v1`

One PR per repo ([ADR-0007](adr/0007-replacing-what-runs-the-build-is-a-major.md)):

- Replace `Build/build.ps1` with the shim; delete `Build/build.psake.ps1`, `Build/depend.psd1` and `Build/PSScriptAnalyzerSettings.psd1`.
- Add `Build/harness.psd1` only if the repo needs one of its settings.
- Make sure every runtime module is in the manifest's `RequiredModules`; the deleted `depend.psd1` no longer supplies any.
- Repoint all three callers from `@v1` to `@v2`, drop `psscriptanalyzer-settings-path`, and give the release caller its `pull_request` dry-run trigger.
- Rename test files to lowercase with `git mv`.
- Update `AGENTS.md`, `CONTRIBUTING.md` and anything else that describes the old build.
- Confirm executed test counts per leg are unchanged, and the dry-run artifact matches the last release apart from changes you can name.
- Close any Dependabot PR that moves a caller to `@v2` on its own: it would run the harness with the old `Build/` still present.
