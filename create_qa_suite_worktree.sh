#!/usr/bin/env bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ENV_FILE="$SCRIPT_DIR/.env"
if [[ ! -f "$ENV_FILE" ]]; then
    echo "Missing env file: $ENV_FILE" >&2
    exit 1
fi
source "$ENV_FILE"

: "${WORKTREE_DIR_PATH:?WORKTREE_DIR_PATH must be set in $ENV_FILE}"
: "${ANDROID_REPO_PATH:?ANDROID_REPO_PATH must be set in $ENV_FILE}"
: "${IOS_REPO_PATH:?IOS_REPO_PATH must be set in $ENV_FILE}"

usage() {
    echo "Usage: $(basename "$0") --feature <dir_name> --ticket <ticket-ref> --branch-base-name <branch-name>"
}

create_mobile_worktree() {
    "$SCRIPT_DIR/create_mobile_worktree.sh" "$@"
}

FEATURE_NAME=""
TICKET_REF=""
BRANCH_BASE_NAME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --feature)
            FEATURE_NAME="$2"
            shift 2
            ;;
        --ticket)
            TICKET_REF="$2"
            shift 2
            ;;
        --branch-base-name)
            BRANCH_BASE_NAME="$2"
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

if [[ -z "$FEATURE_NAME" || -z "$TICKET_REF" || -z "$BRANCH_BASE_NAME" ]]; then
    echo "--feature, --ticket and --branch-base-name are all required." >&2
    usage >&2
    exit 1
fi

create_mobile_worktree --repo appium --worktree-dir "$FEATURE_NAME" --branch "$TICKET_REF/$BRANCH_BASE_NAME"
echo "Created appium worktree on branch $TICKET_REF/$BRANCH_BASE_NAME"
create_mobile_worktree --repo android --worktree-dir "$FEATURE_NAME" --branch "$TICKET_REF/qa-$BRANCH_BASE_NAME"
echo "Created android worktree on branch $TICKET_REF/qa-$BRANCH_BASE_NAME"
create_mobile_worktree --repo ios --worktree-dir "$FEATURE_NAME" --branch "$TICKET_REF/qa-$BRANCH_BASE_NAME"
echo "Created ios worktree on branch $TICKET_REF/qa-$BRANCH_BASE_NAME"

# Point the appium worktree's copied .env at the app worktrees instead of the main repos
FEATURE_PATH="${WORKTREE_DIR_PATH%/}/$FEATURE_NAME"
APPIUM_WORKTREE="$FEATURE_PATH/appium_$FEATURE_NAME"
ANDROID_WORKTREE="$FEATURE_PATH/android_$FEATURE_NAME"
IOS_WORKTREE="$FEATURE_PATH/ios_$FEATURE_NAME"
APPIUM_ENV="$APPIUM_WORKTREE/.env"

if [[ -f "$APPIUM_ENV" ]]; then
    tmp_env="$(mktemp)"
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line//"${ANDROID_REPO_PATH%/}"/"$ANDROID_WORKTREE"}"
        line="${line//"${IOS_REPO_PATH%/}"/"$IOS_WORKTREE"}"
        printf '%s\n' "$line"
    done < "$APPIUM_ENV" > "$tmp_env"
    cat "$tmp_env" > "$APPIUM_ENV"
    rm "$tmp_env"
    echo "Pointed appium .env app paths at the android/ios worktrees"
else
    echo "WARNING: No .env in $APPIUM_WORKTREE — app paths not updated" >&2
fi

echo ""
echo "QA suite ready at $FEATURE_PATH"
echo "Build the apps from these worktrees before running tests:"
echo "  android: $ANDROID_WORKTREE"
echo "  ios:     $IOS_WORKTREE"
