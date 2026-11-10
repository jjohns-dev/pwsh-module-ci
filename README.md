# pwsh-module-ci

Reusable GitHub Actions workflows and the shared build harness for [johnsarie27](https://github.com/johnsarie27)'s PowerShell module repos: PS.Log, PS.GHOps, PS.GitHub, PS.SSL, PS.DCU, AWSAutomation and SecurityTools.

From `v2`, every consumer's build runs from the harness in [`Build/`](Build): staging, PSScriptAnalyzer, Pester and packaging, with the build tools pinned once here. Each consumer keeps only its caller workflows, an identical `Build/build.ps1` shim for local runs, and an optional `Build/harness.psd1` for the few settings that genuinely differ. The workflows also centralize the third-party action pins (`actions/checkout`, `actions/upload-artifact`, `dorny/test-reporter`, `github/codeql-action`, `softprops/action-gh-release`), so a version bump happens once here instead of once per consumer repo.

**Using these workflows:** see the [consumer guide](docs/consumer-guide.md) — callers, inputs, the runner matrix, result verification and the `min-tests` floor, the harness's expectations of your repo, `harness.psd1`, dependencies, local runs, and migrating from `v1`.

## Workflows

| File | Purpose | Trigger in consumer |
| --- | --- | --- |
| `ci.yml` | Stage, analyze, and test the module across a runner matrix | `pull_request`, `push` to `main` |
| `release.yml` | Build the module artifact and cut a GitHub release; on a pull request, a dry run that skips publishing | `push` of a `v*.*.*` tag, `pull_request` |
| `pssa-sarif.yml` | PSScriptAnalyzer findings uploaded to the Security tab | `pull_request`, `push` to `main` |

## Versioning

Tagged with semver (`v2.0.0`, `v2.1.0`, ...). Each major has one moving tag tracking its latest release, and consumer repos pin to it for normal operation. What counts as breaking is in [ADR-0002](docs/adr/0002-breaking-means-the-call-not-the-build-outcome.md), as amended by [ADR-0007](docs/adr/0007-replacing-what-runs-the-build-is-a-major.md): a change that replaces what runs a consumer's build is a major even when its call still works, which is why the shared harness is `v2`.

Two majors are live while the fleet migrates:

- **`v2`** runs the shared harness. A consumer moves to it in one PR that repoints all three callers from `@v1`.
- **`v1`** stays on `v1.6.x` and runs each consumer's own vendored `Build/`. It receives urgent fixes only, cut from a branch off `v1.6.1`, and is retired once the last consumer has moved.

A release can turn a passing build red without being breaking, when the new failure reflects a real defect that was always there. Those are rolled out by pinning each consumer to the **immutable** `vX.Y.Z` tag, confirming it, and only then moving the major tag — after which every staging pin is returned to the major tag. There is deliberately no moving `vX.Y` tag: staging wants the dependency frozen so the consumer's own change is the only variable, and a consumer left pinned stops receiving the centralized action bumps this repo exists to deliver.
