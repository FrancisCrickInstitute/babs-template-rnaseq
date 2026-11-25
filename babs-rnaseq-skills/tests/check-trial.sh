#!/usr/bin/env bash
# Phase 8: check what one agent trial left behind, for the objective parts of
# the case's graders. Read-only towards the trial, apart from the scratch
# folders the comparisons use inside the analysis directory (.babs-compare/,
# .babs-skills/, both git-ignored). The behaviour graders (order of steps,
# what the agent said) are judged from the transcript, not here.
#
# Usage: check-trial.sh --case CASE --run RUN_DIR
#   RUN_DIR is the trial's with_skill/ folder; the agent worked in
#   RUN_DIR/outputs, so the analysis is RUN_DIR/outputs/analysis.
#
# Environment (defaults match tests/RUNBOOK.md on NEMO):
#   BABS_TRIAL_ROOT  /flask/scratch/babs/$USER/skills-test
#   BABS_TRIAL_REF   $BABS_TRIAL_ROOT/reference/differential   (Phase 0 reference)
#   BABS_TRIAL_BASE  $BABS_TRIAL_ROOT/airway   (finished run copied by add-comparison)
#
# Each line: PASS / FAIL / INFO, as in compare-to-reference.sh. Exit 1 on any FAIL.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="$(cd "$HERE/.." && pwd)"
EVALS="$PLUGIN/skills/babs-rnaseq-downstream/evals"
# shellcheck source=../shared/scripts/common.sh
source "$PLUGIN/shared/scripts/common.sh"

case_="" run=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --case) case_="$2"; shift 2 ;;
    --run) run="$2"; shift 2 ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    *) babs_die "unknown option $1" ;;
  esac
done
[[ -n "$case_" && -n "$run" ]] || babs_die "--case and --run are required"
[[ -d "$EVALS/$case_" ]] || babs_die "no eval case $case_ in $EVALS"
run="$(cd "$run" && pwd -P)"
T="${BABS_TRIAL_ROOT:-/flask/scratch/babs/$USER/skills-test}"
REF="${BABS_TRIAL_REF:-$T/reference/differential}"
BASE="${BABS_TRIAL_BASE:-$T/airway}"
out="$run/outputs" A="$run/outputs/analysis" files="$EVALS/$case_/files"
ds=GRCh38

n_pass=0 n_fail=0
say() { # status item [detail]
  printf '%-5s %s%s\n' "$1" "$2" "${3:+  ($3)}"
  case "$1" in PASS) n_pass=$((n_pass+1)) ;; FAIL) n_fail=$((n_fail+1)) ;; esac
}
detail() { sed 's/^/        | /' | head -n "${1:-20}"; }
same_file() { # label expected actual
  if [[ ! -f "$3" ]]; then say FAIL "$1" "missing: ${3#$run/}"
  elif cmp -s "$2" "$3"; then say PASS "$1"
  else say FAIL "$1" "changed"; diff "$2" "$3" | detail 10; fi
}
# the newest VERSION in the analysis, as compare-to-reference.sh picks it
newest_version() { local p; p="$(ls -t "$A"/staging/*.params.yml 2>/dev/null | head -n1)"; [[ -n "$p" ]] && basename "$p" .params.yml; }
html_for() { # page version -> path or empty
  local f
  for f in "$A/staging/results/$2/$1.html" "$A/results/$2/$1.html"; do [[ -f "$f" ]] && { echo "$f"; return; }; done
}
# run an R helper from tests/ inside the analysis directory's container
r_helper() { bash "$PLUGIN/shared/scripts/run-r-helper.sh" --dir "$A" "$@" 2>&1 | grep -v '^- Project\|out-of-sync\|^Loading required\|built under R'; }
cmpref() { bash "$HERE/compare-to-reference.sh" --ref "$REF" --run "$A" "$@"; }

echo "Case:  $case_"
echo "Trial: $run"
echo

