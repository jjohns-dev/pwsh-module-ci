# Centralized build harness — design

- **Requirements:** [requirements.md](requirements.md), approved 2026-11-09
- **Status:** Draft — decisions in progress. Q1–Q3 decided; Q4–Q7 open. The approach, architecture, affected files and risks sections are written once the decisions are settled.

## Decisions

### Q1 — Local builds: a per-repo shim (decided 2026-11-09)

#### Decision

- Each consumer keeps one file, `Build/build.ps1`, **byte-identical across the fleet**. It is a shim, not a harness: it locates the harness version the repo's CI uses, makes it available locally, and hands off.
- The shim reads the version from the repo's own caller, the `jjohns-dev/pwsh-module-ci/.github/workflows/ci.yml@<ref>` line in `.github/workflows/ci.yml`. Local runs therefore use the same harness version as CI, with no second pin to maintain.
- It keeps a clone of this repo in a per-user cache, fetches with `--tags --force`, checks out `<ref>`, and calls the harness's `Build/build.ps1 -ProjectPath <module root> @args`.
- It declares no parameters. Everything is forwarded with `@args`, so a new harness task or parameter never changes the shim.
- **CI never runs the shim.** `ci.yml` checks out the harness itself (`job.workflow_sha`), so a broken shim can break a local run but cannot affect a CI result.
- Genuine per-repo settings live beside the shim in an optional `Build/harness.psd1`; what goes in it is decided under Q2 onward.

#### Why

- The consumers' own `AGENTS.md` files tell agents to run `./Build/build.ps1 -TaskList Analyze` / `Test` / `Cleanup` locally (PS.Log, AWSAutomation, SecurityTools; measured 2026-11-09), as does AWSAutomation's `Get-IAMReport.tests.ps1`. The shim keeps that command working unchanged.
- Agents will not check out a matching harness version by hand. Reading the version from the caller gives local–CI parity by construction rather than by discipline.
- Drift is small and detectable. The shim changes only if the repo URL, cache location, version pattern or git commands change; because it is identical everywhere, a byte comparison detects any drift. `build.ps1` had 5 variants when measured on 2026-10-26.

#### Evidence: spike, 2026-11-09, 14 of 14 cases

Run locally in a scratch directory: a bare repo stood in for GitHub, a stub harness recorded what it received, and PS.Log's real `ci.yml` was used for version reading.

- `-TaskList Analyze, Test` arrived as `String[]`, `-Properties @{ PesterScope = 'All' }` as a hashtable, `-ResolveDependency` as a switch, and a positional `Cleanup` bound to `TaskList`. An invalid task was still rejected by the harness's `ValidateSet`.
- The project path resolved to the module root, including when the shim was called by path from another directory.
- Exit codes propagated: 3 in-session, 5 through a child `pwsh`.
- Version reading handled `@v1`, an immutable `@v1.0.0`, and a full SHA with a trailing `# v1.0.0` comment. An unknown ref threw, naming the ref; a missing reference threw.
- After an annotated `v1` was moved to a new commit, the shim ran the new harness.

Not covered by the spike: a real clone from GitHub, a real build through the shim, Windows, and a non-zero exit through `pwsh -File` (a hashtable cannot be passed on that command line).

#### Known traps — the implementation must handle these

- **A failed fetch silently runs a stale harness.** Measured in the spike: with `--force` removed, a moved `v1` was not picked up and the shim ran the old harness with exit 0, no error and no warning. The likely cause, not confirmed, is that the fetch exits non-zero and the shim never checks it. Any fetch failure, including no network, would behave the same way. The shim must check the fetch result and must carry a code comment stating this finding, so that anyone writing a new version of the shim sees it. Whether it then stops or warns and continues from the cached copy is still to be decided.
- **CRLF checkouts break a byte comparison.** With `core.autocrlf=true`, the Windows default, a Windows checkout stores the shim with CRLF, and a hash against the reference copy reports drift that is not there. Either normalise line endings before comparing, or pin the shim to LF with `.gitattributes` (`Build/build.ps1 text eol=lf`). Inferred, not measured; the Windows tests below will show which.
- **One shared cache.** If two module repos pin different versions, the cache switches between them on each run. Acceptable for serial use; a cache per ref avoids it if it becomes a problem.

