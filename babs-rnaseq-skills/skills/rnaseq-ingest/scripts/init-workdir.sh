#!/usr/bin/env bash
# Create an analysis directory with the babs/differential layout and the
# vendored R code, and git-initialise it as resources/shell/isolated.sh does
# (empty commit tagged `bootstrap-isolated-analysis`), so VERSION/GIT_REF and
# hence every output filename behave as under `make`.
#
# Usage: init-workdir.sh ANALYSIS_DIR
set -euo pipefail
SHARED="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../shared" && pwd)"
source "$SHARED/scripts/common.sh"

[[ $# -eq 1 ]] || babs_die "usage: $(basename "$0") ANALYSIS_DIR"
target="$1"

if [[ -e "$target" ]] && [[ -n "$(ls -A "$target" 2>/dev/null)" ]]; then
  if [[ -d "$target/R" && -d "$target/resources" ]]; then
    babs_info "$target already initialised; leaving the code alone"
    exit 0
  fi
  babs_die "$target exists and is not empty"
fi

"$SHARED/sync-check.sh" >/dev/null || babs_die "vendored code has drifted from babs/differential; run shared/sync-check.sh"

mkdir -p "$target"
cd "$target"
cp -R "$SHARED/R" R
mkdir -p resources
cp -R "$SHARED/resources/." resources/
cp "$SHARED/renv.lock" renv.lock
cp "$SHARED/.env" .env
mkdir -p extdata data
cp "$SHARED/.gitignore" .gitignore

# isolated.sh, no-argument branch
if [[ ! -d .git ]]; then
  git init -q
  git commit -q --allow-empty -m "Create empty repository"
  echo "  Created an empty git repo just for this directory"
  git tag bootstrap-isolated-analysis
fi

echo "Initialised $(pwd)"
echo "  VERSION=$(babs_version)  GIT_REF=$(babs_git_ref)"
