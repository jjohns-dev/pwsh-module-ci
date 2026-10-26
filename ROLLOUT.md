# Rollout tracker

**Temporary working file. Delete it when the last box is checked.** It exists to coordinate one batch of cross-repo work; it is not a permanent part of this repo and nothing reads it.

Authoritative detail lives in the linked issues — this table is an index and an ordering, not a substitute. Where the two disagree, the issue wins.

## Work

| Done | Phase | Repo | Issue | Gated on | Notes |
| ---- | ----- | ---- | ----- | -------- | ----- |
| [ ] | 1 | PS.Log | [PS.Log#54](https://github.com/jjohns-dev/PS.Log/issues/54) | — | Zero matching-help cases collected. Discovery+AST, defects 1/2/3, floor. One PR, floor measured last |
| [ ] | 1 | PS.SSL | [PS.SSL#71](https://github.com/jjohns-dev/PS.SSL/issues/71) | — | Same as PS.Log. Floor semantics affected by #23 — uses `Describe -Skip:` on openssl/network |
| [ ] | 1 | SecurityTools | [SecurityTools#153](https://github.com/jjohns-dev/SecurityTools/issues/153) | — | Same, **plus add the verify step** — only repo with none. Per-leg floor. Affected by #23 |
| [ ] | 2 | AWSAutomation | [AWSAutomation#97](https://github.com/jjohns-dev/AWSAutomation/issues/97) | — | Reference implementation. **Only repo with an existing floor (560) — re-derive in the same PR** |
| [ ] | 2 | ArcGISEnterprise | [ArcGISEnterprise#143](https://github.com/PS-MCS/ArcGISEnterprise/issues/143) | — | Count already looks correct, so nothing surfaces it. Defects 1/2/3 + floor unset |
| [ ] | 2 | MCS | [MCS#212](https://github.com/PS-MCS/MCS/issues/212) | — | Defect 3 only. Deletion drops CrossPlatform 495→444, below the 445 floor — re-derive in same PR |
| [ ] | 3 | pwsh-module-ci | [#23](https://github.com/jjohns-dev/pwsh-module-ci/issues/23) | — | Floor counts skipped tests. **Also apply to `mcssec-ops`.** Staged rollout via immutable tag. Ideally before the two Phase-1 floors |
| [ ] | 3 | PS.GHOps | [PS.GHOps#19](https://github.com/jjohns-dev/PS.GHOps/issues/19) | — | Floor only. No `Help.Tests.ps1` |
| [ ] | 3 | PS.GitHub | [PS.GitHub#37](https://github.com/jjohns-dev/PS.GitHub/issues/37) | — | Floor only. No `Help.Tests.ps1` |
| [ ] | 3 | PS.DCU | [PS.DCU#16](https://github.com/jjohns-dev/PS.DCU/issues/16) | — | Floor **+ stale-help detection**. Best-shaped file in the fleet — do not convert it to `-ForEach` |
| [ ] | 4 | pwsh-module-ci | [#17](https://github.com/jjohns-dev/pwsh-module-ci/issues/17) | Phases 1–3 | **Close it.** PS.ETL, PS.DCU and the Open question are already re-homed |
| [ ] | 5 | pwsh-module-ci | [#20](https://github.com/jjohns-dev/pwsh-module-ci/issues/20) | Phases 1–2 | Stop duplicating `Build/` **and** `Tests/Common/`. Diff the test template only after Phase 1–2 lands |
| [ ] | 6 | pwsh-module-ci | [#19](https://github.com/jjohns-dev/pwsh-module-ci/issues/19) | Phases 1–5 | psake → Sampler. Design for SecurityTools' per-leg scope early, migrate it last |
| [ ] | 6 | pwsh-module-ci | [#21](https://github.com/jjohns-dev/pwsh-module-ci/issues/21) | #19 | Centralize SecurityTools CI. Lean is a second reusable workflow, not extending `ci.yml` |
| [ ] | 7 | pwsh-module-ci | [#22](https://github.com/jjohns-dev/pwsh-module-ci/issues/22) | Phases 1–2 | Stop generating link-test cases with no `.LINK`. Same `It` block as Phases 1–2 |
| [ ] | — | PS.ETL | [PS.ETL#22](https://github.com/PS-MCS/PS.ETL/issues/22) | — | Own clock. Pester 5.5.0 → 6.2.0 first. Decoupled from #17, blocks nothing |

## Two sequencing traps

**#22 edits the same `It` block as Phases 1–2.** Do it with them, or well after — never between, or you rebase the same block twice.

**#23 changes floor semantics for the only two repos that use `-Skip`** (PS.SSL, SecurityTools). Everywhere else `tests` and executed counts are identical, so it does not matter. Either land #23 first or accept re-deriving those two floors.

## Along the way

Three repos have no `AGENTS.md` and are receiving non-trivial PRs: **PS.Log**, **PS.SSL**, **PS.DCU**. Writing one before starting each is cheap and pays off on every later session in that repo. Budget ~3,500 bytes; `AWSAutomation` (4,548) and `PS.GHOps` (4,543) are the calibration, `PS.GitHub` (9,627) is too long.

## Recurring rules for every PR in Phases 1–3

- **Fix first, measure second, set the floor third.** A floor derived before the fix records the defective count as the baseline.
- **Acceptance is the mutation, not the count.** Make the thing you are guarding fail, confirm red, revert. A check that never fires is indistinguishable from one that passes.
- **Verify floors in both directions.** An impossible floor must fail the run *and* leave the result XML uploaded; a correct floor must stay quiet.
