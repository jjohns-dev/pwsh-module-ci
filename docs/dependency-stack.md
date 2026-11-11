# Dependency stack

The build and test dependencies for the module repos, and why each one is in it.

**This file explains the stack; [`Build/depend.psd1`](../Build/depend.psd1) declares it.** From `v2.0.0` every consumer on `@v2` inherits those pins through the harness ([ADR-0008](adr/0008-runtime-modules-float-build-tools-pinned.md)). A consumer still on `@v1` carries its own `Build/depend.psd1` until its migration PR deletes it. This file is not interim: the question of what we depend on, and why, outlives #20.

## The stack

| Tool | Role | Pin | Why it is in the set |
| ---- | ---- | --- | -------------------- |
| `Pester` | test runner | `6.2.0` | No alternative worth considering in PowerShell. 6.x renders a `CommandInfo` passed to `-ForEach` as its full type name, so every affected test is renamed unless names are passed instead — see the note below |
| `psake` | build orchestration | `5.0.4` | Incumbent. Under review against Sampler and PowerShellBuild — see *Under evaluation* |
| `PSScriptAnalyzer` | static analysis | `1.25.0` | The only real linter for PowerShell. Also drives the SARIF upload to the Security tab |
| `PSResourceGet` | dependency resolution | runner-supplied | Replaced `PSDepend` fleet-wide. Ships with the runner images, so it adds nothing to install |
| `ConvertToSARIF` | PSSA output conversion | unpinned | Only consumed by `pssa-sarif.yml`. Exists solely to feed the Security tab |

Deliberately **not** in the set:

