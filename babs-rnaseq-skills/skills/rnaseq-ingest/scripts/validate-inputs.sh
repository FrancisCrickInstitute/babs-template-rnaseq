#!/usr/bin/env bash
# Validate the staged inputs of an analysis directory:
#  - the docs-stage checks (non-empty files; experiment table starts with `ID`;
#    `ID,sample_label` advice)
#  - the makefile's check_spec recipe (parse() every spec; log in logs/check_spec.log)
#  - extra read-only checks: duplicated/blank IDs, every spec variable is a column
#
# Usage: validate-inputs.sh [--dir ANALYSIS_DIR]
# Exit status non-zero if anything is an error (warnings do not fail).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED="$(cd "$HERE/../../../shared" && pwd)"
source "$SHARED/scripts/common.sh"

dir=.
while [[ $# -gt 0 ]]; do
  case "$1" in --dir) dir="$2"; shift 2 ;; -h|--help) sed -n '2,10p' "$0"; exit 0 ;; *) babs_die "unknown option $1" ;; esac
done
cd "$dir"; babs_require_workdir
babs_mkdir_ignored "$BABS_LOG_DIR"
errs=0
err() { echo "ERROR: $*"; errs=$((errs+1)); }
warn() { echo "WARNING: $*"; }

meta="${BABS_METADATA}.csv"
specfiles=(extdata/*.spec); [[ -e "${specfiles[0]}" ]] || { err "no extdata/*.spec"; specfiles=(); }
configs=(extdata/*.config); [[ -e "${configs[0]}" ]] || { err "no extdata/*.config"; configs=(); }

# docs makefile checks
[[ -s "$meta" ]] || err "$meta is missing or empty"
if [[ -s "$meta" ]]; then
  head -1 "$meta" | grep -q "^\"\{0,1\}${BABS_METADATA_ID_COLUMN}" || err "$meta does not start with a column named ${BABS_METADATA_ID_COLUMN}"
  head -1 "$meta" | grep -q "${BABS_METADATA_ID_COLUMN}\"\{0,1\},\"\{0,1\}sample_label" || warn "$meta does not have sample_label column after ${BABS_METADATA_ID_COLUMN} - the first unduplicated column after ${BABS_METADATA_ID_COLUMN}, or ${BABS_METADATA_ID_COLUMN} itself will be used as a label"
  ids="$(tail -n +2 "$meta" | cut -d, -f1 | tr -d '"')"
  dups="$(echo "$ids" | grep -v '^$' | LC_ALL=C sort | uniq -d)"
  [[ -n "$dups" ]] && err "duplicated IDs in $meta: $(echo $dups)"
  if echo "$ids" | grep -q '^$'; then
    if [[ -z "$(echo "$ids" | grep -v '^$')" ]]; then warn "the ID column is entirely blank: 00_init.qmd will SIMULATE counts (isolated.sh behaviour). This is almost never wanted with real nf-core data."
    else err "some rows of $meta have a blank ID"; fi
  fi
fi
for f in "${specfiles[@]}" "${configs[@]}"; do [[ -s "$f" ]] || err "$f is empty"; done

# check_spec recipe: R --vanilla parse() of every spec, stderr -> logs/check_spec.log
if [[ ${#specfiles[@]} -gt 0 ]]; then
  rcode="files <- strsplit('${specfiles[*]}', ' +')[[1]]; ok <- TRUE; for (f in files) { message('Checking ', f); tryCatch(parse(file = f), error = function(e) { message('ERROR in ', f, ': ', e\$message); ok <<- FALSE }) }; if (!ok) quit(status = 1)"
  if command -v R >/dev/null; then
    R --vanilla -s -e "$rcode" 2> "$BABS_LOG_DIR/check_spec.log" >/dev/null
  else
    babs_load_env; babs_exec R --vanilla -s -e "$rcode" 2> "$BABS_LOG_DIR/check_spec.log" >/dev/null
  fi
  [[ $? -eq 0 ]] && echo "Spec files parse OK" || { err "spec parse failure:"; sed 's/^/    /' "$BABS_LOG_DIR/check_spec.log"; }

  # covariate check against each data source's joined metadata (or the full table)
  for ds in $(babs_datasets); do
    m="${BABS_METADATA}_${ds}.csv"; [[ -s "$m" ]] || m="$meta"
    ds_specs=(); for s in $(babs_specs_for_ds "$ds"); do ds_specs+=("extdata/$s.spec"); done
    [[ ${#ds_specs[@]} -gt 0 ]] || { warn "data source $ds has no spec after <ds>.spec/<ds>.nospec filtering"; continue; }
    echo "Covariate check for data source $ds ($m):"
    if command -v Rscript >/dev/null; then
      Rscript --vanilla "$HERE/check-spec-covariates.R" "$m" "${ds_specs[@]}"
    else
      babs_load_env; cp "$HERE/check-spec-covariates.R" "$BABS_LOG_DIR/.check-spec-covariates.R"
      babs_exec Rscript --vanilla "$BABS_LOG_DIR/.check-spec-covariates.R" "$m" "${ds_specs[@]}"
    fi || err "covariate check failed for $ds"
  done
fi

for ds in $(babs_datasets); do
  [[ -s "${BABS_METADATA}_${ds}.csv" ]] || err "${BABS_METADATA}_${ds}.csv missing (run stage-inputs.sh)"
  [[ -d "${BABS_COUNTS_DIR}/${ds}" ]] || err "${BABS_COUNTS_DIR}/${ds} missing (run stage-inputs.sh)"
done

[[ $errs -eq 0 ]] && echo "Inputs valid" || { echo "$errs error(s)"; exit 1; }
