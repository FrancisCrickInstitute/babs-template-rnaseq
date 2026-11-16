#!/usr/bin/env bash
# Gather the inputs of one data source into an analysis directory, exactly
# as the differential makefile's bootstrap recipes do:
#
#   experiment table -> extdata/metadata.csv            (ingress: tr -d '\r')
#   config           -> extdata/<ds>.config             (ingress: tr -d '\r' + defaults)
#   spec(s)          -> extdata/<spec>.spec
#   metadata INNER JOIN samplesheet ON ID = sample
#                    -> extdata/metadata_<ds>.csv       (sqlite, same SQL as the makefile)
#   star_rsem/*.genes.results -> extdata/genes.results/<ds>/   (hard link, else copy)
#   (star_salmon/<s>/quant.sf + salmon_tx2gene.tsv -> extdata/genes.results/<ds>/star_salmon/)
#   multiqc          -> results/multiqc-<ds>/
#
# Usage:
#   stage-inputs.sh --dir ANALYSIS_DIR --nfcore NFCORE_DIR --experiment-table CSV
#                   --spec FILE.spec [--spec ...]
#                   (--config FILE.config | --org-db org.Xx.eg.db)
#                   [--data-source DS] [--samplesheet CSV] [--aligner star_rsem|star_salmon]
#
# --data-source defaults to the config basename, else the nf-core outdir basename.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED="$(cd "$HERE/../../../shared" && pwd)"
source "$SHARED/scripts/common.sh"

dir="" nfcore="" etable="" config="" orgdb="" ds="" sheet="" aligner=""
specs=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) dir="$2"; shift 2 ;;
    --nfcore) nfcore="$2"; shift 2 ;;
    --experiment-table) etable="$2"; shift 2 ;;
    --spec) specs+=("$2"); shift 2 ;;
    --config) config="$2"; shift 2 ;;
    --org-db) orgdb="$2"; shift 2 ;;
    --data-source) ds="$2"; shift 2 ;;
    --samplesheet) sheet="$2"; shift 2 ;;
    --aligner) aligner="$2"; shift 2 ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) babs_die "unknown option $1" ;;
  esac
