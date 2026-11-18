# create_worktree_scripts

Bash script for spinning up a git worktree of an Android app repo, an iOS app repo or an Appium test repo.

Each new worktree also gets copies of the local, gitignored files it needs to build or run (SDK paths, secrets, local tool settings) copied over from the main checkout.

## Scripts

| Script | What it does |
|---|---|
| `create_mobile_worktree.sh` | Creates a single worktree for one repo |

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

   Add the folder itself rather than symlinking the script elsewhere: it finds `.env` relative to its real location.

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

For `--repo appium`, the script also runs `pnpm install --frozen-lockfile` in the new worktree, using the repo's mise-pinned node/pnpm when `mise` is installed (it trusts the worktree's mise config and installs any missing tools first). Without this, the first `pnpm test:*` in a fresh worktree stalls on "Verifying lockfile against supply-chain policies", because pnpm re-checks every lockfile entry against the registry. If `pnpm-lock.yaml` is unchanged from the main checkout, `--trust-lockfile` skips that re-check, since the main checkout already verified it. A failed install prints a warning but doesn't fail the script.

## Requirements

- bash (macOS's built-in 3.2 is fine)
- git 2.5+ (for `git worktree`)
