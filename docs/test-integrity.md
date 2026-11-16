# Test integrity

Why a test suite can be green and prove nothing, and the rules that follow from it. Covers the Pester suites in the PowerShell module repos, the harness's shared suites in `Build/SharedTests/` (which from `v2.2.0` include the help suite that replaced each repo's `Help.Tests.ps1`), and the `min-tests` floor that guards them.

**This file is not interim.** These decisions about how tests are written and measured outlive any de-duplication, as [`dependency-stack.md`](dependency-stack.md) does. They moved here on 2026-11-04 from `shared-ci-standards.md`, which #20 deleted; that file's map of which repo holds the reference copy of each test piece is preserved on [#53](https://github.com/jjohns-dev/pwsh-module-ci/issues/53#issuecomment-6780926659).

## The defect class

Every test defect this fleet fixed across 2026-10 and 2026-11 had one shape: **an assertion that could not fail.** Not a wrong assertion — an assertion with no reachable path to red. A tautology comparing a value to itself, a `-ForEach` that generated zero cases, an `if` whose condition was never true, a collection operator applied to a scalar.

All of them were green. All of them had been green since the day they were written. None of them were caught by CI, by a code review, or by a build framework, because a check that cannot fail is indistinguishable from one that passes — from the outside, both are a tick.

