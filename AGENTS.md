# AGENTS.md

Guidance for AI coding agents working in `pwsh-module-ci`.

## What this repo is

Reusable GitHub Actions workflows called by eight PowerShell module repos: PS.Log, PS.GHOps, PS.GitHub, PS.SSL, PS.DCU, AWSAutomation, SecurityTools, PS.YNAB. From `v2` it also hosts the **build harness** in `Build/` that runs every consumer's stage, analyze, test and package tasks, plus the consumer shim template in `templates/`. It contains no application code and no PowerShell module of its own.

SecurityTools is the only consumer of the object form of `os-matrix`: each leg carries its own `pesterScope` and `minTests`. It adopted `ci.yml` in #21 (SecurityTools#169); a change to how `ci.yml` handles either key must be checked against it.

## Blast radius — read before editing a workflow

Consumers pin to a moving major tag, `@v2`, so anything merged here and tagged reaches every consumer on that major with no review on their side. A mistake in `ci.yml` or in the harness breaks the whole fleet at once, and there is no staging environment. The workflows check the harness out at their own commit (`job.workflow_sha`), so a harness change ships exactly when the workflow tag moves.

Consequences for how you work:

- Never move a major tag as part of landing a change. Land the change, cut `vX.Y.Z`, and move the major tag only after consumers are confirmed.
- Treat a change that can flip a consumer's CI from green to red as a rollout, not a commit. Pin consumers to the immutable `@vX.Y.Z` first.
- Verify a behavior change in **both** directions: that it fires when it should *and* stays quiet when it should. A check that never fires looks identical to a check that passes.

## Layout

