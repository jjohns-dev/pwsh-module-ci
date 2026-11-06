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
- A new `os-matrix-include` input accepts a JSON array of objects carrying `os`, and optionally `pester-scope` and `min-tests`, so a floor can differ per runner.
- **#21's option A, implemented additively.** A new `os-matrix-include` input is added *alongside* `os-matrix` rather than replacing it, so the six current consumers' calls are untouched and opt in individually. #21's option B is rejected: its technical hedge is no longer needed, and it would create a sixth copy of the `Verify Pester results` step when only two of the existing five are covered by the drift guard in `tests/Invoke-VerificationTest.ps1`.
- `SecurityTools` is the design target for the input shape, not the final migration. It is the only repo that exercises per-runner variation, so designing against it last would mean designing the input twice.
- Consumers keep a thin workflow stub, because GitHub requires a workflow file in each repo to bind to that repo's events.

## Consequences

- One edit fixes every consumer. The harness and the workflow can no longer drift apart, because `job.workflow_sha` resolves to the commit of the workflow actually running.
- **Blast radius grows sharply.** A bad harness commit reaches the whole fleet through `v1` with no staging environment. The existing rule — stage behind an immutable `vX.Y.Z` pin — becomes more important, not less.
- **GitHub Enterprise Server is excluded** for as long as this stands: the `job.workflow_*` properties are documented as unavailable there.
- **`os-matrix` is retained, not changed.** Altering its type would break the call for six consumers and force a `v2` under ADR-0002; adding `os-matrix-include` beside it keeps this a minor, at the cost of carrying both until the old one is retired. #9 states the rule directly: adding an input is a minor, removing `os-matrix` is not.
- This repo acquires a PowerShell harness it has never had, and therefore needs real tests for it. `tests/Invoke-VerificationTest.ps1` currently covers exactly one `run:` block.
- Debugging moves further from the consumer. A failing build is no longer explained by files in the repo being built, which is worse for a newcomer even though it is better for maintenance.
- **#21's implementation traps all still apply** and are inherited wholesale: pass caller-supplied values through `env:` rather than interpolating them into a `run:` block, because centralising turns a local literal into untrusted input; branch on an empty matrix key instead of passing `@{ PesterScope = '' }`; update each repo's ruleset in the same change, because adopting a reusable workflow renames the required checks and the old names simply stop reporting; preserve `SecurityTools`' stricter `if-no-files-found: error`; and add the missing `timeout-minutes`.
- **This does not settle #19, and the earlier framing of it here was too strong.** Centralising yields *one* hand-rolled harness instead of seven — still hand-rolled. #19's argument is not about any single defect but about recurring maintenance: Sampler's curated Pester task already encodes the `FailedCount` gap that `ci.yml`'s verify step exists to catch, and ships it maintained. That benefit persists whether or not the harness is centralised here.
- Against that, #19 also records three things Sampler's defaults do **not** provide and that this repo already has: a per-leg test-count floor (no equivalent concept in Sampler), an OS matrix (its default pipeline is a single job), and `JUnitXml` output with the artifact guards that exist because `dorny/test-reporter` mis-parses Pester's NUnitXml v2.5. Hand-rolling keeps all three by construction. The real choice is therefore maintained tasks that must be adapted against hand-rolled tasks that must be maintained — not centralise-or-Sampler.
- Sampler would additionally require a per-repo layout change, since it resolves `SourcePath` from a manifest in `source`, `src`, or a module-named folder, and expects `build.yaml`, `RequiredModules.psd1` and `Resolve-Dependency.ps1` at each repo root. These repos keep the manifest at the repo root beside `Public/` and `Private/`. So adopting it later still costs an N-repo edit, which is the cost this decision exists to remove.
- #19's sequencing step 3 — audit `build.psake.ps1` against **Sampler's** equivalent tasks — remains outstanding. The #20 classification audited the seven repos against *each other*, which is a different question and does not answer it.