Each was eventually caught by a human reading the test and breaking the thing it guarded. That is mutation testing, performed one mutant at a time by hand. Whether to automate it is [#34](https://github.com/jjohns-dev/pwsh-module-ci/issues/34).

**The practical consequence is the rule that runs through everything below:** a new or changed assertion is not finished until it has been observed failing.

## Settled decisions

Do not relitigate these. Each was decided once, with evidence.

- **The mandatory-value test is deleted, not fixed.** `Get-Help` derives `Required` from `[Parameter(Mandatory)]` for comment-based help, so the assertion can only compare a value to itself. Leave the standard marker comment at the deletion site, or a sibling repo will reintroduce it. See [#17](https://github.com/jjohns-dev/pwsh-module-ci/issues/17).

- **The link test is offline, and both of its checks are load-bearing.** A live `Invoke-WebRequest` makes unit tests network-dependent. Neither half of the replacement is redundant: the scheme pattern rejects `ftp://` and `htp:/broken`, which `IsWellFormedUriString` accepts; `IsWellFormedUriString` rejects `https://example.com/a^b`, which the pattern accepts. Verified 2026-10-28.

- **Parameter names and links both come from the AST in the shared help suite; links are classified by scheme.** `Get-Help` silently drops a `.PARAMETER` block naming no real parameter, which is what made the matching-help assertion a tautology — hence the AST for parameters.
  The per-repo `Help.Tests.ps1` copies took links from `Get-Help`, because the AST returns related-topic names (`.LINK Get-Item`) alongside URIs and their scheme check would have failed those. The shared suite instead treats a `.LINK` as a URI only when it starts with a scheme, `^[A-Za-z][A-Za-z0-9+.-]*:`, and skips the rest, so one source serves both checks.
  **Observed, not just argued.** `jjohns-dev/SecurityTools`' only `.LINK` is `ConvertTo-GZipString`, a related-topic name; the shared suite skips it and passes (measured 2026-11-16 at `d18c091`), and a fixture `.LINK Get-Item` must pass. That repo's SecurityTools#159 is where the `Get-Help` route was confirmed for the per-repo copies.
  A Windows path such as `C:\x` reads as a URI and fails, which is right for a `.LINK`.

- **A `$null` help-content guard is required, and the obvious reference implementations lack it.** When a function has no comment-based help at all, `$HelpContent` is `$null`, and `$null.Parameters.Keys` piped through `Where-Object` yields a **one-element array containing `$null`** — not an empty array. That generates a single case literally named `$null`, which then fails. `-AllowNullOrEmptyForEach` does not help, because the array is neither null nor empty. The guard is `Where-Object { $_ -and ... }`. Found while implementing jjohns-dev/PS.Log#54.

- **`Help.Tests.ps1` opens with an analyzer-suppression preamble. It does not affect the build gate, and it is not dead weight.** The `Analyze` task lints only the staged module, so the preamble changes no pass/fail result. But the rule it suppresses, `PSUseDeclaredVarsMoreThanAssignments`, fires on every Pester fixture variable because it cannot follow assignment in `BeforeDiscovery`/`BeforeAll` into an `It`, and that noise appears in the editor, in local analyzer runs, and in the Security tab, since `pssa-sarif.yml` scans the whole repo, `Tests/` included.
  **Do not conclude it is dead weight because the build ignores it** — that reasoning appears in PS-MCS/MCS#207, and MCS has carried the preamble ever since.
  *Recorded 2026-10-28 as byte-identical at 264 characters in every repo that has it; not re-measured since, and see the `-ceq` trap below for why "identical" needs saying precisely.*

- **Build tooling is pinned exactly, never to a range and never to `latest`**, because an unpinned bump can change a test or analysis result with no commit to explain it. The stack, the policy and the `Install-PSResource` mechanics are in [`dependency-stack.md`](dependency-stack.md).

- **The shared meta suite loops: one test per check, not one per file.** A per-file suite ties the `min-tests` floor to the number of source files. The floor's margin is at most 10, so with three checks per file, deleting four files in an ordinary refactor drops twelve tests and fails CI with nothing wrong. Looped, the suite is always three tests, and each failure names every offending file instead. Decided 2026-11-13 on [#53](https://github.com/jjohns-dev/pwsh-module-ci/issues/53); the reasoning is the requirements' AC 7. The path-literal suite stays per public file on purpose: it tracks the module's public surface, as help tests already do.

- **The shared suites do not assert what the harness already enforces.** Exactly one root manifest, the module name, the loader's presence, a clean import, and anything a failed import already reports, such as an unparseable `ModuleVersion` or `GUID`, are all checked by harness steps that run before `Test`. As shared tests they could never fail. The measured list is in the shared-test-minimum design, *What the harness already enforces*; do not re-add them.

- **The shared help suite runs four tests per exported function and one looped link test, not one per parameter or link.** Per parameter ties the `min-tests` floor to the number of parameters, so removing a dozen in a refactor would fail CI with nothing wrong — the meta suite's reason, above. A per-function link test would pass with nothing to check in every repo without links, inflating the floor without guarding anything. Decided 2026-11-16 on [#55](https://github.com/jjohns-dev/pwsh-module-ci/issues/55); the requirements' *Decisions* record it. A function with no help at all fails all four of its tests, so there is no separate *not auto-generated* test.

- **A function with a `DynamicParam` block may document parameters it does not declare statically.** A `DynamicParam` block emits its parameters only when the command is bound, so neither `Get-Command` nor the module's export table lists them; measured 2026-11-16 on SecurityTools' `Get-KEVList -OutputDirectory`. The shared help suite therefore skips its *names no declared parameter* check for such functions, and an undocumented or stale dynamic parameter goes unseen. If that ever matters, the path is per-function trigger arguments in `harness.psd1`: the shared-help-suite design, [*Future: checking dynamic parameters*](specs/shared-help-suite/design.md#future-checking-dynamic-parameters).

## Traps that have cost real time

- **A check that never fires is indistinguishable from one that passes.** Every new assertion needs a mutation: break the thing it guards, confirm red, revert. This matters most where a test cannot fire at all — a repo with no `.LINK` shows no difference before and after, which proves nothing. Where a repo cannot produce that evidence incidentally, the mutation has to be manufactured.

- **A test that generates no cases is a second, separate vacuity.** Mutating an assertion proves the assertion works; it says nothing about whether the `-ForEach` collection is still populated. A filter bug that returns nothing *unconditionally* produces zero cases and passes green through the normal run **and** through every assertion mutation, because a case that is never created cannot fail.
  Prove the generator independently: confirm the case count rises when a qualifying input exists. `SecurityTools` mutation runs collected 998 tests with exactly 1 link case where the clean run had 0, which is what ruled this out.
  Applies to any data-driven test whose `-ForEach` is bound to a filtered collection, not just links.

- **The floor counts cases, so an assertion inside a run-time loop is invisible to it.** A `min-tests` floor can only see things that produce a `testcase` node. An assertion that loops *within* one `It` contributes nothing to the count, so deleting it leaves the count unchanged and the floor silent.
  `PS.DCU` is the clearest instance: its stale-help check was added in jjohns-dev/PS.DCU#21 and the collected count stayed at **85**, so the fleet's main regression guard does not cover one of that repo's sharpest tests.
  This is **not** an argument for converting such tests to `-ForEach` — in `PS.DCU` the run-time loop is deliberate, and is what makes the file immune to the discovery-binding defect. It is an argument for knowing which of your assertions the floor actually guards, and not describing the floor as protecting more than it does.

- **`-ceq` proves character-identity after parsing, not byte-identity on disk.** It is the right operator for comparing a copied `run:` block, because PowerShell's bare `-eq` is case-insensitive on strings and would call `$ErrorActionPreference` and `$erroractionpreference` equal — a comparison that cannot fail on a real class of drift. But YAML normalises line endings inside a block scalar, so a CRLF file and an LF file parse to the **same string**, and `-ceq` is true for both. Measured 2026-11-03.
  **Check the file's encoding as a separate claim.** That gap is why [SecurityTools#161](https://github.com/jjohns-dev/SecurityTools/issues/161) existed at all rather than being covered by a `-ceq` result. Same defect class as everything above: a comparison that cannot report the difference you are asking about.

- **Pester's `Run.Path` throws on a scalar `FileInfo` and accepts an array.** A glob matching exactly one file returns a single `FileInfo`, so a build that worked with two test files breaks with one. Verified on Pester 6.2.0 in [#20](https://github.com/jjohns-dev/pwsh-module-ci/issues/20); the harness passes `[System.String[]]` of full paths for this reason.

- **A dictionary with a `Keys` entry hides its `.Keys` property.** On any `IDictionary`, `.Keys` resolves to an entry named `Keys` before the property, so `$command.Parameters.Keys` on a function with a `-Keys` parameter returns that parameter's metadata instead of the name list. AWSAutomation's `Get-RoleCredential` has one; read naively, it produced nine false findings (measured 2026-11-16). Read keys through `.PSBase.Keys`, as the shared help suite does. PS.DCU's own `help.tests.ps1` uses the naive form and passes only because no PS.DCU function has a `-Keys` parameter.

- **An `Assert` on an undefined variable passes silently.** psake does not apply `Set-StrictMode` to task bodies on its own, so a misspelt variable is `$null` and the condition can come out `True`. Six of seven repos had exactly that in `Analyze`'s `default` branch (`$analysisResult` for `$Results`), and on psake 5.0.4 the build succeeded (#20). The harness sets `Set-StrictMode -Version Latest` at the top of `build.psake.ps1`, which does reach task bodies; setting it in `build.ps1` does not (measured 2026-11-09).

- **A non-terminating `Write-Error` already fails a psake task.** `$psake.build_success` was `False` with and without `-ErrorAction Stop` (#20). A gate that uses a bare `Write-Error` works, so do not add `-ErrorAction Stop` everywhere believing it does not.

## Deriving a `min-tests` floor

- **Fix first, measure second, set the floor third.** A floor derived before the fix records the defective count as the baseline, and can never trip on a regression back to it.

- **Read the number from the run's JUnit artifact. Never predict it**, and never carry it forward from a previous value.

- **The floor is `executed - margin`, where `margin = min(floor(executed * 0.05), 10)`** — [ADR-0004](adr/0004-min-tests-floor-margin.md). Read aloud: *five percent of executed, but never more than ten tests*. The cap is the operative part; the percentage term exists only so very small legs do not get a zero margin.

- **`executed` is the JUnit root's `tests` attribute minus its `disabled` attribute.** Pester's JUnitXml routes skipped and tag-excluded tests to `disabled` — never to `skipped` — while still counting them in `tests`, so a mass-skip regression leaves `tests` untouched. Since `v1.5.0` the verify step gates on `tests - disabled`, so a floor derived from the collected count in a repo with disabled tests sits **above** what actually runs. The two numbers differ only where something is skipped: `PS.SSL` (14 ubuntu, 15 windows) and `SecurityTools` (1 ubuntu). Everywhere else they are the same. Settled in [#23](https://github.com/jjohns-dev/pwsh-module-ci/issues/23).

- **Record the derivation in the `min-tests` trailing comment**, naming the executed count and the arithmetic. This matters most when the value does not change — `PS.Log` stayed at 87 across a back-fill that removed six cases, and without the comment the diff carries no evidence the floor was considered at all. A reviewer cannot otherwise tell "re-derived, unchanged" from "forgotten".

- **Deleting tests moves the floor, so re-derive it in the same pull request.** Otherwise CI goes red for the wrong reason.

- **Verify a floor in both directions, as two separate claims.** An impossible floor must fail the run *and* still leave the result XML uploaded; a correct floor must stay quiet. A throwing verify step placed ahead of a `success()`-gated upload suppresses the diagnostic exactly when it is wanted.

- **Existing floors move opportunistically, not in a sweep.** A repo's floor is re-derived under the current formula the next time a pull request touches it for any reason. A repo still on the old 90% convention is expected, not a bug — check its last floor-touching PR before filing anything.

- **Do not describe the floor as protecting more than it does.** It catches catastrophic collection failure. It does not catch a single small test file dropping out, it cannot see assertions inside run-time loops, and a test file that fails at discovery *adds* to `tests` rather than reducing it. The verify step's `errors` check is what catches that last one.
