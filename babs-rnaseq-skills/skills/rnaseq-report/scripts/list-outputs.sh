#!/usr/bin/env bash
# Tabulate everything under results/<VERSION>/ (default: results/latest, else newest).
# Usage: list-outputs.sh [--dir ANALYSIS_DIR] [VERSION]
set -euo pipefail
dir=.
[[ "${1:-}" == --dir ]] && { dir="$2"; shift 2; }
cd "$dir"
if [[ -n "${1:-}" ]]; then v="results/$1"
elif [[ -e results/latest ]]; then v="results/$(readlink results/latest)"
else v="$(ls -td results/*/ 2>/dev/null | grep -v 'multiqc-' | head -1)"; v="${v%/}"
fi
[[ -n "$v" && -d "$v" ]] || { echo "no results/<VERSION> directory found" >&2; exit 1; }
echo "Outputs in $(pwd -P)/$v"
echo
echo "HTML pages:"
find "$v" -maxdepth 1 -name '*.html' | sort | sed 's/^/  /'
echo
printf '%-45s %6s %6s %6s %6s %6s %6s\n' "page folder" tsv csv xlsx png pdf other
for d in "$v"/*/; do
  d="${d%/}"; n="$(basename "$d")"; [[ "$n" == *_files || "$n" == site_libs ]] && continue
  c() { find "$d" -type f -name "*.$1" | wc -l | tr -d ' '; }
  all=$(find "$d" -type f | wc -l | tr -d ' ')
  t=$(c tsv) cs=$(c csv) x=$(c xlsx) pn=$(c png) pd=$(c pdf)
  printf '%-45s %6s %6s %6s %6s %6s %6s\n' "$n" "$t" "$cs" "$x" "$pn" "$pd" $((all-t-cs-x-pn-pd))
done
echo
echo "Spreadsheets:"; find "$v" -name '*.xlsx' | sort | sed 's/^/  /'
echo "Manifest:";     find "$v" -maxdepth 1 -name 'manifest*.txt' | sed 's/^/  /'
echo
echo "R objects (data/):"; ls -1 data/*.rds data/*.rda 2>/dev/null | sed 's/^/  /' || true
for m in results/multiqc-*; do [[ -d "$m" ]] && echo "MultiQC: $m/multiqc_report.html"; done