#### Verification

- A Pester suite in `tests/` runs the shim against a fixture module and a local origin, covering every case above in both directions. Include the fetch-failure case, which must fail or warn as decided, and never pass silently.
- `self-test.yml` runs the suites on `ubuntu-latest` **and** `windows-latest`, so Windows behaviour, including the CRLF case, is tested on every change.

#### Accepted without mitigation

- `git` on `PATH`, `pwsh` 7+ rather than Windows PowerShell 5.1, and path separators. These are the user's or agent's responsibility, and the shim does not guard against them.

#### Fallback, kept open: run the harness from a clone of this repo

- No per-repo file. A developer or agent runs `& <path-to-pwsh-module-ci>/Build/build.ps1 -ProjectPath <module> -TaskList Test`, with `-ProjectPath` defaulting to the current directory.
- Costs: AGENTS.md, CONTRIBUTING.md, AWSAutomation's test-file comment and PS.DCU's dev container `postCreateCommand` all change in each repo; matching CI's version means checking out the right tag by hand.
- **Switching is cheap by design.** Criterion 2 already makes `-ProjectPath` an explicit harness input, so both options call the same harness the same way. Switching replaces the shim and changes no harness code.
- **Revisit if:**
  - the shim has to change often enough that keeping it identical becomes a burden;
  - fetching or caching proves unreliable for people or agents;
  - a platform problem appears that the shim cannot handle and the fallback avoids.

### Q2 — Runtime dependencies: read from the manifest, float unless declared (decided 2026-11-09)

#### Decision

- **Names** come from the module manifest's `RequiredModules`, the list PowerShell already enforces at import. The runtime entries in each repo's `depend.psd1` are not carried forward.
- **Versions float by default.** A module the manifest lists without a version is installed at the latest release, by calling `Install-PSResource` with no `-Version`.
- **A specific version is supported, but only when the manifest declares it.** Pinning is a property of the module, so it lives where users' installs see it:

  ```powershell
  RequiredModules = @(
      'AWS.Tools.Common'                                           # floats
      @{ ModuleName = 'ImportExcel'; RequiredVersion = '7.8.10' }  # exact pin, only when declared
  )
  ```

  | Manifest entry | Harness installs |
  | -------------- | ---------------- |
  | `'Name'` | latest |
  | `@{ ModuleName; ModuleVersion }`, a minimum | latest, which satisfies the minimum |
  | `@{ ModuleName; RequiredVersion }` | exactly that version |
  | `@{ ModuleName; MaximumVersion }` | fails with a message naming the module, until a repo needs it |

- **Every build logs each resolved version**, as `Resolved dependency: <name> <version>`. With nothing pinned, that line is the only record of what a build ran against. AWSAutomation and PS.DCU already do this; it is one of the eight stranded fixes from #20 and becomes required here.
- **Build tools stay pinned**, centrally in the harness: Pester, psake and PSScriptAnalyzer. They change test and analysis outcomes, so a new release could turn a build red with no change in the repo. Bumping them stays deliberate; which PSScriptAnalyzer version is Q6.
- **`Build/harness.psd1` does not carry dependencies.** It holds only settings that change what the build does and have no other home.

#### Why

- Floating keeps every module off stale releases, including ones carrying known bugs or vulnerabilities. SecurityTools' `ImportExcel = '7.8.10'` was the latest release when written, not a deliberate pin.
- The manifest is what users get. A pin held only in a harness setting would make CI test against one version while users install whatever the manifest allows.
- One list, not two. Today the names in `depend.psd1` and the manifest are kept in step by hand.
- Omitting `-Version` is the only reliable way to get the latest: a NuGet range resolves to an arbitrary member under PSResourceGet 1.2.0 (`docs/dependency-stack.md`). This is also why `MaximumVersion` fails rather than being guessed.

#### Evidence: measured 2026-11-09 against each repo's `main`

