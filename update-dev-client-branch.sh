#!/usr/bin/env bash
set -euo pipefail

# Copy a chosen local branch from the sibling web-client-v2 checkout into this site's root.
# Also installs that branch's network.js. update-dev-client.sh keeps this site's network.js_dev instead.
# Requires Bash, Git, tar, and rsync. Run from any directory; no build is needed.
#
# Usage: ./update-dev-client-branch.sh <local-branch>
# Example: ./update-dev-client-branch.sh codex/1883-near-send-qr

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_REPO="$(dirname "$REPO_DIR")/web-client-v2"

if [[ $# -ne 1 || "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: $(basename "$0") <local-branch>" >&2
    echo "Copies that local web-client-v2 branch, including its network.js." >&2
    echo "Example: $(basename "$0") codex/1883-near-send-qr" >&2
    exit 2
fi

BRANCH="$1"

for command in git tar rsync; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Error: $command is required." >&2
        exit 1
    fi
done

if [[ ! -e "$SOURCE_REPO/.git" ]]; then
    echo "Error: source checkout not found: $SOURCE_REPO" >&2
    exit 1
fi

# Only a branch checked out in the source repo is accepted. Remote-tracking names are not.
if ! git -C "$SOURCE_REPO" show-ref --verify --quiet "refs/heads/${BRANCH}"; then
    echo "Error: local branch not found in $SOURCE_REPO: $BRANCH" >&2
    echo "List local branches with: git -C \"$SOURCE_REPO\" branch" >&2
    exit 1
fi

# Export one committed snapshot, excluding staged edits and untracked files.
SOURCE_COMMIT=$(git -C "$SOURCE_REPO" rev-parse --verify "refs/heads/${BRANCH}")
SOURCE_DIR=$(mktemp -d)
trap 'rm -rf "$SOURCE_DIR"' EXIT
git -C "$SOURCE_REPO" archive "$SOURCE_COMMIT" | tar -xf - -C "$SOURCE_DIR"

for file in "$SOURCE_DIR/index.html" "$SOURCE_DIR/app.js" "$SOURCE_DIR/.gitignore" "$SOURCE_DIR/network.js"; do
    if [[ ! -f "$file" ]]; then
        echo "Error: required file not found: $file" >&2
        exit 1
    fi
done

# Continue the deployed version, or start from the source on first use.
VERSION_FILE="$REPO_DIR/app.js"
if [[ ! -f "$VERSION_FILE" ]]; then
    VERSION_FILE="$SOURCE_DIR/app.js"
fi
current_version=$(sed -n "s/^const version = '\([^']*\)'.*/\1/p" "$VERSION_FILE")
if [[ ! "$current_version" =~ ^[a-zA-Z0-9._-]*[a-zA-Z]$ ]]; then
    echo "Error: expected a version ending in a letter in $VERSION_FILE" >&2
    exit 1
fi
if ! grep -q "^const version = '[^']*'" "$SOURCE_DIR/app.js"; then
    echo "Error: source app.js is missing its version declaration." >&2
    exit 1
fi
next_char=$(printf '%s' "${current_version: -1}" | LC_ALL=C tr 'a-zA-Z' 'b-zaB-ZA')
new_version="${current_version:0:${#current_version}-1}$next_char"

echo "Copying $SOURCE_REPO branch $BRANCH at $SOURCE_COMMIT into $REPO_DIR..."
# Never copy source Git metadata, workflows, local tooling, or site-owned files.
# network.js is excluded here and installed from the branch afterward.
# No --delete: preserve this site's configuration and other local files.
rsync -av \
    --exclude='/.*' \
    --exclude='CNAME' \
    --exclude='update-*.sh' \
    --exclude='network.js*' \
    --exclude='*.md' \
    --exclude='*.code-workspace' \
    --exclude='package*.json' \
    --exclude='LOCAL_DATA.txt' \
    --exclude='data_structures_flow/' \
    --exclude='validation-reports/' \
    --exclude='tests-local/' \
    --exclude-from="$SOURCE_DIR/.gitignore" \
    "$SOURCE_DIR/" "$REPO_DIR/"

cp "$SOURCE_DIR/network.js" "$REPO_DIR/network.js"
sed -i "s/^const version = '[^']*'/const version = '$new_version'/" "$REPO_DIR/app.js"
date +'%Y.%m%d.%H%M' > "$REPO_DIR/version.html"

echo "Updated root client to $new_version ($(cat "$REPO_DIR/version.html"))."
echo "Installed network.js from $BRANCH."
echo "Left network.js_dev unchanged. ./update-dev-client.sh would copy that file over network.js."
echo "Review the changes with git diff before committing or publishing."
