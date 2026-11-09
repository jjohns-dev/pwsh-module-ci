# Centralized build harness — design

- **Requirements:** [requirements.md](requirements.md), approved 2026-11-09
- **Status:** Draft — decisions in progress. Q1 decided; Q2–Q7 open. The approach, architecture, affected files and risks sections are written once the decisions are settled.

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
