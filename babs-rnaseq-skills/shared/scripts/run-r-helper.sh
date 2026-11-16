#!/usr/bin/env bash
# Run one of the skills' read-only R helpers inside the analysis directory,
# in the same container and renv library the report used.
#
# Usage: run-r-helper.sh [--dir ANALYSIS_DIR] HELPER.R [ARGS...]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/common.sh"
dir=.
[[ "${1:-}" == --dir ]] && { dir="$2"; shift 2; }
[[ $# -ge 1 ]] || babs_die "usage: run-r-helper.sh [--dir DIR] HELPER.R [ARGS...]"
helper="$(cd "$(dirname "$1")" && pwd -P)/$(basename "$1")"; shift
cd "$dir"; babs_require_workdir
mkdir -p .babs-skills; echo '*' > .babs-skills/.gitignore
cp "$helper" "$HERE/helpers-common.R" .babs-skills/
babs_load_env
babs_exec Rscript ".babs-skills/$(basename "$helper")" "$@"
