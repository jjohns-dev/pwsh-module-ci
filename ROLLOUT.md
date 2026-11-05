# Rollout tracker

**Temporary working file. Delete it when the last box is checked.** It exists to coordinate one batch of cross-repo work; it is not a permanent part of this repo and nothing reads it.

Authoritative detail lives in the linked issues — this is an index and an ordering, not a substitute. Where the two disagree, the issue wins.

## Where we are

Phase numbers are **names, not a sequence**. They were assigned before #22 moved and before the Phase 2B debt surfaced, and they are cited from issue bodies and merged PRs, so they are not being renumbered. The table below is the running order, agreed 2026-11-04.

| | Phase | State |
| - | ----- | ----- |
| ✓ | **1**, **2**, **2B**, **7** | complete 2026-10-27 to 10-29. Narratives drained 2026-11-04; the issues and PRs are authoritative |
| ✓ | **3** — make regressions visible | complete 2026-11-03. The floor measures **executed**, shipped as `v1.5.0` and live fleet-wide |
| ✓ | **4** — close the tracker issue | complete 2026-11-03 — #17 closed after auditing every box against the repos |
| ✓ | **8** — drain this file | **complete 2026-11-04** — [#43](https://github.com/jjohns-dev/pwsh-module-ci/issues/43), closed. 391 lines to 117 |
| ✓ | [#27](https://github.com/jjohns-dev/pwsh-module-ci/issues/27) | **complete 2026-11-04** — `pssa-sarif.yml` moved to `Install-PSResource`, released as `v1.5.1`, `v1` moved and verified on a live consumer run |
| → | **5** — stop the duplication | **next.** [#24](https://github.com/jjohns-dev/pwsh-module-ci/issues/24) only. #20 comes in its own time, not as part of this |
| | **6** — migration | #19, then #21 |
| | [#9](https://github.com/jjohns-dev/pwsh-module-ci/issues/9) | parked deliberately until Phases 5 and 6 inform it, and may be absorbed by them |
| | **Final phase** — delete this file | once it has nothing left to carry |

Completed phases are closed. New work goes in a later phase or a new one, never back into a phase already marked done — Phase 2B exists because that rule was applied rather than reopening Phase 1.

**The table above is the running order. The section order below is not** — sections sit where their phase number put them, and phase numbers are names. Read the table to find what is live; read a section for its detail.

## Phase 5 — Stop the duplication

**`jjohns-dev` repos only.** `PS-MCS` is downstream: changes are incubated and vetted here, then promoted, so its repos are not in scope for this phase and will pick the work up with that promotion.

- [ ] **pwsh-module-ci** — [#24](https://github.com/jjohns-dev/pwsh-module-ci/issues/24)
  Converge the fleet off `BuildHelpers`. Prep for #20 — it removes one known `Build/` difference before the classification work starts.
  **Re-scoped 2026-11-04, and it is smaller and different than this said.** Measured across the seven `jjohns-dev` repos: **none declares, imports, installs or calls `BuildHelpers`** — `Set-BuildEnvironment` appears zero times. Each repo assigns `$env:BHProjectPath`, `$env:BHProjectName` and `$env:BHPSModuleManifest` itself, identically. So what remains is a **naming fossil, not a dependency**, and because the three assignments are identical fleet-wide it removes no `Build/` difference either. Full measurement on the issue.
  **`AWSAutomation` half complete 2026-11-04** — [#106](https://github.com/jjohns-dev/AWSAutomation/pull/106), squashed to `2e6e7fb`. Dropped the unused `PlatyPS` pin, **amended** ADR-0002 rather than superseding it, and gave that ADR the do-not-copy caveat the Phase 8 row below found missing. It also took `psake 4.9.1 → 5.0.4` and `PSScriptAnalyzer 1.24.0 → 1.25.0`, both current PSGallery latest — `AWSAutomation` was the last module repo in the fleet on psake 4.x, and the major bump needed no change to `build.psake.ps1`. Post-merge run on `main` green, 444 executed with `disabled=0` on both sides.
  **What is left is one decision, and it is already taken: do not rename the `$env:BH*` variables.** Roughly 130 call sites, no behaviour change, and #20 may replace the files that carry them. Recording that on the issue is what closes it.
- [ ] **pwsh-module-ci** — [#20](https://github.com/jjohns-dev/pwsh-module-ci/issues/20)
  Stop duplicating `Build/` **and** `Tests/Common/`. Diff the test template only after Phase 1–2 lands, or you classify drift against a moving baseline.

## Phase 6 — Migration

- [ ] **pwsh-module-ci** — [#19](https://github.com/jjohns-dev/pwsh-module-ci/issues/19) — gated on Phases 1–5
  psake → Sampler. Design for SecurityTools' per-leg test scope from the start, migrate that repo last.
- [ ] **pwsh-module-ci** — [#21](https://github.com/jjohns-dev/pwsh-module-ci/issues/21) — gated on #19
  Centralize SecurityTools CI. Current lean is a second reusable workflow rather than extending `ci.yml`.

## Phase 8 — Drain this file

The header says to delete this file when the last box is checked, which is right about the file and wrong about its contents: several sections were the only written record of something measured once and expensive to re-derive. The "Found during the rollout" section already conceded the point — it exists *"so they are not lost when this file is deleted."*

So this phase is a drain, not a `git rm`. **Nothing is deleted until its destination is named**, and a destination means a merged commit rather than an intention. Deleting the file is a separate, later phase; see the end of this document.

**Considered and rejected: moving this file to `docs/specs/`.** It is not a spec — no requirements, no design, and the task list is a byproduct rather than the artifact. It was written during and after execution rather than before, so filing it as one would imply approval gates that never happened. The decisive objection is the third: `docs/specs/` is read as *current intent*, and this file disclaims authority in its own header — *"Where the two disagree, the issue wins."* A permanent, unmaintained, non-authoritative document in a directory agents treat as intent is how stale guidance gets manufactured. `docs/adr/` is already this repo's mechanism for the durable half.

- [x] **Disposition pass**, one row at a time. **Complete 2026-11-04**, worked as [#43](https://github.com/jjohns-dev/pwsh-module-ci/issues/43) items 0–5.

  | Section | Destination |
  | ------- | ----------- |
  | Phase table, every checkbox, all sequencing and gating | **kept until the end** — it is this file's remaining job, and the final phase takes it |
  | Per-repo phase narratives | ✓ **done 2026-11-04** — deleted; the issues and PRs are authoritative. Recoverable with `git show <this PR's merge commit>^:ROLLOUT.md` |
  | `Install-PSResource` exact-pin and NuGet-range traps | ✓ **done** — already stated in `docs/dependency-stack.md`; the copies here and in `shared-ci-standards.md` were duplicates, so deleted rather than moved |
  | Floor, vacuity and measurement traps | ✓ **done 2026-11-04** — [`docs/test-integrity.md`](docs/test-integrity.md) |
  | The opportunistic-floor blind spot | ✓ **done 2026-11-04** — [ADR-0005](docs/adr/0005-floor-sweeps-scoped-by-repo-list.md) |
  | Repo-local gotchas | ✓ **done 2026-11-04 — nothing to move.** Measured: no repo-local gotcha remained here, and no `AGENTS.md` in the seven `jjohns-dev` repos asserts anything the rollout invalidated — zero stale `PSDepend` or `Install-Module` claims. This row always said *verified in the repo rather than copied across*, so the repo was the source, not this file. The three `PS-MCS` repos with no `AGENTS.md` at all are [mcssec-ops#154](https://github.com/PS-MCS/mcssec-ops/issues/154) |
  | GitHub ruleset mechanics — `PUT` not `PATCH`, and no classic branch protection anywhere in the fleet | ✓ **done 2026-11-04** — `AGENTS.md`, under *Gotchas that have bitten here* |
  | Anything still open | ✓ **done 2026-11-04** — each open item is carried by its own issue: [#24](https://github.com/jjohns-dev/pwsh-module-ci/issues/24), [#34](https://github.com/jjohns-dev/pwsh-module-ci/issues/34), [PS.DCU#20](https://github.com/jjohns-dev/PS.DCU/issues/20), [mcssec-ops#154](https://github.com/PS-MCS/mcssec-ops/issues/154) |
  | `mcssec-ops` cannot be staged; the copies of the verify step | ✓ **done 2026-11-04** — [#20](https://github.com/jjohns-dev/pwsh-module-ci/issues/20), with the copy count re-measured at **5**, not four |
  | `AWSAutomation`'s ADR-0002 caveat | ✓ **drained 2026-11-04** — but the confirmation this row asked for **failed**: the caveat was *not* in that repo's ADR. Removing it from here was safe only because [`docs/dependency-stack.md`](docs/dependency-stack.md) states it independently. **Resolved 2026-11-04** — [#106](https://github.com/jjohns-dev/AWSAutomation/pull/106) added it to that ADR's Consequences |

Deleting `ROLLOUT.md` itself is **not** a row in this phase. It moved to the **Final phase** at the end of this document, because it is gated on far more than the drain.

**Two things that looked like they needed a retrospective, and do not.** Checked 2026-11-03, and the check corrected a row above.

**The traps were already written — in a file scheduled for deletion. Resolved 2026-11-04.** `docs/shared-ci-standards.md` declares itself *"Interim scaffolding. Delete it when #20 lands"* while carrying lessons that are in no way interim, so they were carved into [`docs/test-integrity.md`](docs/test-integrity.md) exactly as `dependency-stack.md` was carved out before it.
**It was more than the four traps this row originally named.** Reading the file properly showed that only the reference-implementations table dies with #20; the test-design decisions, the floor procedure and the mutation rule all survive it. `shared-ci-standards.md` is now that table plus a pointer. The move also fixed a self-contradiction it had been carrying — one bullet derived the floor margin from the **collected** count while another, four lines later, said a floor must be derived from the **executed** count.

**The evidence catalogue belongs on [#34](https://github.com/jjohns-dev/pwsh-module-ci/issues/34), not in a doc.** #34 makes the argument but names its evidence in a single sentence — four defects, no links, no commits. Its decisive checkbox asks whether `PSMutant` would have caught the defects already fixed, and answering it needs the actual list: repo, pre-fix commit, what the defect was, and the mutation that proved it red. Evidence serving a pending decision has a home; a free-floating retrospective would be the same content with nowhere to act on it.

**So: no retrospective.** What looked like a page-sized gap is a misfiled set of traps plus a thin evidence section on an open issue.

## Found during the rollout, deliberately not folded into it

Each of these was surfaced by rollout work, is independent of it, and would have expanded a phase's scope if bundled. Recorded here so they are not lost when this file is deleted.

- [x] **`SecurityTools` has no `.gitattributes`** — [SecurityTools#161](https://github.com/jjohns-dev/SecurityTools/issues/161), opened 2026-11-02, **closed 2026-11-03**
  **72 tracked files were CRLF; zero are now.** Surfaced when [#160](https://github.com/jjohns-dev/SecurityTools/pull/160) had to split into two commits — one pure EOL conversion, one real change — just to keep the substantive diff legible. Measured across the fleet: 22 of 23 workflow files in the 8 `jjohns-dev` repos are LF, and `validate.yml` was the single exception *and* the odd file inside its own repo. Done **before** [#21](https://github.com/jjohns-dev/pwsh-module-ci/issues/21), as planned.
  Landed as [#163](https://github.com/jjohns-dev/SecurityTools/pull/163), squashed to `6bf77d4`, then [#164](https://github.com/jjohns-dev/SecurityTools/pull/164) → `8d3d72d` for `.git-blame-ignore-revs` and an `AGENTS.md` note. Both post-merge runs green.
  **The safety argument was made properly**: `git diff --ignore-cr-at-eol` empty across the renormalisation, *plus* a control proving that command can return non-empty against a real content change. An empty diff from a command that cannot report a difference would have proved nothing. Test counts identical before and after on both legs (997/1 and 21/0), so the floors never moved.
  **Blame attribution moves, but only partly.** Measured against the real squash commit: 5,514 → 596 across the 72 files, and every remaining line is blank — git's ignore-revs matching does not reassign blank lines. The issue body implied attribution returns wholesale to the original authors; it does not. Independently re-measured here at 5,528 → 610 over all 73 files the commit touched, the 14-line difference being `.gitattributes` itself.
  **Two sequencing traps, both caught before they bit.** The `.git-blame-ignore-revs` entry had to name the **post-merge squash SHA**, which does not exist until the merge — this repo allows squash only, so the pre-merge commit SHAs would have matched nothing. And #163 deliberately said *"Part of #161"* rather than *"Closes"*, so the issue stayed open to carry the blame follow-up rather than taking it to the grave.
- [ ] **`PS.DCU` has no behavioural tests** — [PS.DCU#20](https://github.com/jjohns-dev/PS.DCU/issues/20), opened 2026-11-02
  Its 85 tests are `Meta` 42, `Help` 32, `Manifest` 11 — the only three test files in the repo, none using `Mock`, none executing module logic — against 12 source files carrying 25 `dcu-cli` and 24 `System.Management` references. Found while questioning whether the Windows-only switch was justified. **Its `min-tests` floor guards metadata coverage, not behaviour**, and nothing in the rollout changes that.
- [ ] **Evaluate `PSMutant`** — [#34](https://github.com/jjohns-dev/pwsh-module-ci/issues/34), opened 2026-11-02
  Every test-authoring defect this rollout fixed shared one shape: an assertion that could not fail. Each was caught by a human reading the test and proving it by hand — which is mutation testing, executed one mutant at a time. `PSMutant` 0.9.1 was published 2026-10-26. **Independent of [#19](https://github.com/jjohns-dev/pwsh-module-ci/issues/19)**: a build framework operates at a different layer, and #19 already records that Sampler *"would have prevented none of"* these defects.
- [x] **Remove the unused `PlatyPS` pin** — folded into [#24](https://github.com/jjohns-dev/pwsh-module-ci/issues/24), **complete 2026-11-04**
  Pinned at `0.14.2` in `AWSAutomation` and **never invoked** — no `New-MarkdownHelp`, no `en-US/`, no docs task, `HelpInfoURI` commented out. Same category as the `BuildHelpers` work already in that issue. Its ADR-0002 justifies the pin on a premise that cannot hold for an uncalled tool, so that ADR needed an **amendment, not a superseding ADR** — the decision stands, one item in its enumeration was wrong.
  Landed as [#106](https://github.com/jjohns-dev/AWSAutomation/pull/106) → `2e6e7fb`. The amendment corrects the Decision in place and deliberately leaves Context alone, since Context records the forces as they stood on 2026-10-28. Verified exhaustively rather than by sampling: across all 86 blobs at head, the only remaining `PlatyPS` mentions are the amendment note and that untouched Context bullet, and the name appears nowhere in the post-merge run log.
- [ ] **Three `PS-MCS` repos have no `AGENTS.md`** — [mcssec-ops#154](https://github.com/PS-MCS/mcssec-ops/issues/154), opened 2026-11-04
  `MCS`, `ArcGISEnterprise` and `PS.ETL` have none; all seven `jjohns-dev` module repos do, at 3,206–9,627 bytes. **Surfaced by this drain, and only because the gate was run properly**: the section being deleted carried a reusable `AGENTS.md` authoring prompt, and checking whether it still had consumers found three. The earlier check had covered only the three repos that section happened to name — the same consumer-graph-not-repo-list error [ADR-0005](docs/adr/0005-floor-sweeps-scoped-by-repo-list.md) is about.
  **Filed in `mcssec-ops`, not here.** `jjohns-dev` is where this was incubated; `PS-MCS` is where the work lands. The prompt moved with it **adapted rather than copied**, since its context section named `jjohns-dev` workflows that do not apply there.

**Not work, a standing caveat — now in `AWSAutomation`'s own ADR-0002, and still in [`docs/dependency-stack.md`](docs/dependency-stack.md).** `AWSAutomation` floats its runtime dependencies to `'latest'`; **do not copy that without re-deriving it**, since it turns on those modules being unversioned `RequiredModules`, which no other repo has. **Phase 8 assumed this caveat was already in that repo's ADR-0002. It was not** — checked 2026-11-04, that ADR recorded the decision but carried no do-not-copy warning, so deleting on that premise would have lost it. **Added 2026-11-04** as a Consequences bullet by [#106](https://github.com/jjohns-dev/AWSAutomation/pull/106), so it now travels with the decision it qualifies instead of depending on a file in another repo.

## Reference — moved out

The floor procedure, the mutation rule, the vacuity traps and the `-ceq` distinction moved to [`docs/test-integrity.md`](docs/test-integrity.md) on 2026-11-04, along with the whole non-interim half of `docs/shared-ci-standards.md`. Read that file; these rules are no longer duplicated here.

**Deleted rather than moved**, and worth recording why. The two #22 / #23 sequencing traps went: both issues are closed, and their only durable content — which repos have `disabled` tests — is now in `test-integrity.md`. That section also carried a **superseded measurement**, `PS.SSL` at executed 361 / 362 against a floor of 337 from 2026-10-29, where the correct later pair was 346 / 347 against 350; copying the old one forward would have propagated the wrong number. The PSDepend migration rule went too — all ten repos are migrated, so it is a completed instruction rather than a standing one, and its two carry-forward facts are in [`docs/dependency-stack.md`](docs/dependency-stack.md).

## Final phase — Delete this file

**Not "Phase 9", and not "Phase X"** — X reads as Roman numeral 10 among numbered phases. This is the only unnumbered phase, because it is the only one whose position cannot change.

Gated on everything: the drain ([#43](https://github.com/jjohns-dev/pwsh-module-ci/issues/43)), then [#27](https://github.com/jjohns-dev/pwsh-module-ci/issues/27)'s remaining half, then Phase 5, then Phase 6, then [#9](https://github.com/jjohns-dev/pwsh-module-ci/issues/9). The file stays until all of those are done, because it still carries the Phase 5 and Phase 6 sections and the running order at the top.

- [ ] **Delete `ROLLOUT.md` from `main`**, in its own PR, once nothing here is unrecorded elsewhere.

Two things worth stating in that PR rather than assuming:

- **Deleting it does not lose the content.** `git show <merge-sha>^:ROLLOUT.md` retrieves the last complete version, and every drained section names its destination in the disposition table above.
- **The running order is the one thing with no other home.** Either it is finished by then, or it moves to an issue before the file goes — otherwise deleting this file loses the sequence rather than the history.
