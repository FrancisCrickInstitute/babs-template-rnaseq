# Shared shell functions for the babs-rnaseq-skills drivers.
# Source this file; do not execute it.
#
# Everything here is a transcription of logic in
# babs/differential/resources/make/shared.mk and project.mk, so that
# the drivers behave as `make` does. Comments name the make variable
# each function replaces.

BABS_SHARED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export BABS_SHARED_DIR

# shared.mk constants
BABS_SOURCE_DIR=resources        # source_dir
BABS_STAGING_DIR=staging         # staging_dir (no ANALYSIS support)
BABS_RESULTS_DIR=results         # RESULTS_DIR
BABS_LOG_DIR=logs                # log_dir
BABS_METADATA_ID_COLUMN=ID       # metadata_id_column
BABS_SAMPLESHEET_ID_COLUMN=sample  # samplesheet_id_column
BABS_NAME_COL=sample_name        # name_col
BABS_COUNTS_DIR=extdata/genes.results   # my_counts_dir (module.mk)
BABS_METADATA=extdata/metadata          # my_metadata (module.mk)
BABS_SECTIONS=(00_init 01_exploratory 02_differential 03_enrichment)  # project.mk `sections`

babs_die() { echo "ERROR: $*" >&2; exit 1; }
babs_warn() { echo "WARNING: $*" >&2; }
babs_info() { echo "== $*" >&2; }

# Portable in-place sed (GNU and BSD): babs_sed_i <file> <sed args...>
babs_sed_i() {
  local f="$1"; shift
  local tmp; tmp="$(mktemp "${f}.XXXXXX")"
  sed "$@" "$f" > "$tmp" && cat "$tmp" > "$f" && rm -f "$tmp"
}

# Parent of each section (project.mk *_parent). Echoes the parent page name.
babs_parent_page() {
  local section="$1" ds="$2" spec="${3:-}"
  case "$section" in
    00_init) echo "" ;;
    01_exploratory) echo "00_init_${ds}" ;;
    02_differential) echo "01_exploratory_${spec}_${ds}" ;;
    03_enrichment) echo "02_differential_${spec}_${ds}" ;;
    *) babs_die "unknown section '$section' (expected one of ${BABS_SECTIONS[*]})" ;;
  esac
}

babs_page_name() {
  local section="$1" ds="$2" spec="${3:-}"
  if [[ "$section" == 00_* ]]; then echo "${section}_${ds}"; else echo "${section}_${spec}_${ds}"; fi
}