| Repo | Runtime entries in `depend.psd1` | Manifest `RequiredModules` |
| ---- | -------------------------------- | -------------------------- |
| PS.Log, PS.GHOps, PS.GitHub, PS.SSL, PS.DCU | none | none; commented out in PS.Log, PS.SSL and PS.DCU |
| AWSAutomation | 15, all `latest`: `ImportExcel` and 14 `AWS.Tools.*` | the same 15 names, unversioned |
| SecurityTools | `ImportExcel = '7.8.10'` | `ImportExcel`, unversioned |

The names match exactly in both repos that have any, so reading them from the manifest installs the same set. No manifest declares a version today.

#### Consequences

- SecurityTools' CI moves from `ImportExcel` `7.8.10` to the current release. Its executed counts are checked against the baseline like every other change (criterion 5).
- Adding a dependency to a manifest is enough for CI and local builds to install it. Forgetting to add it to a second list is no longer possible.
- A floated release can still break a build overnight. That is the accepted trade, and the resolved-version log is what diagnoses it.

#### Verification

- Pester cases for each manifest form in the table, including the `MaximumVersion` failure, a manifest with no `RequiredModules`, and one with the key commented out.
- A case proving an unversioned entry is installed without `-Version`, and one proving the resolved-version line is emitted for every module.

### Q3 — Workflow scope: all three move together (decided 2026-11-09)

#### Decision

- **One harness release covers `ci.yml`, `release.yml` and `pssa-sarif.yml`**, behind the opt-in chosen under Q5. Work in this repo can land in steps, but nothing reaches a consumer until all three are ready.
- **Each consumer switches all three callers in one PR**, and in the same PR deletes `Build/` except the shim and any `Build/harness.psd1`.
- **`pssa-sarif.yml` uses the harness's analyzer settings**, the central settings file plus the repo's `ExcludeRules` from `harness.psd1`, so the Security tab and the build gate apply the same rules.
- **`release.yml` gains a dry-run mode** that builds and uploads the artifact but skips publishing the release. Each consumer's migration PR exercises it, and compares the artifact's contents with its last real release, before merging.

#### Why

What each workflow takes from the consumer's `Build/` today, read from the workflow files on 2026-11-09:

| Workflow | Uses |
| -------- | ---- |
| `ci.yml` | `./Build/build.ps1` for `Init`, `CombineFunctionsAndStage`, `Analyze`, `Test` |
| `release.yml` | the same four, plus `CreateBuildArtifact` |
| `pssa-sarif.yml` | `./Build/PSScriptAnalyzerSettings.psd1`, the default of its settings-path input |

Moving `ci.yml` alone does not work for any consumer:

- Once a consumer adopts the shim, its `Build/build.ps1` *is* the shim, so an unmigrated `release.yml` would run the shim in CI. That breaks Q1's guarantee that CI never runs the shim, and the shim would fetch the harness version pinned in `ci.yml` rather than in `release.yml`, which can differ while a consumer is staged on an immutable pin.
- `build.psake.ps1`, `depend.psd1` and the settings file could not be deleted while `release.yml` still used them.
- `pssa-sarif.yml` would fail once the settings file was deleted.

The dry run exists because the release path is almost never exercised. `release.yml` runs only on a consumer's version-tag push, which is why the `action-gh-release` bump in `v1.6.1` is still unconfirmed. Without it, a harness change to `CreateBuildArtifact`, including the `PS.DCU` dependency question in criterion 8, would first run on someone's real release.

#### Consequences

- A consumer's migration PR touches three caller files and deletes up to three `Build/` files. It is larger than a one-workflow change, but it leaves the repo in one consistent state, never half-migrated.
- `pssa-sarif.yml` needs the harness checkout, as `ci.yml` and `release.yml` do.
- The Security tab still analyses the whole repo, while the build gate analyses `Staging/`. That difference is pre-existing and out of scope; this decision only stops the *rules* from differing too.

#### Verification

- Each consumer's migration PR shows all three workflows green on the harness, plus a dry-run release whose artifact matches its last real release, file for file.
