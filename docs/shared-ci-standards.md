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
| `min-tests` floor, per-leg | `jjohns-dev/pwsh-module-ci` `ci.yml` | Per-leg floors plus all three no-result-file guards. SecurityTools held the reference copy until it adopted `ci.yml` in #21 and deleted its own |
| PSDepend to `Install-PSResource` loop | `jjohns-dev/AWSAutomation` | Handles exact pins **and** a `'latest'` sentinel, and logs resolved versions. `SecurityTools` has the simpler pin-only form if that is all a repo needs |

When you improve one of these, update the row. That is the whole maintenance burden.

## What this file no longer holds

The test-design decisions, the vacuity traps and the `min-tests` floor procedure moved to [`test-integrity.md`](test-integrity.md) on 2026-11-04. **None of them were interim.** They describe how tests are written and measured, which does not change when the files stop being copy-pasted — leaving them here would have scheduled them for deletion alongside a file they have no reason to die with.

The `Install-PSResource` pinning mechanics, the NuGet-range trap and the `AWSAutomation` runtime-dependency caveat were already stated in [`dependency-stack.md`](dependency-stack.md). The copies here were duplicates, and are gone rather than moved.

What remains above is the only genuinely interim thing this file carried: a map of which repo currently holds the best version of each copy-pasted piece. [#20](https://github.com/jjohns-dev/pwsh-module-ci/issues/20) is what makes that question obsolete, and this file with it.
