#!/usr/bin/env bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
