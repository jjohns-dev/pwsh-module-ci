# Dependency stack

The designed set of build and test dependencies for the module repos, and why each one is in it.

**This is the single place the stack is defined.** Repos should inherit it rather than each declaring their own — that is the point of [#20](https://github.com/jjohns-dev/pwsh-module-ci/issues/20). Until #20 lands, every repo carries its own `Build/depend.psd1` and the fleet drifts; the drift recorded below is a symptom of that, not a list of repos to go and fix by hand.

Unlike `shared-ci-standards.md`, this file is **not** interim. It outlives #20, because the question "what do we depend on and why" does not go away once the files stop being copy-pasted.

## The stack

| Tool | Role | Pin | Why it is in the set |
| ---- | ---- | --- | -------------------- |
| `Pester` | test runner | `6.2.0` | No alternative worth considering in PowerShell. 6.x is required for the `CommandInfo`-in-`-ForEach` discovery hang fixed in 6.2.0 |
| `psake` | build orchestration | `5.0.4` | Incumbent. Under review against Sampler — see *Under evaluation* |
| `PSScriptAnalyzer` | static analysis | `1.25.0` | The only real linter for PowerShell. Also drives the SARIF upload to the Security tab |
| `PSResourceGet` | dependency resolution | runner-supplied | Replaced `PSDepend` fleet-wide. Ships with the runner images, so it adds nothing to install |
| `ConvertToSARIF` | PSSA output conversion | unpinned | Only consumed by `pssa-sarif.yml`. Exists solely to feed the Security tab |
| `PlatyPS` | external help generation | `0.14.2` | **`AWSAutomation` only.** Not fleet policy; no other repo generates external help |

Deliberately **not** in the set:

- **`PSDepend`** — removed fleet-wide. It required bootstrapping itself before it could resolve anything, and the registration-state flakiness tracked in [#27](https://github.com/jjohns-dev/pwsh-module-ci/issues/27) was the trigger. `Install-PSResource` needs no bootstrap.
- **`BuildHelpers`** — a real dependency in `PS.Log` and `PS.ETL` only, vestigial elsewhere, and a naming fossil (`$env:BH*`) in the rest. Being removed under [#24](https://github.com/jjohns-dev/pwsh-module-ci/issues/24).
- **A mutation-testing tool** — none adopted. See *Under evaluation*.

## Pinning policy

**Build tooling is pinned exactly, never to a range and never to `latest`.** Pester, psake, PSScriptAnalyzer and PlatyPS all change test and analysis outcomes, so an unpinned bump turns a green build red — or worse, a red build green — with no commit to explain it.

Two mechanical consequences worth knowing:

- **A bare version string in `Install-PSResource -Version` is an exact pin**, not a minimum. This is the opposite of the NuGet default and has been confirmed three times in this fleet: `-Version '5.0.0'` returns exactly `5.0.0`, while `'[5.0.0,)'` returns 28 results.
- **A NuGet range does not resolve to its newest member.** Under PSResourceGet 1.2.0, `Find-PSResource` returns range results in a non-semantic order and the installer takes the first. `[5.0.0,6.0.0)` gave `AWS.Tools.Common` 5.0.300 when 5.0.324 existed. Omitting `-Version` is the only reliable way to get latest — so "pin exactly, or do not constrain at all" is the only honest choice.

**Runtime dependencies are a separate question** and are not covered here. `AWSAutomation` deliberately floats its `AWS.Tools.*` modules and `ImportExcel` to `latest`, recorded as ADR-0002 in that repo. That turns on those modules being unversioned `RequiredModules` in its manifest, which no other repo has. **Do not copy it without re-deriving it.**

## Current drift, measured 2026-11-02

| Repo | Pester | psake | PSScriptAnalyzer | Other |
| ---- | ------ | ----- | ---------------- | ----- |
| `PS.Log` | 6.2.0 | 5.0.4 | **1.25.0** | |
| `PS.SSL` | 6.2.0 | 5.0.4 | 1.24.0 | |
| `PS.GHOps` | 6.2.0 | 5.0.4 | 1.24.0 | |
| `PS.GitHub` | 6.2.0 | 5.0.4 | 1.24.0 | |
| `PS.DCU` | 6.2.0 | 5.0.4 | 1.24.0 | |
| `SecurityTools` | 6.2.0 | 5.0.4 | 1.24.0 | ImportExcel 7.8.10 |
| `AWSAutomation` | 6.2.0 | **4.9.1** | 1.24.0 | PlatyPS 0.14.2, ImportExcel `latest` |

Two things this surfaces:

- **Two PSScriptAnalyzer versions analyse the same code.** `Build/depend.psd1` pins 1.24.0 for the gating `Analyze` task, while the reusable `pssa-sarif.yml` hardcodes `Install-Module -RequiredVersion '1.25.0'`. In six of seven repos the build gate and the Security tab therefore run different analyzers, and can legitimately disagree about the same file. `PS.Log` at 1.25.0 is the only repo where they match — it is the consistent one, not the outlier it looks like.
- **`AWSAutomation` is still on psake 4.9.1.** Every other repo is on 5.0.4.

**Neither is a sweep to run.** Aligning seven `depend.psd1` files by hand reproduces the exact problem #20 exists to end, and the next drift would start the day after. The fix is for the stack to be declared once and inherited; these rows are the evidence for doing that, and the list to reconcile against when it happens.

## Under evaluation

Neither is adopted. Both are independent decisions at different layers — adopting one says nothing about the other, and neither blocks the other.

| Candidate | Layer | Issue | Status |
| --------- | ----- | ----- | ------ |
| `Sampler` | build orchestration, would replace psake | [#19](https://github.com/jjohns-dev/pwsh-module-ci/issues/19) | Deferred, not rejected. Sampler is Invoke-Build underneath, and the DSC Community has standardised on it. #19 records three things its defaults do not provide that must not be lost |
| `PSMutant` | test quality | [#34](https://github.com/jjohns-dev/pwsh-module-ci/issues/34) | Unevaluated. 0.9.1, published 2026-10-26. Mutation testing is the established answer to assertions that cannot fail, which is the defect class this fleet has spent two weeks fixing by hand |

**A build framework will not improve test quality**, and expecting it to is a category error. #19 records that Sampler *"would have prevented none of"* the test-authoring defects that prompted this work. Build orchestrators sequence tasks; whether an assertion can fail is a different layer.

## Selection criteria

Applied when considering anything new:

- **Does the job need a dependency at all?** The `min-tests` floor is ~30 lines of inline PowerShell precisely because no dependency was warranted.
- **One tool per job.** Two linters or two test runners means two sets of results to reconcile, and the PSScriptAnalyzer split above shows what that costs even when it is the *same* tool at two versions.
- **Maintained, with evidence.** Assess the project, not the README — #19's Sampler evaluation is the worked example.
- **Can it be pinned exactly?** Anything that cannot is a runtime dependency decision, not a build one.
