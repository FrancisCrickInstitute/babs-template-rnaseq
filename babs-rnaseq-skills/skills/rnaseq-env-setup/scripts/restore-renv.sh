#!/usr/bin/env bash
# Replicates the differential makefile's `renv` and `extdata/R.bib` targets:
#  - rewrite resources/_dependencies.R so it ends with library(<org.db>) for
#    every data source's org.db
#  - renv activate / restore, then install the org.db packages (lock=TRUE)
#  - commit renv.lock, renv/, .Rprofile, resources/, R/ ("Renv initialised by pipeline")
#  - knitr::write_bib of every package in renv.lock -> extdata/R.bib
#
# Run after stage-inputs.sh (it needs extdata/<ds>.config to know the org.db).
# Usage: restore-renv.sh [--dir ANALYSIS_DIR]
set -euo pipefail
SHARED="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../shared" && pwd)"
source "$SHARED/scripts/common.sh"

dir=.
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) dir="$2"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) babs_die "unknown option $1" ;;
  esac
done
cd "$dir"
babs_require_workdir
babs_load_env
babs_mkdir_ignored "$BABS_LOG_DIR"

# module.mk: renv: orgs=$(strip $(foreach data_source,$(datasets),$($(data_source).org.db)))
orgs=()
for ds in $(babs_datasets); do
  o="$(babs_config_get "extdata/${ds}.config" "org\\.db")"
  [[ -z "$o" ]] && o="$(babs_config_get "extdata/${ds}.config" "${ds}\\.org\\.db")"
  [[ -n "$o" ]] && orgs+=("$o")
done
[[ ${#orgs[@]} -gt 0 ]] || babs_warn "no org.db found in any extdata/*.config; annotation will fall back to row names"
orgs_str="${orgs[*]:-}"

# sed -i '/#DO NOT EDIT AFTER THIS LINE/q' resources/_dependencies.R ; append library() lines.
# (make writes all orgs into one library() call when there are several, which
# is not valid R; one line per package is written here.)
babs_sed_i resources/_dependencies.R '/#DO NOT EDIT AFTER THIS LINE/q'
for o in "${orgs[@]:-}"; do [[ -n "$o" ]] && echo "library($o)" >> resources/_dependencies.R; done

{
  babs_exec R -e 'library(renv); activate()'
  babs_exec R -e "library(renv); restore(); install(strsplit(\"${orgs_str}\", \" +\")[[1]], lock=TRUE)"
} 2>&1 | tee "$BABS_LOG_DIR/renv.log"

git add renv.lock renv .Rprofile "$BABS_SOURCE_DIR" 2>/dev/null || true
for f in makefile R .Rbuildignore .gitignore resources/_dependencies.R; do [[ -e "$f" ]] && git add "$f"; done
git commit -q -m 'Renv initialised by pipeline' || echo "No initialisation files need commiting"

babs_exec R -e 'knitr::write_bib(names(renv:::lockfile("renv.lock")$data()$Packages), file="extdata/R.bib",prefix="pkg_")' 2>&1 | tee "$BABS_LOG_DIR/bib.log"
[[ -s extdata/R.bib ]] && echo "renv restored; extdata/R.bib written" || babs_die "extdata/R.bib was not created; see $BABS_LOG_DIR/bib.log"
