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
      id-token: write
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
`with:` inputs — omit them to use the defaults every current repo already matches.

## Versioning

Tagged with semver (`v1.0.0`, `v1.1.0`, ...); a floating `v1` tag tracks the latest
non-breaking release. Consumer repos should pin to `@v1` so action-version bumps and fixes
land automatically; a breaking change to inputs or job structure bumps to `v2`, and
consumers migrate on their own schedule.