done
[[ -n "$dir" && -n "$nfcore" && -n "$etable" ]] || babs_die "--dir, --nfcore and --experiment-table are required"
[[ ${#specs[@]} -gt 0 ]] || babs_die "at least one --spec is required (the user supplies the spec; do not invent one)"
[[ -n "$config" || -n "$orgdb" ]] || babs_die "give --config or --org-db"
abspath() { echo "$(cd "$(dirname "$1")" && pwd -P)/$(basename "$1")"; }
etable="$(abspath "$etable")"; [[ -s "$etable" ]] || babs_die "experiment table $etable missing or empty"
[[ -n "$config" ]] && { config="$(abspath "$config")"; [[ -s "$config" ]] || babs_die "config $config missing or empty"; }
[[ -n "$sheet" ]] && sheet="$(abspath "$sheet")"
for i in "${!specs[@]}"; do
  specs[$i]="$(abspath "${specs[$i]}")"
  [[ "${specs[$i]}" == *.spec ]] || babs_die "${specs[$i]} must have a .spec extension"
done
[[ -z "$ds" && -n "$config" ]] && ds="$(basename "$config" .config)"

# --- discover nf-core outputs
disc_args=("$nfcore"); [[ -n "$ds" ]] && disc_args+=(--data-source "$ds"); [[ -n "$sheet" ]] && disc_args+=(--samplesheet "$sheet")
disc="$("$HERE/discover-nfcore.sh" "${disc_args[@]}")" || babs_die "nf-core output not recognised (see messages above)"
getd() { sed -n "s/^$1=//p" <<<"$disc"; }
[[ -z "$ds" ]] && ds="$(getd DATA_SOURCE)"
outdir="$(getd NFCORE_OUTDIR)"
found_aligner="$(getd ALIGNER)"
mqc="$(getd MULTIQC_DIR)"
sheet="$(getd SAMPLESHEET)"
[[ "$ds" =~ ^[A-Za-z0-9._-]+$ ]] || babs_die "data source name '$ds' must be letters, digits, '.', '_' or '-'"

cd "$dir"
babs_require_workdir
mkdir -p extdata data

# --- experiment table (ingress + differential: tr -d '\r', cp)
tr -d '\r' < "$etable" > "${BABS_METADATA}.csv"

# --- config (ingress $(configs) recipe; md5 lines omitted, they are not used downstream)
cfg="extdata/${ds}.config"
if [[ -n "$config" ]]; then
  tr -d '\r' < "$config" > "$cfg"
  grep -q "^universal" "$cfg" || echo 'universal=yes' >> "$cfg"
  grep -q "^strandedness" "$cfg" || echo 'strandedness=auto' >> "$cfg"
  grep -q "^aligner" "$cfg" || echo "aligner=${aligner:-${found_aligner:-star_rsem}}" >> "$cfg"
  if [[ -n "$orgdb" ]] && ! grep -q "^\(${ds}\.\)\{0,1\}org\.db" "$cfg"; then echo "org.db=$orgdb" >> "$cfg"; fi
else
  { echo "org.db=$orgdb"; echo "aligner=${aligner:-${found_aligner:-star_rsem}}"; } > "$cfg"
fi
cfg_aligner="$(babs_config_get "$cfg" aligner)"
[[ "$cfg_aligner" == "$found_aligner" ]] || babs_die "config says aligner=$cfg_aligner but the nf-core output has $found_aligner"
cfg_org="$(babs_config_get "$cfg" "org\\.db")"; [[ -z "$cfg_org" ]] && cfg_org="$(babs_config_get "$cfg" "${ds}\\.org\\.db")"
[[ -n "$cfg_org" ]] || babs_warn "no org.db in $cfg: genes will not be annotated and 03_enrichment will be skipped"

# --- spec files
for s in "${specs[@]}"; do cp "$s" "extdata/$(basename "$s")"; done

# --- counts ($(genes_results) recipe)
cdir="${BABS_COUNTS_DIR}/${ds}"
rm -rf "$cdir"; mkdir -p "$cdir"
if [[ "$found_aligner" == star_salmon ]]; then
  for s in "$outdir"/star_salmon/*/quant.sf; do
    d="$cdir/star_salmon/$(basename "$(dirname "$s")")"; mkdir -p "$d"; cp -l "$s" "$d/" 2>/dev/null || cp "$s" "$d/"
  done
  cp "$outdir/star_salmon/salmon_tx2gene.tsv" "$cdir/star_salmon/"
else
  cp -l "$outdir"/star_rsem/*.genes.results "$cdir/" 2>/dev/null || cp "$outdir"/star_rsem/*.genes.results "$cdir/"
fi

# --- multiqc
babs_mkdir_ignored "$BABS_RESULTS_DIR"
if [[ -n "$mqc" ]]; then
  rm -rf "${BABS_RESULTS_DIR}/multiqc-${ds}"; mkdir -p "${BABS_RESULTS_DIR}/multiqc-${ds}"
  cp -lR "$mqc/." "${BABS_RESULTS_DIR}/multiqc-${ds}" 2>/dev/null || cp -R "$mqc/." "${BABS_RESULTS_DIR}/multiqc-${ds}"
fi

# --- samplesheet join ($(covariate_files_dep) recipe)
tmpd="$(mktemp -d /tmp/babs-stage.XXXXXX)"; trap 'rm -rf "$tmpd"' EXIT
if [[ -z "$sheet" ]]; then
  sheet="$tmpd/samplesheet_${ds}.csv"
  echo "sample" > "$sheet"
  if [[ "$found_aligner" == star_salmon ]]; then
    for s in "$outdir"/star_salmon/*/quant.sf; do basename "$(dirname "$s")"; done >> "$sheet"
  else
    for s in "$outdir"/star_rsem/*.genes.results; do basename "$s" .genes.results; done >> "$sheet"
  fi
fi
tr -d '\r' < "$sheet" > "$tmpd/sheet.csv"
sql="SELECT metadata.* FROM metadata INNER JOIN (SELECT * FROM \"${ds}\" GROUP BY ${BABS_SAMPLESHEET_ID_COLUMN}) AS nfcore on metadata.${BABS_METADATA_ID_COLUMN}=nfcore.${BABS_SAMPLESHEET_ID_COLUMN};"
# (-csv before -header: newer sqlite3 resets headers when the mode is set after them)
cp "${BABS_METADATA}.csv" "$tmpd/metadata.csv"
cat > "$tmpd/join.sh" <<EOSQL
set -e
cd "$tmpd"; rm -f join.db
sqlite3 join.db '.import --csv sheet.csv ${ds}'
sqlite3 join.db '.import --csv metadata.csv metadata'
sqlite3 -csv -header join.db '${sql}'
EOSQL
if command -v sqlite3 >/dev/null; then
  bash "$tmpd/join.sh" > "${BABS_METADATA}_${ds}.csv"
else
  # as in make, sqlite3 comes from the container when the host has none
  # (the temporary directory must be under /tmp, which the container binds)
  babs_load_env
  babs_exec bash "$tmpd/join.sh" > "${BABS_METADATA}_${ds}.csv"
fi

# report who was dropped
meta_ids="$(tail -n +2 "${BABS_METADATA}.csv" | cut -d, -f1 | tr -d '"' | LC_ALL=C sort -u)"
sheet_ids="$(tail -n +2 "$tmpd/sheet.csv" | cut -d, -f1 | tr -d '"' | LC_ALL=C sort -u)"
kept=$(( $(wc -l < "${BABS_METADATA}_${ds}.csv") - 1 ))
only_meta="$(LC_ALL=C comm -23 <(echo "$meta_ids") <(echo "$sheet_ids") | grep -v '^$' || true)"
only_sheet="$(LC_ALL=C comm -13 <(echo "$meta_ids") <(echo "$sheet_ids") | grep -v '^$' || true)"

# --- git add as the makefile does (keeps VERSION clean: git diff ignores the index)
git add "${BABS_METADATA}.csv" "$cfg" "${BABS_METADATA}_${ds}.csv" extdata/*.spec

echo "Staged data source '$ds' into $(pwd)"
echo "  counts:   $cdir ($found_aligner, $(find "$cdir" -name '*.genes.results' -o -name quant.sf | wc -l | tr -d ' ') samples)"
echo "  metadata: ${BABS_METADATA}_${ds}.csv ($kept samples kept)"
[[ -n "$only_meta" ]] && echo "  DROPPED (in experiment table, not in nf-core run): $(echo $only_meta)"
[[ -n "$only_sheet" ]] && echo "  NOT ANALYSED (in nf-core run, not in experiment table): $(echo $only_sheet)"
echo "  specs:    $(cd extdata && ls *.spec | tr '\n' ' ')"
echo "  multiqc:  ${mqc:+${BABS_RESULTS_DIR}/multiqc-${ds}}"
[[ $kept -gt 0 ]] || babs_die "no samples in common between the experiment table ID column and the nf-core samplesheet"
