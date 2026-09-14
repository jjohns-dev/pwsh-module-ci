# ADR 1: Centralized Reusable CI Workflows for PowerShell Module Repos

## Status

Accepted — 2026-09-14

## Context

- Seven PowerShell module repos (`PS.Log`, `PS.GHOps`, `PS.GitHub`, `PS.SSL`, `PS.DCU`, `AWSAutomation`, `SecurityTools`) each ran their own near-identical Actions workflows for build, analyze, test, and release.
- Each repo independently pinned the same third-party actions (`actions/checkout`, `actions/upload-artifact`, `dorny/test-reporter`, `github/codeql-action`, `softprops/action-gh-release`), so one action release produced one Dependabot version-update PR **per repo**.
- That per-repo PR volume produced notification fatigue for a single maintainer, which reduced the attention paid to each individual update — the opposite of the intent.
- The real build logic already lives in each repo's `Build/build.ps1` (psake); the workflows only standardize how those tasks are invoked in CI.
- Consumer repos still require local control of triggers, `permissions:`, and a few inputs (`os-matrix`, `enable-test-report`, `artifact-name`, `psscriptanalyzer-settings-path`).
- Dependabot resolves `uses:` references only one level deep: it inventories the workflow files in a repo, not the dependencies of any reusable workflow those files call.

## Decision

- We will host the shared `ci.yml`, `release.yml`, and `pssa-sarif.yml` as reusable workflows in this repo, and consumer module repos will call them instead of defining their own equivalents.
- We will keep every third-party action pin here, so an action version bump is reviewed and merged once in this repo rather than once per consumer.
- Consumers will pin to the floating `@v1` tag; non-breaking releases and action bumps land automatically, while a breaking change to inputs or job structure bumps to `v2` and consumers migrate on their own schedule.
- Consumers retain their own triggers, `permissions:` blocks, and optional `with:` inputs.

## Consequences

- **Positive** — a third-party action bump is one PR here instead of seven, which is what removed the notification fatigue that motivated the change.
- **Positive** — CI behavior is consistent across every module repo by construction, and a fix reaches all consumers on their next run with no per-repo change.
- **Negative** — Dependabot alerts for the pinned actions fire **only in this repo**. Consumers inherit the coverage but have no local visibility: a consumer's dependency graph contains just `jjohns-dev/pwsh-module-ci`, so a vulnerable action executing in its CI never appears in its own Security tab.
- **Negative** — `@v1` is a mutable reference. Consumers run whatever it points at without review, so a mistaken or malicious commit here propagates to all seven repos automatically; this repo's blast radius is now the entire module fleet.
- **Negative** — this repo is a single point of failure: an error in a shared workflow breaks every consumer's CI at once.
- **Neutral** — consumer-visible changes now require a release here, and breaking ones require a coordinated `@v2` migration across seven repos.
- **Neutral** — this repo's `CODEOWNERS` and Dependabot configuration become the control points for the whole fleet's CI supply chain, and should be reviewed as such.
