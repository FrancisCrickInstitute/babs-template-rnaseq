#!/usr/bin/env bash
# Copy the finished airway analysis from the Phases 2-7 runbook as ./analysis.
# The copy keeps its git history, so VERSION is unchanged until the spec is
# edited. renv/library holds links into the shared renv cache, kept by cp -a.
set -eu
base="${BABS_TRIAL_BASE:-/flask/scratch/babs/$USER/skills-test/airway}"
[ -f "$base/data/analyse_x_GRCh38.rds" ] || { echo "place-files.sh: no finished analysis at $base (set BABS_TRIAL_BASE)" >&2; exit 1; }
cp -a "$base" analysis
