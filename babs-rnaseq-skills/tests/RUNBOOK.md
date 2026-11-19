# Testing the plugin against the Phase 0 reference (plan Phases 2 to 7)

This runbook drives the plugin's scripts by hand on NEMO, page by page, on the
airway data, and compares each stage with the frozen Phase 0 reference using
`compare-to-reference.sh`. No agent is involved yet; that is Phase 8.

Pass standard (plan section 6): identical data objects and tables once the
version stamps are replaced by placeholders, the same set of figure names, and
staged qmd/yml files identical apart from the stamps and the author block.

Run every block from the same shell, inside one compute allocation. Each
phase saves a report under `$T/reports/`. Send those back for review.

## 0. Set up (once)

**Get a compute allocation.** Page 03 needs the most memory.

```bash
srun --cpus-per-task=8 --mem=64G --time=4:00:00 --pty bash
```

**Set the paths.** These are real paths, not placeholders.

```bash
REPO=/nemo/stp/babs/working/bootj/github/babs-template-rnaseq
PLUGIN=$REPO/babs-rnaseq-skills
REFARC=/nemo/stp/babs/working/bootj/phase0-reference-20261119
T=/flask/scratch/babs/$USER/skills-test
REF=$T/reference/differential
NF=$T/nfcore
WORK=$T/airway
DOCS=$REPO/airway/docs
```

**Check out the plugin branch on NEMO.** The NEMO clone is on `main`.
Switching is safe: `agentic_skills` is `main` plus the plugin and the plan.

```bash
cd $REPO && git fetch origin && git checkout agentic_skills && git pull --ff-only && git log --oneline -1
```

**Unpack the reference and the cached nf-core output.** Nothing here writes
into the repo.

```bash
mkdir -p $T/reference $NF $T/reports
tar xzf $REFARC/differential.tar.gz -C $T/reference
tar xzf $REFARC/nfcore.tar.gz -C $NF
ls $REF/data $NF/results/GRCh38/star_rsem | head
```

**Write the site settings.** The drivers read `.env.local` from the analysis
directory or any parent, as make does. Put it in `$T` so it never ends up
inside the analysis directory. It points at the same image and renv cache as
Phase 0, so nothing new is downloaded.

```bash
cat > $T/.env.local <<EOF
export SINGULARITY_MODULE=Singularity/3.11.3
export SINGULARITY_IMAGEDIR=/flask/scratch/babs/$USER/singularity
export SINGULARITYENV_RENV_PATHS_ROOT=/flask/scratch/babs/$USER/renv
EOF
```

**A shorthand for the comparison.** It always compares against `$REF` and
writes the report given as the first argument.

```bash
cmpref() { local out=$1; shift; bash $PLUGIN/tests/compare-to-reference.sh --ref $REF --run $WORK --report $T/reports/$out "$@"; }
```

## Phase 2: environment (plan step 7)

**Check the container and renv cache.** Expect `Environment OK`. The image
should already be present from Phase 0.

```bash
bash $PLUGIN/skills/rnaseq-env-setup/scripts/check-env.sh --dir $T --pull 2>&1 | tee $T/reports/phase2-env.txt
```

The in-container package check needs a restored analysis directory, so it
runs at the end of Phase 3 setup below.

## Phase 3: ingest and 00_init (plan steps 8 to 10)

**Create the analysis directory.** It prints the VERSION, which ends in
`bootstrap-isolated-analysis` at this point and in `unreleased` once
`restore-renv.sh` commits. If git's default branch on NEMO is not `main`,
the branch name is prefixed, for example `master.unreleased`. That is how
make names it too, and the comparison ignores it.

```bash
bash $PLUGIN/skills/rnaseq-ingest/scripts/init-workdir.sh $WORK
```

**Stage the airway inputs.** These are the same files the reference run used:
the experiment table, spec and config from `airway/docs`, and the cached
nf-core output in the BABS folder layout. Expect 8 samples kept, none dropped.

```bash
bash $PLUGIN/skills/rnaseq-ingest/scripts/stage-inputs.sh --dir $WORK --nfcore $NF --data-source GRCh38 --experiment-table $DOCS/experiment_table.csv --spec $DOCS/analyse.spec --config $DOCS/GRCh38.config 2>&1 | tee $T/reports/phase3-stage.txt
```

**Validate the inputs.** Expect `Inputs valid`. A warning about a missing
`sample_label` column is normal for airway.

```bash
bash $PLUGIN/skills/rnaseq-ingest/scripts/validate-inputs.sh --dir $WORK 2>&1 | tee $T/reports/phase3-validate.txt
```

**Restore renv and write the bibliography.** This installs `org.Hs.eg.db`
and commits once. It is quick when the Phase 0 renv cache is in place.

```bash
bash $PLUGIN/skills/rnaseq-env-setup/scripts/restore-renv.sh --dir $WORK 2>&1 | tail -20
```

**Finish the Phase 2 check inside the container.** Expect R 4.6.0 and quarto
1.9.36, as in the reference provenance, and no package reported `MISSING`.

```bash
bash $PLUGIN/skills/rnaseq-env-setup/scripts/check-env.sh --dir $WORK --deep 2>&1 | tee -a $T/reports/phase2-env.txt
```

