#!/usr/bin/env bash
# Report whether the runtime needed by the BABS downstream analysis is
# ready, and optionally pull the pinned container image.
#
# Usage: check-env.sh [--dir ANALYSIS_DIR] [--pull] [--deep]
#   --dir   analysis directory (default: .). Its .env chain is read, as make does.
#   --pull  pull the singularity image if it is missing (shared.mk $(SIF_ORIGIN) rule)
#   --deep  also start the container and check R, quarto and the key R packages
set -uo pipefail
SHARED="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../shared" && pwd)"
source "$SHARED/scripts/common.sh"

dir=. pull=false deep=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) dir="$2"; shift 2 ;;
    --pull) pull=true; shift ;;
    --deep) deep=true; shift ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) babs_die "unknown option $1" ;;
  esac
done
cd "$dir" || babs_die "no such directory $dir"
[[ -f .env ]] || { babs_warn "no .env in $(pwd); using the vendored one from $SHARED"; set -a; source "$SHARED/.env"; set +a; }
babs_load_env

problems=0
ok() { printf '  [ok]   %s\n' "$*"; }
bad() { printf '  [FAIL] %s\n' "$*"; problems=$((problems+1)); }
note() { printf '  [note] %s\n' "$*"; }

echo "Executor: ${EXECUTOR}   threads: ${NUM_THREADS}"
echo "Image:    ${docker_image}"

for t in git; do command -v "$t" >/dev/null && ok "$t: $(command -v $t)" || bad "$t not on PATH"; done
command -v sqlite3 >/dev/null && ok "sqlite3 (host): $(sqlite3 --version | cut -d' ' -f1)" || note "sqlite3 not on host PATH; stage-inputs.sh will run it inside the container"

case "$EXECUTOR" in
  singularity)
    if [[ -n "${SINGULARITY_MODULE:-}" ]] && command -v module >/dev/null 2>&1; then
      module load "$SINGULARITY_MODULE" 2>/dev/null && ok "module $SINGULARITY_MODULE loaded" || note "could not load module $SINGULARITY_MODULE"
    fi
    if command -v singularity >/dev/null; then ok "singularity $(singularity --version 2>/dev/null)"; else bad "singularity not on PATH (on NEMO: set SINGULARITY_MODULE in .env.local, e.g. Singularity/3.11.3)"; fi
    origin="$(babs_sif_origin)"; sif="$(babs_sif_path)"
    if [[ -e "$sif" ]]; then
      ok "image present: $sif"
    elif $pull; then
      echo "  pulling docker://${docker_image} -> $origin"
      mkdir -p "$(dirname "$origin")"
      env DOCKER_USERNAME="${DOCKER_USERNAME:-${GITHUB_USERNAME:-$(git config --get github.user || true)}}" \
          DOCKER_PASSWORD="${DOCKER_PASSWORD-${GITHUB_PAT:-}}" \
          singularity pull "$origin" "docker://${docker_image}" && ok "pulled $origin" || bad "pull failed"
      chmod g+rwx,u+rwx "$origin" 2>/dev/null || true
    else
      bad "image not found at $origin (looked in SINGULARITY_IMAGEDIR, then SINGULARITY_CACHEDIR/library, then ~/.singularity/cache/library). Re-run with --pull"
    fi
    if [[ -e "$origin" ]] && [[ -d resources ]] && [[ ! -e "resources/docker/${sif_file}" ]]; then
      mkdir -p "$(dirname "resources/docker/${sif_file}")"
      ln -sfn "$origin" "resources/docker/${sif_file}" && ok "linked resources/docker/${sif_file} -> $origin"
    fi
    ;;
  docker) note "docker executor is UNTESTED"; command -v docker >/dev/null && ok "docker found" || bad "docker not on PATH" ;;
  shell) note "shell executor is UNTESTED and not reproducible"
         for t in R quarto; do command -v $t >/dev/null && ok "$t found" || bad "$t not on PATH"; done ;;
esac

if [[ -n "${SINGULARITYENV_RENV_PATHS_ROOT:-}" ]]; then
  ok "renv cache (SINGULARITYENV_RENV_PATHS_ROOT): ${SINGULARITYENV_RENV_PATHS_ROOT}"
else
  note "SINGULARITYENV_RENV_PATHS_ROOT is not set: with --containall the renv cache lives in a throw-away home and packages are reinstalled on every run. Set it in .env.local to a directory on fast disk."
fi

if $deep && [[ $problems -eq 0 ]]; then
  echo "In-container checks:"
  babs_exec bash -c 'R --version | head -1; quarto --version | sed "s/^/quarto /"' | sed 's/^/  /' || bad "could not run R/quarto in the container"
  if [[ -f renv.lock && -f .Rprofile ]]; then
    babs_exec Rscript -e 'for (p in c("DESeq2","IHW","emmeans","ashr","clusterProfiler","ReactomePA","knitr")) cat(sprintf("  %-16s %s\n", p, tryCatch(as.character(packageVersion(p)), error=function(e) "MISSING")))' || bad "package check failed"
  else
    note "renv not yet restored here (run restore-renv.sh), skipping package check"
  fi
fi

[[ $problems -eq 0 ]] && echo "Environment OK" || { echo "$problems problem(s) found"; exit 1; }
