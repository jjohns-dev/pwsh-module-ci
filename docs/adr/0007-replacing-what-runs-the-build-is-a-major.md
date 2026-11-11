# ADR 7: Replacing What Runs a Consumer's Build Is a Major Version

Amends: ADR-0002

## Status

Accepted — 2026-11-10

## Context

- ADR-0002 defines a breaking change as one that stops a consumer's call from working, and bumps the major version only for that. A change that leaves the call valid is a minor or a patch, even when it changes the consumer's CI outcome; such changes are staged behind an immutable `vX.Y.Z` pin.
- The centralized harness (#20, ADR-0006) leaves every input and job name unchanged, so by ADR-0002's test it is a minor. But it replaces what runs the build: a consumer's own `Build/` is ignored and the harness here runs instead.
- Shipped on `v1`, it would change every unmigrated consumer the moment `v1` moved. PS.SSL would stop excluding its `Network` tests, since it would have no `harness.psd1` yet, and any repo whose vendored build differs from the harness would change behaviour without its own PR. The spec's criterion 6 forbids that.
- The alternatives each cost more: an input switch on `v1` carries two code paths in every workflow, and removing the switch later is itself a major under ADR-0002 unless it stays as a no-op; an exact-version pin needs seven repoint PRs and still ends in one fleet-wide `v1` move.
- Consumers read the major in their caller. A distinct major would show which mechanism a repo is on without any other record.
- All seven consumers run Dependabot on `github-actions`, which keeps reusable-workflow references current. Whether it proposes a `@v1` → `@v2` jump for a reusable workflow is unverified; it does for actions.

## Decision

- We will release a change that **replaces what runs a consumer's build** as a new major version, even when the consumer's call still works. ADR-0002's definition of breaking stays in force for every other change.
- We will apply it first to the centralized harness: `v2.0.0` with a moving `v2` tag. `v1` never moves onto the harness.
- We will migrate a consumer by repointing all three of its callers from `@v1` to `@v2` in one PR, with no input switch and no interim exact-version pin.
- We will keep `v1` on `v1.6.x` for unmigrated consumers, cut any urgent fix for them from a branch off `v1.6.1`, and retire `v1` once the last consumer has moved.
- We will close any Dependabot PR that repoints a consumer to `@v2` outside its migration PR.

## Consequences

- **Positive** — no single tag move changes all seven repos at once; each consumer changes in its own reviewed PR.
- **Positive** — `@v2` in a caller records that the repo is on the harness, and `@v1` that it still vendors its own build.
- **Positive** — no closing round of repoint PRs, which an exact-version pin would have needed.
- **Negative** — two major lines run in parallel until the last migration lands, and an urgent fix for unmigrated repos needs a maintenance branch because `main` carries `v2`.
- **Negative** — "replaces what runs the build" is a judgement call with no test attached, like ADR-0002's "materially different behavior"; a future change will have to argue which side it falls on.
- **Negative** — a Dependabot `@v2` PR, if merged by mistake, half-migrates a repo: it runs the harness with its old `Build/` still present and no `harness.psd1`. Closing them is an obligation nothing enforces.
