#!/usr/bin/env bash
# Compare a skill-driven analysis directory with the Phase 0 reference
# (the `differential/` folder unpacked from differential.tar.gz).
# Read-only towards both directories, except for a scratch folder
# RUN_DIR/.babs-compare/ (git-ignored) used to hand files to the container.
#
# Usage:
#   compare-to-reference.sh --ref REF_DIR --run RUN_DIR [--stage STAGE]...
#                           [--ds DATA_SOURCE] [--spec SPEC]
#                           [--run-version VERSION] [--r container|host]
#                           [--report FILE]
#
#   STAGE: inputs | 00_init | 01_exploratory | 02_differential | 03_enrichment
#          | site | all (default). With `all`, a page that has not been
#          rendered in RUN_DIR yet is reported as SKIP, not FAIL.
#   --ds / --spec default to the reference's only extdata/*.config / *.spec.
#   --run-version picks results/<VERSION> in RUN_DIR when several exist
#          (default: the newest staging/<VERSION>.params.yml).
#   --r    where compare-objects.R runs: `container` (default; the run's
#          executor and renv library, as the pages were rendered) or `host`
#          (Rscript on PATH with DESeq2 installed).
#
# What "same" means (plan section 6): identical data objects and tables once
# the version stamps (VERSION, GIT_REF) are replaced by placeholders; the same
# set of figures (names only, not pixels); staged qmd/yml identical apart from
# the stamps and the author block. Each check prints one line:
#   PASS   identical after normalising the stamps
#   FAIL   real difference, missing or unexpected file (details follow)
#   WARN   difference that plan section 6 allows (author block, the xlsx
#          session-info sheets), shown for review
#   SKIP   not applicable / not rendered yet
# Exit status 1 if any FAIL.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED="$(cd "$HERE/../shared" && pwd)"
# shellcheck source=../shared/scripts/common.sh
source "$SHARED/scripts/common.sh"

ref="" run="" ds="" spec="" run_version="" rmode=container report=""
stages=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref) ref="$2"; shift 2 ;;
    --run) run="$2"; shift 2 ;;
    --stage) stages+=("$2"); shift 2 ;;
    --ds) ds="$2"; shift 2 ;;
    --spec) spec="$2"; shift 2 ;;
    --run-version) run_version="$2"; shift 2 ;;
    --r) rmode="$2"; shift 2 ;;
    --report) report="$2"; shift 2 ;;
    -h|--help) sed -n '2,32p' "$0"; exit 0 ;;
    *) babs_die "unknown option $1" ;;
  esac