| Path | Contents |
| ---- | -------- |
| `.github/workflows/ci.yml` | Reusable: stage, analyze, test across an OS matrix |
| `.github/workflows/release.yml` | Reusable: build artifact, cut a GitHub release |
| `.github/workflows/pssa-sarif.yml` | Reusable: PSScriptAnalyzer findings to the Security tab |
| `.github/workflows/actionlint.yml` | This repo's own CI; lints the workflows above |
| `.github/workflows/self-test.yml` | This repo's own CI; runs `tests/` on ubuntu and windows |
| `.github/actionlint.yaml` | actionlint config; ignores only the `job.workflow_*` properties actionlint 1.7.12 does not know ([rhysd/actionlint#707](https://github.com/rhysd/actionlint/pull/707)) |
| `.github/release.yml` | Label categories for this repo's generated release notes; not a workflow |
| `Build/` | The harness: `build.ps1` entry point (`-ProjectPath`), `build.psake.ps1` tasks, `Harness.Functions.ps1`, pinned `depend.psd1`, shared `PSScriptAnalyzerSettings.psd1` |
| `templates/Build/` | The consumer shim `build.ps1`, byte-identical in every consumer, and the optional `harness.psd1` sample |
| `tests/` | Pester suites for the harness, the shim and the workflows' `run:` blocks, their fixtures, and the runner |
| `docs/adr/` | Architecture Decision Records, Nygard format |
| `docs/specs/` | Spec-driven work: requirements, design and tasks per feature |
| `docs/test-integrity.md` | Why a suite can be green and prove nothing: test-design decisions, vacuity traps, and the `min-tests` floor procedure. Permanent |
| `README.md` | Overview, workflows and versioning; links the consumer guide |
| `docs/consumer-guide.md` | Consumer-facing usage: callers, inputs, the harness's repo layout, `harness.psd1`, dependencies, local runs, migrating from `v1` |
| `ROLLOUT.md` | Index and running order for the in-flight cross-repo batch. Temporary; it disclaims its own authority — where it and an issue disagree, the issue wins. Deleted in its own PR when the batch ends |

The three reusable workflows are `on: workflow_call` only. `actionlint.yml` and `self-test.yml` are the only workflows that run on this repo's own pushes and PRs.

## Conventions

- **Pin every third-party action to a full commit SHA** with the version as a trailing comment: `uses: actions/checkout@3d3c42e...  # v7.0.1`. Centralizing these pins is the reason this repo exists (ADR-0001); a tag or branch ref defeats it.
- **`permissions:` is least-privilege and explicit**, at both workflow and job level. Add a trailing comment naming what needs the scope.
- **`shell: pwsh` for every `run:` block**, on every runner OS.
- **Start every multi-line `run:` with `$ErrorActionPreference = 'Stop'`.** A `run:` block does not inherit it.
- **Conventional commit subjects** — `feat(ci):`, `docs(adr):`, `ci:`. Reference the tracking issue in the body, not the subject.
- **Sign all commits.** Never disable signing to get a commit through.
- Do not add a `.github/copilot-instructions.md`; this file is loaded natively.
- **`templates/Build/build.ps1` is fleet-identical.** Any change to it is a change to every consumer's copy; the harness warns on drift but does not fail. Consumer test files are lowercase, `*.tests.ps1` and `*.tests.windows.ps1` (design Q4); the consumer-facing rules are in `docs/consumer-guide.md`.

## Versioning

Semver tags plus one moving tag per major. **`v2`** runs the shared harness, and every consumer is on it. **`v1` is retired and deleted** (2026-11-12): `v1.6.1` was its last release, no further `v1` releases will be made, and with no caller left the moving `v1` tag and the `release/v1` branch were deleted. Every `v1.x.y` tag and release remains. Replacing what runs a consumer's build is a major even when the call still works (ADR-0007), which is why the harness is `v2`.

`main` carries `v2`.

**Restoring `v1`** if a caller turns out to need it. Both pointed at `v1.6.1` (`b40b9c8`), which an immutable release and `protect-version-tags` lock, so they can be recreated exactly. `v1` has no release, so its name is not locked:

```pwsh
git fetch origin --tags --force
git rev-parse 'v1.6.1^{commit}'   # must be b40b9c849f62c609f969436583401593103a526a
git tag -a v1 -m 'v1 -> v1.6.1' 'v1.6.1^{commit}'
git push origin v1
git branch release/v1 'v1.6.1^{commit}'   # only if a v1 fix must be cut
git push origin release/v1
```

The rulesets still cover both names (`release/*` in `protect-main`, `v*` in `protect-release-tags`), so a restored ref is protected from its first push. Old clones keep a stale local `v1` until `git fetch --prune --prune-tags origin`.

Consumers normally pin the major tag; while staging a release that can change CI outcomes they pin the immutable `vX.Y.Z`, then repoint once the major tag has moved. There is deliberately no moving `vX.Y` tag, and a consumer left pinned stops receiving the centralized action bumps (ADR-0002).

"Breaking" otherwise means the consumer's **call** stops working, not its **build** stops passing (ADR-0002): removing an input any consumer passes, or renaming a job (which silently un-gates branch protection), is a new major; removing an input no consumer passes is a minor; turning a wrongly-green build red is not breaking. Verify which you have against the eight consumer repos and record it in the PR.

### Cutting a release

Nothing automates this; `release.yml` is for consumers and never runs here. Every tag is **annotated**; keep it that way.

```pwsh
git tag -a v2.3.0 -m 'v2.3.0' <commit>
git push origin v2.3.0
gh release create v2.3.0 --verify-tag --title 'v2.3.0' --notes-file <notes.md>
```

Every `vX.Y.Z` gets a GitHub release: it is where consumers read what changed, and what a Releases watch notifies on. List the PRs since the previous tag *on the same major*, by hand or with `--generate-notes --notes-start-tag <previous vX.Y.Z>`, which groups them by the labels in `.github/release.yml`; the default start tag is undocumented and may cross majors. A release on an older major takes `--latest=false`. Moving tags (`v2`) get no release.

Releases are immutable (repo setting, enabled 2026-11-10): a published release locks its tag, and deleting the release does not free the tag name. Notes, title and the latest flag stay editable.

Moving `v2` is a separate act, only after every consumer is confirmed:

```pwsh
git fetch origin --tags --force
git rev-parse 'v2.3.1^{commit}'   # confirm the target before moving
git tag -fa v2 -m 'v2 -> v2.3.1' 'v2.3.1^{commit}'
git push --force origin v2
git ls-remote origin 'refs/tags/v2^{}'   # must show the target commit
```

Two non-overlapping tag rulesets block updating and deleting tags (ADR-0003):

| Ruleset | Covers | Bypass |
| ------- | ------ | ------ |
| `protect-release-tags` | `v*` excluding `v*.*.*`: `v2`, and any future major tag | repository admin |
| `protect-version-tags` | `v*.*.*` | none, owner included |

So only an admin can move a major tag; anyone else gets `GH013: Cannot update this protected ref`. Never disable a ruleset or widen a bypass to get a push through. A `vX.Y.Z` cut on the wrong commit is never moved: cut the next patch, check no consumer pins the bad one, and never move the major tag onto it.

## Validating a change

`actionlint` checks workflow syntax, expression validity, and (via shellcheck) `run:` blocks — it does **not** execute anything.

`tests/` holds Pester suites for the harness and for the three `run:` blocks with real logic. The workflow suites extract the step body from the workflow YAML rather than copying it: `VerifyPesterResults.Tests.ps1` runs the `Verify Pester results` body against the fixtures in `tests/fixtures/` and asserts that `ci.yml` and `release.yml` carry it identically; `TestStep.Tests.ps1` runs `ci.yml`'s Test step against a stub `$RUNNER_TEMP/harness/Build/build.ps1` to prove an empty scope omits `-Properties` rather than passing it empty; `Normalize.Tests.ps1` runs the `normalize` job's step, including the single-entry `os-matrix` that `PS.Log` depends on. `WorkflowStep.Helpers.ps1` extracts a step body by name or id and runs it in a child `pwsh`. Extracting from the YAML is deliberate: the code under test is then the code that ships, by construction.

The harness suites: `Harness.Tests.ps1` covers `Harness.Functions.ps1` (project resolution, `harness.psd1` validation, dependency resolution, analyzer settings and the `.harness` exclusion); `HarnessTasks.Tests.ps1` runs real psake tasks in a child `pwsh` against fixture modules in `TestDrive:`; `Shim.Tests.ps1` runs the template shim against local git origins; `Workflows.Tests.ps1` checks the three workflows' structure (harness checkout at `job.workflow_sha` without credentials, moved to `$RUNNER_TEMP/harness` before any step uses it, no call to a consumer's shim, the dry-run gate).

Run it with `pwsh -File tests/Invoke-VerificationTest.ps1`. It needs `powershell-yaml` 0.4.12, Pester 6.2.0 and the harness's build tools, which `self-test.yml` installs at pinned versions; a failed import stops the run with a GitHub error annotation naming the module and the reason. `self-test.yml` runs it on ubuntu and windows as `verify Pester (<os>)`, and a summary job named `verify Pester result step` passes only when every leg did. That summary name is the **required check** on `main` and `release/*`.

Every case asserts a **direction** — some must make the step fail and some must leave it quiet — because a check that never fires is indistinguishable from one that passes. When you add a case, add its opposite too.

Neither gate covers a step's `if:` condition — that is orchestration, not script logic, and needs a real run on a branch with an earlier step deliberately failing.

Nor do they cover a step's `env:` block. The suites set `MIN_TESTS`, `PESTER_SCOPE` and `OS_MATRIX` themselves and run only the `run:` body, so whether a workflow input actually reaches a step is proven only by a consumer run that sets the input.

The workflow pins actionlint `1.7.12` with a SHA256 check. Match that version locally rather than installing latest.

## Gotchas that have bitten here

- **`#Requires -Modules` silently discards a script's exit code under `pwsh -File`**: `exit 1` exits `0`, so a gate invoking it is permanently green. `#Requires -Version` and `pwsh -Command "& ./script.ps1"` are unaffected. `tests/Invoke-VerificationTest.ps1` uses `Import-Module` for this reason; do not "correct" it to `#Requires`. Verified on PowerShell 7.6.6.
- **Under `shell: pwsh`, a step exits with whatever `$LASTEXITCODE` holds**, because GitHub runs `pwsh -command ". '<file>'"`. A stale non-zero from an earlier native call fails a step that succeeded, in CI but not under local `pwsh -File`. End any script that shells out with `exit 0`.
- **A tag pattern that matches a major tag freezes it along with the version tags**; that is why the two rulesets above must not overlap (ADR-0003). If you change either include or exclude, check every tag still matches exactly one. `/rules/tags/{tag}` returns 404, so test the patterns against `git tag --list` with fnmatch.
- **An annotated tag's ref SHA is not its commit SHA.** `git rev-parse v2` and the refs API return the tag object; use `git rev-parse 'v2^{commit}'` for the commit, and check which one a SHA in prose is before "fixing" it.
- **Re-running a consumer's run picks up a moved major tag, and `referenced_workflows` records the tag object.** After `v2` moved from `b7be996` to `19862a3`, `gh run rerun` on PS.DCU's runs ran the new harness: attempt 1 recorded the old tag object `85fa20d`, attempt 2 the new one `9cd60b5` (2026-11-12). So no new commit is needed to re-verify a consumer after a tag move. To confirm which harness a run used, compare `referenced_workflows[].sha` with `git rev-parse v2`, not `v2^{commit}`; a SHA pin records the commit itself.
- **A moved major tag makes `git pull` fail outright**, branch included (hit when `v1` moved): fetch refuses to overwrite the stale local tag (`would clobber existing tag`), and the error names only the tag. One-off fix: `git fetch --tags --force origin`. Permanent: `git config --add remote.origin.fetch '+refs/tags/*:refs/tags/*'`, which lives in `.git/config` and so is needed once per clone.

- **YAML block scalars cannot carry a PowerShell here-string.** A here-string's closing delimiter (`'@`) must sit at column 0, which terminates the block scalar. Build multi-line strings with an array and `-join` instead.
- **PowerShell's XML adapter surfaces attributes as properties**, so on `<testsuites name="Pester">` the expression `$root.Name` returns `Pester`, not `testsuites`. Use `.LocalName` for element names and `GetAttribute()` for attributes whenever an attribute could shadow a real member.
- **A step that never started still reports `outcome` as `'skipped'`**, despite the docs reading as though it would be absent and compare as `''`. Measured on a run where an earlier step failed, so `!= 'skipped'` and `== 'success' || == 'failure'` are equivalent there. Do not rewrite one into the other; probe with a step that echoes the value.
- **`always()` is not available inside a step's `env:` block** — only `hashFiles` is. It fails the whole run at workflow resolution with zero jobs, which `gh run rerun` refuses to retry; re-trigger with a new commit.
- **`[int]''` is `0` but `[int]'abc'` throws.** When reading a numeric XML attribute that might be absent *or* malformed, `[int]($x -as [int])` yields `0` for both. Do not "simplify" it to a bare cast.
- **Pester container and discovery errors do not increment `FailedCount`.** They land in the root `<testsuites>` `errors` attribute, so a gate reading `FailedCount` misses them. The harness gates on `$TestResults.Result -ne 'Passed'`, which catches them; `ci.yml`'s verify step still checks independently, and adds the `min-tests` floor and the missing-result-file check.
- **Pester's JUnitXml routes skipped and tag-excluded tests to `disabled`, never `skipped`, and still counts them in `tests`.** Measured on Pester 6.2.0: `-Skip`, `Set-ItResult -Skipped` and `Filter.ExcludeTag` all land in `disabled`, so `tests - disabled` is the executed count. The `min-tests` floor gates on executed since `v1.5.0` (#23); a consumer pinned to an older tag still measures `tests`, so check its pin before assuming the floor measures what ran.

- **These repos use rulesets, not classic branch protection.** `GET /branches/main/protection` returns 404 fleet-wide. In the module repos the ruleset is `protect` (id `18439023` in `PS.GitHub`): required checks plus `required_signatures`, `required_linear_history`, `non_fast_forward`, `deletion` and `pull_request`. A change that renames a required check needs the **ruleset** edited, or the PR can never merge.
- **Updating a ruleset is `PUT`, not `PATCH`, and a failed `gh` call does not throw.** `PATCH` returns 404, and a script can report success while nothing changed. Read the ruleset back and compare before and after.
- **A job matrix renames its required check.** Adding `strategy.matrix` turned `verify Pester result step` into `verify Pester result step (<os>)`, so a ruleset requiring the plain name never sees it report. `self-test.yml` keeps the name with a summary job over the legs rather than editing `protect-main`, which also covers `release/*`, whose self-test has no matrix.
- **On Windows, git fixture repos in `TestDrive:` break Pester's cleanup.** git writes object files read-only, so the container fails after every test passed. Remove them with `Remove-Item -Force` in `AfterAll`, as `Shim.Tests.ps1` does.
- **A parameter typed `[System.Management.Automation.PSCustomObject]` rejects `[PSCustomObject] @{}`.** The value's runtime type is `PSObject`, so type such parameters `[System.Management.Automation.PSObject]`.
- **A mutation run interrupted mid-way leaves a mutant in the tree.** A second command sent to a terminal running a long job interrupted one during phase B. Run mutations from a script that restores the original bytes in a `finally`, and check every mutated file is restored before trusting the tree.
- **`Invoke-ScriptAnalyzer -Recurse` descends into dot-folders**, so analysing a checkout root also reports `.harness/` and `.git/`. `Invoke-HarnessAnalysis` analyses each top-level item except those two instead. Measured 2026-11-10.
- **On Windows a dot-folder is an ordinary folder.** On Linux and macOS, `Get-ChildItem -Recurse` skips dot-folders unless `-Force` is passed; on Windows it does not. A harness left in `.harness/` was therefore tested by consumer tests that walk the repo, on Windows legs only, so the workflows move it to `$RUNNER_TEMP/harness` ([#77](https://github.com/jjohns-dev/pwsh-module-ci/issues/77)). `actions/checkout` accepts only a `path` under the workspace, so the move is its own step.
- **actionlint 1.7.12 rejects `job.workflow_repository` and `job.workflow_sha`**, though GitHub documents both. `.github/actionlint.yaml` ignores exactly those two names, so a typo such as `job.workflow_shaa` is still reported. Remove the config once a release includes [rhysd/actionlint#707](https://github.com/rhysd/actionlint/pull/707).
- **The shim resolves a branch pin to a stale commit.** `git checkout --detach main` in the cache picks the local `main` that `git fetch` never advances. Tags and SHAs are unaffected. Tracked as [#73](https://github.com/jjohns-dev/pwsh-module-ci/issues/73).
