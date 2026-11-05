# 6. Host the build harness in this repo and configure it by workflow input

## Status

Proposed — 2026-11-05

## Context

- Seven `jjohns-dev` module repos each vendor four `Build/` files. Measured 2026-10-26: 5–6 distinct variants per file; only `PS.GitHub` and `PS.GHOps` are byte-identical across all four.
- Fixing one CI problem takes N pull requests. Two weeks of rollout work across #17, #22, #23, #24 and #27 is the evidence, and the maintenance burden — not the drift itself — is what forces this.
- Classifying `Build/PSScriptAnalyzerSettings.psd1` on 2026-11-05 found the divergence largely illusory: three of its four variants are behaviourally inert (`Rules = @{}`, `IncludeDefaultRules`, `Severity` ordering), and three of its five `ExcludeRules` suppress nothing in any repo. The cost is real; most of the variation is not.
- `job.workflow_repository` and `job.workflow_sha` let a reusable workflow check out its own source at the exact commit being run. This is a documented pattern, not a workaround, and it pins the harness to the workflow version automatically.
- `SecurityTools` cannot consume `ci.yml` today for one reason: `os-matrix` is a JSON array of strings, and it needs `os`, `pesterScope` and `minTests` travelling together per runner.
- The genuinely per-repo configuration found so far is small: `AWSAutomation` needs `PSUsePSCredentialType` and `PSAvoidUsingPlainTextForPassword` excluded, because `AWS.Tools.*` authenticates with `Amazon.Runtime.AWSCredentials` and never `PSCredential` — verified against `AWS.Tools.Common` 5.0.318, where zero cmdlets take a `PSCredential`-typed `-Credential`.

## Decision

- `Build/` moves into this repo. The reusable workflows check it out via `job.workflow_sha` and run it against the caller's checkout.
- Per-repo variation is expressed as **workflow inputs**, never as vendored files. Each input is a declared seam added with a recorded reason, not an accident of drift.
- `os-matrix` becomes a JSON array of objects carrying `os`, and optionally `pester-scope` and `min-tests`, so a floor can differ per runner.
- `SecurityTools` is the design target for the input shape, not the final migration. It is the only repo that exercises per-runner variation, so designing against it last would mean designing the input twice.
- Consumers keep a thin workflow stub, because GitHub requires a workflow file in each repo to bind to that repo's events.

## Consequences

- One edit fixes every consumer. The harness and the workflow can no longer drift apart, because `job.workflow_sha` resolves to the commit of the workflow actually running.
- **Blast radius grows sharply.** A bad harness commit reaches the whole fleet through `v1` with no staging environment. The existing rule — stage behind an immutable `vX.Y.Z` pin — becomes more important, not less.
- **GitHub Enterprise Server is excluded** for as long as this stands: the `job.workflow_*` properties are documented as unavailable there.
- Changing `os-matrix`'s type breaks the call for six consumers, which is a `v2` under ADR-0002. Adding a parallel input and deprecating the old one avoids that, at the cost of carrying both.
- This repo acquires a PowerShell harness it has never had, and therefore needs real tests for it. `tests/Invoke-VerificationTest.ps1` currently covers exactly one `run:` block.
- Debugging moves further from the consumer. A failing build is no longer explained by files in the repo being built, which is worse for a newcomer even though it is better for maintenance.
- **This weakens the case for #19 rather than settling it.** Sampler is an opinionated scaffolding framework, not only a task runner: it resolves `SourcePath` and `ProjectName` from a manifest in `source`, `src`, or a module-named folder, and expects `build.yaml`, `RequiredModules.psd1` and `Resolve-Dependency.ps1` at each repo root. These repos keep the manifest at the repo root beside `Public/` and `Private/`, so adopting Sampler later still requires a per-repo layout change — the very cost this decision exists to remove. Centralising first is still correct, because it is useful whether or not Sampler is ever adopted, but it should not be sold as making that migration free.