# ---------------------------------------------------------------- common
common_checks() {
  local f bad=()
  for f in "$PLUGIN"/shared/R/*; do cmp -s "$f" "$A/R/$(basename "$f")" || bad+=("R/$(basename "$f")"); done
  for f in "$PLUGIN"/shared/resources/*.qmd; do cmp -s "$f" "$A/resources/$(basename "$f")" || bad+=("resources/$(basename "$f")"); done
  [[ ${#bad[@]} -eq 0 ]] && say PASS "vendored R/ and resources/*.qmd untouched" \
    || { say FAIL "vendored R/ and resources/*.qmd untouched" "${#bad[@]} file(s) differ from the plugin"; printf '%s\n' "${bad[@]}" | detail; }
  # prepare-trial.sh gives the agent a copy of the plugin; it must match this one
  local pcopy="$T/trial-plugin/babs-rnaseq-skills" d
  if [[ -d "$pcopy" ]]; then
    d="$(diff -rq --exclude=evals --exclude=tests "$PLUGIN" "$pcopy" 2>&1)"
    [[ -z "$d" ]] && say PASS "agent's plugin copy unchanged" || { say FAIL "agent's plugin copy unchanged"; echo "$d" | detail; }
  else
    local dirty; dirty="$(git -C "$PLUGIN" status --porcelain -- . 2>/dev/null)"
    [[ -z "$dirty" ]] && say PASS "plugin checkout unchanged" || { say FAIL "plugin checkout unchanged"; echo "$dirty" | detail; }
  fi
  local v; v="$(newest_version)"
  say INFO "VERSIONs staged" "$(cd "$A/staging" 2>/dev/null && ls *.params.yml 2>/dev/null | sed 's/\.params\.yml$//' | tr '\n' ' ')"
  local h n
  while IFS= read -r h; do
    n="$(grep -c 'cell-output-error' "$h" 2>/dev/null || true)"
    if [[ "${n:-0}" -eq 0 ]]; then say PASS "no R errors in ${h#$A/}"; else say FAIL "R errors in ${h#$A/}" "$n error block(s)"; fi
  done < <(find "$A/staging/results" "$A/results" -maxdepth 2 -name '0[0-3]_*.html' 2>/dev/null | LC_ALL=C sort)
  if [[ -f "$A/logs/renv.log" ]]; then
    say INFO "renv.log ends" "$(grep -E 'synchronized|out-of-sync|installed|restored' "$A/logs/renv.log" | tail -n1)"
  fi
}

expect_pages() { # version page...
  local v="$1" p; shift
  for p in "$@"; do
    [[ -n "$(html_for "$p" "$v")" ]] && say PASS "page $p rendered for $v" || say FAIL "page $p rendered for $v" "no html"
  done
}

# ---------------------------------------------------------------- cases
case "$case_" in
  airway-shipped-spec-matches-reference)
    [[ -d "$A" ]] || say FAIL "analysis directory" "missing"
    same_file "input analyse.spec unchanged" "$files/analyse.spec" "$out/analyse.spec"
    same_file "staged analyse.spec unchanged" "$files/analyse.spec" "$A/extdata/analyse.spec"
    common_checks
    v="$(newest_version)"
    expect_pages "$v" 00_init_$ds 01_exploratory_analyse_$ds 02_differential_analyse_$ds 03_enrichment_analyse_$ds
    [[ -f "$A/results/$v/index.html" ]] && say PASS "site built for $v" || say FAIL "site built for $v" "no results/$v/index.html"
    cmpref --stage all > "$run/compare.txt" 2>&1
    s="$(grep '^Summary:' "$run/compare.txt")"
    if [[ "$s" == *" 0 fail"* ]]; then say PASS "matches Phase 0 reference" "$s"
    else say FAIL "matches Phase 0 reference" "$s; see compare.txt"; grep -A4 '^FAIL' "$run/compare.txt" | detail 30; fi
    ;;

  airway-two-specs-renders-every-page)
    [[ -d "$A" ]] || say FAIL "analysis directory" "missing"
    for s in analyse treatment; do
      same_file "staged $s.spec unchanged" "$files/$s.spec" "$A/extdata/$s.spec"
    done
    common_checks
    v="$(newest_version)"
    expect_pages "$v" 00_init_$ds \
      01_exploratory_analyse_$ds 02_differential_analyse_$ds 03_enrichment_analyse_$ds \
      01_exploratory_treatment_$ds 02_differential_treatment_$ds 03_enrichment_treatment_$ds
    [[ -f "$A/results/$v/index.html" ]] && say PASS "site built for $v" || say FAIL "site built for $v" "no results/$v/index.html"
    cmpref --spec analyse --stage inputs --stage 00_init --stage 01_exploratory --stage 02_differential --stage 03_enrichment > "$run/compare.txt" 2>&1
    s="$(grep '^Summary:' "$run/compare.txt")"
    others="$(grep '^FAIL' "$run/compare.txt" | grep -v 'exploratory_plots\.rds' || true)"
    if [[ -z "$others" ]]; then say PASS "analyse pages match Phase 0 reference" "$s; exploratory_plots.rds may differ"
    else say FAIL "analyse pages match Phase 0 reference" "$s; see compare.txt"; echo "$others" | detail 30; fi
    # treatment C1 should be reference D1/M1/C1 with the direction reversed
    if [[ -f "$A/data/treatment_x_$ds.rds" ]]; then
      mkdir -p "$A/.babs-compare"; echo '*' > "$A/.babs-compare/.gitignore"
      cp "$REF/data/analyse_x_$ds.rds" "$A/.babs-compare/old.rds"
      r_helper "$HERE/check-results.R" .babs-compare/old.rds "data/treatment_x_$ds.rds" > "$run/results-match.txt"
      rm -f "$A/.babs-compare/old.rds"
      l="$(grep '^NEW ' "$run/results-match.txt" | head -n1)"
      if [[ "$l" == *"OLD D1/M1/C1 "*"(reversed)"* ]]; then say PASS "treatment comparison = reference C1 reversed" "$(echo "$l" | sed 's/  */ /g')"
      else say FAIL "treatment comparison = reference C1 reversed" "see results-match.txt"; cat "$run/results-match.txt" | detail 10; fi
    else say FAIL "treatment comparison" "no data/treatment_x_$ds.rds"; fi
    ;;

  unknown-covariate-stops-before-render)
    same_file "input analyse.spec unchanged" "$files/analyse.spec" "$out/analyse.spec"
    same_file "input experiment_table.csv unchanged" "$files/experiment_table.csv" "$out/experiment_table.csv"
    if [[ -d "$A" ]]; then
      same_file "staged analyse.spec unchanged" "$files/analyse.spec" "$A/extdata/analyse.spec"
      if [[ -f "$A/extdata/metadata.csv" ]]; then
        if diff -q <(tr -d '\r' < "$files/experiment_table.csv") "$A/extdata/metadata.csv" >/dev/null; then say PASS "staged experiment table unchanged"
        else say FAIL "staged experiment table unchanged"; diff <(tr -d '\r' < "$files/experiment_table.csv") "$A/extdata/metadata.csv" | detail 10; fi
      fi
      grep -rl 'cell_line' "$A"/extdata/*.csv >/dev/null 2>&1 && say FAIL "no cell_line column added" || say PASS "no cell_line column added"
      h="$(find "$A" -path '*results*' -name '0[0-3]_*.html' 2>/dev/null | head -n3)"
      [[ -z "$h" ]] && say PASS "no page rendered" || { say FAIL "no page rendered"; echo "$h" | detail; }
      [[ -f "$A/logs/renv.log" ]] && say INFO "restore-renv.sh was run" "the orchestrator validates before restoring" || say PASS "stopped before restore-renv.sh"
    else
      say INFO "analysis directory" "not created; check the transcript for where the agent stopped"
    fi
    ;;

  add-comparison-to-finished-run)
    [[ -d "$A" ]] || say FAIL "analysis directory" "missing"
    d="$(diff "$BASE/extdata/analyse.spec" "$A/extdata/analyse.spec")"
    if [[ -z "$d" ]]; then say FAIL "spec edited" "analysis/extdata/analyse.spec is unchanged"
    else
      say INFO "spec diff (base -> trial)"; echo "$d" | detail 20
      removed="$(echo "$d" | grep -c '^<' || true)"; added="$(echo "$d" | grep '^>' || true)"
      if [[ "$removed" -eq 0 ]] && echo "$added" | grep -q 'trt\.vs\.ctrl\|N61311'; then say PASS "spec edit only adds a comparison"
      else say FAIL "spec edit only adds a comparison" "$removed line(s) removed or changed; check the diff"; fi
    fi
    common_checks
    v="$(newest_version)"
    vb="$(basename "$(ls -t "$BASE"/staging/*.params.yml | head -n1)" .params.yml)"
    say INFO "VERSION before / after" "$vb / $v"
    expect_pages "$v" 00_init_$ds 01_exploratory_analyse_$ds 02_differential_analyse_$ds 03_enrichment_analyse_$ds
    [[ -f "$A/results/$v/index.html" ]] && say PASS "site rebuilt for $v" || say FAIL "site rebuilt for $v" "no results/$v/index.html"
    # every original comparison kept, plus three new ones that each equal a C2 pairwise contrast
    mkdir -p "$A/.babs-compare"; echo '*' > "$A/.babs-compare/.gitignore"
    cp "$BASE/data/analyse_x_$ds.rds" "$A/.babs-compare/old.rds"
    r_helper "$HERE/check-results.R" .babs-compare/old.rds "data/analyse_x_$ds.rds" > "$run/results-match.txt"
    rm -f "$A/.babs-compare/old.rds"
    s="$(grep '^SUMMARY' "$run/results-match.txt")"
    [[ -n "$s" ]] || { say FAIL "results comparison" "check-results.R failed"; cat "$run/results-match.txt" | detail 10; }
    [[ "$s" == *"old_missing=0"* ]] && say PASS "existing comparisons unchanged" "$s" || say FAIL "existing comparisons unchanged" "$s"
    # three added contrasts, each equal (up to sign) to a pairwise contrast already there
    if [[ "$s" == *"extra=3"* && "$s" == *"new_only=0"* ]] && ! grep -q 'LFC differs' "$run/results-match.txt"; then
      say PASS "three new contrasts, each equal to a C2 pairwise contrast"
    else say FAIL "three new contrasts, each equal to a C2 pairwise contrast" "see results-match.txt"; fi
    # the new ones are the NEW lines whose OLD match is also claimed by an earlier NEW line
    awk '/^NEW / && / <-  OLD / { o=$5; if (seen[o]++) print }' "$run/results-match.txt" | detail 10
    ;;

  *) babs_die "no checks written for case $case_" ;;
esac

echo
echo "Checks: $n_pass pass, $n_fail fail"
[[ $n_fail -eq 0 ]]