**Compare the lockfile with the reference's.** The reference run ended with
`org.Hs.eg.db` 3.23.1 added and `rlang` at 1.3.0. Any other version
difference is worth reporting, even if every later check passes.

```bash
diff <(grep -A1 '"Package"' $REF/renv.lock | grep -v '^--') <(grep -A1 '"Package"' $WORK/renv.lock | grep -v '^--') | tee $T/reports/phase3-renv-diff.txt
```

**Compare the staged inputs.** Every line should be PASS.

```bash
cmpref phase3-inputs.txt --stage inputs
```

**Render 00_init and summarise it.** The render takes a few minutes.

```bash
bash $PLUGIN/shared/scripts/render-section.sh --dir $WORK 00_init GRCh38
```

```bash
bash $PLUGIN/shared/scripts/run-r-helper.sh --dir $WORK $PLUGIN/skills/rnaseq-ingest/scripts/summarise-counts.R GRCh38 | tee $T/reports/phase3-summary.txt
```

**Compare 00_init.** This checks the page for R errors, the staged qmd, yml
and params files, and the counts object. The reference has no table folder
for this page, so that line is SKIP.

```bash
cmpref phase3-00_init.txt --stage 00_init
```

## Phase 4: 01_exploratory (plan steps 11 and 12)

```bash
bash $PLUGIN/shared/scripts/render-section.sh --dir $WORK 01_exploratory GRCh38 analyse
```

```bash
bash $PLUGIN/shared/scripts/run-r-helper.sh --dir $WORK $PLUGIN/skills/rnaseq-exploratory/scripts/summarise-exploratory.R GRCh38 analyse | tee $T/reports/phase4-summary.txt
```

**Compare.** This covers `ddsList_GRCh38_analyse.rda`, the plot data object,
every tsv and csv in the page folder, and the figure names.

```bash
cmpref phase4-01_exploratory.txt --stage 01_exploratory
```

## Phase 5: 02_differential (plan steps 13 and 14)

```bash
bash $PLUGIN/shared/scripts/render-section.sh --dir $WORK 02_differential GRCh38 analyse
```

```bash
bash $PLUGIN/shared/scripts/run-r-helper.sh --dir $WORK $PLUGIN/skills/rnaseq-differential/scripts/summarise-differential.R GRCh38 analyse | tee $T/reports/phase5-summary.txt
```

**Compare.** This covers every comparison's results table in
`analyse_x_GRCh38.rds`, including padj, shrunkLFC and class, and the xlsx
workbook sheet by sheet.

```bash
cmpref phase5-02_differential.txt --stage 02_differential
```

## Phase 6: 03_enrichment (plan steps 15 and 16)

```bash
bash $PLUGIN/shared/scripts/render-section.sh --dir $WORK 03_enrichment GRCh38 analyse
```

```bash
bash $PLUGIN/shared/scripts/run-r-helper.sh --dir $WORK $PLUGIN/skills/rnaseq-enrichment/scripts/summarise-enrichment.R GRCh38 analyse | tee $T/reports/phase6-summary.txt
```

```bash
cmpref phase6-03_enrichment.txt --stage 03_enrichment
```

## Phase 7: report site (plan step 17)

```bash
bash $PLUGIN/skills/rnaseq-report/scripts/build-site.sh --dir $WORK
```

```bash
bash $PLUGIN/skills/rnaseq-report/scripts/list-outputs.sh --dir $WORK | tee $T/reports/phase7-outputs.txt
```

**Check every file named in the manifest exists.** This is what the download
links point at. It should print nothing.

```bash
cd $WORK && tail -n +2 results/latest/manifest_*.txt | cut -f1 | while read -r f; do [ -f "$f" ] || echo "MISSING $f"; done; cd - >/dev/null
```

**Run the full comparison.** This repeats every stage and adds the site
checks. It is the one report that sums up Phases 3 to 7.

```bash
cmpref phase7-all.txt
```

**Look at the site.** Flask scratch is not mounted on the Mac, so copy the
results to your working area first.

```bash
rsync -a $WORK/results/ /nemo/stp/babs/working/$USER/skills-test-site/
```

Then open `/Volumes/babs/working/bootj/skills-test-site/latest/index.html` on
the Mac. The index should list all four pages, and each page should open.

## Reading the reports

- **PASS** means identical once the version stamps are replaced.
- **FAIL** means a real difference, or a missing or unexpected file. The
  lines under it show the first differences. An object FAIL lists each part
  of the object that differs, by its path inside the object.
- **WARN** marks a difference plan section 6 allows, such as the author
  block. It is shown so you can confirm that is all it is.
- **SKIP** means there is nothing to compare, or the page is not rendered yet.

If a stage fails, fix the driver scripts, never the vendored R or qmd code,
and re-render from that page onwards. A change to any tracked file in `$WORK`
flips VERSION to `modified`, and later pages then cannot find their parent. In
that case start again from `init-workdir.sh` in a fresh `$WORK`.

## What to send back

The contents of `$T/reports/`, as a list or a tarball:

```bash
tar czf $T/skills-test-reports.tgz -C $T reports && ls -l $T/skills-test-reports.tgz
```

When every report is PASS, the plan's Phases 2 to 7 are complete, and the
plugin README's "Tested" line becomes true.
