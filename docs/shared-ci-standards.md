# Shared CI standards

**Interim scaffolding. Delete it when #20 lands.** It exists because the shared files are copy-pasted across ten repos, so "what is the current best version of X" is a question with no answer in the source. Once #20 gives those files a canonical copy that propagates mechanically, this file has no job.

It deliberately contains **no code**. A pasted snippet here would be an eleventh copy of the template, drifting against the ten in source — the exact problem #20 exists to fix. Go read the reference repo instead.

## Reference implementations

No single repo is best at everything. Measured 2026-10-28.

| Piece | Reference | Why that one |
| ----- | --------- | ------------ |
| `Help.Tests.ps1` overall shape | `jjohns-dev/AWSAutomation` | All four defects fixed, mandatory-value test deleted with its marker comment. The smallest correct version |
| Link test | `PS-MCS/MCS` | No redundant outer `if` — the filtered `foreach` already iterates zero times. Its comment names what each check misses, which the later copies dropped |
| Conditional `DynamicParam` resolution | `jjohns-dev/SecurityTools` | Only repo that has it. Dynamic parameters are invisible to static `Get-Command` metadata, so a `.PARAMETER` block documenting one looks like help for a parameter that does not exist |
| `min-tests` floor, per-leg | `jjohns-dev/SecurityTools` | Per-leg floors plus all three no-result-file guards |
| PSDepend to `Install-PSResource` loop | `jjohns-dev/AWSAutomation` | Handles exact pins **and** a `'latest'` sentinel, and logs resolved versions. `SecurityTools` has the simpler pin-only form if that is all a repo needs |

When you improve one of these, update the row. That is the whole maintenance burden.

## Settled decisions

Do not relitigate these. Each was decided once, with evidence, and the link goes to the reasoning.

- **The mandatory-value test is deleted, not fixed.** `Get-Help` derives `Required` from `[Parameter(Mandatory)]`, so it compares a value to itself. Leave the standard marker comment at the deletion site or a sibling repo will reintroduce it. See #17.
- **The link test is offline.** A live `Invoke-WebRequest` makes unit tests network-dependent. Both the scheme pattern and `IsWellFormedUriString` are load-bearing and neither is redundant: the pattern rejects `ftp://` and `htp:/broken`, which `IsWellFormedUriString` accepts; `IsWellFormedUriString` rejects `https://example.com/a^b`, which the pattern accepts. Verified 2026-10-28.
- **Parameter names come from the AST; link URIs come from `Get-Help`.** These look contradictory and are not. `Get-Help` silently drops a `.PARAMETER` block naming no real parameter, which makes the matching-help assertion a tautology — hence the AST for parameters. But the AST returns related-topic names (`.LINK Get-Item`) alongside URIs, which would fail the scheme check, while `Get-Help` sorts them into `linkText` with an empty `uri` — hence `Get-Help` for links. Filter on a **non-empty `uri`**, not on the collection being empty: a command with no `.LINK` at all still yields a `navigationLink` entry whose `uri` is an empty string, so a null or count check does not drop it. Any repo doing both needs a comment saying so, or someone will "fix" one of them into a bug.
  **This is observed, not just argued.** `jjohns-dev/SecurityTools` is the only repo in the fleet where the two sources diverge: its single `.LINK` is `ConvertTo-GZipString`, a related-topic name rather than a URI. Confirmed green under `Get-Help` in SecurityTools#159, where the AST would have reported a valid link as a malformed URI. Go there before re-opening the question.
