# pwsh-module-ci

Reusable GitHub Actions workflows shared by [johnsarie27](https://github.com/johnsarie27)'s
PowerShell module repos (PS.Log, PS.GHOps, PS.GitHub, PS.SSL, PS.DCU, AWSAutomation,
SecurityTools). Each module repo's own `Build/build.ps1` (psake) already does the real
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
`with:` inputs — omit them to use the defaults, which match most repos.

## Pester result verification

`ci.yml` verifies the JUnit XML that the `Test` task writes, after the Pester step and
independently of the consumer's own psake gate. The run fails if no result file was
produced, if the root `<testsuites>` element reports `errors > 0`, or if it reports
`tests == 0`.

This exists because a discovery or container error attaches to the *container* rather than
to a test, so a psake gate written as `if ($TestResults.FailedCount -gt 0)` leaves
`FailedCount` at `0` and the build passes having collected a fraction of its suite. The
counts must be read from the **root** `<testsuites>` element: the child `<testsuite>`
reports `errors="0"` for the same run, so a check written against the child parses cleanly
and silently never fires.

Consumers must therefore configure Pester with `TestResult.OutputFormat = 'JUnitXml'`.
`NUnitXml` is not supported — the verification step fails with an explicit message naming
the root element it found, and `dorny/test-reporter`'s `java-junit` reporter cannot parse
NUnit-format XML either. All seven consumers already emit `JUnitXml`.

The verification step is the gate; the `dorny/test-reporter` step is display only and keeps
`fail-on-error: false` / `fail-on-empty: false`.

`artifact-name` (release.yml) sets the uploaded build artifact's display name — default
`'Artifacts'`. Set it to something like `'MyModule-${{ github.ref_name }}'` in the consumer
workflow to preserve a repo-specific naming convention.

## Versioning

Tagged with semver (`v1.0.0`, `v1.1.0`, ...). Two floating tags track releases: `v1` for the
latest non-breaking release, and a per-minor `v1.3` that picks up patch fixes within that
minor without taking the next minor's behavior change. Consumer repos pin to `@v1` for
normal operation, and to a `@v1.<minor>` when staging a change that alters CI outcomes.
A breaking change to inputs or job structure bumps to `v2`, and consumers migrate on their
own schedule.
