# AGENTS.md

Guidance for AI coding agents working in `pwsh-module-ci`.

## What this repo is

Reusable GitHub Actions workflows called by six PowerShell module repos: PS.Log, PS.GHOps, PS.GitHub, PS.SSL, PS.DCU, AWSAutomation. It contains no application code and no PowerShell module — only workflow definitions, their pinned action versions, and the docs describing both.

SecurityTools is **not** a consumer. It pairs each runner with a `PesterScope` psake property via `matrix.include`, which the flat `os-matrix` input cannot express. Do not add it to consumer lists.

## Blast radius — read before editing a workflow

Consumers pin to the moving `@v1` tag, so anything merged here and tagged reaches every consumer's CI with no review on their side. A mistake in `ci.yml` breaks the whole fleet at once, and there is no staging environment.

Consequences for how you work:

- Never move the `v1` tag as part of landing a change. Land the change, cut `vX.Y.Z` plus the moving `vX.Y`, and move `v1` only after consumers are confirmed.
- Treat a change that can flip a consumer's CI from green to red as a rollout, not a commit. Pin one consumer to `@vX.Y` first.
- Verify a behavior change in **both** directions: that it fires when it should *and* stays quiet when it should. A check that never fires looks identical to a check that passes.

## Layout

| Path | Contents |
| ---- | -------- |
| `.github/workflows/ci.yml` | Reusable: stage, analyze, test across an OS matrix |
| `.github/workflows/release.yml` | Reusable: build artifact, cut a GitHub release |
| `.github/workflows/pssa-sarif.yml` | Reusable: PSScriptAnalyzer findings to the Security tab |
| `.github/workflows/actionlint.yml` | This repo's own CI; lints the workflows above |
| `.github/workflows/self-test.yml` | This repo's own CI; exercises the shipped verification step |
| `tests/` | Fixtures and the harness that runs them |
| `docs/adr/` | Architecture Decision Records, Nygard format |
| `README.md` | Consumer-facing usage and inputs |

The three reusable workflows are `on: workflow_call` only. `actionlint.yml` and `self-test.yml` are the only workflows that run on this repo's own pushes and PRs.

## Conventions

- **Pin every third-party action to a full commit SHA** with the version as a trailing comment: `uses: actions/checkout@3d3c42e...  # v7.0.1`. Centralizing these pins is the reason this repo exists (ADR-0001); a tag or branch ref defeats it.
- **`permissions:` is least-privilege and explicit**, at both workflow and job level. Add a trailing comment naming what needs the scope.
- **`shell: pwsh` for every `run:` block**, on every runner OS.
- **Start every multi-line `run:` with `$ErrorActionPreference = 'Stop'`.** A `run:` block does not inherit it.
- **Conventional commit subjects** — `feat(ci):`, `docs(adr):`, `ci:`. Reference the tracking issue in the body, not the subject.
- **Sign all commits.** Never disable signing to get a commit through.
- Do not add a `.github/copilot-instructions.md`; this file is loaded natively.

## Versioning

Semver tags plus one moving tag, `v1`, tracking the latest non-breaking release. Consumers normally pin `@v1`. While staging a release that can change CI outcomes they pin the **immutable** `vX.Y.Z` instead, so the dependency is frozen while they migrate, then repoint to `@v1` once `v1` has moved. There is deliberately no moving `vX.Y` tag — a staging pin that moves underneath an in-flight migration defeats the point of staging. Leaving a consumer pinned is debt: it stops receiving the centralized action bumps this repo exists to deliver.

"Breaking" means the consumer's **call** stops working, not its **build** stops passing — see ADR-0002. Removing an input no consumer passes is a minor; removing one any consumer passes, or renaming a job (which silently un-gates branch protection), is a `v2`. A change that turns a wrongly-green build red is not breaking, and is staged through an immutable `vX.Y.Z` pin instead. Verify which you have by checking the six consumer repos, and record the result in the PR.

### Cutting a release

Nothing automates this. `release.yml` is a reusable workflow *for consumers*; it never runs here, and there is no tagging pipeline in this repo.

Every existing tag is **annotated**, including `v1`. Keep it that way — the ref-SHA gotcha below assumes it.

```pwsh
git tag -a v1.3.0 -m 'v1.3.0' <commit>
git push origin v1.3.0
```