done
[[ -n "$ref" && -n "$run" ]] || babs_die "--ref and --run are required"
[[ -d "$ref/extdata" && -d "$ref/staging" ]] || babs_die "$ref does not look like the unpacked reference differential/ folder"
[[ -d "$run/extdata" ]] || babs_die "$run does not look like an analysis directory"
ref="$(cd "$ref" && pwd -P)"; run="$(cd "$run" && pwd -P)"
[[ ${#stages[@]} -eq 0 ]] && stages=(all)
[[ " ${stages[*]} " == *" all "* ]] && { stages=(inputs 00_init 01_exploratory 02_differential 03_enrichment site); auto=true; } || auto=false
[[ "$rmode" == container || "$rmode" == host ]] || babs_die "--r must be container or host"
command -v perl >/dev/null || babs_die "perl is needed for the text normalisation"

if [[ -n "$report" ]]; then
  report="$(cd "$(dirname "$report")" && pwd -P)/$(basename "$report")"
  exec > >(tee "$report") 2>&1
fi

# ---------------------------------------------------------------- stamps
# VERSION is the basename of staging/<VERSION>.params.yml; GIT_REF is read from it.
pick_params() { # dir [version]
  if [[ -n "${2:-}" ]]; then echo "$1/staging/$2.params.yml"; return; fi
  ls -t "$1"/staging/*.params.yml 2>/dev/null | head -n1
}
stamp_of() { # params.yml -> "VERSION GIT_REF"
  local f="$1" v g
  v="$(basename "$f" .params.yml)"
  g="$(sed -n 's/.*GIT_REF: *"\([^"]*\)".*/\1/p' "$f" | head -n1)"
  echo "$v $g"
}
rp="$(pick_params "$ref")"; [[ -f "$rp" ]] || babs_die "no staging/*.params.yml in $ref"
read -r REF_V REF_G <<<"$(stamp_of "$rp")"
up="$(pick_params "$run" "$run_version")"
if [[ -f "$up" ]]; then
  read -r RUN_V RUN_G <<<"$(stamp_of "$up")"
  n_params=$(ls "$run"/staging/*.params.yml 2>/dev/null | wc -l | tr -d ' ')
else
  RUN_V="" RUN_G="" n_params=0
fi
export REF_V REF_G RUN_V RUN_G

# defaults for data source and spec: the reference's only ones
if [[ -z "$ds" ]]; then
  c=( "$ref"/extdata/*.config ); [[ ${#c[@]} -eq 1 ]] || babs_die "reference has several data sources; give --ds"
  ds="$(basename "${c[0]}" .config)"
fi
if [[ -z "$spec" ]]; then
  c=( "$ref"/extdata/*.spec ); [[ ${#c[@]} -eq 1 ]] || babs_die "reference has several specs; give --spec"
  spec="$(basename "${c[0]}" .spec)"
fi

# ---------------------------------------------------------------- output helpers
n_pass=0 n_fail=0 n_warn=0 n_skip=0
say() { # status stage item [detail]
  printf '%-5s %-16s %s%s\n' "$1" "$2" "$3" "${4:+  ($4)}"
  case "$1" in PASS) n_pass=$((n_pass+1)) ;; FAIL) n_fail=$((n_fail+1)) ;; WARN) n_warn=$((n_warn+1)) ;; SKIP) n_skip=$((n_skip+1)) ;; esac
}
detail() { sed 's/^/        | /' | head -n "${1:-15}"; }

# Normalise a text stream: stamps -> placeholders (GIT_REF first, it contains VERSION).
norm() { # side(ref|run) < in > out
  if [[ "$1" == ref ]]; then G="$REF_G" V="$REF_V"; else G="$RUN_G" V="$RUN_V"; fi
  G="$G" V="$V" perl -pe 's/\Q$ENV{G}\E/<GIT_REF>/g if length $ENV{G}; s/\Q$ENV{V}\E/<VERSION>/g if length $ENV{V};'
}
# ... and also drop the author block of a merged qmd / params.yml.
norm_noauthor() {
  norm "$1" | perl -ne 'if (/^author:/) { $skip = 1; next if /^author:\s*\[/; } if ($skip) { if (/^\S/ && !/^author:/) { $skip = 0 } else { next } } print'
}
authors_of() { perl -ne 'if (/^author:/) { $s = 1 } elsif (/^\S/) { $s = 0 } print if $s' "$1"; }

cmp_text() { # stage label reffile runfile [norm|norm_noauthor|raw]
  local stage="$1" label="$2" a="$3" b="$4" how="${5:-norm}"
  [[ -f "$a" ]] || { say SKIP "$stage" "$label" "not in reference"; return; }
  [[ -f "$b" ]] || { say FAIL "$stage" "$label" "missing in run: ${b#$run/}"; return; }
  if cmp -s "$a" "$b"; then say PASS "$stage" "$label"; return; fi
  local d
  if [[ "$how" == raw ]]; then d="$(diff "$a" "$b")"
  else d="$(diff <("$how" ref < "$a") <("$how" run < "$b"))"; fi
  if [[ -z "$d" ]]; then say PASS "$stage" "$label" "after normalising version stamps"
  else say FAIL "$stage" "$label" "content differs"; echo "$d" | detail; fi
}

# ---------------------------------------------------------------- R comparisons
r_pairs=()
queue_r() { r_pairs+=("$1" "$2"); }
run_r() { # stage
  local stage="$1"
  [[ ${#r_pairs[@]} -gt 0 ]] || return 0
  local out rc
  if [[ "$rmode" == host ]]; then
    out="$(Rscript --no-init-file "$HERE/compare-objects.R" "$REF_V" "$REF_G" "$RUN_V" "$RUN_G" "${r_pairs[@]}" 2>&1)"; rc=$?
  else
    # The container only binds the run's git top level, /tmp and the renv
    # cache, so hand it copies of the reference files inside RUN_DIR.
    local scratch="$run/.babs-compare" args=() i a b
    mkdir -p "$scratch/ref"; echo '*' > "$scratch/.gitignore"
    cp "$HERE/compare-objects.R" "$scratch/"
    for (( i=0; i<${#r_pairs[@]}; i+=2 )); do
      a="${r_pairs[$i]}" b="${r_pairs[$((i+1))]}"
      local base; base="$(basename "$a")"
      if [[ -f "$a" ]]; then cp "$a" "$scratch/ref/$base"; args+=(".babs-compare/ref/$base"); else args+=("$a"); fi
      args+=("${b#$run/}")
    done
    out="$(cd "$run" && babs_load_env && babs_exec Rscript .babs-compare/compare-objects.R "$REF_V" "$REF_G" "$RUN_V" "$RUN_G" "${args[@]}" 2>&1)"; rc=$?
    rm -rf "$scratch/ref"
  fi
  # compare-objects.R prints a file's leaf lines before its SUMMARY line;
  # buffer them so each result line is followed by its own details.
  local line buf="" f st
  while IFS= read -r line; do
    case "$line" in
      *" SUMMARY "*)
        f="$(echo "$line" | awk '{print $1}')"
        st=PASS
        [[ "$line" == *"-> PASS (session info differs)" ]] && st=WARN
        [[ "$line" == *"-> FAIL" ]] && st=FAIL
        say "$st" "$stage" "object $f" "$(echo "$line" | sed 's/.*SUMMARY *//; s/ -> .*//')"
        [[ -n "$buf" ]] && printf '%s' "$buf" | sed 's/^[^ ]* *//' | detail 40
        buf="" ;;
      *" MISSING reference file "*|*" MISSING run file "*)
        say FAIL "$stage" "object $(echo "$line" | awk '{print $1}')" "$(echo "$line" | sed 's/^[^ ]* *//')" ;;
      *" DIFFERS "*|*" MISSING "*|*" EXTRA "*|*" EQUAL "*|*" SESSION "*)
        buf+="$line"$'\n' ;;
    esac
  done <<<"$out"
  if ! grep -q ' SUMMARY \| MISSING reference file \| MISSING run file ' <<<"$out"; then
    say FAIL "$stage" "R comparison" "compare-objects.R failed to run (exit $rc)"
    echo "$out" | grep -v 'built under R version\|^Loading required package\|^Warning messages' | detail 20
  fi
  r_pairs=()
}

# ---------------------------------------------------------------- page outputs
rendered_html() { # page -> path of the run's html, or empty
  local p="$1" f
  for f in "$run/staging/results/$RUN_V/$p.html" "$run/results/$RUN_V/$p.html"; do [[ -f "$f" ]] && { echo "$f"; return; }; done
}

# A page's outputs are split across two folders until build-site.sh runs:
# quarto writes figures and the knitr-linked downloads under
# staging/results/<VERSION>/<page>/, while the R code writes some tables and
# the xlsx straight to results/<VERSION>/<page>/. build-site.sh then copies
# the staging folder over results/ (`cp -R`), so staging wins on a clash.
# The run's page folder is therefore the union of the two, staging first.
run_page_dirs=()
set_run_page_dirs() { # page
  run_page_dirs=()
  local d
  for d in "$run/staging/results/$RUN_V/$1" "$run/results/$RUN_V/$1"; do [[ -d "$d" ]] && run_page_dirs+=("$d"); done
}
run_file() { # rel -> path in the run's page folder (staging first), or empty
  local d
  for d in ${run_page_dirs[@]+"${run_page_dirs[@]}"}; do [[ -f "$d/$1" ]] && { echo "$d/$1"; return; }; done
}
run_rel_files() { # find-args... -> relative paths across the run's page folders, de-duplicated
  local d
  for d in ${run_page_dirs[@]+"${run_page_dirs[@]}"}; do (cd "$d" && find . -type f "$@" | sed 's#^\./##'); done | LC_ALL=C sort -u
}

compare_page_folder() { # stage page
  local stage="$1" page="$2"
  local rd="$ref/results/$REF_V/$page"
  if [[ ! -d "$rd" ]]; then say SKIP "$stage" "tables" "reference has no results folder for $page"; return; fi
  set_run_page_dirs "$page"
  [[ ${#run_page_dirs[@]} -gt 0 ]] || { say FAIL "$stage" "tables" "missing folder results/$RUN_V/$page (and staging/results/$RUN_V/$page)"; return; }
  local where="" n_staging_only
  n_staging_only=0
  if [[ ! -f "$run/results/$RUN_V/index.html" && -d "$run/staging/results/$RUN_V/$page" ]]; then
    n_staging_only="$(cd "$run/staging/results/$RUN_V/$page" && find . -type f | while IFS= read -r f; do [[ -f "$run/results/$RUN_V/$page/$f" ]] || echo x; done | grep -c . || true)"
    [[ "$n_staging_only" -gt 0 ]] && where="; $n_staging_only file(s) read from staging/, build-site.sh not run yet"
  fi
  local f uf rel name mapped n_same=0 n_ver=0 bad=() figs_ref figs_run
  local tables=( \( -name '*.tsv' -o -name '*.csv' -o -name '*.txt' -o -name '*.json' \) )
  # text tables
  while IFS= read -r f; do
    rel="${f#$rd/}"; name="$(basename "$rel")"
    [[ "$name" == manifest* ]] && continue   # per-page manifests are merged by build-site
    mapped="${rel//$REF_G/$RUN_G}"
    uf="$(run_file "$mapped")"
    if [[ -z "$uf" ]]; then bad+=("MISSING  $mapped"); continue; fi
    if cmp -s "$f" "$uf"; then n_same=$((n_same+1))
    elif diff -q <(norm ref < "$f") <(norm run < "$uf") >/dev/null; then n_ver=$((n_ver+1))
    else bad+=("DIFFERS  $rel"); fi
  done < <(find "$rd" -type f "${tables[@]}" | LC_ALL=C sort)
  # files in the run with no reference counterpart
  while IFS= read -r rel; do
    name="$(basename "$rel")"
    [[ "$name" == manifest* ]] && continue
    mapped="${rel//$RUN_G/$REF_G}"
    [[ -f "$rd/$mapped" ]] || bad+=("EXTRA    $rel")
  done < <(run_rel_files "${tables[@]}")
  local total=$((n_same+n_ver+${#bad[@]}))
  if [[ ${#bad[@]} -eq 0 ]]; then
    say PASS "$stage" "tables" "$n_same identical, $n_ver identical apart from stamps$where"
  else
    say FAIL "$stage" "tables" "${#bad[@]} of $total not matching"
    printf '%s\n' "${bad[@]}" | detail 30
    # show the start of the first real difference
    for f in "${bad[@]}"; do
      [[ "$f" == DIFFERS* ]] || continue
      rel="${f#DIFFERS  }"
      diff <(norm ref < "$rd/$rel") <(norm run < "$(run_file "${rel//$REF_G/$RUN_G}")") | detail 10
      break
    done
  fi
  # figures: names only
  local figs=( \( -name '*.png' -o -name '*.pdf' -o -name '*.svg' \) )
  figs_ref="$(cd "$rd" && find . -type f "${figs[@]}" | sed 's#^\./##' | norm ref | LC_ALL=C sort)"
  figs_run="$(run_rel_files "${figs[@]}" | norm run | LC_ALL=C sort)"
  if [[ "$figs_ref" == "$figs_run" ]]; then
    say PASS "$stage" "figure set" "$(echo -n "$figs_ref" | grep -c . | tr -d ' ') files, names only"
  else
    say FAIL "$stage" "figure set" "file names differ"
    diff <(echo "$figs_ref") <(echo "$figs_run") | grep '^[<>]' | sed 's/^</only in reference:/; s/^>/only in run:      /' | detail 20
  fi
  # spreadsheets go through the R comparison, sheet by sheet
  while IFS= read -r f; do
    rel="${f#$rd/}"; mapped="${rel//$REF_G/$RUN_G}"
    uf="$(run_file "$mapped")"
    queue_r "$f" "${uf:-$run/results/$RUN_V/$page/$mapped}"
  done < <(find "$rd" -type f -name '*.xlsx' | LC_ALL=C sort)
}

check_errors_in_html() { # stage html
  local n; n="$(grep -c 'cell-output-error' "$2" 2>/dev/null || true)"
  if [[ "${n:-0}" -eq 0 ]]; then say PASS "$1" "no R errors in page"
  else say FAIL "$1" "R errors in page" "$n error block(s) in ${2#$run/}; see the page and its log"; fi
}

check_section() { # section
  local section="$1" page stage="$1"
  page="$(babs_page_name "$section" "$ds" "$spec")"
  local html; html="$(rendered_html "$page")"
  if [[ -z "$RUN_V" || -z "$html" ]]; then
    if $auto; then say SKIP "$stage" "$page" "not rendered in run yet"; else say FAIL "$stage" "$page" "not rendered in run"; fi
    return
  fi
  check_errors_in_html "$stage" "$html"
  cmp_text "$stage" "staged $page.yml" "$ref/staging/$page.yml" "$run/staging/$page.yml"
  cmp_text "$stage" "staged $page.qmd" "$ref/staging/$page.qmd" "$run/staging/$page.qmd" norm_noauthor
  if ! diff -q <(authors_of "$ref/staging/$page.qmd") <(authors_of "$run/staging/$page.qmd") >/dev/null 2>&1; then
    say WARN "$stage" "author block of $page.qmd" "differs; allowed by plan section 6"
    diff <(authors_of "$ref/staging/$page.qmd") <(authors_of "$run/staging/$page.qmd") | detail 8
  fi
  case "$section" in
    00_init)
      cmp_text "$stage" "staged params.yml" "$rp" "$up" norm_noauthor
      queue_r "$ref/data/counts_${ds}.rds" "$run/data/counts_${ds}.rds"
      queue_r "$ref/data/counts_${ds}.rda" "$run/data/counts_${ds}.rda" ;;
    01_exploratory)
      queue_r "$ref/data/ddsList_${ds}_${spec}.rda" "$run/data/ddsList_${ds}_${spec}.rda"
      queue_r "$ref/data/exploratory_plots.rds" "$run/data/exploratory_plots.rds" ;;
    02_differential)
      queue_r "$ref/data/${spec}_x_${ds}.rds" "$run/data/${spec}_x_${ds}.rds"
      queue_r "$ref/data/${spec}_x_${ds}.rda" "$run/data/${spec}_x_${ds}.rda" ;;
  esac
  compare_page_folder "$stage" "$page"
  run_r "$stage"
}

check_inputs() {
  local stage=inputs
  cmp_text $stage "extdata/metadata.csv" "$ref/extdata/metadata.csv" "$run/extdata/metadata.csv" raw
  cmp_text $stage "extdata/metadata_${ds}.csv" "$ref/extdata/metadata_${ds}.csv" "$run/extdata/metadata_${ds}.csv" raw
  cmp_text $stage "extdata/${spec}.spec" "$ref/extdata/${spec}.spec" "$run/extdata/${spec}.spec" raw
  # config: the ingress stage adds md5 lines that nothing downstream reads
  local a="$ref/extdata/${ds}.config" b="$run/extdata/${ds}.config"
  if [[ -f "$b" ]]; then
    local d; d="$(diff <(grep -v '_md5=' "$a" | LC_ALL=C sort) <(grep -v '_md5=' "$b" | LC_ALL=C sort))"
    if [[ -z "$d" ]]; then say PASS $stage "extdata/${ds}.config" "ignoring *_md5 lines and line order"
    else say FAIL $stage "extdata/${ds}.config" "settings differ"; echo "$d" | detail; fi
  else say FAIL $stage "extdata/${ds}.config" "missing in run"; fi
  # counts
  local rc="$ref/extdata/genes.results/$ds" uc="$run/extdata/genes.results/$ds"
  if [[ ! -d "$rc" ]]; then say SKIP $stage "count files" "reference archive has no extdata/genes.results/$ds"
  elif [[ ! -d "$uc" ]]; then say FAIL $stage "count files" "missing folder extdata/genes.results/$ds"
  else
    local la lb diffs=0 f
    la="$(cd "$rc" && find . -type f | LC_ALL=C sort)"; lb="$(cd "$uc" && find . -type f | LC_ALL=C sort)"
    if [[ "$la" != "$lb" ]]; then say FAIL $stage "count files" "different file lists"; diff <(echo "$la") <(echo "$lb") | detail
    else
      while IFS= read -r f; do cmp -s "$rc/$f" "$uc/$f" || diffs=$((diffs+1)); done <<<"$la"
      if [[ $diffs -eq 0 ]]; then say PASS $stage "count files" "$(echo "$la" | grep -c .) files identical"
      else say FAIL $stage "count files" "$diffs file(s) differ"; fi
    fi
  fi
  if [[ -f "$run/results/multiqc-$ds/multiqc_report.html" ]]; then say PASS $stage "multiqc report staged"
  elif [[ -f "$ref/results/multiqc-$ds/multiqc_report.html" ]]; then say FAIL $stage "multiqc report staged" "missing results/multiqc-$ds/multiqc_report.html"
  else say SKIP $stage "multiqc report staged" "not in reference either"; fi
  [[ -s "$run/extdata/R.bib" ]] && say PASS $stage "extdata/R.bib written" || say SKIP $stage "extdata/R.bib written" "not yet (restore-renv.sh)"
}

check_site() {
  local stage=site
  if [[ -z "$RUN_V" || ! -f "$run/results/$RUN_V/index.html" ]]; then
    if $auto; then say SKIP $stage "site" "build-site.sh not run yet"; else say FAIL $stage "site" "results/$RUN_V/index.html missing"; fi
    return
  fi
  local l; l="$(readlink "$run/results/latest" 2>/dev/null || true)"
  [[ "$l" == "$RUN_V" ]] && say PASS $stage "results/latest -> $RUN_V" || say FAIL $stage "results/latest" "points to '${l:-nothing}', expected $RUN_V"
  local f
  for f in index.html notes.html downloads.php; do
    [[ -f "$run/results/$RUN_V/$f" ]] && say PASS $stage "$f present" || say FAIL $stage "$f present" "missing"
  done
  local p
  for p in $(cd "$ref/results/$REF_V" && ls *.html 2>/dev/null); do
    [[ -f "$run/results/$RUN_V/$p" ]] || say FAIL $stage "page $p" "missing from results/$RUN_V"
  done
  cmp_text $stage "manifest" "$ref/results/$REF_V/manifest${REF_G}.txt" "$run/results/$RUN_V/manifest${RUN_G}.txt"
  cmp_text $stage "staged _quarto.yml" "$ref/staging/_quarto.yml" "$run/staging/_quarto.yml"
  cmp_text $stage "staged index.qmd" "$ref/staging/index.qmd" "$run/staging/index.qmd"
  grep -q "${RUN_G}" "$run/results/$RUN_V/downloads.php" 2>/dev/null \
    && say PASS $stage "downloads.php stamped with $RUN_G" \
    || say FAIL $stage "downloads.php" "does not mention $RUN_G"
}

# ---------------------------------------------------------------- main
echo "Reference: $ref"
echo "  VERSION=$REF_V  GIT_REF=$REF_G"
echo "Run:       $run"
echo "  VERSION=${RUN_V:-<none rendered yet>}  GIT_REF=${RUN_G:-<none>}"
echo "Data source: $ds   spec: $spec   R comparisons: $rmode"
[[ "$n_params" -gt 1 ]] && babs_warn "run has $n_params staging/*.params.yml files (VERSION changed during the run); comparing $RUN_V. Use --run-version to pick another."
echo
for s in "${stages[@]}"; do
  case "$s" in
    inputs) check_inputs ;;
    00_init|01_exploratory|02_differential|03_enrichment) check_section "$s" ;;
    site) check_site ;;
    *) babs_die "unknown stage $s" ;;
  esac
done
echo
echo "Summary: $n_pass pass, $n_fail fail, $n_warn warn, $n_skip skip"
[[ $n_fail -eq 0 ]]
