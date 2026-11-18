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
: "${REPO_PATH:?REPO_PATH must be set in $ENV_FILE}"

usage() {
    echo "Usage: $(basename "$0") --worktree-dir <dir-name> --branch <branch-name>"
}

WORKTREE_DIR=""
BRANCH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
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

if [[ -z "$WORKTREE_DIR" || -z "$BRANCH" ]]; then
    echo "--worktree-dir and --branch are both required." >&2
    usage >&2
    exit 1
fi

NEW_WORKTREE_PATH="${WORKTREE_DIR_PATH%/}/${WORKTREE_DIR}"

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

# Paths are relative to the repo root
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
# new worktree. Uses the directory's mise-pinned node/pnpm when mise is available.
install_pnpm_deps() {
    local rel="$1"                       # package directory, relative to the repo root
    local dir="$NEW_WORKTREE_PATH/$rel"
    local runner=()

    if command -v mise >/dev/null 2>&1; then
        mise trust --yes "$dir" >/dev/null
        (cd "$dir" && mise install) || return 1
        runner=(mise exec --)
    fi

    # The main checkout's lockfile was already verified there, so skip re-verifying it when unchanged
    local install_args=(--frozen-lockfile)
    if git -C "$NEW_WORKTREE_PATH" diff --quiet "$(git -C "$REPO_PATH" rev-parse HEAD)" -- "$rel/pnpm-lock.yaml"; then
        install_args+=(--trust-lockfile)
    else
        echo "$rel/pnpm-lock.yaml differs from the main checkout — installing with full lockfile verification."
    fi

    (cd "$dir" && "${runner[@]}" pnpm install "${install_args[@]}")
}

for rel in "${PNPM_INSTALL_DIRS[@]}"; do
    if [[ ! -f "$NEW_WORKTREE_PATH/$rel/package.json" ]]; then
        echo "Skipping pnpm install: no package.json in $rel" >&2
        continue
    fi
    echo "Installing pnpm dependencies in $rel..."
    if ! install_pnpm_deps "$rel"; then
        echo "pnpm install failed — run it manually in $NEW_WORKTREE_PATH/$rel before running tests." >&2
    fi
done

echo "Worktree ready at $NEW_WORKTREE_PATH"