- **Floors are derived after the fixes land, never before.** A floor measured before the fix records the defective count as the baseline and can never trip on a regression back to it. Read the number from the run's JUnit artifact; do not predict it.
- **Record the derivation in the `min-tests` trailing comment**, naming the collected count and the arithmetic. This matters most when the floor value does not change — `PS.Log` stayed at 87 across a back-fill that removed six cases, and without the comment the diff carries no evidence the floor was considered at all. A reviewer cannot tell "re-derived, unchanged" from "forgotten" otherwise.
- **The floor margin is `min(floor(collected * 0.05), 10)`** — see [ADR-0004](adr/0004-min-tests-floor-margin.md) for why the cap is the operative part. Use it for every floor you derive. **Existing floors move to it opportunistically**: when a PR touches a repo's floor for any reason, re-derive under this formula while you are there. There is no dedicated back-port sweep, and #23 catches any stragglers when it changes the floor's input from `tests` to `tests - disabled`. A repo still on the old 90% convention is expected, not a bug.
- **`Help.Tests.ps1` opens with an analyzer-suppression preamble.** Byte-identical in every repo that has it, 264 characters, and it must stay that way:

  ```powershell
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
      'PSUseDeclaredVarsMoreThanAssignments',
      '',
      Justification = 'Pester assigns fixtures in BeforeDiscovery/BeforeAll and consumes them in It blocks; PSScriptAnalyzer cannot follow that scope.'
  )]
  Param()
  ```

  **It is for editors, not CI.** Every repo's `Analyze` task runs `Invoke-ScriptAnalyzer` against the staging folder only, so `Tests/` is never linted in a build and the preamble changes no CI outcome. Without it, every Pester fixture variable raises `PSUseDeclaredVarsMoreThanAssignments` in the editor and in a local analyzer run, because the rule cannot follow assignment in `BeforeDiscovery`/`BeforeAll` into an `It`. That noise is what the suppression removes. **Do not conclude it is dead weight from the fact that CI ignores it** — that reasoning appears in PS-MCS/MCS#207 and MCS has carried the preamble ever since.
- **Build tooling stays exactly pinned everywhere.** Pester, psake, PSScriptAnalyzer and PlatyPS change test and analysis outcomes. The full stack, the pinning policy and the `Install-PSResource` version-string mechanics live in [`dependency-stack.md`](dependency-stack.md), which outlives this file.

## Traps that have cost real time

- **Deleting tests moves the floor, so re-derive it in the same PR.** Otherwise CI goes red for the wrong reason. Read the new count from the run's JUnit artifact; do not predict it.
- **A check that never fires is indistinguishable from one that passes.** Every new assertion needs a mutation: break the thing it guards, confirm red, revert. This matters most where a test cannot fire at all — a repo with no `.LINK` will show no difference before and after, which proves nothing.
- **A test that generates no cases is a second, separate vacuity.** Mutating an assertion proves the assertion works; it says nothing about whether the `-ForEach` collection is still populated. A filter bug that returns nothing *unconditionally* produces zero cases and passes green through the normal run **and** through every assertion mutation, because a case that is never created cannot fail. Prove the generator independently: confirm the case count rises when a qualifying input exists. `SecurityTools` mutation runs collected 998 tests with exactly 1 link case where the clean run had 0, which is what ruled this out. Applies to any data-driven test whose `-ForEach` is bound to a filtered collection, not just links.
- **The floor counts cases, so an assertion inside a run-time loop is invisible to it.** A `min-tests` floor can only see things that produce a `testcase` node. An assertion that loops *within* one `It` contributes nothing to the count, so deleting it leaves the count unchanged and the floor silent. `PS.DCU` is the clearest instance: its stale-help check was added in jjohns-dev/PS.DCU#21 and the collected count stayed at **85**, so the fleet's main regression guard does not cover one of that repo's sharpest tests. This is **not** an argument for converting such tests to `-ForEach` — in `PS.DCU` the run-time loop is deliberate and is what makes the file immune to the discovery-binding defect. It is an argument for knowing which of your assertions the floor actually guards, and not describing the floor as protecting more than it does.
- **The floor measures executed tests, not collected.** Pester's JUnitXml writes skipped and tag-excluded tests to `disabled`, never `skipped`, and still counts them in `tests` — so a mass-skip regression leaves `tests` untouched. Since `v1.5.0` the step gates on `tests - disabled`, which is why a floor must be **derived from the executed count**, not the collected one. The two differ only where something is skipped: `PS.SSL` (14 ubuntu, 15 windows) and `SecurityTools` (1 ubuntu). Everywhere else they are the same number. Settled in #23.
- **A NuGet version range does not resolve to the newest member.** Under PSResourceGet 1.2.0, `Find-PSResource` returns range results in a non-semantic order and the installer takes the first. Omitting `-Version` is the only reliable way to get latest. Measured 2026-10-28, recorded on #27.
- **Verify a floor in both directions, as separate claims.** An impossible floor must fail the run *and* still upload the result XML — a throwing verify step placed ahead of a `success()`-gated upload suppresses the diagnostic exactly when it is wanted.

## Not fleet policy

`jjohns-dev/AWSAutomation` floats its `AWS.Tools.*` and `ImportExcel` dependencies to `'latest'` (its ADR-0002). That turns on those modules being unversioned `RequiredModules` in its manifest, which no other repo has. Do not copy it without re-deriving it.
