# ADR 8: Runtime Modules Float From the Manifest; Build Tools Are Pinned Centrally

## Status

Accepted — 2026-11-10

## Context

- Each consumer used to list its modules in `Build/depend.psd1`. Two kinds of module share that file and change outcomes in different ways:
  - **runtime modules** the module itself needs, such as `ImportExcel` and the `AWS.Tools.*` modules;
  - **build tools** that run the build: Pester, psake and PSScriptAnalyzer.
- Measured 2026-11-09: two repos have runtime modules. AWSAutomation lists 15, all at `latest`. SecurityTools lists `ImportExcel` at `7.8.10`, which was the latest release when written, not a deliberate pin. Both repos' manifests list exactly the same names with no version, so the two lists are kept in step by hand.
- The manifest's `RequiredModules` is what users' installs see. A pin held only in `depend.psd1` makes CI test against one version while users install whatever the manifest allows.
- A stale runtime module can carry known bugs or vulnerabilities. A newly released one can break a build overnight with no change in the repo.
- A new build-tool release can turn a build red with no change in the repo: Pester and PSScriptAnalyzer decide test and analysis outcomes. Before the harness, PSScriptAnalyzer ran at 1.25.0 in two repos and 1.24.0 in five, while `pssa-sarif.yml` used 1.25.0 for all seven.
- Under PSResourceGet 1.2.0 a NuGet version range resolves to an arbitrary member (`docs/dependency-stack.md`), so the only reliable way to get the latest release is to omit `-Version`.
- AWSAutomation records a version of this rule for itself only (its own ADR-0002). This repo now runs every consumer's build (ADR-0006), so a rule here applies to all seven.

## Decision

- We will read a consumer's runtime modules from its manifest's `RequiredModules`, and never from a second list.
- We will install a runtime module at its latest release by default, calling `Install-PSResource` without `-Version`.
- We will honour an exact version only when the manifest declares it with `RequiredVersion`; a `ModuleVersion` minimum still installs the latest; a `MaximumVersion` fails the build with a message naming the module, until a repo needs one.
- We will log every resolved module as `Resolved dependency: <name> <version>`, build tools included.
- We will pin the build tools in this repo's `Build/depend.psd1` only, and bump them as a deliberate, released change: Pester `6.2.0`, psake `5.0.4` and PSScriptAnalyzer `1.25.0` at `v2.0.0`.
- We will not let `Build/harness.psd1` carry dependencies; it holds only settings that change what the build does.

## Consequences

- **Positive** — consumers stay off stale runtime releases without anyone remembering to bump them.
- **Positive** — CI and users install from the same list, and adding a module to the manifest is enough for every build to install it.
- **Positive** — every consumer builds and analyses with the same tool versions, and the Security tab and the build gate use the same PSScriptAnalyzer.
- **Negative** — a broken or compromised runtime release reaches the next build of every consumer that lists it. The resolved-version log is the only record of what a build ran against, and it diagnoses a failure after the fact rather than preventing it.
- **Negative** — runtime builds are no longer reproducible: the same commit can build against different module versions on different days.
- **Negative** — nothing bumps the build-tool pins. Dependabot cannot see Gallery pins, so a new Pester or PSScriptAnalyzer release is adopted only when someone looks.
- **Neutral** — a repo that genuinely needs a fixed runtime version must declare `RequiredVersion` in its manifest, which also constrains users' installs. That is intended: the pin then means the same thing in CI and in use.
