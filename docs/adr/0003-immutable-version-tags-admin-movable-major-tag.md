# ADR 3: Version Tags Are Immutable; Only an Admin Can Move a Major Tag

## Status

Accepted — 2026-10-11

## Context

- This repo carries two kinds of tag under one prefix. `vX.Y.Z` tags are documented as **immutable**, and ADR-0002's staging pins depend on that. `v1` is documented as **moving**: it is repointed after every release that consumers have been confirmed against.
- The repository ruleset `protect-release-tags` (id `22409717`) targets `refs/tags/v*` and blocks `update` and `deletion`. It was created on 2026-09-06, alongside the `protect-main` branch ruleset and about ten minutes after `v1` was last moved. No issue, ADR or doc records its intent, and it was never edited afterwards.
- Unlike `protect-main`, it had **no bypass actors**, so `current_user_can_bypass` was `never` even for the owner. The `v*` pattern therefore froze `v1` along with the version tags.
- Nothing needed `v1` to move again until issue #6. On 2026-10-11 `git push --force origin v1` was rejected with `GH013: Cannot update this protected ref`, after every consumer had been confirmed on `v1.3.1`.
- The org baseline (`jjohns-dev/.github`, ADR-0002 and `docs/repo-baseline.md`) gives branch rulesets an admin bypass (`RepositoryRole` / `actor_id` 5 / `always`) as the owner's escape hatch. It does not cover tag rulesets.
- `v1` is what all six consumers execute. Whoever can move it can change the CI of every consumer at once, so it needs at least as much protection as any other tag.
- When rulesets overlap, GitHub aggregates their rules and applies the most restrictive. Its docs do not say whether a bypass granted in one ruleset exempts the actor from another, so protection that depends on how two overlapping rulesets interact rests on undocumented behavior.

## Decision

- We will protect the two kinds of tag with two rulesets whose targets **do not overlap**, both blocking `update` and `deletion`:
  - `protect-version-tags` (id `24893815`) targets `refs/tags/v*.*.*` with **no bypass actors**. No one can move or delete a version tag.
  - `protect-release-tags` (id `22409717`) targets `refs/tags/v*` and excludes `refs/tags/v*.*.*`, with the repository-admin bypass. It covers major tags such as `v1`, which only an admin can move.
- We will **not** rely on overlapping rulesets. The exclude keeps every tag under exactly one ruleset, so no tag's protection depends on how bypass behaves across rulesets.
- We will **not** give the major tag a deletion-only ruleset. That would let anyone with write access repoint the tag every consumer runs, making `v1` the least protected tag in the repo.
- We will recover from a version tag cut on the wrong commit by cutting the next patch version, never by moving or deleting the bad one.

## Consequences

- **Positive** — the documented release process (cut `vX.Y.Z`, confirm consumers, then move `v1`) works again, and moving `v1` stays limited to admins.
- **Positive** — version tag immutability is enforced by the ruleset for everyone, owner included, rather than resting on care. Staging pins can trust it.
- **Positive** — the major-tag ruleset follows the org baseline's existing bypass model rather than introducing a second one.
- **Negative** — a version tag cut on the wrong commit is permanent. It cannot be deleted, stays visible beside the good tags, and keeps serving the wrong commit to anyone pinned to it until they move to the replacement. Check the consumers for such a pin, and never move `v1` onto the bad tag.
- **Negative** — a bypassed push to `v1` is not reviewed. Moving it stays a deliberate manual act, and the ruleset will not catch a wrong target.
- **Negative** — the split depends on two patterns staying complementary. Changing either ruleset's include or exclude can leave a tag covered twice or not at all, and nothing here checks for that.
- **Neutral** — a `vX.Y` tag would fall under the major-tag ruleset and be movable by an admin. ADR-0002 rules out publishing one.
- **Neutral** — granting repository admin is now also the control point for who can move `v1`.