# Load the .env chain exactly as shared.mk's ENV_FILES does: walking up
# from the analysis directory, collecting .env.local.$USER, .env.$USER,
# .env.local, .env, then sourcing in reverse (outermost first).
babs_load_env() {
  local dir; dir="$(pwd -P)"
  local files=()
  while :; do
    [[ -f "$dir/.env.local.${USER}" ]] && files+=("$dir/.env.local.${USER}")
    [[ -f "$dir/.env.${USER}" ]] && files+=("$dir/.env.${USER}")
    [[ -f "$dir/.env.local" ]] && files+=("$dir/.env.local")
    [[ -f "$dir/.env" ]] && files+=("$dir/.env")
    [[ "$dir" == "/" ]] && break
    dir="$(dirname "$dir")"
  done
  local i
  set -a
  for (( i=${#files[@]}-1; i>=0; i-- )); do
    # shellcheck disable=SC1090
    source "${files[$i]}"
  done
  set +a
  # shared.mk: NUM_THREADS:=$(or ${SLURM_CPUS_PER_TASK},$(NUM_THREADS),2)
  NUM_THREADS="${SLURM_CPUS_PER_TASK:-${NUM_THREADS:-2}}"
  export NUM_THREADS
  export SINGULARITYENV_GITHUB_PAT="${GITHUB_PAT:-}"
  # module.mk: EXECUTOR = singularity (overridable from the environment)
  EXECUTOR="${EXECUTOR:-singularity}"
  export EXECUTOR
}

# shared.mk VERSION / GIT_HASH / GIT_REF. Must be run inside the analysis dir.
babs_version() {
  local branch
  branch="$(git branch --show-current 2>/dev/null | sed 's/^main$//')"
  local v
  if git diff --quiet --ignore-submodules --exit-code 2>/dev/null; then
    v="$(git describe --tags --exact-match 2>/dev/null || printf "unreleased")"
  else
    v="modified"
  fi
  echo "${branch:+${branch}.}${v}"
}
babs_git_hash() { git rev-parse --short=8 HEAD 2>/dev/null || echo "uncontrolled"; }
babs_git_ref() { echo "_$(babs_version)-$(babs_git_hash)"; }

# Read a key from a make-style config file (as the makefile's sed calls do),
# dropping any trailing make comment. Echoes empty if absent.
babs_config_get() {
  local file="$1" key="$2"
  [[ -f "$file" ]] || return 0
  sed -n "s/^${key}[[:space:]]*=[[:space:]]*\(.*\)/\1/p" "$file" | head -n1 | sed 's/[[:space:]]*#.*$//; s/[[:space:]]*$//'
}

# Datasets (make `datasets`): basenames of extdata/*.config, sorted.
babs_datasets() {
  local f
  for f in extdata/*.config; do [[ -e "$f" ]] && basename "$f" .config; done | LC_ALL=C sort
}
# Specs (make `specs`): basenames of extdata/*.spec, sorted.
babs_specs() {
  local f
  for f in extdata/*.spec; do [[ -e "$f" ]] && basename "$f" .spec; done | LC_ALL=C sort
}

# make `spec_of_data_source`: specs for a data source, honouring
# <ds>.spec (allow-list) and <ds>.nospec (deny-list) in its config.
# The make version splits on spaces; commas are also accepted here
# because the example config documents comma-separated lists.
babs_specs_for_ds() {
  local ds="$1" cfg="extdata/$1.config"
  local allow deny s
  allow="$(babs_config_get "$cfg" spec | tr ',' ' ')"
  deny="$(babs_config_get "$cfg" nospec | tr ',' ' ')"
  [[ -z "$allow" ]] && allow="$(babs_config_get "$cfg" "${ds}\\.spec" | tr ',' ' ')"
  [[ -z "$deny" ]] && deny="$(babs_config_get "$cfg" "${ds}\\.nospec" | tr ',' ' ')"
  for s in $(babs_specs); do
    if [[ -n "$allow" ]] && [[ " $allow " != *" $s "* ]]; then continue; fi
    if [[ " $deny " == *" $s "* ]]; then continue; fi
    echo "$s"
  done
}

# All pages for all sections, in make's order (section, then data source, then spec).
babs_all_pages() {
  local section ds spec
  for section in "${BABS_SECTIONS[@]}"; do
    for ds in $(babs_datasets); do
      if [[ "$section" == 00_* ]]; then
        echo "${section} ${ds}"
      else
        for spec in $(babs_specs_for_ds "$ds"); do echo "${section} ${ds} ${spec}"; done
      fi
    done
  done
}

# Run a command in the analysis directory under the configured executor.
# Mirrors shared.mk CONTAINER / CONTAINER_OPTIONS / CONTAINER_IMAGE.
babs_exec() {
  local bind_dir renv_root
  bind_dir="$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)"
  renv_root="${SINGULARITYENV_RENV_PATHS_ROOT:-${HOME}/.cache/R/renv}"
  mkdir -p "$renv_root" 2>/dev/null || true
  renv_root="$(cd "$renv_root" && pwd -P)"
  case "$EXECUTOR" in
    singularity)
      [[ -n "${SINGULARITY_MODULE:-}" ]] && { module is-loaded "$SINGULARITY_MODULE" 2>/dev/null || module load "$SINGULARITY_MODULE" 2>/dev/null || true; }
      local sif; sif="$(babs_sif_path)"
      [[ -e "$sif" ]] || babs_die "container image $sif not found; run rnaseq-env-setup's check-env.sh --pull"
      local binds="${bind_dir},/tmp,${renv_root}"
      local notes; notes="$(babs_notesfile_if_exists)"
      [[ -n "$notes" ]] && binds="${binds},$(cd "$(dirname "$notes")" && pwd -P)/$(basename "$notes")"
      singularity exec --bind "$binds" --pwd "$(pwd -P)" --containall --cleanenv \
        --env "SQLITE_TMPDIR=/tmp,OMP_NUM_THREADS=${NUM_THREADS},OPENBLAS_NUM_THREADS=${NUM_THREADS},BIOCPARALLEL_WORKER_NUMBER=${NUM_THREADS},SLURM_JOB_ID=${SLURM_JOB_ID:-},SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID:-},BABS_IN_CONTAINER=1,EXECUTOR=make,FULLNAME=${FULLNAME:-},MY_AFFILIATION=${MY_AFFILIATION:-}" \
        "$sif" "$@"
      ;;
    docker)
      # UNTESTED: transcribed from shared.mk for completeness (plan decision 2).
      docker run --rm \
        --mount type=bind,source="$bind_dir",target="$bind_dir" \
        --mount type=bind,source=/tmp,target=/tmp \
        --mount type=bind,source="$renv_root",target="$renv_root" --env RENV_PATHS_ROOT="$renv_root" \
        --env SQLITE_TMPDIR=/tmp --env BIOCPARALLEL_WORKER_NUMBER="$NUM_THREADS" --env GITHUB_PAT \
        --env OMP_NUM_THREADS="$NUM_THREADS" --env OPENBLAS_NUM_THREADS="$NUM_THREADS" \
        --env BABS_IN_CONTAINER=1 --env EXECUTOR=make --env FULLNAME --env MY_AFFILIATION --env USER \
        --workdir="$(pwd -P)" \
        "${IMAGE_REG}${IMAGE}:${IMAGE_TAG}" "$@"
      ;;
    shell|make)
      # shell: UNTESTED and not reproducible (shared.mk prints the same caveat).
      [[ "$EXECUTOR" == shell ]] && babs_warn "EXECUTOR=shell: not using the pinned container, results are not necessarily reproducible"
      BABS_IN_CONTAINER=1 "$@"
      ;;
    *) babs_die "unrecognised EXECUTOR '$EXECUTOR' (singularity|docker|shell)" ;;
  esac
}

# shared.mk SIF_ORIGIN, with the resources/docker/<sif_file> symlink
# (CONTAINER_IMAGE) preferred when it already exists.
babs_sif_path() {
  local link="${BABS_SOURCE_DIR}/docker/${sif_file}"
  if [[ -e "$link" ]]; then echo "$link"; return; fi
  echo "$(babs_sif_origin)"
}
babs_sif_origin() {
  local base="${SINGULARITY_IMAGEDIR:-}"
  [[ -z "$base" ]] && base="${SINGULARITY_CACHEDIR:-${HOME}/.singularity/cache}/library"
  echo "${base}/${sif_file}"
}

# shared.mk notesfile = first of NOTES.org NOTES.md CHANGELOG.md
babs_notesfile() {
  local f
  for f in NOTES.org NOTES.md; do [[ -f "$f" ]] && { echo "$f"; return; }; done
  echo CHANGELOG.md
}
babs_notesfile_if_exists() { local f; f="$(babs_notesfile)"; [[ -f "$f" ]] && echo "$f" || true; }

# Ensure we're at the root of an analysis directory made by init-workdir.sh
babs_require_workdir() {
  [[ -d R && -d resources && -f renv.lock ]] || babs_die "$(pwd) is not an analysis directory (run rnaseq-ingest/scripts/init-workdir.sh first)"
}

# make's `$(log_dir) $(RESULTS_DIR) $(staging_dir)` rule: mkdir + ignore-all .gitignore
babs_mkdir_ignored() {
  local d
  for d in "$@"; do
    if [[ ! -d "$d" ]]; then mkdir -p "$d"; echo "*" > "$d/.gitignore"; fi
  done
}
