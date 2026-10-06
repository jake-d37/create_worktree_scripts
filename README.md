# create_worktree_scripts

Bash scripts for spinning up (and tearing down) git worktrees across an Android app repo, an iOS app repo and an Appium test repo — one at a time, or all three at once for a QA feature.

Each new worktree also gets copies of the local, gitignored files it needs to build or run (SDK paths, secrets, local tool settings) copied over from the main checkout.

## Scripts

| Script | What it does |
|---|---|
| `create_mobile_worktree.sh` | Creates a single worktree for one repo |
| `create_qa_suite_worktree.sh` | Creates matching worktrees for all three repos under one feature folder |
| `remove_worktree_suite.sh` | Removes a feature's worktrees (and optionally their branches) |

## Setup

1. Copy the example config and fill it in:

   ```bash
   cp .env.example .env
   ```

   ```bash
   WORKTREE_DIR_PATH="$HOME/worktrees/"

   ANDROID_REPO_PATH="$HOME/repos/my-android-app"
   IOS_REPO_PATH="$HOME/repos/my-ios-app"
   APPIUM_REPO_PATH="$HOME/repos/my-appium-tests"

   ANDROID_GITIGNORED_FILES=(
       # paths relative to ANDROID_REPO_PATH
       local.properties
   )
   IOS_GITIGNORED_FILES=(
       # paths relative to IOS_REPO_PATH
       Config/Secrets.xcconfig
   )
   APPIUM_GITIGNORED_FILES=(
       # paths relative to APPIUM_REPO_PATH
       .env
   )
   ```

   `.env` is gitignored, so your local paths stay out of the repo.

2. (Optional) Add the folder to your `PATH` so the scripts run from anywhere — e.g. in `~/.zshrc`:

   ```bash
   export PATH="$HOME/path/to/create_worktree_scripts:$PATH"
   ```

   Add the folder itself rather than symlinking the scripts elsewhere: they find `.env` (and each other) relative to their real location.

> **Note:** `.env` is loaded with `source`, so it's really a bash file — `$HOME` expands and arrays work, but it won't parse with standard dotenv tools.

## Usage

### Create one worktree

```bash
create_mobile_worktree.sh --repo <android|ios|appium> --worktree-dir <feature> --branch <branch>
```

Creates `WORKTREE_DIR_PATH/<feature>/<repo>_<feature>`, then copies in that repo's gitignored files. Files that don't exist in the main checkout are skipped with a warning.

Branch handling:
- **Exists locally or on `origin`** → checked out (remote branches are tracked automatically)
- **Doesn't exist** → created from the main checkout's current `HEAD`

Fails if the worktree folder already exists.

### Create a QA suite (all three repos)

```bash
create_qa_suite_worktree.sh --feature <feature> --ticket <ticket-ref> --branch-base-name <name>
```

Example:

```bash
create_qa_suite_worktree.sh --feature login-tests --ticket abc-123 --branch-base-name login-tests
```

```
WORKTREE_DIR_PATH/login-tests/
├── appium_login-tests    → abc-123/login-tests
├── android_login-tests   → abc-123/qa-login-tests
└── ios_login-tests       → abc-123/qa-login-tests
```

The app repos get a `qa-` prefixed branch so QA tweaks stay separate from the test branch.

Once all three exist, any `ANDROID_REPO_PATH` / `IOS_REPO_PATH` paths in the Appium worktree's copied `.env` are rewritten to point at the new Android/iOS worktrees, so the tests run against the worktree builds rather than the main checkouts. (The main Appium repo's `.env` isn't touched.) Build each app worktree before running tests — the script prints their paths at the end.

The script stops at the first failure, and any worktrees created before that point are left in place. Clean them up with `remove_worktree_suite.sh` before re-running.

### Remove a suite

```bash
remove_worktree_suite.sh --feature <feature> [--delete-branches]
```

- Runs `git worktree remove` on each `<repo>_<feature>` worktree; missing ones are skipped, so it's safe to re-run.
- Worktrees with uncommitted changes are **not** removed — commit, stash, or remove them manually with `git worktree remove --force`. The script carries on with the others and exits non-zero, listing what failed.
- `--delete-branches` also deletes each worktree's branch with `git branch -d`, which refuses unmerged branches. Use `git branch -D` manually if you're sure.
- The feature folder is removed only once it's empty.

## Requirements

- bash (macOS's built-in 3.2 is fine)
- git 2.22+ (for `git worktree remove` and `git branch --show-current`)
