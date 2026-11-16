#!/usr/bin/env bash
# Assemble the rendered pages into the final site, as the differential
# makefile's `pages`, `notes` and `run` targets do once all pages exist:
#   - render staging/index.qmd (listing of every page) and staging/notes.md
#   - copy staging/results/<VERSION>/ into results/<VERSION>/
#   - concatenate the per-page manifests into results/<VERSION>/manifest<GIT_REF>.txt
#   - results/latest -> <VERSION>
#   - results/<VERSION>/downloads.php from resources/html/downloads.php
#
# Usage: build-site.sh [--dir ANALYSIS_DIR]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$HERE/$(basename "${BASH_SOURCE[0]}")"
if [[ -n "${BABS_IN_CONTAINER:-}" ]]; then
  source "$HERE/common.sh"          # copies placed in .babs-skills/ by the host side
else
  SHARED="$(cd "$HERE/../../../shared" && pwd)"
  source "$SHARED/scripts/common.sh"
fi

dir=.
while [[ $# -gt 0 ]]; do
  case "$1" in --dir) dir="$2"; shift 2 ;; -h|--help) sed -n '2,11p' "$0"; exit 0 ;; *) babs_die "unknown option $1" ;; esac
done
cd "$dir"; babs_require_workdir

if [[ -z "${BABS_IN_CONTAINER:-}" ]]; then
  babs_load_env
  mkdir -p .babs-skills; echo '*' > .babs-skills/.gitignore
  cp "$SELF" "$SHARED/scripts/common.sh" .babs-skills/
  babs_exec bash .babs-skills/build-site.sh
  exit $?
fi

S="$BABS_STAGING_DIR" RES="$BABS_RESULTS_DIR"
VERSION="$(babs_version)"; GIT_REF="$(babs_git_ref)"
[[ -f "$S/index.qmd" && -f "$S/_quarto.yml" ]] || babs_die "nothing staged: render the pages with render-section.sh first"

# every staged page must have been rendered for this VERSION
missing=()
for q in "$S"/0*.qmd; do
  p="$(basename "$q" .qmd)"
  [[ -f "$S/$RES/$VERSION/$p.html" ]] || missing+=("$p")
done
[[ ${#missing[@]} -eq 0 ]] || babs_die "pages not yet rendered for VERSION=$VERSION: ${missing[*]}"

quarto_opts=(--output-dir "$RES/$VERSION" --execute-dir "$(pwd -P)" -M repo:)
mkdir -p "$RES/$VERSION"
quarto render "$S/index.qmd" "${quarto_opts[@]}" 2>&1 | tee "$BABS_LOG_DIR/html-index.log"
quarto render "$S/notes.md" "${quarto_opts[@]}" 2>&1 | tee "$BABS_LOG_DIR/html-notes.log"
cp -R "$S/$RES/$VERSION/." "$RES/$VERSION/"

shopt -s nullglob
manifests=("$RES/$VERSION"/*/manifest"${GIT_REF}".txt)
if [[ ${#manifests[@]} -gt 0 ]]; then
  awk 'FNR==1 && NR!=1 { next } { print }' "${manifests[@]}" > "$RES/$VERSION/manifest${GIT_REF}.txt"
  rm -f "${manifests[@]}"
else
  babs_warn "no per-page manifest${GIT_REF}.txt files found (were the pages rendered with a different GIT_REF?)"
fi
ln -sfn "$VERSION" "$RES/latest"
sed "s/<<GIT_REF>>/${GIT_REF}/" "$BABS_SOURCE_DIR/html/downloads.php" > "$RES/$VERSION/downloads.php"

echo "Site assembled: $(pwd -P)/$RES/$VERSION/index.html"
echo "  manifest: $RES/$VERSION/manifest${GIT_REF}.txt"
