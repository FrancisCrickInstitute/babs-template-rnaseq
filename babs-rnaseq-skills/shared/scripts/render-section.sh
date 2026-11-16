#!/usr/bin/env bash
# Render one report page, doing exactly what the differential makefile does
# for `make html-<page>` (the `pages` route):
#
#   1. stage every page's qmd: staging/<page>.yml (per-page params),
#      staging/<VERSION>.params.yml (project params), merge_yml.ts, then the
#      choose_staging() substitution
#   2. staging/_quarto.yml via sidebar.ts, css/html/_extensions, _quarto-*.yml
#   3. staging/notes.md, staging/index.qmd, staging/R.bib, logs/check_spec.log
#   4. quarto render staging/<page>.qmd --output-dir results/<VERSION>
#        --execute-dir <analysis dir> -M repo:      (log: logs/html-<page>.log)
#
# The parent page (project.mk *_parent) must already have been rendered.
#
# Usage: render-section.sh [--dir ANALYSIS_DIR] SECTION DATA_SOURCE [SPEC]
#   SECTION is 00_init | 01_exploratory | 02_differential | 03_enrichment
#   SPEC (basename of extdata/<spec>.spec) is required except for 00_init.
#   --stage-only   do steps 1-3 and stop (equivalent to `make scripts`)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

dir=. stage_only=false
pos=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) dir="$2"; shift 2 ;;
    --stage-only) stage_only=true; shift ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    *) pos+=("$1"); shift ;;
  esac
done
cd "$dir"
babs_require_workdir

# ------------------------------------------------------------------
# Host side: re-execute this script inside the container, as make does
# with `$(containerPrefix) make $@ EXECUTOR=make`.
# ------------------------------------------------------------------
if [[ -z "${BABS_IN_CONTAINER:-}" ]]; then
  babs_load_env
  # the script and common.sh must be visible inside the container: copy them
  # into the analysis dir (bound) rather than relying on the plugin path.
  mkdir -p .babs-skills
  cp "$SELF" "$(dirname "$SELF")/common.sh" .babs-skills/
  echo '*' > .babs-skills/.gitignore
  args=(); $stage_only && args+=(--stage-only)
  babs_exec bash .babs-skills/render-section.sh ${args[@]+"${args[@]}"} ${pos[@]+"${pos[@]}"}
  exit $?
fi

