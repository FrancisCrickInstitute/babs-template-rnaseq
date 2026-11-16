#!/usr/bin/env bash
# Locate the files the differential stage pulls from an nf-core/rnaseq run.
# Prints KEY=VALUE lines (machine-readable) followed by a human summary on stderr.
#
# Usage: discover-nfcore.sh NFCORE_DIR [--data-source DS] [--samplesheet CSV]
#   NFCORE_DIR is either the run's --outdir (contains star_rsem/, multiqc/,
#   pipeline_info/) or a BABS babs/nfcore folder (contains results/DS/).
#
# Supported: nf-core/rnaseq 3.26.0, aligner star_rsem (plan decision 4).
# star_salmon is reported (00_init.qmd can read it) but untested.
set -uo pipefail
SHARED="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../shared" && pwd)"
source "$SHARED/scripts/common.sh"

SUPPORTED_VERSION=3.26.0
[[ $# -ge 1 ]] || babs_die "usage: $(basename "$0") NFCORE_DIR [--data-source DS] [--samplesheet CSV]"
root="$1"; shift
ds="" sheet=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --data-source) ds="$2"; shift 2 ;;
    --samplesheet) sheet="$2"; shift 2 ;;
    *) babs_die "unknown option $1" ;;
  esac
done
[[ -d "$root" ]] || babs_die "no such directory $root"
root="$(cd "$root" && pwd -P)"

outdir=""
if [[ -d "$root/star_rsem" || -d "$root/star_salmon" || -d "$root/pipeline_info" ]]; then
  outdir="$root"
elif [[ -d "$root/results" ]]; then
  if [[ -n "$ds" && -d "$root/results/$ds" ]]; then
    outdir="$root/results/$ds"
  else
    cands=$(cd "$root/results" && ls -d */ 2>/dev/null | tr -d /)
    babs_die "$root is a BABS nfcore folder; choose one with --data-source (found: ${cands:-none})"
  fi
fi
[[ -n "$outdir" ]] || babs_die "$root does not look like an nf-core/rnaseq output (no star_rsem/, star_salmon/ or pipeline_info/)"
[[ -z "$ds" ]] && ds="$(basename "$outdir")"

# aligner
aligner="" n_rsem=0 n_salmon=0 tx2gene=""
n_rsem=$(find "$outdir/star_rsem" -maxdepth 1 -name '*.genes.results' 2>/dev/null | wc -l | tr -d ' ')
n_salmon=$(find "$outdir/star_salmon" -mindepth 2 -maxdepth 2 -name quant.sf 2>/dev/null | wc -l | tr -d ' ')
[[ -f "$outdir/star_salmon/salmon_tx2gene.tsv" ]] && tx2gene="$outdir/star_salmon/salmon_tx2gene.tsv"
if [[ $n_rsem -gt 0 ]]; then aligner=star_rsem
elif [[ $n_salmon -gt 0 && -n "$tx2gene" ]]; then aligner=star_salmon
fi

# multiqc: BABS symlink results/DS/multi-qc -> multiqc/<aligner>/, else nf-core default locations
mqc=""
for c in "$outdir/multi-qc" "$outdir/multiqc/${aligner:-star_rsem}" "$outdir/multiqc"; do
  if [[ -f "$c/multiqc_report.html" ]]; then mqc="$c"; break; fi
done

# pipeline version
version=""
for f in "$outdir"/pipeline_info/*software*versions*.yml "$outdir"/pipeline_info/*.yml; do
  [[ -f "$f" ]] || continue
  version=$(sed -n 's/.*nf-core\/rnaseq:[[:space:]]*v\{0,1\}\([0-9][0-9.a-z-]*\).*/\1/p' "$f" | head -n1)
  [[ -n "$version" ]] && break
done
if [[ -z "$version" ]]; then
  for f in "$outdir"/pipeline_info/params_*.json "$outdir"/pipeline_info/execution_report*.html; do
    [[ -f "$f" ]] || continue
    version=$(grep -o 'nf-core/rnaseq[^0-9]\{0,20\}[0-9][0-9.]*' "$f" | grep -o '[0-9][0-9.]*$' | head -n1)
    [[ -n "$version" ]] && break
  done
fi

# samplesheet: explicit > BABS nfcore/samplesheet_DS.csv > nf-core samplesheet.valid.csv > derived
sheet_src=""
if [[ -n "$sheet" ]]; then
  [[ -f "$sheet" ]] || babs_die "samplesheet $sheet not found"
  sheet="$(cd "$(dirname "$sheet")" && pwd -P)/$(basename "$sheet")"; sheet_src=user
else
  for c in "$outdir/../../samplesheet_${ds}.csv" "$outdir/pipeline_info/samplesheet.valid.csv"; do
    if [[ -f "$c" ]] && head -1 "$c" | grep -q "^\"\{0,1\}sample\"\{0,1\},"; then
      sheet="$(cd "$(dirname "$c")" && pwd -P)/$(basename "$c")"; sheet_src=found; break
    fi
  done
  if [[ -z "$sheet" ]]; then sheet_src=derived; fi
fi

layout=recognised
reasons=()
if [[ -z "$aligner" ]]; then layout=unrecognised; reasons+=("no star_rsem/*.genes.results or star_salmon/*/quant.sf + salmon_tx2gene.tsv"); fi
[[ "$aligner" == star_salmon ]] && reasons+=("star_salmon input: understood by 00_init.qmd but not a tested path")
[[ -z "$mqc" ]] && reasons+=("no multiqc_report.html found (the report will omit the MultiQC link)")
if [[ -z "$version" ]]; then reasons+=("could not determine the nf-core/rnaseq version")
elif [[ "$version" != "$SUPPORTED_VERSION" ]]; then reasons+=("nf-core/rnaseq $version: only $SUPPORTED_VERSION is tested")
fi
[[ "$sheet_src" == derived ]] && reasons+=("no samplesheet found; sample list will be taken from the count file names")

echo "DATA_SOURCE=$ds"
echo "NFCORE_OUTDIR=$outdir"
echo "NFCORE_VERSION=$version"
echo "ALIGNER=$aligner"
echo "N_SAMPLES_RSEM=$n_rsem"
echo "N_SAMPLES_SALMON=$n_salmon"
echo "SALMON_TX2GENE=$tx2gene"
echo "MULTIQC_DIR=$mqc"
echo "SAMPLESHEET=$sheet"
echo "SAMPLESHEET_SOURCE=$sheet_src"
echo "LAYOUT=$layout"

{
  echo "nf-core output for data source '$ds': $outdir"
  echo "  version: ${version:-unknown}   aligner: ${aligner:-none found}   samples: rsem=$n_rsem salmon=$n_salmon"
  echo "  multiqc: ${mqc:-not found}"
  echo "  samplesheet: ${sheet:-<derived from count files>} ($sheet_src)"
  for r in "${reasons[@]:-}"; do [[ -n "$r" ]] && echo "  NOTE: $r"; done
} >&2
[[ "$layout" == recognised ]]
