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
- **Parameter names come from the AST; link URIs come from `Get-Help`.** These look contradictory and are not. `Get-Help` silently drops a `.PARAMETER` block naming no real parameter, which makes the matching-help assertion a tautology — hence the AST for parameters. But the AST returns related-topic names (`.LINK Get-Item`) alongside URIs, which would fail the scheme check, while `Get-Help` sorts them into `linkText` with an empty `uri` — hence `Get-Help` for links. Any repo doing both needs a comment saying so, or someone will "fix" one of them into a bug.
  **This is observed, not just argued.** `jjohns-dev/SecurityTools` is the only repo in the fleet where the two sources diverge: its single `.LINK` is `ConvertTo-GZipString`, a related-topic name rather than a URI. Confirmed green under `Get-Help` in SecurityTools#159, where the AST would have reported a valid link as a malformed URI. Go there before re-opening the question.
- **Filter links on a non-empty `uri`, not on the collection being empty.** A command with no `.LINK` at all still yields a `navigationLink` entry whose `uri` is an empty string, so a null or count check on the collection does not drop it.
- **Floors are derived after the fixes land, never before.** A floor measured before the fix records the defective count as the baseline and can never trip on a regression back to it. Read the number from the run's JUnit artifact; do not predict it.
- **Record the derivation in the `min-tests` trailing comment**, naming the collected count and the arithmetic. This matters most when the floor value does not change — `PS.Log` stayed at 87 across a back-fill that removed six cases, and without the comment the diff carries no evidence the floor was considered at all. A reviewer cannot tell "re-derived, unchanged" from "forgotten" otherwise.
- **The floor margin is `min(floor(collected * 0.05), 10)`** — see [ADR-0004](adr/0004-min-tests-floor-margin.md) for why the cap is the operative part. Use it for every floor you derive. **Existing floors move to it opportunistically**: when a PR touches a repo's floor for any reason, re-derive under this formula while you are there. There is no dedicated back-port sweep, and #23 catches any stragglers when it changes the floor's input from `tests` to `tests - disabled`. A repo still on the old 90% convention is expected, not a bug.
- **Build tooling stays exactly pinned everywhere.** Pester, psake, PSScriptAnalyzer and PlatyPS change test and analysis outcomes.

## Traps that have cost real time

- **Deleting tests moves the floor, so re-derive it in the same PR.** Otherwise CI goes red for the wrong reason. Read the new count from the run's JUnit artifact; do not predict it.
- **A check that never fires is indistinguishable from one that passes.** Every new assertion needs a mutation: break the thing it guards, confirm red, revert. This matters most where a test cannot fire at all — a repo with no `.LINK` will show no difference before and after, which proves nothing.
- **A test that generates no cases is a second, separate vacuity.** Mutating an assertion proves the assertion works; it says nothing about whether the `-ForEach` collection is still populated. A filter bug that returns nothing *unconditionally* produces zero cases and passes green through the normal run **and** through every assertion mutation, because a case that is never created cannot fail. Prove the generator independently: confirm the case count rises when a qualifying input exists. `SecurityTools` mutation runs collected 998 tests with exactly 1 link case where the clean run had 0, which is what ruled this out. Applies to any data-driven test whose `-ForEach` is bound to a filtered collection, not just links.
- **`tests` includes skipped tests.** Pester's JUnitXml writes them to `disabled`, never `skipped`, and still counts them in `tests`, so a mass-skip regression sails past a floor. Only `PS.SSL` and `SecurityTools` use `-Skip`. See #23.
- **A NuGet version range does not resolve to the newest member.** Under PSResourceGet 1.2.0, `Find-PSResource` returns range results in a non-semantic order and the installer takes the first. Omitting `-Version` is the only reliable way to get latest. Measured 2026-10-28, recorded on #27.
- **Verify a floor in both directions, as separate claims.** An impossible floor must fail the run *and* still upload the result XML — a throwing verify step placed ahead of a `success()`-gated upload suppresses the diagnostic exactly when it is wanted.

## Not fleet policy

`jjohns-dev/AWSAutomation` floats its `AWS.Tools.*` and `ImportExcel` dependencies to `'latest'` (its ADR-0002). That turns on those modules being unversioned `RequiredModules` in its manifest, which no other repo has. Do not copy it without re-deriving it.
