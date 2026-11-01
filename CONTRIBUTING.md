# Contributing

Welcome! This guide covers how work gets from a ticket into Zedu Desktop: forks, branches, pull requests, CI, and review. If you've never used these conventions before, don't worry. Read it through once, keep it handy for your first few PRs, and it'll start to feel natural quickly.

---

## The workflow at a glance

There are three repos in the chain, and you only ever work in the bottom one:

```
zeduchat/zedu-desktop              Zedu's repo. Reviewers send batches here.
  └─ zedu-hng/zedu-desktop         Review org. Your PRs land on `dev` here.
       └─ <your-team>/zedu-desktop Your team's fork. You work here.
```

| Branch in `zedu-hng` | Purpose | Who merges |
|---|---|---|
| `dev` (default) | All PRs land here, from teams and reviewers alike. | Reviewers, squash merge |
| `central-staging` | What's ready to go to Zedu; mirrors `zeduchat:central-staging`. | Reviewers promote `dev` → `central-staging` |

The full cycle for any piece of work:

1. Pick up an **approved** ticket in ClickUp or Linear. No ticket, no work.
2. Sync your fork's `dev` from `zedu-hng`.
3. Create a ticket branch, do the work, and test it against the live backend.
4. Open **one PR** from your ticket branch into `zedu-hng/zedu-desktop:dev`. One ticket, one person, or a team PR that consolidates several members' work (see *One person per PR* below).
5. Run the first build in your fork (see *How your PR gets built*). Your fork builds every push after that.
6. Your team lead reviews and approves on the PR, and the **Lead approved** check goes green. Then Zedu reviewers review, using your fork's build.
7. Once approved, reviewers squash-merge it into `dev`, and your team syncs.
8. Reviewers promote `dev` → `central-staging` and send it to Zedu. Verify, then close the ticket.

---

## One-time setup (per team)

