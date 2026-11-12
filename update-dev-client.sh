#!/usr/bin/env bash
set -euo pipefail

# Copy the sibling web-client-v2 HEAD commit into this site's root, including its network.js.
# Requires Bash, Git, tar, and rsync. Run from any directory; no build is needed.
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_REPO="$(dirname "$REPO_DIR")/web-client-v2"

for command in git tar rsync; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Error: $command is required." >&2
        exit 1
    fi
done

# Export one committed snapshot, excluding staged edits and untracked files.
SOURCE_COMMIT=$(git -C "$SOURCE_REPO" rev-parse --verify HEAD)
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

echo "Copying $SOURCE_REPO at $SOURCE_COMMIT into $REPO_DIR..."
# Never copy source Git metadata, workflows, local tooling, or site-owned files.
# network.js is excluded here and installed from the source commit afterward.
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
echo "Installed network.js from $SOURCE_COMMIT."
echo "Review the changes with git diff before committing or publishing."
