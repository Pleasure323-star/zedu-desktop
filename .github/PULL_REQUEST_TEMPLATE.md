## Ticket

<!-- Link to the approved ClickUp/Linear ticket. -->

## Team lead

<!-- @handle of your team lead. A lead registered for your fork's org must approve before the Lead approved check passes and Zedu reviewers pick it up. -->

@

## What changed

<!-- Short summary of the change. -->

## Why

<!-- The problem or reason this ticket exists. -->

## How to test

<!-- Numbered steps a reviewer can follow to verify the change themselves. -->

1.

## What to expect

<!-- The expected behaviour after following the steps above. -->

## Backend

<!-- Leave this section empty: your fork's build runs against the dev backend.
     Only if this PR needs backend work that isn't on dev yet, add a line here starting with "Backend URL:"
     followed by that backend's host, for example https://api.<team>.groups.zedu.chat. Your build then uses
     that backend, and the Backend dependency check blocks merging until the backend lands on dev and you
     delete the line (then re-run PR build in your fork). -->

## Test evidence

<!-- The Fork build check posts your build links automatically. Say which backend you tested against.
     Say whether unit/widget/integration tests were added or updated for what this ticket changed, and why if not. -->

- Tested against:
- Tests:

## Screenshots / recording

<!-- Required for visible or interactive changes. Otherwise write "N/A, non-visual change". -->

## Checklist

- [ ] Linked to an approved ticket
- [ ] Only intended files changed; no protected files without reviewer agreement
- [ ] No secrets or debug code committed
- [ ] Tests added/updated for what this ticket changed (not retroactive coverage of unrelated code)
- [ ] Fork build triggered (first run: fork → Actions → PR build → Run workflow)
- [ ] Team lead approved this PR
- [ ] Self-reviewed (`git status` / `git diff`)
