#!/usr/bin/env bash
# Put the case's input files in the run folder and link the cached airway
# nf-core output (BABS nfcore layout) as ./nfcore. The run folder must be on
# the same filesystem as the nf-core output: stage-inputs.sh hard-links counts.
set -eu
cp -R "$(dirname "$0")/files/." .
nf="${BABS_TRIAL_NFCORE:-/flask/scratch/babs/$USER/skills-test/nfcore}"
[ -d "$nf/results/GRCh38" ] || { echo "place-files.sh: no nf-core output at $nf (set BABS_TRIAL_NFCORE)" >&2; exit 1; }
ln -s "$nf" nfcore
