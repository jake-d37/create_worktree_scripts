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
    echo "Usage: $(basename "$0") --feature <dir_name> [--delete-branches]"
}

FEATURE_NAME=""
DELETE_BRANCHES=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --feature)
            FEATURE_NAME="$2"
            shift 2
            ;;
        --delete-branches)
            DELETE_BRANCHES=true
            shift
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

if [[ -z "$FEATURE_NAME" ]]; then
    echo "--feature is required." >&2
    usage >&2
    exit 1
fi

FEATURE_PATH="${WORKTREE_DIR_PATH%/}/$FEATURE_NAME"

if [[ ! -d "$FEATURE_PATH" ]]; then
    echo "No feature folder at $FEATURE_PATH" >&2
    exit 1
fi

FAILED=()

remove_worktree() {
    local repo="$1"
    local repo_path="$2"
    local worktree_path="$FEATURE_PATH/${repo}_${FEATURE_NAME}"

    if [[ ! -d "$worktree_path" ]]; then
        echo "Skipping $repo: no worktree at $worktree_path"
        return
    fi

    # Grab the branch before the worktree is gone
    local branch
    branch="$(git -C "$worktree_path" branch --show-current)"

    if ! git -C "$repo_path" worktree remove "$worktree_path"; then
        echo "ERROR: Couldn't remove $repo worktree (see output above). Commit/stash changes, or remove it with --force." >&2
        FAILED+=("$repo")
        return
    fi
    echo "Removed $repo worktree at $worktree_path"

    if [[ "$DELETE_BRANCHES" == true && -n "$branch" ]]; then
        # -d refuses unmerged branches, so unpushed work isn't lost
        if git -C "$repo_path" branch -d "$branch"; then
            echo "Deleted $repo branch $branch"
        else
            echo "Kept $repo branch $branch (not fully merged — use 'git branch -D' if you're sure)" >&2
        fi
    fi
}

remove_worktree appium "$APPIUM_REPO_PATH"
remove_worktree android "$ANDROID_REPO_PATH"
remove_worktree ios "$IOS_REPO_PATH"

# Only removes the feature folder if it's now empty
if rmdir "$FEATURE_PATH" 2>/dev/null; then
    echo "Removed $FEATURE_PATH"
else
    echo "Left $FEATURE_PATH in place (not empty)"
fi

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo "" >&2
    echo "ERROR: Failed to remove: ${FAILED[*]}" >&2
    exit 1
fi