- **`PSDepend`** — removed fleet-wide. It required bootstrapping itself before it could resolve anything, and the registration-state flakiness tracked in [#27](https://github.com/jjohns-dev/pwsh-module-ci/issues/27) was the trigger. `Install-PSResource` needs no bootstrap.
- **`BuildHelpers`** — **absent from all ten module repos across both orgs**, verified 2026-11-05. It was a real dependency in `PS.Log` and `PS.ETL` and vestigial elsewhere; both were converged under [#24](https://github.com/jjohns-dev/pwsh-module-ci/issues/24), now closed. The `$env:BH*` variable names survive as a naming fossil: the harness sets them alongside its own `$env:HARNESS_*` names because consumers' tests still read them.
- **`PlatyPS`** — **removed 2026-11-04** by [AWSAutomation#106](https://github.com/jjohns-dev/AWSAutomation/pull/106). It had been pinned at `0.14.2` in that repo's `depend.psd1` and **never invoked**: verified 2026-11-02 across all 69 text files there, with no `New-MarkdownHelp`, `New-ExternalHelp` or `Update-MarkdownHelp`; no `en-US/`, no `*-help.xml`, no markdown help; no docs task in `build.psake.ps1`; and `HelpInfoURI` commented out in the manifest. All three mentions were declarative — the pin, a line in `AGENTS.md`, and ADR-0002 — so it was installed on every CI run and did nothing.
- **A mutation-testing tool** — none adopted. See *Under evaluation*.

**`AWSAutomation`'s ADR-0002 stated a premise that did not hold, and has been amended.** It justified pinning `PlatyPS` on the grounds that it, like Pester and psake, *"change[s] test and analysis outcomes"*. A tool that is never called cannot change any outcome. The ADR's actual decision — float runtime dependencies, pin build tooling — was unaffected and remains correct; it was the supporting enumeration that was wrong. [#106](https://github.com/jjohns-dev/AWSAutomation/pull/106) **amended** that ADR in place rather than superseding it, correcting the Decision and deliberately leaving Context alone, since Context records the forces as they stood on 2026-10-28.

**The `CommandInfo`-in-`-ForEach` problem was recorded fleet-wide as a hang, and it is not one.** Measured 2026-11-03 in `PS-MCS/PS.ETL`: on **6.2.0** a `CommandInfo` passed to `-ForEach` renders as `Management.Automation.FunctionInfo{Name='...'} help`, renaming 68 of that repo's 78 tests — so the real cost is that every affected test name changes, which breaks name-level comparison between runs. On **6.0.0** it did not hang either; it completed in 52s and wrote a **1.2 GB** result file, which is almost certainly what the original report described. Pass `.Name` and re-resolve with `Get-Command` inside the block. The fix is unchanged; the stated reason was wrong.

**The correction is older than this note, which is the part worth remembering.** `PS-MCS/MCS#207` measured and recorded it during that repo's own 6.2.0 upgrade — *"does not hang: 34 blocks, 517 tests, 1.1s"* — while naming `#206` and earlier prior art as the source of the hang story. The claim still reached `PS.ETL#22`, `ROLLOUT.md` and this file afterwards, because it was copied from the older sources rather than from the reference that had already disproved it. Citing a reference is not the same as reading it.

## Pinning policy

**Build tooling is pinned exactly, never to a range and never to `latest`.** Pester, psake and PSScriptAnalyzer all change test and analysis outcomes, so an unpinned bump turns a green build red — or worse, a red build green — with no commit to explain it.

Two mechanical consequences worth knowing:

- **A bare version string in `Install-PSResource -Version` is an exact pin**, not a minimum. This is the opposite of the NuGet default and has been confirmed three times in this fleet: `-Version '5.0.0'` returns exactly `5.0.0`, while `'[5.0.0,)'` returns 28 results.
- **A NuGet range does not resolve to its newest member.** Under PSResourceGet 1.2.0, `Find-PSResource` returns range results in a non-semantic order and the installer takes the first. `[5.0.0,6.0.0)` gave `AWS.Tools.Common` 5.0.300 when 5.0.324 existed. Omitting `-Version` is the only reliable way to get latest — so "pin exactly, or do not constrain at all" is the only honest choice.

**Runtime dependencies float from the manifest, fleet-wide** ([ADR-0008](adr/0008-runtime-modules-float-build-tools-pinned.md)). The harness reads a consumer's runtime modules from its manifest's `RequiredModules`, installs each at its latest release by omitting `-Version`, honours an exact version only when the manifest declares `RequiredVersion`, and fails on `MaximumVersion`. Every build logs `Resolved dependency: <name> <version>`, which is the only record of what it ran against. This generalises the rule `AWSAutomation` recorded for itself as its ADR-0002.

## Drift before the harness, measured 2026-11-06

The record of why the stack moved into the harness. It is not a sweep to run: each repo's row is resolved by its migration PR, which deletes its `depend.psd1` so the harness's pins apply.

| Repo | Pester | psake | PSScriptAnalyzer | Other |
| ---- | ------ | ----- | ---------------- | ----- |
| `PS.Log` | 6.2.0 | 5.0.4 | **1.25.0** | |
| `PS.SSL` | 6.2.0 | 5.0.4 | 1.24.0 | |
| `PS.GHOps` | 6.2.0 | 5.0.4 | 1.24.0 | |
| `PS.GitHub` | 6.2.0 | 5.0.4 | 1.24.0 | |
| `PS.DCU` | 6.2.0 | 5.0.4 | 1.24.0 | |
| `SecurityTools` | 6.2.0 | 5.0.4 | 1.24.0 | ImportExcel 7.8.10 |
| `AWSAutomation` | 6.2.0 | 5.0.4 | **1.25.0** | ImportExcel `latest` |

One thing this surfaces:

- **Two PSScriptAnalyzer versions analyse the same code** until each repo migrates. `Build/depend.psd1` pins 1.24.0 for the gating `Analyze` task in five of seven repos, while `pssa-sarif.yml` installs 1.25.0, so in those five the build gate and the Security tab can disagree about the same file. `PS.Log` and `AWSAutomation` are the consistent ones, not the outliers they look like.

**Pester and psake are uniform fleet-wide** at 6.2.0 and 5.0.4. `AWSAutomation` was the last repo on psake 4.9.1 and moved to 5.0.4 in [#106](https://github.com/jjohns-dev/AWSAutomation/pull/106), which also took it to PSScriptAnalyzer 1.25.0 and dropped its unused `PlatyPS` pin.

## Under evaluation

None is adopted. `Sampler` and `PowerShellBuild` are alternatives to each other, for the build layer; `PSMutant` is at the test-quality layer, so adopting either kind says nothing about the other.

| Candidate | Layer | Issue | Status |
| --------- | ----- | ----- | ------ |
| `Sampler` | build orchestration, would replace psake | [#19](https://github.com/jjohns-dev/pwsh-module-ci/issues/19) | Deferred, not rejected. Sampler is Invoke-Build underneath, and the DSC Community has standardised on it. #19 records three things its defaults do not provide that must not be lost |
| `PowerShellBuild` | shared psake tasks distributed as a module | [#19](https://github.com/jjohns-dev/pwsh-module-ci/issues/19#issuecomment-6775962578) | Not adopted. The closest match to the harness, but its README calls it a work in progress (0.8.2), and it calls BuildHelpers' `Set-BuildEnvironment` |
| `PSMutant` | test quality | [#34](https://github.com/jjohns-dev/pwsh-module-ci/issues/34) | Unevaluated. 0.9.1, published 2026-10-26. Mutation testing is the established answer to assertions that cannot fail, which is the defect class this fleet has spent two weeks fixing by hand |

**A build framework will not improve test quality**, and expecting it to is a category error. #19 records that Sampler *"would have prevented none of"* the test-authoring defects that prompted this work. Build orchestrators sequence tasks; whether an assertion can fail is a different layer.

## Selection criteria

Applied when considering anything new:

- **Does the job need a dependency at all?** The `min-tests` floor is ~30 lines of inline PowerShell precisely because no dependency was warranted.
- **Is it still doing the job?** A pin outlives its purpose silently. `PlatyPS` above is the worked example — pinned, installed on every run, invoked nowhere, and described in two documents as something it did not do. It survived that way for months before anyone checked.
- **One tool per job.** Two linters or two test runners means two sets of results to reconcile, and the PSScriptAnalyzer split above shows what that costs even when it is the *same* tool at two versions.
- **Maintained, with evidence.** Assess the project, not the README — #19's Sampler evaluation is the worked example.
- **Can it be pinned exactly?** Anything that cannot is a runtime dependency decision, not a build one.
