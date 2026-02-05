#!/usr/bin/env bash
# Usage: ./update-submodules.sh [branch_override]
# If branch_override is provided, the script will attempt to update every submodule
# to that branch (if it exists in the submodule). Otherwise it will update each
# submodule to its configured branch or the remote default using --remote.
set -euo pipefail

BRANCH_OVERRIDE="${1:-}"

echo "Syncing submodule config..."
git submodule sync --recursive

echo "Initializing submodules..."
git submodule update --init --recursive

if [ -n "$BRANCH_OVERRIDE" ]; then
  echo "Updating all submodules to branch: $BRANCH_OVERRIDE"
  # For each submodule, try to checkout the branch and pull latest; if branch doesn't exist, skip
  git submodule foreach --recursive '
    echo "=== Updating $sm_path ==="
    if git show-ref --verify --quiet "refs/remotes/origin/'"$BRANCH_OVERRIDE"'"; then
      git fetch origin '"$BRANCH_OVERRIDE"' --quiet
      git checkout -B '"$BRANCH_OVERRIDE"' "origin/'"$BRANCH_OVERRIDE"'" || git checkout -B '"$BRANCH_OVERRIDE"'
      git pull --ff-only origin '"$BRANCH_OVERRIDE"' || git reset --hard "origin/'"$BRANCH_OVERRIDE"'"
    else
      echo "Branch '"$BRANCH_OVERRIDE"' not found in $sm_path; skipping"
    fi
  '
else
  echo "Updating submodules to the remote tips of their configured branches (or remote defaults)..."
  # This will update to whatever branch each submodule is configured to track in .gitmodules (or to remote default).
  git submodule update --remote --merge --recursive
fi

echo "Staging submodule pointer updates..."
git add -A

if git diff --cached --quiet; then
  echo "No changes to commit (submodules already up-to-date)."
  exit 0
fi

BRNAME="update-submodules-$(date +%Y%m%d%H%M%S)"
echo "Creating branch $BRNAME and committing changes..."
git checkout -b "$BRNAME"
git commit -m "Update submodules to latest remote commits"
echo "Pushing branch $BRNAME to origin..."
git push -u origin "$BRNAME"

echo "Done. Branch pushed: $BRNAME"
echo "Create a PR from $BRNAME to your target branch (e.g. main) to merge the updates."