# ------------------------------------------------------------------
# Container side
# ------------------------------------------------------------------
[[ ${#pos[@]} -ge 2 ]] || babs_die "usage: render-section.sh SECTION DATA_SOURCE [SPEC]"
section="${pos[0]}" ds="${pos[1]}" spec="${pos[2]:-}"
[[ "$section" == 00_* || -n "$spec" ]] || babs_die "$section needs a SPEC"
[[ "$section" == 00_* ]] && spec=""
[[ -f "extdata/${ds}.config" ]] || babs_die "extdata/${ds}.config not found (stage the data source first)"
[[ -z "$spec" || -f "extdata/${spec}.spec" ]] || babs_die "extdata/${spec}.spec not found"
if [[ -n "$spec" ]] && ! babs_specs_for_ds "$ds" | grep -qx "$spec"; then
  babs_die "spec '$spec' is excluded for data source '$ds' by its <ds>.spec/<ds>.nospec setting"
fi
page="$(babs_page_name "$section" "$ds" "$spec")"

S="$BABS_STAGING_DIR" SRC="$BABS_SOURCE_DIR" RES="$BABS_RESULTS_DIR"
VERSION="$(babs_version)"
GIT_REF="$(babs_git_ref)"
babs_info "page $page  VERSION=$VERSION  GIT_REF=$GIT_REF"

babs_mkdir_ignored "$BABS_LOG_DIR" "$RES" "$S"
mkdir -p data "$RES/$VERSION" "$S/$RES/$VERSION"

squote="'"
spec_tag() { # sed -n "s/^#'[[:space:]]*@TAG[[:space:]]*\(.*\)/\1/p" extdata/SPEC.spec | head -n1
  sed -n "s/^#${squote}[[:space:]]*@$2[[:space:]]*\(.*\)/\1/p" "extdata/$1.spec" | head -n1
}

# Per-page yml: the makefile's $(qmds:qmd=yml) recipe, with the
# target-specific variables from the generated .make-<section> files.
write_page_yml() {
  local section="$1" ds="$2" spec="$3" page="$4"
  local cfg="extdata/${ds}.config" cat1="" cat2="" specname="" sourcename=""
  if [[ "$section" == 00_* ]]; then
    cat1="$(babs_config_get "$cfg" categories)"
  else
    cat1="$(spec_tag "$spec" categories)"; cat1="${cat1:-$spec}"
    cat2="$(babs_config_get "$cfg" categories)"; [[ -z "$cat2" ]] && cat2="$(babs_config_get "$cfg" name)"; cat2="${cat2:-$ds}"
    specname="$(spec_tag "$spec" specname)"; specname="${specname:-$spec}"
    sourcename="$(babs_config_get "$cfg" name)"; sourcename="${sourcename:-$ds}"
  fi
  local cats
  if [[ -n "$cat1" ]]; then cats="${cat1}${cat2:+,${cat2}}"; else cats="$cat2"; fi
  local y="$S/${page}.yml"
  {
    echo "title: ${sourcename:-$ds} ${specname:-$spec}"
    echo "description: ${sourcename:-$ds} data${spec:+ according to plan '${specname:-$spec}'}"
    echo "categories: [${cats}]"
    echo "params:"
    echo "  data_source: ${ds}"
    echo "  spec: ${spec:-''}"
    echo "  specname: ${specname:-''}"
    echo "  data_sourcename: ${sourcename:-''}"
    echo "  script: $S/${page}.qmd"
  } > "$y"
}

# $(staging_dir)/$(VERSION).params.yml. The makefile writes this once, with
# metadata/counts taken from whichever page first triggered it; here it is
# rewritten for each page so metadata/counts always match that page's data
# source (identical when there is one data source).
write_params_yml() {
  local ds="$1"
  local me aff; me="$(whoami)"
  aff="${MY_AFFILIATION:-}"; [[ -n "$aff" ]] || aff='{ref: [fci]}'
  {
    echo "author: [{name: \"${FULLNAME:-$me}\", id: ${me}, roles: Analyst, affiliation: ${aff}}]"
    echo "params: {res_dir: \"$RES/$VERSION\", VERSION: \"$VERSION\", GIT_REF: \"$GIT_REF\", staging_dir: \"$S\", file_col: \"${BABS_METADATA_ID_COLUMN}\", name_col: \"${BABS_NAME_COL}\", metadata: \"${BABS_METADATA}_${ds}.csv\", counts: \"${BABS_COUNTS_DIR}/${ds}/\",}"
  } > "$S/${VERSION}.params.yml"
}

# $(qmds) recipe
stage_qmd() {
  local section="$1" ds="$2" spec="$3"
  local p; p="$(babs_page_name "$section" "$ds" "$spec")"
  write_page_yml "$section" "$ds" "$spec" "$p"
  write_params_yml "$ds"
  quarto run "$SRC/typescript/merge_yml.ts" \
    --script="$SRC/${section}.qmd" \
    --fixed="$SRC/params.yml" \
    --subsection="$S/${p}.yml" \
    --generated="$S/${VERSION}.params.yml" > "$S/${p}.qmd"
  babs_sed_i "$S/${p}.qmd" -e "s#choose_staging(\"${section}\")#\"$S/${p}\"#"
}

# ---- 1. stage every page (make's _quarto.yml and index.qmd depend on all qmds)
qmds=()
while read -r sec d sp; do
  stage_qmd "$sec" "$d" "${sp:-}"
  qmds+=("$(babs_page_name "$sec" "$d" "${sp:-}").qmd")
done < <(babs_all_pages)
printf '%s\n' "${qmds[@]}" | grep -qx "${page}.qmd" || babs_die "page $page is not part of this analysis"
# leave the params file matching the page being rendered
write_params_yml "$ds"

# ---- 2. css / html includes / _quarto.yml
cp "$SRC"/css/*.css "$S/"
cp "$SRC"/html/*.html "$S/"
join_by() { local sep="$1"; shift; local out="" x; for x in "$@"; do out="${out:+${out}${sep}}${x}"; done; echo "$out"; }
datasets=($(babs_datasets)); specs=($(babs_specs))
{
  echo "data_source: [$(join_by ', ' "${datasets[@]}")]"
  echo "spec: [null,$(join_by ', ' "${specs[@]}")]"
  echo "section: [$(join_by ', ' "${BABS_SECTIONS[@]}")]"
} > "$S/_sidebar.yml"
quarto run "$SRC/typescript/sidebar.ts" --template="$SRC/_quarto.yml" --staging="$S" --repo="" > "$S/_quarto.yml"
if compgen -G "$RES/multiqc-*" >/dev/null; then echo 'multiqc: "MultiQC and "' >> "$S/_quarto.yml"; else echo 'multiqc: ""' >> "$S/_quarto.yml"; fi
cp "$SRC"/_quarto-*.yml "$S/"
for f in "$S"/_quarto-*.yml; do babs_sed_i "$f" "s/<<GIT_REF>>/${GIT_REF}/"; done
rm -f "$S/_sidebar.yml"
mkdir -p "$S/_extensions"; cp -R "$SRC/_extensions/." "$S/_extensions/"

# ---- 3. check_spec.log, notes.md, index.qmd, R.bib
specfiles=(extdata/*.spec)
R --vanilla -s -e "files <- strsplit('${specfiles[*]}', ' +')[[1]]; ok <- TRUE; for (f in files) { message('Checking ', f); tryCatch(parse(file = f), error = function(e) { message('ERROR in ', f, ': ', e\$message); ok <<- FALSE }) }; if (!ok) quit(status = 1)" \
  2> "$BABS_LOG_DIR/check_spec.log" >/dev/null || { cat "$BABS_LOG_DIR/check_spec.log" >&2; babs_die "a spec file does not parse"; }

notesfile="$(babs_notesfile)"
[[ -f CHANGELOG.md ]] || git log --pretty=format:"- %s (%h)" > CHANGELOG.md
: > "$S/notes.md"
if command -v pandoc >/dev/null; then pandoc -s -o "$S/notes.md" "$notesfile"; else quarto pandoc -s -o "$S/notes.md" "$notesfile"; fi
[[ "$notesfile" == CHANGELOG.md ]] || cat CHANGELOG.md >> "$S/notes.md"

sed "s#^  contents: .*#  contents: [$(join_by ',' "${qmds[@]}")]#" "$SRC/index.qmd" > "$S/index.qmd"

[[ -s extdata/R.bib ]] || babs_die "extdata/R.bib missing: run rnaseq-env-setup/scripts/restore-renv.sh first"
cp extdata/R.bib "$S/R.bib"

$stage_only && { echo "Staged ${#qmds[@]} page(s) in $S (no render)"; exit 0; }

# ---- 4. render
parent="$(babs_parent_page "$section" "$ds" "$spec")"
if [[ -n "$parent" && ! -f "$S/$RES/$VERSION/${parent}.html" ]]; then
  babs_die "parent page $parent has not been rendered for VERSION=$VERSION (render it first; if VERSION changed since, re-render from 00_init)"
fi
log="$BABS_LOG_DIR/html-${page}.log"
set +e
quarto render "$S/${page}.qmd" --output-dir "$RES/$VERSION" --execute-dir "$(pwd -P)" -M repo: 2>&1 | tee "$log"
rc=${PIPESTATUS[0]}
set -e
[[ $rc -eq 0 && -f "$S/$RES/$VERSION/${page}.html" ]] || babs_die "render of $page failed (exit $rc); see $log"
echo "Rendered $S/$RES/$VERSION/${page}.html (log: $log)"
