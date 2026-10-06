#!/usr/bin/env bash
set -eo pipefail

# Load paths from the .env next to this script, regardless of where it's run from
ENV_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.env"
if [[ ! -f "$ENV_FILE" ]]; then
    echo "Missing env file: $ENV_FILE" >&2
    exit 1
fi
source "$ENV_FILE"

: "${WORKTREE_DIR_PATH:?WORKTREE_DIR_PATH must be set in $ENV_FILE}"
: "${ANDROID_REPO_PATH:?ANDROID_REPO_PATH must be set in $ENV_FILE}"
: "${IOS_REPO_PATH:?IOS_REPO_PATH must be set in $ENV_FILE}"
: "${APPIUM_REPO_PATH:?APPIUM_REPO_PATH must be set in $ENV_FILE}"

usage() {
    echo "Usage: $(basename "$0") --repo <android|ios|appium> --worktree-dir <dir-name> --branch <branch-name>"
}

DIR_PREFIX=""
REPO_PATH=""
GITIGNORED_FILES=()
INSTALL_PNPM_DEPS=false
WORKTREE_DIR=""
BRANCH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)
            case "$2" in
                android)
                    REPO_PATH="$ANDROID_REPO_PATH"
                    GITIGNORED_FILES=("${ANDROID_GITIGNORED_FILES[@]}")
                    DIR_PREFIX="android_"
                    ;;
                ios)
                    REPO_PATH="$IOS_REPO_PATH"
                    GITIGNORED_FILES=("${IOS_GITIGNORED_FILES[@]}")
                    DIR_PREFIX="ios_"
                    ;;
                appium)
                    REPO_PATH="$APPIUM_REPO_PATH"
                    GITIGNORED_FILES=("${APPIUM_GITIGNORED_FILES[@]}")
                    DIR_PREFIX="appium_"
                    INSTALL_PNPM_DEPS=true
                    ;;
                *)
                    echo "Unknown --repo value: '$2' (expected android, ios or appium)" >&2
                    usage >&2
                    exit 1
                    ;;
            esac
            shift 2
            ;;
        --worktree-dir)
            WORKTREE_DIR="$2"
            shift 2
            ;;
        --branch)
            BRANCH="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ -z "$REPO_PATH" || -z "$WORKTREE_DIR" || -z "$BRANCH" ]]; then
    echo "--repo, --worktree-dir and --branch are all required." >&2
    usage >&2
    exit 1
fi

# Group by feature: worktrees/<feature>/<repo>_<feature>
NEW_WORKTREE_PATH="${WORKTREE_DIR_PATH%/}/${WORKTREE_DIR}/${DIR_PREFIX}${WORKTREE_DIR}"

if [[ -e "$NEW_WORKTREE_PATH" ]]; then
    echo "Worktree path already exists: $NEW_WORKTREE_PATH" >&2
    exit 1
fi

mkdir -p "$(dirname "$NEW_WORKTREE_PATH")"

# Existing local branch, or a remote branch git can auto-track; otherwise create a new branch
if git -C "$REPO_PATH" show-ref --verify --quiet "refs/heads/$BRANCH" \
    || git -C "$REPO_PATH" show-ref --quiet "refs/remotes/origin/$BRANCH"; then
    git -C "$REPO_PATH" worktree add "$NEW_WORKTREE_PATH" "$BRANCH"
else
    echo "Branch '$BRANCH' not found locally or on origin — creating it from current HEAD."
    git -C "$REPO_PATH" worktree add -b "$BRANCH" "$NEW_WORKTREE_PATH"
fi

for file in "${GITIGNORED_FILES[@]}"; do
    src="$REPO_PATH/$file"
    dest="$NEW_WORKTREE_PATH/$file"

    if [[ ! -e "$src" ]]; then
        echo "Skipping missing file: $src" >&2
        continue
    fi

    mkdir -p "$(dirname "$dest")"
    cp -R "$src" "$dest"
    echo "Copied $file"
done

# Install pnpm deps up front. Otherwise the first `pnpm test:*` sees node_modules out of sync and
# re-verifies every lockfile entry against the registry, since that cache doesn't carry over to a
# new worktree. Uses the repo's mise-pinned node/pnpm when mise is available.
install_pnpm_deps() {
    local worktree="$1"
    local runner=()

    if command -v mise >/dev/null 2>&1; then
        mise trust --yes "$worktree" >/dev/null
        (cd "$worktree" && mise install) || return 1
        runner=(mise exec --)
    fi

    # The main checkout's lockfile was already verified there, so skip re-verifying it when unchanged
    local install_args=(--frozen-lockfile)
    if git -C "$worktree" diff --quiet "$(git -C "$REPO_PATH" rev-parse HEAD)" -- pnpm-lock.yaml; then
        install_args+=(--trust-lockfile)
    else
        echo "pnpm-lock.yaml differs from the main checkout — installing with full lockfile verification."
    fi

    (cd "$worktree" && "${runner[@]}" pnpm install "${install_args[@]}")
}

if [[ "$INSTALL_PNPM_DEPS" == true ]]; then
    echo "Installing pnpm dependencies..."
    if ! install_pnpm_deps "$NEW_WORKTREE_PATH"; then
        echo "pnpm install failed — run it manually in $NEW_WORKTREE_PATH before running tests." >&2
    fi
fi

echo "Worktree ready at $NEW_WORKTREE_PATH"