Moving `v1` is a separate, deliberate act performed only after every consumer is confirmed, never bundled with cutting the release:

```pwsh
git tag -fa v1 -m 'v1 -> v1.3.0' 'v1.3.0^{commit}'
git push --force origin v1
```

## Validating a change

`actionlint` checks workflow syntax, expression validity, and (via shellcheck) `run:` blocks — it does **not** execute anything.

`tests/Invoke-VerificationTest.ps1` covers the one `run:` block with real logic. It parses `ci.yml` and `release.yml`, pulls out the `Verify Pester results` step body, asserts the two have not drifted, then runs that body against the fixtures in `tests/fixtures/`. Extracting from the YAML rather than committing a copy is deliberate: the code under test is then the code that ships, by construction.

Run it with `pwsh -File tests/Invoke-VerificationTest.ps1`. It needs `powershell-yaml`, which `self-test.yml` installs at a pinned version.

Every fixture asserts a **direction**. Half must make the step fail and half must leave it quiet, because a check that never fires is indistinguishable from one that passes. When you add a case, add it to whichever half is thinner.

Neither gate covers a step's `if:` condition — that is orchestration, not script logic, and needs a real run on a branch with an earlier step deliberately failing.

The workflow pins actionlint `1.7.12` with a SHA256 check. Match that version locally rather than installing latest.

## Gotchas that have bitten here

- **`#Requires -Modules` silently discards a script's exit code under `pwsh -File`.** A script that calls `exit 1` exits `0`, so a CI gate invoking it is permanently green. `#Requires -Version` is unaffected, and `pwsh -Command "& ./script.ps1"` propagates correctly. `tests/Invoke-VerificationTest.ps1` therefore uses `Import-Module` and says so in its `.NOTES`; do not "correct" it back to the house `#Requires` convention. Verified on PowerShell 7.6.6.
- **Under `shell: pwsh`, a step exits with whatever `$LASTEXITCODE` holds.** GitHub invokes the script as `pwsh -command ". '<file>'"`, so a stale non-zero `$LASTEXITCODE` left by any earlier native call fails the step even when the script itself succeeded. `pwsh -File` does not behave this way, so it passes locally and fails in CI. End any script that shells out with an explicit `exit 0`.
- **An annotated tag's ref SHA is not its commit SHA.** `git rev-parse v1` and the GitHub refs API both return the tag *object*; `git log` quietly dereferences to the commit. Use `git rev-parse 'v1^{commit}'` when you mean the commit, and do not "fix" a tag SHA in prose without checking which one it is.

- **YAML block scalars cannot carry a PowerShell here-string.** A here-string's closing delimiter (`'@`) must sit at column 0, which terminates the block scalar. Build multi-line strings with an array and `-join` instead.
- **PowerShell's XML adapter surfaces attributes as properties**, so on `<testsuites name="Pester">` the expression `$root.Name` returns `Pester`, not `testsuites`. Use `.LocalName` for element names and `GetAttribute()` for attributes whenever an attribute could shadow a real member.
- **A step that never started still reports `outcome` as `'skipped'`.** The docs describe the `steps` context as holding steps that "have already run", and say a nonexistent property evaluates to `''` — which reads as though a never-started step would be absent and compare as empty. It is not. Measured on a real run where an earlier step failed: both `outcome` and `conclusion` were `skipped`, so `!= 'skipped'` and `== 'success' || == 'failure'` are equivalent there. Do not rewrite one into the other believing the first is broken; probe it with a step that echoes the value.
- **`always()` is not available inside a step's `env:` block** — only `hashFiles` is. Putting it there fails the whole run at workflow resolution with zero jobs, which `gh run rerun` then refuses to retry; re-trigger with a new commit instead. The context-availability table in the Actions docs lists what each key accepts.
- **`[int]''` is `0` but `[int]'abc'` throws.** When reading a numeric XML attribute that might be absent *or* malformed, `[int]($x -as [int])` yields `0` for both. Do not "simplify" it to a bare cast.
- **Pester container and discovery errors do not increment `FailedCount`.** They attach to the container, land in the root `<testsuites>` `errors` attribute, and are invisible to a psake gate — this is the entire reason `ci.yml` verifies results independently.
