# create_worktree_scripts

Bash script for spinning up a git worktree of a monorepo that holds mobile apps and their test suite.

Each new worktree also gets copies of the local, gitignored files it needs to build or run (SDK paths, secrets, local tool settings) copied over from the main checkout, and its Node packages installed.

## Scripts

| Script | What it does |
|---|---|
| `create_mobile_worktree.sh` | Creates a worktree of the repo |

## Setup

1. Copy the example config and fill it in:

   ```bash
   cp .env.example .env
   ```

   ```bash
   WORKTREE_DIR_PATH="$HOME/worktrees/"

   REPO_PATH="$HOME/repos/my-mobile-monorepo"

   GITIGNORED_FILES=(
       # paths relative to REPO_PATH
       android/local.properties
       ios/Config/Secrets.xcconfig
       tests/.env
   )

   PNPM_INSTALL_DIRS=(
       # directories relative to REPO_PATH
       tests
   )
   ```

   `.env` is gitignored, so your local paths stay out of the repo.

2. (Optional) Add the folder to your `PATH` so the script runs from anywhere — e.g. in `~/.zshrc`:

   ```bash
   export PATH="$HOME/path/to/create_worktree_scripts:$PATH"
   ```

   Add the folder itself rather than symlinking the script elsewhere: it finds `.env` relative to its real location.

> **Note:** `.env` is loaded with `source`, so it's really a bash file — `$HOME` expands and arrays work, but it won't parse with standard dotenv tools.

## Usage

```bash
create_mobile_worktree.sh --worktree-dir <name> --branch <branch>
```

Creates `WORKTREE_DIR_PATH/<name>`, a full checkout of the repo (every app and the test suite, on one branch), then copies in the gitignored files. Files that don't exist in the main checkout are skipped with a warning.

Branch handling:
- **Exists locally or on `origin`** → checked out (remote branches are tracked automatically)
- **Doesn't exist** → created from the main checkout's current `HEAD`

Fails if the worktree folder already exists.

For each directory in `PNPM_INSTALL_DIRS`, the script also runs `pnpm install --frozen-lockfile` there, using that directory's mise-pinned node/pnpm when `mise` is installed (it trusts the directory's mise config and installs any missing tools first). Without this, the first `pnpm test:*` in a fresh worktree stalls on "Verifying lockfile against supply-chain policies", because pnpm re-checks every lockfile entry against the registry. If the directory's `pnpm-lock.yaml` is unchanged from the main checkout, `--trust-lockfile` skips that re-check, since the main checkout already verified it. A failed install prints a warning but doesn't fail the script.

To remove a worktree, use `git -C <repo> worktree remove <path>`.

## Requirements

- bash (macOS's built-in 3.2 is fine)
- git 2.5+ (for `git worktree`)