1. Fork **`zedu-hng/zedu-desktop`** into your team's GitHub org. Not `zeduchat`: forking the wrong one points your PRs and **Sync fork** at the wrong repo. Not a personal account either: the org identifies your team, and PRs from personal forks fail **Lead approved**.
2. In the fork, go to **Actions** and enable workflows. Forks have them off by default, and your PR builds run there.
3. Register your team: your lead sends a Zedu reviewer the org name and every lead's GitHub handle. Reviewers add them to [`teams.yml` in `zedu-hng/zedu-ci`](https://github.com/zedu-hng/zedu-ci/blob/main/teams.yml), one file for every Zedu repo, so a team registered for another repo is already set. Until then, your PRs fail **Lead approved**.
4. Builds need no configuration: CI points them at the live backend (see [How your PR gets built](#how-your-pr-gets-built)). An `APP_ENV_FILE` variable left in the fork from earlier isn't read any more; delete it.
5. Each contributor clones the **team fork**:

```bash
git clone https://github.com/<your-team>/zedu-desktop.git
cd zedu-desktop
cp .env.example .env
flutter pub get
flutter run
```

See the README for configuration and platform setup. Never commit `.env`.

Set `API_BASE_URL` in your `.env` (or pass `--dart-define=API_BASE_URL=...`) to the live backend, `https://api.zedu.chat/api/v1/`, or to your team's backend while you build backend work that isn't on dev yet. Don't leave the `.env.example` value: it points at Zedu's own staging, which bootcamp work never touches. The values CI uses are in [`build/zedu-desktop.env`](https://github.com/zedu-hng/zedu-ci/blob/main/build/zedu-desktop.env).

---

## Working on a ticket

```bash
# 1. Sync the fork: GitHub "Sync fork" button on your fork's dev, then:
git checkout dev
git pull origin dev

# 2. Create your ticket branch
git checkout -b feat/123-dark-mode-toggle

# 3. Do work, commit
git add <files>
git commit -m "feat: add toggle component"

# 4. Push to your fork, then open a PR into zedu-hng:dev
git push -u origin feat/123-dark-mode-toggle
```

---

## Branch naming

Format: `type/<ticket-id>-short-description`

```
feat/123-dark-mode-toggle
fix/245-crash-on-empty-project
chore/190-bump-flutter
refactor/301-extract-file-loader
docs/110-setup-instructions
```

**Types:**

| Type       | When to use it                                              |
|------------|-------------------------------------------------------------|
| `feat`     | New functionality the user can see                          |
| `fix`      | Bug fix                                                     |
| `refactor` | Restructuring code without changing behaviour               |
| `chore`    | Dependency bumps, config changes, build tweaks              |
| `docs`     | Documentation only                                          |
| `test`     | Adding or fixing tests, no production code change           |
| `perf`     | Performance improvement                                     |
| `security` | Security hardening                                          |

**Rules:**

- Always include the ticket ID from ClickUp or Linear.
- Lowercase, hyphen-separated. No spaces, no underscores, no camelCase.
- 3–5 words after the ticket ID. The PR title carries the full description.
- No personal names (`remi/dark-mode` is an anti-pattern; git already knows who you are).
- One ticket per branch. If you find another problem, open another ticket.
- The **Branch name** check enforces the format on every PR. *(Switched off for now: a consolidated team PR may use any branch format, but should still include the main ticket ID.)*

**One person per PR. Team PRs are allowed for now.** A team can consolidate several members' work into one PR from its fork. The **Single author**, **Branch name** and **Size** checks are switched off for now: they still report, as passed, and can be switched back on. For a consolidated PR, put the main ticket in the branch and in the title and list the other tickets in the description. The earlier rule is kept for when it returns: *each member opens their own PR from their own ticket branch, with no team branches and no combined PRs, so nobody's work is held up by someone else's. The **Single author** check fails a PR with commits from more than one person.* If you commit from several emails, add all of them to your GitHub account (**Settings → Emails**), or they count as different authors. Credit a collaborator with a `Co-authored-by:` trailer instead.

**Dependent tickets:** if ticket B needs ticket A, open B's PR after A merges, then update B from `dev`.

**Testing combinations:** merge ticket branches into a private branch in your fork to test them together if you like. Never open a PR from that branch.

---

## PR titles

Format: `type: short description in present tense, lowercase`

```
feat: add dark mode toggle to settings
fix: prevent crash when opening empty project
refactor: extract file loader into its own module
chore: bump flutter to 3.41.5
docs: explain how to run tests on windows
```

**Rules:**

- Same `type` prefix as your branch. If the branch is `feat/...`, the PR is `feat: ...`.
- **Present tense, imperative mood.** "add", not "added" or "adds". It reads as a command: *this PR will add dark mode*.
- Lowercase after the colon.
- No period at the end.
- Aim for 50 characters, hard cap at 72.

Your PR title becomes the commit message on `dev` when it's squash-merged. This convention is called [Conventional Commits](https://www.conventionalcommits.org/).

---

## Testing

Run the same checks CI runs:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos --fatal-warnings
flutter test
```

Build and run on at least one desktop target (`flutter build macos|windows|linux`).

**What tests you need:**

- **Non-UI code** (business logic, state management, services/API layer, utilities): unit tests for what the ticket changed.
- **UI code:** a widget test for the changed widget. Integration tests only for new or changed *critical* flows (auth, payments, anything data-destructive).
- **Only what your ticket touched.** Not retroactive coverage of pre-existing untested code in the same file. If you notice a real gap, file a separate ticket.

For UI changes, also check the relevant window sizes, keyboard navigation, accessibility labels, and loading, empty and error states.

Then self-review:

```bash
git status
git diff
```

Check that:

- only intended files changed;
- debug code is gone;
- no secrets are committed;
- tests cover what this ticket changed.

---

## Protected files

These are owned by the reviewers. The **Protected files** check fails any PR that changes them, unless a reviewer has agreed it first and added the `config-change-approved` label:

- `.github/` (workflows and templates);
- `AGENTS.md` and `CONTRIBUTING.md`;
- `analysis_options.yaml`;
- `scripts/` (the CI scan scripts);
- secret-like files anywhere: `.env*` (except `.env.example`), keystores, certificates and keys (`.p12`, `.pfx`, `.pem`, `.p8`), provisioning profiles, credential or service-account JSON.

Dependency changes (`pubspec.yaml`, `pubspec.lock`) are fine when the ticket needs them. **Moving or restructuring files needs its own approved ticket**; never mix it into feature work.

---

## How your PR gets built

Your fork builds your PR on its own Actions minutes. Every build talks to the **live backend**, `https://api.zedu.chat`, unless the PR body has a `Backend URL:` line. Reviewers use test accounts.

- **Needs backend work that isn't on dev yet?** Add a line to the PR description, under **Backend**: `Backend URL: https://api.<team>.groups.zedu.chat`. Your build then uses that backend, and the **Backend dependency** check stays red until you delete the line, once the backend change is on dev. Adding, changing or deleting the line after a build makes **Fork build** fail until you re-run PR build in your fork, so the build always matches the description.
- Nothing secret goes into a build: `.env` ships inside the app.

- **Builds run only while your PR is open.** Pushes to a ticket branch without an open PR skip the build, and a PR that only changes Markdown needs no build. It uses your fork's Actions minutes, which are free on public repos.
- **First build:** opening the PR doesn't trigger one. In your fork, go to **Actions → PR build → Run workflow** on your branch, or push a commit. After that, every push builds automatically.
- On your PR, the **Fork build** check finds that build for your latest commit, waits for it, and posts download links and install notes for macOS, Windows and Linux. Reviewers test with those.
- Start a manual build within 30 minutes of opening the PR (or of your last push) and **Fork build** picks it up on its own. Later than that, or to check straight away, comment `/fork-build` on the PR. Comment it too after re-running a failed build in your fork. No build showing at all? Check that Actions is enabled in your fork and that it's synced.

Format, analyze, tests, the security scans, **Branch name**, **Single author**, **Protected files**, **Size**, **PR title**, **PR template**, **Backend dependency** and **Lead approved** run on the PR itself, each as its own check. On a first-time contribution, a maintainer has to approve the run before format, analyze, tests and the scans start; the other checks run straight away.

---

## Opening the PR

Open the PR from your fork's **ticket branch** into **`zedu-hng/zedu-desktop:dev`**. Don't open it from your fork's `dev`: that drags in everything else merged there.

Fill out the PR template (`.github/PULL_REQUEST_TEMPLATE.md`). It loads automatically when you open a PR. The short version:

- **Ticket**: link to the ClickUp or Linear ticket.
- **What changed / Why**: the outcome, and the problem it solves.
- **How to test / What to expect**: steps a reviewer can follow, and the result they should see.
- **Team lead**: their GitHub handle. A bot also comments with your team and requests review from your lead(s). One of them leaves an **Approve** review.
- **Test evidence**: the backend you tested against, and the tests you added or updated. The build link is posted for you.
- **Screenshots / recording**: for any visible or interactive change.

Skip sections that don't apply, but write "N/A because…" so your reviewer can see you thought about it.

---

## Keeping your branch up to date

While you're working, `dev` will move forward as other PRs land. Pull those changes into your branch periodically, especially before opening your PR.

**We use `merge` for this, not `rebase`.** Sync your fork's `dev` first (GitHub **Sync fork** button), then:

```bash
git checkout feat/123-dark-mode-toggle
git fetch origin
git merge origin/dev

# Resolve any conflicts, commit them, push
git push
```

### Why merge and not rebase?

Both are valid ways to stay in sync. Here's the honest tradeoff:

- **Merge** is safer and conceptually simpler. You never rewrite history, so if you get something wrong, nothing is lost. The downside is that your branch ends up with "Merge branch 'dev'…" commits in its history.
- **Rebase** produces a cleaner history but requires `git push --force-with-lease`, and getting it wrong on a shared branch can cause people to lose work.

Because we **squash-merge** PRs into `dev`, the messy merge commits in your branch get thrown away anyway. So we get the clean-history benefit *without* the rebase risk.

---

## How PRs land

- **Your team lead approves first.** **Lead approved** goes green once a lead registered for your fork's org approves. It re-checks as soon as a lead reviews (on a first-time contribution, once a maintainer has approved the run; until then a periodic re-check covers it). Zedu reviewers only pick up PRs with it green.
- A lead who opens their own PR needs another lead's approval. A team with one lead is waived and goes straight to Zedu review.
- If your lead approved somewhere GitHub can't see, a reviewer can add the `lead-verified` label.
- **1 Zedu reviewer approval** is required, and it must come after your last push.
- All checks must pass, including **Fork build**.
- All review threads must be resolved. Don't resolve a thread without actually addressing it.
- Contributors don't merge their own PRs.
- Reviewers **squash-merge** into `dev`: all your commits become one commit, with your PR title as the message. So commit as often and as messily as you like on your branch, but make the PR title good.

After merge, reviewers promote `dev` → `central-staging` with a merge commit, and send `central-staging` to `zeduchat` in batches. Sync your fork's `dev` (**Sync fork**) to pull in what's merged. The ticket goes **MERGED → VERIFIED → CLOSED** once the change is verified.

---

## Security and secrets

Never commit:

- API keys or tokens;
- passwords or private keys;
- signing certificates or provisioning profiles;
- cloud or database credentials;
- `.env` files with real values;
- user data.

`.env` is bundled into the app as an asset, so anything in it is readable by anyone who has the app. Real secrets belong on the backend.

If you expose a secret, deleting it in the next commit is not enough. Tell a reviewer immediately so it can be rotated.

---

## A few extra tips

- **Pull before you start work each day.** It saves you from a painful merge later.
- **Push often.** Pushed code is backed up, and once your PR is open every push builds.
- **Open PRs in draft mode** if you want early feedback before the work is done.
- **Keep PRs small.** A PR with 50 lines of change gets reviewed in 10 minutes. A PR with 500 lines gets a rubber-stamp review or sits for days.
- **If you're stuck, ask.** Use your team channel first, then the project channel. For a blocker, include:
  - the ticket number;
  - what you tried to do;
  - what happened, with the error or build output;
  - what you already tried;
  - what help you need.

---

## Quick reference

```bash
# Start new work (after "Sync fork" on your fork's dev)
git checkout dev
git pull origin dev
git checkout -b feat/123-your-feature

# Save progress (once your PR is open, every push builds in your fork)
git add <files>
git commit -m "feat: message"
git push

# Update from dev while working
git fetch origin
git merge origin/dev

# Ready for review
# → open a PR from your branch into zedu-hng/zedu-desktop:dev, run the first build, ask your lead to approve
```
