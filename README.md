# pwsh-module-ci

Reusable GitHub Actions workflows shared by [johnsarie27](https://github.com/johnsarie27)'s
PowerShell module repos (PS.Log, PS.GHOps, PS.GitHub, PS.SSL, PS.DCU, AWSAutomation).
SecurityTools is not a consumer *yet*: it pairs each runner with a `PesterScope` psake
property and its own per-leg floor, which `os-matrix` now expresses through its object
form, so what remains is adopting it. Each module
repo's own `Build/build.ps1` (psake) already does the real
work — `Init`, `CombineFunctionsAndStage`, `Analyze`, `Test`, `CreateBuildArtifact` — these
workflows just standardize how that gets invoked in CI, and centralize the third-party
action pins (`actions/checkout`, `actions/upload-artifact`, `dorny/test-reporter`,
`github/codeql-action`, `softprops/action-gh-release`) so a version bump happens once here
instead of once per consumer repo.

## Workflows

| File | Purpose | Trigger in consumer |
| --- | --- | --- |
| `ci.yml` | Stage, analyze, and test the module across a runner matrix | `pull_request`, `push` to `main` |
| `release.yml` | Build the module artifact and cut a GitHub release | `push` of a `v*.*.*` tag |
| `pssa-sarif.yml` | PSScriptAnalyzer findings uploaded to the Security tab | `pull_request`, `push` to `main` |

## Usage

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
    uses: jjohns-dev/pwsh-module-ci/.github/workflows/ci.yml@v1
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
jobs:
  release:
    uses: jjohns-dev/pwsh-module-ci/.github/workflows/release.yml@v1
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
    uses: jjohns-dev/pwsh-module-ci/.github/workflows/pssa-sarif.yml@v1
    permissions:
      contents: read
      security-events: write
```

`os-matrix` (ci.yml) and `psscriptanalyzer-settings-path` (pssa-sarif.yml) are optional
`with:` inputs — omit them to use the defaults, which match most repos. `os-matrix` has a
second form for repos whose runners differ, covered under [Runner matrix](#runner-matrix).
`min-tests` (ci.yml) is covered under [Minimum test count](#minimum-test-count).

`artifact-name` (release.yml) sets the uploaded build artifact's display name — default
`'Artifacts'`. Set it to something like `'MyModule-${{ github.ref_name }}'` in the consumer
workflow to preserve a repo-specific naming convention.

## Runner matrix

`os-matrix` accepts **two forms**, and `ci.yml` normalises them into one before building its
matrix. Most repos never need the second.

**A JSON array of OS names.** The common case — every runner does the same thing.

```yaml
jobs:
  validate:
    uses: jjohns-dev/pwsh-module-ci/.github/workflows/ci.yml@v1
    with:
      os-matrix: '["ubuntu-latest", "windows-latest"]'
      min-tests: 91
    permissions:
      contents: read
      checks: write
```

The default is `'["ubuntu-latest", "windows-latest", "macos-latest"]'`.

**A JSON array of objects.** Use this when runners need *different* values — a different psake
property, a different floor, or both. Each object must carry `os`; `pesterScope` and `minTests`
are optional and apply only to that leg.

```yaml
jobs:
  validate:
    uses: jjohns-dev/pwsh-module-ci/.github/workflows/ci.yml@v1
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
| `pesterScope` | no | Passed to the `Test` task as `-Properties @{ PesterScope = ... }`. Omitted entirely when absent, so your psake default stands |
| `minTests` | no | This leg's floor. Overrides the workflow-wide `min-tests` for this leg only |

The two forms are interchangeable per call, not per entry — do not mix strings and objects in
the same array. Supplying an object without an `os` key fails the `normalize` job with a
message naming the offending entry, rather than producing a leg that silently does nothing.

Why one polymorphic input rather than a second `os-matrix-include` input: when a matrix
declares both `os:` and `include:`, an `os` leg that no `include` entry matches **still runs**,
carrying empty values. A caller who supplied the include list but forgot to narrow `os-matrix`
would get an extra leg whose empty `pesterScope` fell through to the psake default — green, and
wrong. Measured; see ADR-0006.

Expanding the input is done by a small `normalize` job that runs before `validate`. It adds one
check name, `<your job> / normalize matrix`, and leaves the existing
`<your job> / validate (<os>)` names unchanged — measured, so required-check rules do not need
editing when you adopt this.

## Pester result verification

`ci.yml` verifies the JUnit XML that the `Test` task writes, after the Pester step and
independently of the consumer's own psake gate. The run fails if no result file was
produced, if the root `<testsuites>` element reports `errors > 0`, or if it reports
`tests == 0`. `release.yml` carries the identical step.

This exists because a discovery or container error attaches to the *container* rather than
to a test, so a psake gate written as `if ($TestResults.FailedCount -gt 0)` leaves
`FailedCount` at `0` and the build passes having collected a fraction of its suite. The
counts must be read from the **root** `<testsuites>` element: the child `<testsuite>`
reports `errors="0"` for the same run, so a check written against the child parses cleanly
and silently never fires.

Consumers must therefore configure Pester with `TestResult.OutputFormat = 'JUnitXml'`.
`NUnitXml` is not supported — the verification step fails with an explicit message naming
the root element it found, and `dorny/test-reporter`'s `java-junit` reporter cannot parse
NUnit-format XML either. All six consumers already emit `JUnitXml`.

The verification step is the gate; the `dorny/test-reporter` step is display only and keeps
`fail-on-error: false` / `fail-on-empty: false`.

### Minimum test count

A suite can also shrink with `errors = 0`: a test-file glob that stops matching, a file moved
outside `Run.Path`, or a `-ForEach` data source that shrinks rather than empties. It can also
stop *running* without shrinking at all, when tests become skipped or tag-excluded. To catch
both, pass the optional `min-tests` input to `ci.yml`. The run then fails when a result file's
**executed** count — root `tests` minus `disabled` — is below it. The default, `0`, disables the
check. `release.yml` does not take the input: a release is cut from a commit that already
passed `ci.yml`, so the floor is set in one place.

```yaml
jobs:
  validate:
    uses: jjohns-dev/pwsh-module-ci/.github/workflows/ci.yml@v1
    with:
      min-tests: 430
    permissions:
      contents: read
      checks: write
```

`min-tests` is a floor, not an exact count, so adding tests never fails a run. Derive it from
the **executed** count, using the lowest across your runner OSes when they differ — Pester's
JUnitXml routes both skipped and tag-excluded tests to `disabled` while still counting them in
`tests`, so a repo that skips anything has an executed count below its collected one.
It catches a large drop rather than a single lost file, and it only stays useful if you raise
it as the suite grows.

When the lowest-across-OSes compromise costs too much — one leg running a fraction of the
suite, so a single floor is either far too low for the other leg or fails it outright — give
each leg its own `minTests` through the object form of `os-matrix`, described under
[Runner matrix](#runner-matrix). A leg that declares no `minTests` falls back to the
workflow-wide `min-tests`.

The floor is compared against each result file separately, so it assumes one `Test-*.xml`
per run, which is what every current consumer writes.

The root `tests` count includes tests excluded by `Filter.ExcludeTag`; Pester reports them in
the root `disabled` attribute without a `<testcase>` element. A floor therefore does not catch
a filter that starts excluding more of the suite.

## Versioning

Tagged with semver (`v1.0.0`, `v1.1.0`, ...). One floating tag, `v1`, tracks the latest
non-breaking release, and consumer repos pin to `@v1` for normal operation. A breaking change
to inputs or job structure bumps to `v2`, and consumers migrate on their own schedule — see
[ADR-0002](docs/adr/0002-breaking-means-the-call-not-the-build-outcome.md) for what counts as
breaking.

A release can turn a passing build red without being breaking, when the new failure reflects a
real defect that was always there. Those are rolled out by pinning each consumer to the
**immutable** `vX.Y.Z` tag, confirming it, and only then moving `v1` — after which every
staging pin is returned to `@v1`. There is deliberately no moving `vX.Y` tag: staging wants
the dependency frozen so the consumer's own change is the only variable, and a consumer left
pinned stops receiving the centralized action bumps this repo exists to deliver.
