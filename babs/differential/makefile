include ../config/global.mk
include local.mk
-include ../ingress/*.config
-include *.config

.PHONY: build run copy publish clean

run: analyses | run.sh

my_counts_dir=inst/extdata/genes.results
nfcore_dir=../nfcore/results
my_metadata=inst/extdata/metadata


alignments := $(patsubst ${my_counts_dir}/%,%,$(wildcard ${my_counts_dir}/*))
specfiles := $(patsubst %.spec,%,$(wildcard *.spec))
result_objs := $(foreach alignment,$(alignments),$(foreach spec,$(specfiles),data/$(spec)_x_$(alignment).dda))
align1 := $(firstword $(alignments))
spec1 := $(firstword $(specfiles))

.PHONY: analyses
analyses: $(result_objs)

define RESULT_RULE
data/$(spec)_x_$(alignment).dda : resdir = results/$(VERSION)/$(alignment)
data/$(spec)_x_$(alignment).dda : 01_analyse.r $(spec).spec data/counts_$(alignment).rda R.bib
	mkdir -p "$$(resdir)" 
	$(R) -e "rmarkdown::render('01_analyse.r',\
	 output_file='$(spec)_x_$(alignment)_$(TAG).html',\
	 output_options = list(self_contained=$(contained)),\
	 params=list(res_dir='$$(resdir)',spec_file='$(spec).spec', count_source='$(alignment)'))"
	mv -f "$(spec)_x_$(alignment)_$(TAG).html"  "$$(resdir)"
	rm -rf "$$(resdir)/$(spec)_x_$(alignment)_$(TAG)_files"
	mv "$(spec)_x_$(alignment)_$(TAG)_files" "$$(resdir)"
	ln -sfn "$(VERSION)" results/latest
endef

$(foreach spec,$(specfiles), \
   $(foreach alignment,$(alignments), \
     $(eval $(RESULT_RULE)) \
   ) \
)


count_objs := $(patsubst %,data/counts_%.rda,$(alignments)) %.config
$(count_objs) : data/counts_%.rda : 00_init.r $(wildcard $(my_counts_dir)/%/*.genes.results)
	$(R) -e "source('00_init.r')" --args count_source="$*" metadata="$(my_metadata)_$*.csv" file_col="$(meta2asf)" counts="$(my_counts_dir)/$*/" org_package="$($*.org.db)"


R.bib: renv.lock
	 $(R) -e 'knitr::write_bib(names(renv:::lockfile("renv.lock")$$data()$$Packages), file="$@",prefix="pkg_")'



################################################################
#### Bootrap all relevant data from outside
################################################################
run.sh: build

build: specfiles samplesheets genes_results scripts
	make -n -s run > run.sh

specfiles := $(patsubst ../docs/%,%,$(wildcard ../docs/*.spec))
specfiles: $(specfiles)
$(specfiles): %: ../docs/%
	cp $< $@


alignments := $(patsubst $(nfcore_dir)/%,%,$(wildcard $(nfcore_dir)/*))
samplesheets:= $(patsubst %,$(my_metadata)_%.csv,$(alignments))
samplesheets: $(samplesheets)
$(samplesheets) : $(my_metadata)_%.csv : samples.db
	$(SQLITE) -header -csv  samples.db 'SELECT metadata.* FROM metadata LEFT JOIN (SELECT * FROM fastqs GROUP BY $(label_column)) AS asf on metadata.$(meta2asf)=asf.$(label_column) WHERE asf._babs_config_file="$*";' > $@

samples.db: ../ingress/samples.db ../docs/$(BABS_TABLE).csv
	cp $< $@
	$(SQLITE) $@ -csv "DROP TABLE IF EXISTS metadata;"
	$(SQLITE) $@ -csv ".import $(word 2, $^) metadata"



genes_results := $(patsubst %,$(my_counts_dir)/%,$(alignments))
genes_results : $(genes_results)
$(genes_results): $(my_counts_dir)/%: $(nfcore_dir)/% %.config
	dir=$(if $($*.group-as),$($*.group-as),$*);\
	mkdir -p $(my_counts_dir)/$${dir} ;\
	ln -f $(nfcore_dir)/$${dir}/star_rsem/*.genes.results $(my_counts_dir)/$${dir}/ 


.PHONY: scripts
scripts = 00_init.r 01_analyse.r
scripts: $(scripts)

$(scripts) &: $(align1).config | renv.lock
	for file in $(scripts) ; do \
	  [ -f $${file} ] && git add "$${file}" || true;\
	done ;\
	if [ ! -z "$$(git diff --staged)" ] ; then \
	  git status ;\
	  echo "Please commit changes before re-running 'prepare_scripts'" ; exit 1 ;\
	fi ;\
	$(R) -e 'DESdemonA::get_started(files=commandArgs(trailing=TRUE),nfcore="", metadata="$(my_metadata)_$(align1).csv", file_col="$(meta2asf)",name_col=c($(NAME_COLUMN)), counts="$(my_counts_dir)/$(align1)/", org_package="$($(align1).org.db)", count_source="$(align1)", specfile="$(spec1)",  project="$(babsproject)", overwrite=TRUE)' --args $(scripts)
	git add $(scripts)
	echo -e 'Initialised by DESdemonA\n\n' `grep -A 4 DESdemonA renv.lock` | git commit -F - || true
	git rev-parse "v0.0.1" >/dev/null 2>&1 || git tag v0.0.1

renv.lock:orgs=$(subst $(space),$(comma),$(foreach align,$(alignments),$($(align).org.db))),
renv.lock:
	sed -i 's/^Imports:/Imports:\n    $(orgs)/' DESCRIPTION
	module purge ;\
	export RENV_PATHS_LIBRARY=renv/library ;\
	$(R) -e 'library(renv); renv::install("BiocManager"); options(repos=BiocManager::repositories()); renv::init(bioconductor=TRUE, bare=TRUE); renv::install(); renv::snapshot()'
	git add renv.lock
	git commit -m "Pipeline creates renv environment"


configs=$(patsubst ../ingress/%.config,%.config,$(wildcard ../ingress/*.config))

$(configs):%.config: ../ingress/%.config
	cp $< $@


copy:

clean:

publish:
