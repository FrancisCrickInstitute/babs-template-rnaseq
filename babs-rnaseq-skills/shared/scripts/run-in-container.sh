#!/usr/bin/env bash
# Run a command inside the analysis directory under the configured executor
# (singularity by default; docker/shell are untested). Equivalent to
# shared.mk's `$(containerPrefix) <cmd>`.
#
# Usage: run-in-container.sh [--dir ANALYSIS_DIR] [--] CMD [ARGS...]
#   e.g. run-in-container.sh --dir ~/proj/analysis -- Rscript -e 'library(DESeq2)'
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

dir=.
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) dir="$2"; shift 2 ;;
    --) shift; break ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) break ;;
  esac
done
[[ $# -gt 0 ]] || babs_die "no command given"
cd "$dir"
babs_load_env
babs_exec "$@"
