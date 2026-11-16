#!/usr/bin/env bash
# Verify that the vendored copies in shared/ are byte-identical to
# babs/differential. Exits non-zero (and prints the diff) on any drift.
#
# Usage: shared/sync-check.sh [path/to/babs/differential]
#        shared/sync-check.sh --update [path/to/babs/differential]   # re-copy, then check
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

update=false
if [[ "${1:-}" == "--update" ]]; then update=true; shift; fi
src="${1:-${here}/../../babs/differential}"
src="$(cd "$src" && pwd)"

# Paths (relative to babs/differential) that are vendored. Keep in step
# with plan.md section 3, decision 1.
dirs=(R resources/css resources/html resources/_extensions resources/typescript resources/docker)
files=(renv.lock .env .gitignore
       resources/00_init.qmd resources/01_exploratory.qmd resources/02_differential.qmd resources/03_enrichment.qmd
       resources/_quarto.yml resources/_quarto-concise.yml resources/index.qmd resources/params.yml
       resources/_dependencies.R)

if $update; then
  for d in "${dirs[@]}"; do rm -rf "${here:?}/${d}"; mkdir -p "$(dirname "${here}/${d}")"; cp -R "${src}/${d}" "${here}/${d}"; done
  for f in "${files[@]}"; do mkdir -p "$(dirname "${here}/${f}")"; cp "${src}/${f}" "${here}/${f}"; done
fi

status=0
for d in "${dirs[@]}"; do
  if ! diff -r "${src}/${d}" "${here}/${d}"; then status=1; fi
done
for f in "${files[@]}"; do
  if ! cmp -s "${src}/${f}" "${here}/${f}"; then
    echo "DIFFERS: ${f}"; diff "${src}/${f}" "${here}/${f}" || true; status=1
  fi
done

# The spec-grammar reference is the spec vignette verbatim.
vign="${src}/../../pkgdown/vignettes/spec.rmd"
ref="${here}/../skills/babs-rnaseq-downstream/references/spec-grammar.md"
if [[ -f "$vign" ]]; then
  $update && cp "$vign" "$ref"
  cmp -s "$vign" "$ref" || { echo "DIFFERS: skills/babs-rnaseq-downstream/references/spec-grammar.md vs pkgdown/vignettes/spec.rmd"; status=1; }
fi

# Nothing extra may sit in the vendored R/ directory.
extra=$(cd "${here}" && find R -type f | while read -r f; do [[ -e "${src}/${f}" ]] || echo "$f"; done)
if [[ -n "$extra" ]]; then echo "EXTRA files not in source: $extra"; status=1; fi

if [[ $status -eq 0 ]]; then
  echo "sync-check: vendored code identical to ${src}"
else
  echo "sync-check: DRIFT DETECTED against ${src}" >&2
fi
exit $status
